//+------------------------------------------------------------------+
//|                                                Divergences.mqh   |
//|                     CHAPITRE 9 - DIVERGENCES PROFESSIONNELLES    |
//|                     SYSTÈME D'ANTICIPATION - PAS UN SIGNAL       |
//|                     Bot Multi-Marchés Forex & Crypto             |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "2.00"
#property strict

#include "CandleAnalysis.mqh"
#include "MarketStructure.mqh"

//+------------------------------------------------------------------+
//| PHILOSOPHIE:                                                      |
//| Une divergence n'est PAS un signal d'entrée                      |
//| C'est un signal d'ANTICIPATION                                    |
//|                                                                   |
//| Le module doit:                                                   |
//|   - Détecter un déséquilibre                                     |
//|   - Prévenir d'un affaiblissement                                |
//|   - Attendre une confirmation externe                            |
//|   - Alimenter le moteur de décision                              |
//|                                                                   |
//| ❌ Aucun trade                                                    |
//| ❌ Aucun signal instantané                                        |
//| ✅ Analyse contextuelle                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Types de divergence                                               |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
{
   DIV_NONE = 0,
   DIV_BULLISH_REGULAR,     // Divergence haussière classique (retournement)
   DIV_BEARISH_REGULAR,     // Divergence baissière classique (retournement)
   DIV_BULLISH_HIDDEN,      // Divergence haussière cachée (continuation)
   DIV_BEARISH_HIDDEN       // Divergence baissière cachée (continuation)
};

//+------------------------------------------------------------------+
//| Indicateur source de la divergence                                |
//+------------------------------------------------------------------+
enum ENUM_DIV_INDICATOR
{
   DIV_IND_RSI = 0,         // RSI (14)
   DIV_IND_MACD,            // MACD Histogramme
   DIV_IND_BOTH             // Les deux confirment
};

//+------------------------------------------------------------------+
//| Statut de la divergence - CRITIQUE                                |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_STATUS
{
   DIV_STATUS_NONE = 0,
   DIV_STATUS_DETECTED,     // Divergence détectée, en attente
   DIV_STATUS_CONFIRMED,    // Confirmée par structure/pattern
   DIV_STATUS_INVALIDATED,  // Invalidée (prix a cassé dans le sens opposé)
   DIV_STATUS_EXPIRED       // Expirée (trop vieille)
};

//+------------------------------------------------------------------+
//| Force/Qualité de la divergence                                    |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_QUALITY
{
   DIV_QUALITY_WEAK = 0,    // Faible (juste visible)
   DIV_QUALITY_MODERATE,    // Modérée (claire)
   DIV_QUALITY_STRONG,      // Forte (très nette)
   DIV_QUALITY_EXTREME      // Extrême (impossible à ignorer)
};

//+------------------------------------------------------------------+
//| Structure d'un point Swing                                        |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   int               bar;           // Index de la barre
   datetime          time;          // Timestamp
   double            price;         // Prix (High ou Low)
   double            rsiValue;      // Valeur RSI à ce point
   double            macdHist;      // Valeur histogramme MACD
   bool              isValid;       // Point valide (fractal confirmé)
};

//+------------------------------------------------------------------+
//| Structure complète d'une divergence                               |
//+------------------------------------------------------------------+
struct SDivergence
{
   // Identification
   ENUM_DIVERGENCE_TYPE     type;              // Type de divergence
   ENUM_DIV_INDICATOR       indicator;         // Indicateur source
   ENUM_DIVERGENCE_STATUS   status;            // Statut actuel
   ENUM_DIVERGENCE_QUALITY  quality;           // Force/qualité
   ENUM_TIMEFRAMES          timeframe;         // Timeframe de détection

   // Points de la divergence
   SSwingPoint              point1;            // Premier point (plus ancien)
   SSwingPoint              point2;            // Deuxième point (plus récent)

   // Mesures
   double                   priceDivergence;   // Écart de prix en %
   double                   indicatorDivergence; // Écart indicateur en %
   int                      barsSpan;          // Nombre de barres entre les points
   int                      barsSinceDetection; // Barres depuis détection

   // Confirmation
   bool                     isConfirmed;       // Confirmé par structure/pattern
   string                   confirmationType;  // Type de confirmation
   datetime                 detectionTime;     // Timestamp de détection
   datetime                 confirmationTime;  // Timestamp de confirmation

   // Filtres
   bool                     passedFilters;     // A passé les filtres anti-faux
   string                   filterMessage;     // Message si filtré

   // Score global
   int                      score;             // Score de qualité (0-100)
};

//+------------------------------------------------------------------+
//| Structure pour le tracking multi-timeframe                        |
//+------------------------------------------------------------------+
struct SMTFDivergence
{
   SDivergence              daily;             // Divergence Daily
   SDivergence              h4;                // Divergence H4
   SDivergence              h1;                // Divergence H1
   SDivergence              m15;               // Divergence M15
   bool                     hasAlignment;      // Alignement MTF
   string                   alignmentDesc;     // Description alignement
};

//+------------------------------------------------------------------+
//| Classe de détection des divergences PROFESSIONNELLE               |
//+------------------------------------------------------------------+
class CDivergences
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Handles indicateurs
   int               m_rsiHandle;
   int               m_macdHandle;

   // Buffers
   double            m_rsiBuffer[];
   double            m_macdBuffer[];
   double            m_signalBuffer[];
   double            m_histBuffer[];

   // Paramètres de détection Swing
   int               m_fractalBars;       // Barres à gauche/droite pour fractal (défaut: 3)
   int               m_lookbackBars;      // Période de recherche (défaut: 100)
   int               m_minSwingDistance;  // Distance min entre swings (défaut: 5)
   int               m_maxSwingDistance;  // Distance max entre swings (défaut: 50)

   // Seuils de significativité
   double            m_minPriceDivergence;    // Écart prix min % (défaut: 0.1%)
   double            m_minIndicatorDivergence; // Écart indicateur min (défaut: 3 points RSI)

   // Paramètres d'expiration
   int               m_maxBarsToConfirm;  // Max barres pour confirmation (défaut: 20)
   int               m_maxBarsToExpire;   // Max barres avant expiration (défaut: 50)

   // Cache des divergences actives
   SDivergence       m_activeDivergences[];
   int               m_maxActiveDivergences;

   // Références externes
   CCandleAnalysis   *m_candleAnalysis;
   CMarketStructure  *m_marketStructure;

   // ============ MÉTHODES PRIVÉES ============

   // Chargement des buffers
   bool              LoadIndicatorBuffers(int count);

   // Détection des Swing Points (PRIORITÉ ABSOLUE)
   bool              IsSwingLow(int bar);
   bool              IsSwingHigh(int bar);
   void              FindSwingLows(SSwingPoint &points[], int maxPoints);
   void              FindSwingHighs(SSwingPoint &points[], int maxPoints);
   bool              ValidateSwingPoint(SSwingPoint &point);

   // Calcul des divergences
   bool              CalculateDivergence(SSwingPoint &p1, SSwingPoint &p2,
                                         ENUM_DIVERGENCE_TYPE expectedType,
                                         ENUM_DIV_INDICATOR ind, SDivergence &div);
   ENUM_DIVERGENCE_QUALITY EvaluateQuality(SDivergence &div);
   int               CalculateScore(SDivergence &div);

   // Filtres anti-faux signaux
   bool              ApplyFilters(SDivergence &div);
   bool              FilterRSIZone(SDivergence &div);
   bool              FilterMACDDirection(SDivergence &div);
   bool              FilterImpulseCandle(SDivergence &div);
   bool              FilterRetailTrap(SDivergence &div);

   // Gestion du cache
   void              AddToCache(SDivergence &div);
   void              UpdateCache();
   void              CleanExpiredDivergences();

public:
   CDivergences();
   ~CDivergences();

   // ============ INITIALISATION ============
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetFractalParams(int fractalBars, int lookback);
   void              SetSwingDistance(int minDist, int maxDist);
   void              SetSignificanceThresholds(double minPrice, double minIndicator);
   void              SetExpirationParams(int maxConfirm, int maxExpire);
   void              SetAnalyzers(CCandleAnalysis *candle, CMarketStructure *structure);

   // ============ DÉTECTION PRINCIPALE ============

   // Divergences Classiques (RETOURNEMENT)
   bool              DetectBullishRegular(SDivergence &div);
   bool              DetectBearishRegular(SDivergence &div);

   // Divergences Cachées (CONTINUATION)
   bool              DetectBullishHidden(SDivergence &div);
   bool              DetectBearishHidden(SDivergence &div);

   // Détection automatique (toutes)
   bool              DetectAny(SDivergence &div);
   bool              DetectAll(SDivergence &divergences[], int &count);

   // ============ SYSTÈME DE STATUT ============

   // Mise à jour du statut
   ENUM_DIVERGENCE_STATUS UpdateStatus(SDivergence &div);
   bool              CheckConfirmation(SDivergence &div);
   bool              CheckInvalidation(SDivergence &div);
   bool              IsExpired(SDivergence &div);

   // Vérification de confirmation
   bool              HasStructureBreakConfirmation(SDivergence &div);
   bool              HasCandlePatternConfirmation(SDivergence &div);
   bool              HasPriceRejection(SDivergence &div);

   // ============ MULTI-TIMEFRAME ============
   bool              GetMTFDivergence(SMTFDivergence &mtf);
   bool              HasMTFAlignment(ENUM_DIVERGENCE_TYPE type);
   string            GetMTFAnalysis();

   // ============ ACCÈS AUX DIVERGENCES ACTIVES ============
   int               GetActiveDivergenceCount();
   bool              GetActiveDivergence(int index, SDivergence &div);
   bool              HasPendingDivergence(ENUM_DIVERGENCE_TYPE type);
   bool              HasConfirmedDivergence(ENUM_DIVERGENCE_TYPE type);

   // ============ INTÉGRATION MOTEUR DE DÉCISION ============

   // Pour le système de confluence
   bool              SupportsBullishSetup();
   bool              SupportsBearishSetup();
   bool              ContradictsDirection(bool isBullish);
   int               GetDivergenceScore();

   // ============ UTILITAIRES ============
   string            TypeToString(ENUM_DIVERGENCE_TYPE type);
   string            StatusToString(ENUM_DIVERGENCE_STATUS status);
   string            QualityToString(ENUM_DIVERGENCE_QUALITY quality);
   string            GetDivergenceDescription(SDivergence &div);
   string            GetAlertMessage(SDivergence &div);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CDivergences::CDivergences()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_rsiHandle = INVALID_HANDLE;
   m_macdHandle = INVALID_HANDLE;

   // Paramètres par défaut - Swing Detection
   m_fractalBars = 3;           // 3 barres de chaque côté
   m_lookbackBars = 100;        // 100 barres de recherche
   m_minSwingDistance = 5;      // Min 5 barres entre swings
   m_maxSwingDistance = 50;     // Max 50 barres entre swings

   // Seuils de significativité
   m_minPriceDivergence = 0.001;    // 0.1% minimum
   m_minIndicatorDivergence = 3.0;  // 3 points RSI minimum

   // Expiration
   m_maxBarsToConfirm = 20;     // 20 barres pour confirmer
   m_maxBarsToExpire = 50;      // 50 barres avant expiration

   // Cache
   m_maxActiveDivergences = 10;
   ArrayResize(m_activeDivergences, 0);

   // Références
   m_candleAnalysis = NULL;
   m_marketStructure = NULL;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CDivergences::~CDivergences()
{
   if(m_rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_rsiHandle);
      m_rsiHandle = INVALID_HANDLE;
   }
   if(m_macdHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_macdHandle);
      m_macdHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CDivergences::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   // Créer handle RSI (14 périodes standard)
   m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur création handle RSI pour divergences");
      return false;
   }

   // Créer handle MACD (12, 26, 9 standard)
   m_macdHandle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
   if(m_macdHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur création handle MACD pour divergences");
      return false;
   }

   // Configuration des buffers
   ArraySetAsSeries(m_rsiBuffer, true);
   ArraySetAsSeries(m_macdBuffer, true);
   ArraySetAsSeries(m_signalBuffer, true);
   ArraySetAsSeries(m_histBuffer, true);

   Print("✅ Module Divergences initialisé: ", m_symbol, " ", EnumToString(m_timeframe));
   return true;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres Fractal                              |
//+------------------------------------------------------------------+
void CDivergences::SetFractalParams(int fractalBars, int lookback)
{
   m_fractalBars = MathMax(2, fractalBars);
   m_lookbackBars = MathMax(50, lookback);
}

//+------------------------------------------------------------------+
//| Configuration distance entre Swings                               |
//+------------------------------------------------------------------+
void CDivergences::SetSwingDistance(int minDist, int maxDist)
{
   m_minSwingDistance = MathMax(3, minDist);
   m_maxSwingDistance = MathMax(m_minSwingDistance + 10, maxDist);
}

//+------------------------------------------------------------------+
//| Configuration seuils de significativité                           |
//+------------------------------------------------------------------+
void CDivergences::SetSignificanceThresholds(double minPrice, double minIndicator)
{
   m_minPriceDivergence = MathMax(0.0001, minPrice);
   m_minIndicatorDivergence = MathMax(1.0, minIndicator);
}

//+------------------------------------------------------------------+
//| Configuration expiration                                          |
//+------------------------------------------------------------------+
void CDivergences::SetExpirationParams(int maxConfirm, int maxExpire)
{
   m_maxBarsToConfirm = MathMax(5, maxConfirm);
   m_maxBarsToExpire = MathMax(m_maxBarsToConfirm + 10, maxExpire);
}

//+------------------------------------------------------------------+
//| Définir les analyseurs externes                                   |
//+------------------------------------------------------------------+
void CDivergences::SetAnalyzers(CCandleAnalysis *candle, CMarketStructure *structure)
{
   m_candleAnalysis = candle;
   m_marketStructure = structure;
}

//+------------------------------------------------------------------+
//| Charger les buffers indicateurs                                   |
//+------------------------------------------------------------------+
bool CDivergences::LoadIndicatorBuffers(int count)
{
   if(m_rsiHandle == INVALID_HANDLE || m_macdHandle == INVALID_HANDLE)
      return false;

   // Vérifier qu'on a assez de barres
   int available = Bars(m_symbol, m_timeframe);
   if(available < count)
   {
      Print("⚠️ Pas assez de barres disponibles: ", available, " < ", count);
      return false;
   }

   // Charger RSI
   if(CopyBuffer(m_rsiHandle, 0, 0, count, m_rsiBuffer) < count)
   {
      Print("⚠️ Erreur chargement buffer RSI");
      return false;
   }

   // Charger MACD (ligne principale)
   if(CopyBuffer(m_macdHandle, 0, 0, count, m_macdBuffer) < count)
   {
      Print("⚠️ Erreur chargement buffer MACD");
      return false;
   }

   // Charger Signal
   if(CopyBuffer(m_macdHandle, 1, 0, count, m_signalBuffer) < count)
   {
      Print("⚠️ Erreur chargement buffer Signal");
      return false;
   }

   // Calculer histogramme
   ArrayResize(m_histBuffer, count);
   for(int i = 0; i < count; i++)
   {
      m_histBuffer[i] = m_macdBuffer[i] - m_signalBuffer[i];
   }

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si une barre est un Swing Low (FRACTAL)                  |
//| RÈGLE: N barres plus hautes à gauche ET à droite                  |
//+------------------------------------------------------------------+
bool CDivergences::IsSwingLow(int bar)
{
   // Vérifier les limites
   if(bar < m_fractalBars || bar >= m_lookbackBars - m_fractalBars)
      return false;

   double currentLow = iLow(m_symbol, m_timeframe, bar);

   // Vérifier les barres à gauche (plus récentes)
   for(int i = 1; i <= m_fractalBars; i++)
   {
      if(iLow(m_symbol, m_timeframe, bar - i) <= currentLow)
         return false;
   }

   // Vérifier les barres à droite (plus anciennes)
   for(int i = 1; i <= m_fractalBars; i++)
   {
      if(iLow(m_symbol, m_timeframe, bar + i) <= currentLow)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si une barre est un Swing High (FRACTAL)                 |
//| RÈGLE: N barres plus basses à gauche ET à droite                  |
//+------------------------------------------------------------------+
bool CDivergences::IsSwingHigh(int bar)
{
   // Vérifier les limites
   if(bar < m_fractalBars || bar >= m_lookbackBars - m_fractalBars)
      return false;

   double currentHigh = iHigh(m_symbol, m_timeframe, bar);

   // Vérifier les barres à gauche (plus récentes)
   for(int i = 1; i <= m_fractalBars; i++)
   {
      if(iHigh(m_symbol, m_timeframe, bar - i) >= currentHigh)
         return false;
   }

   // Vérifier les barres à droite (plus anciennes)
   for(int i = 1; i <= m_fractalBars; i++)
   {
      if(iHigh(m_symbol, m_timeframe, bar + i) >= currentHigh)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Trouver tous les Swing Lows valides                               |
//+------------------------------------------------------------------+
void CDivergences::FindSwingLows(SSwingPoint &points[], int maxPoints)
{
   ArrayResize(points, 0);

   if(!LoadIndicatorBuffers(m_lookbackBars))
      return;

   int found = 0;

   // Parcourir de la barre la plus récente à la plus ancienne
   for(int bar = m_fractalBars; bar < m_lookbackBars - m_fractalBars && found < maxPoints; bar++)
   {
      if(IsSwingLow(bar))
      {
         SSwingPoint point;
         point.bar = bar;
         point.time = iTime(m_symbol, m_timeframe, bar);
         point.price = iLow(m_symbol, m_timeframe, bar);
         point.rsiValue = m_rsiBuffer[bar];
         point.macdHist = m_histBuffer[bar];
         point.isValid = true;

         // Valider le point
         if(ValidateSwingPoint(point))
         {
            int size = ArraySize(points);
            ArrayResize(points, size + 1);
            points[size] = point;
            found++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trouver tous les Swing Highs valides                              |
//+------------------------------------------------------------------+
void CDivergences::FindSwingHighs(SSwingPoint &points[], int maxPoints)
{
   ArrayResize(points, 0);

   if(!LoadIndicatorBuffers(m_lookbackBars))
      return;

   int found = 0;

   // Parcourir de la barre la plus récente à la plus ancienne
   for(int bar = m_fractalBars; bar < m_lookbackBars - m_fractalBars && found < maxPoints; bar++)
   {
      if(IsSwingHigh(bar))
      {
         SSwingPoint point;
         point.bar = bar;
         point.time = iTime(m_symbol, m_timeframe, bar);
         point.price = iHigh(m_symbol, m_timeframe, bar);
         point.rsiValue = m_rsiBuffer[bar];
         point.macdHist = m_histBuffer[bar];
         point.isValid = true;

         // Valider le point
         if(ValidateSwingPoint(point))
         {
            int size = ArraySize(points);
            ArrayResize(points, size + 1);
            points[size] = point;
            found++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Valider un point Swing                                            |
//+------------------------------------------------------------------+
bool CDivergences::ValidateSwingPoint(SSwingPoint &point)
{
   // Vérifier que les valeurs indicateurs sont valides
   if(point.rsiValue <= 0 || point.rsiValue >= 100)
      return false;

   // Le point est valide
   return true;
}

//+------------------------------------------------------------------+
//| Calculer et valider une divergence                                |
//+------------------------------------------------------------------+
bool CDivergences::CalculateDivergence(SSwingPoint &p1, SSwingPoint &p2,
                                        ENUM_DIVERGENCE_TYPE expectedType,
                                        ENUM_DIV_INDICATOR ind, SDivergence &div)
{
   // Initialiser la structure
   div.type = DIV_NONE;
   div.indicator = ind;
   div.status = DIV_STATUS_NONE;
   div.quality = DIV_QUALITY_WEAK;
   div.timeframe = m_timeframe;
   div.point1 = p1;
   div.point2 = p2;
   div.isConfirmed = false;
   div.confirmationType = "";
   div.passedFilters = false;
   div.filterMessage = "";
   div.score = 0;

   // Calculer les écarts
   double avgPrice = (p1.price + p2.price) / 2.0;
   div.priceDivergence = MathAbs(p2.price - p1.price) / avgPrice;

   // Écart indicateur selon le type
   double ind1 = 0, ind2 = 0;
   if(ind == DIV_IND_RSI || ind == DIV_IND_BOTH)
   {
      ind1 = p1.rsiValue;
      ind2 = p2.rsiValue;
   }
   else if(ind == DIV_IND_MACD)
   {
      ind1 = p1.macdHist;
      ind2 = p2.macdHist;
   }
   div.indicatorDivergence = MathAbs(ind2 - ind1);

   // Calculer la distance en barres
   div.barsSpan = MathAbs(p2.bar - p1.bar);
   div.barsSinceDetection = p2.bar;  // Plus récent point

   // Vérifier la distance entre les swings
   if(div.barsSpan < m_minSwingDistance || div.barsSpan > m_maxSwingDistance)
      return false;

   // Vérifier le seuil de significativité
   if(div.priceDivergence < m_minPriceDivergence)
      return false;

   if(ind == DIV_IND_RSI && div.indicatorDivergence < m_minIndicatorDivergence)
      return false;

   // Vérifier le type attendu
   bool priceLL = (p2.price < p1.price);
   bool priceHH = (p2.price > p1.price);
   bool priceHL = (p2.price > p1.price);
   bool priceLH = (p2.price < p1.price);

   bool indHL = (ind2 > ind1);
   bool indLH = (ind2 < ind1);
   bool indLL = (ind2 < ind1);
   bool indHH = (ind2 > ind1);

   switch(expectedType)
   {
      case DIV_BULLISH_REGULAR:
         // Prix fait LL, Indicateur fait HL
         if(!(priceLL && indHL)) return false;
         break;

      case DIV_BEARISH_REGULAR:
         // Prix fait HH, Indicateur fait LH
         if(!(priceHH && indLH)) return false;
         break;

      case DIV_BULLISH_HIDDEN:
         // Prix fait HL, Indicateur fait LL (continuation haussière)
         if(!(priceHL && indLL)) return false;
         break;

      case DIV_BEARISH_HIDDEN:
         // Prix fait LH, Indicateur fait HH (continuation baissière)
         if(!(priceLH && indHH)) return false;
         break;

      default:
         return false;
   }

   // La divergence est valide!
   div.type = expectedType;
   div.status = DIV_STATUS_DETECTED;
   div.detectionTime = TimeCurrent();

   // Évaluer la qualité
   div.quality = EvaluateQuality(div);

   // Appliquer les filtres anti-faux signaux
   div.passedFilters = ApplyFilters(div);

   // Calculer le score
   div.score = CalculateScore(div);

   return true;
}

//+------------------------------------------------------------------+
//| Évaluer la qualité d'une divergence                               |
//+------------------------------------------------------------------+
ENUM_DIVERGENCE_QUALITY CDivergences::EvaluateQuality(SDivergence &div)
{
   int qualityPoints = 0;

   // 1. Écart de prix (plus c'est grand, mieux c'est)
   if(div.priceDivergence > 0.005) qualityPoints += 2;      // > 0.5%
   else if(div.priceDivergence > 0.002) qualityPoints += 1; // > 0.2%

   // 2. Écart indicateur
   if(div.indicatorDivergence > 15) qualityPoints += 2;     // > 15 points
   else if(div.indicatorDivergence > 8) qualityPoints += 1; // > 8 points

   // 3. Distance entre swings (ni trop près ni trop loin)
   if(div.barsSpan >= 10 && div.barsSpan <= 30) qualityPoints += 2;
   else if(div.barsSpan >= 5 && div.barsSpan <= 40) qualityPoints += 1;

   // 4. RSI en zone extrême (plus de poids)
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      if(div.point2.rsiValue < 25) qualityPoints += 2;
      else if(div.point2.rsiValue < 35) qualityPoints += 1;
   }
   else
   {
      if(div.point2.rsiValue > 75) qualityPoints += 2;
      else if(div.point2.rsiValue > 65) qualityPoints += 1;
   }

   // 5. Double confirmation (RSI + MACD)
   if(div.indicator == DIV_IND_BOTH) qualityPoints += 2;

   // Déterminer la qualité
   if(qualityPoints >= 8) return DIV_QUALITY_EXTREME;
   if(qualityPoints >= 6) return DIV_QUALITY_STRONG;
   if(qualityPoints >= 4) return DIV_QUALITY_MODERATE;
   return DIV_QUALITY_WEAK;
}

//+------------------------------------------------------------------+
//| Calculer le score global (0-100)                                  |
//+------------------------------------------------------------------+
int CDivergences::CalculateScore(SDivergence &div)
{
   int score = 0;

   // Base selon la qualité
   switch(div.quality)
   {
      case DIV_QUALITY_EXTREME:  score = 40; break;
      case DIV_QUALITY_STRONG:   score = 30; break;
      case DIV_QUALITY_MODERATE: score = 20; break;
      default:                   score = 10; break;
   }

   // Bonus si filtres passés
   if(div.passedFilters) score += 20;

   // Bonus si confirmé
   if(div.isConfirmed) score += 25;

   // Bonus double indicateur
   if(div.indicator == DIV_IND_BOTH) score += 15;

   // Pénalité si trop ancien
   if(div.barsSinceDetection > 10) score -= 5;
   if(div.barsSinceDetection > 20) score -= 10;

   return MathMin(100, MathMax(0, score));
}

//+------------------------------------------------------------------+
//| Appliquer les filtres anti-faux signaux                           |
//+------------------------------------------------------------------+
bool CDivergences::ApplyFilters(SDivergence &div)
{
   div.filterMessage = "";

   // Filtre 1: Zone RSI inappropriée
   if(!FilterRSIZone(div))
   {
      div.filterMessage = "RSI en zone inappropriée";
      return false;
   }

   // Filtre 2: MACD accélère dans le sens du prix
   if(!FilterMACDDirection(div))
   {
      div.filterMessage = "MACD accélère contre la divergence";
      return false;
   }

   // Filtre 3: Bougie d'impulsion forte
   if(!FilterImpulseCandle(div))
   {
      div.filterMessage = "Bougie d'impulsion forte détectée";
      return false;
   }

   // Filtre 4: Piège retail
   if(!FilterRetailTrap(div))
   {
      div.filterMessage = "Possible piège retail";
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Filtre: Zone RSI                                                  |
//| ❌ Divergence haussière avec RSI > 70                             |
//| ❌ Divergence baissière avec RSI < 30                             |
//+------------------------------------------------------------------+
bool CDivergences::FilterRSIZone(SDivergence &div)
{
   double rsi = div.point2.rsiValue;

   // Divergence haussière: RSI ne doit PAS être > 70
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      if(rsi > 70) return false;
   }

   // Divergence baissière: RSI ne doit PAS être < 30
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      if(rsi < 30) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Filtre: Direction MACD                                            |
//| ❌ Si l'histogramme MACD accélère dans le sens du prix            |
//+------------------------------------------------------------------+
bool CDivergences::FilterMACDDirection(SDivergence &div)
{
   // Vérifier les 3 dernières barres d'histogramme
   if(ArraySize(m_histBuffer) < 3) return true;

   double hist0 = m_histBuffer[0];
   double hist1 = m_histBuffer[1];
   double hist2 = m_histBuffer[2];

   // Histogramme en accélération?
   bool acceleratingUp = (hist0 > hist1 && hist1 > hist2 && hist0 > 0);
   bool acceleratingDown = (hist0 < hist1 && hist1 < hist2 && hist0 < 0);

   // Divergence haussière mais MACD accélère à la baisse = OK
   // Divergence haussière mais MACD accélère à la hausse = DANGER
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      if(acceleratingDown) return false;  // Le bearish s'accélère
   }

   // Divergence baissière mais MACD accélère à la hausse = DANGER
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      if(acceleratingUp) return false;  // Le bullish s'accélère
   }

   return true;
}

//+------------------------------------------------------------------+
//| Filtre: Bougie d'impulsion                                        |
//| ❌ Si bougie pleine sans mèche (momentum fort)                    |
//+------------------------------------------------------------------+
bool CDivergences::FilterImpulseCandle(SDivergence &div)
{
   // Analyser la dernière bougie complète
   double open = iOpen(m_symbol, m_timeframe, 1);
   double high = iHigh(m_symbol, m_timeframe, 1);
   double low = iLow(m_symbol, m_timeframe, 1);
   double close = iClose(m_symbol, m_timeframe, 1);

   double body = MathAbs(close - open);
   double range = high - low;

   if(range == 0) return true;

   // Ratio corps/range
   double bodyRatio = body / range;

   // Si le corps représente > 85% de la bougie = impulsion
   if(bodyRatio > 0.85)
   {
      // Vérifier la direction
      bool bullishCandle = (close > open);

      // Divergence haussière + bougie baissière impulsive = ignorer
      if((div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN) && !bullishCandle)
         return false;

      // Divergence baissière + bougie haussière impulsive = ignorer
      if((div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN) && bullishCandle)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Filtre: Piège retail                                              |
//| ❌ Divergence trop évidente en zone de liquidité                  |
//+------------------------------------------------------------------+
bool CDivergences::FilterRetailTrap(SDivergence &div)
{
   // Divergence haussière en zone de survente extrême (< 15)
   // peut être un piège si le prix continue de chuter
   if(div.type == DIV_BULLISH_REGULAR && div.point2.rsiValue < 15)
   {
      // Vérifier si le prix continue de faire des lows
      double currentLow = iLow(m_symbol, m_timeframe, 0);
      if(currentLow < div.point2.price)
         return false;  // Le prix casse encore plus bas
   }

   // Divergence baissière en zone de surachat extrême (> 85)
   if(div.type == DIV_BEARISH_REGULAR && div.point2.rsiValue > 85)
   {
      double currentHigh = iHigh(m_symbol, m_timeframe, 0);
      if(currentHigh > div.point2.price)
         return false;  // Le prix casse encore plus haut
   }

   return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION: Divergence Haussière Régulière                         |
//| Condition: Prix fait LL, RSI/MACD fait HL                         |
//| Signification: Les vendeurs perdent le contrôle                   |
//+------------------------------------------------------------------+
bool CDivergences::DetectBullishRegular(SDivergence &div)
{
   SSwingPoint swingLows[];
   FindSwingLows(swingLows, 5);  // Chercher les 5 derniers swing lows

   if(ArraySize(swingLows) < 2) return false;

   // Essayer avec RSI d'abord
   for(int i = 0; i < ArraySize(swingLows) - 1; i++)
   {
      if(CalculateDivergence(swingLows[i+1], swingLows[i], DIV_BULLISH_REGULAR, DIV_IND_RSI, div))
      {
         // Vérifier aussi avec MACD
         SDivergence macdDiv;
         if(CalculateDivergence(swingLows[i+1], swingLows[i], DIV_BULLISH_REGULAR, DIV_IND_MACD, macdDiv))
         {
            div.indicator = DIV_IND_BOTH;  // Double confirmation!
            div.score = CalculateScore(div);
         }

         AddToCache(div);
         return true;
      }
   }

   // Essayer avec MACD seul
   for(int i = 0; i < ArraySize(swingLows) - 1; i++)
   {
      if(CalculateDivergence(swingLows[i+1], swingLows[i], DIV_BULLISH_REGULAR, DIV_IND_MACD, div))
      {
         AddToCache(div);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION: Divergence Baissière Régulière                         |
//| Condition: Prix fait HH, RSI/MACD fait LH                         |
//| Signification: Les acheteurs s'essoufflent                        |
//+------------------------------------------------------------------+
bool CDivergences::DetectBearishRegular(SDivergence &div)
{
   SSwingPoint swingHighs[];
   FindSwingHighs(swingHighs, 5);

   if(ArraySize(swingHighs) < 2) return false;

   // Essayer avec RSI d'abord
   for(int i = 0; i < ArraySize(swingHighs) - 1; i++)
   {
      if(CalculateDivergence(swingHighs[i+1], swingHighs[i], DIV_BEARISH_REGULAR, DIV_IND_RSI, div))
      {
         // Vérifier aussi avec MACD
         SDivergence macdDiv;
         if(CalculateDivergence(swingHighs[i+1], swingHighs[i], DIV_BEARISH_REGULAR, DIV_IND_MACD, macdDiv))
         {
            div.indicator = DIV_IND_BOTH;
            div.score = CalculateScore(div);
         }

         AddToCache(div);
         return true;
      }
   }

   // Essayer avec MACD seul
   for(int i = 0; i < ArraySize(swingHighs) - 1; i++)
   {
      if(CalculateDivergence(swingHighs[i+1], swingHighs[i], DIV_BEARISH_REGULAR, DIV_IND_MACD, div))
      {
         AddToCache(div);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION: Divergence Haussière Cachée (CONTINUATION)             |
//| Condition: Prix fait HL, RSI/MACD fait LL                         |
//| Signification: Tendance haussière continue                        |
//+------------------------------------------------------------------+
bool CDivergences::DetectBullishHidden(SDivergence &div)
{
   SSwingPoint swingLows[];
   FindSwingLows(swingLows, 5);

   if(ArraySize(swingLows) < 2) return false;

   for(int i = 0; i < ArraySize(swingLows) - 1; i++)
   {
      if(CalculateDivergence(swingLows[i+1], swingLows[i], DIV_BULLISH_HIDDEN, DIV_IND_RSI, div))
      {
         SDivergence macdDiv;
         if(CalculateDivergence(swingLows[i+1], swingLows[i], DIV_BULLISH_HIDDEN, DIV_IND_MACD, macdDiv))
         {
            div.indicator = DIV_IND_BOTH;
            div.score = CalculateScore(div);
         }

         AddToCache(div);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION: Divergence Baissière Cachée (CONTINUATION)             |
//| Condition: Prix fait LH, RSI/MACD fait HH                         |
//| Signification: Tendance baissière continue                        |
//+------------------------------------------------------------------+
bool CDivergences::DetectBearishHidden(SDivergence &div)
{
   SSwingPoint swingHighs[];
   FindSwingHighs(swingHighs, 5);

   if(ArraySize(swingHighs) < 2) return false;

   for(int i = 0; i < ArraySize(swingHighs) - 1; i++)
   {
      if(CalculateDivergence(swingHighs[i+1], swingHighs[i], DIV_BEARISH_HIDDEN, DIV_IND_RSI, div))
      {
         SDivergence macdDiv;
         if(CalculateDivergence(swingHighs[i+1], swingHighs[i], DIV_BEARISH_HIDDEN, DIV_IND_MACD, macdDiv))
         {
            div.indicator = DIV_IND_BOTH;
            div.score = CalculateScore(div);
         }

         AddToCache(div);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter n'importe quelle divergence                              |
//+------------------------------------------------------------------+
bool CDivergences::DetectAny(SDivergence &div)
{
   // Priorité aux divergences régulières (retournement)
   if(DetectBullishRegular(div)) return true;
   if(DetectBearishRegular(div)) return true;

   // Puis les divergences cachées (continuation)
   if(DetectBullishHidden(div)) return true;
   if(DetectBearishHidden(div)) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Détecter toutes les divergences actives                           |
//+------------------------------------------------------------------+
bool CDivergences::DetectAll(SDivergence &divergences[], int &count)
{
   ArrayResize(divergences, 0);
   count = 0;

   SDivergence div;

   // Chercher chaque type
   if(DetectBullishRegular(div))
   {
      ArrayResize(divergences, count + 1);
      divergences[count] = div;
      count++;
   }

   if(DetectBearishRegular(div))
   {
      ArrayResize(divergences, count + 1);
      divergences[count] = div;
      count++;
   }

   if(DetectBullishHidden(div))
   {
      ArrayResize(divergences, count + 1);
      divergences[count] = div;
      count++;
   }

   if(DetectBearishHidden(div))
   {
      ArrayResize(divergences, count + 1);
      divergences[count] = div;
      count++;
   }

   return (count > 0);
}

//+------------------------------------------------------------------+
//| Ajouter une divergence au cache                                   |
//+------------------------------------------------------------------+
void CDivergences::AddToCache(SDivergence &div)
{
   // Vérifier si elle existe déjà
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      if(m_activeDivergences[i].type == div.type &&
         m_activeDivergences[i].point2.bar == div.point2.bar)
      {
         // Mettre à jour
         m_activeDivergences[i] = div;
         return;
      }
   }

   // Ajouter nouvelle
   int size = ArraySize(m_activeDivergences);
   if(size < m_maxActiveDivergences)
   {
      ArrayResize(m_activeDivergences, size + 1);
      m_activeDivergences[size] = div;
   }
   else
   {
      // Remplacer la plus ancienne
      for(int i = 0; i < size - 1; i++)
      {
         m_activeDivergences[i] = m_activeDivergences[i + 1];
      }
      m_activeDivergences[size - 1] = div;
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour le cache des divergences                            |
//+------------------------------------------------------------------+
void CDivergences::UpdateCache()
{
   for(int i = ArraySize(m_activeDivergences) - 1; i >= 0; i--)
   {
      UpdateStatus(m_activeDivergences[i]);

      // Supprimer si invalidée ou expirée
      if(m_activeDivergences[i].status == DIV_STATUS_INVALIDATED ||
         m_activeDivergences[i].status == DIV_STATUS_EXPIRED)
      {
         // Décaler les éléments
         for(int j = i; j < ArraySize(m_activeDivergences) - 1; j++)
         {
            m_activeDivergences[j] = m_activeDivergences[j + 1];
         }
         ArrayResize(m_activeDivergences, ArraySize(m_activeDivergences) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les divergences expirées                                 |
//+------------------------------------------------------------------+
void CDivergences::CleanExpiredDivergences()
{
   UpdateCache();
}

//+------------------------------------------------------------------+
//| Mettre à jour le statut d'une divergence                          |
//+------------------------------------------------------------------+
ENUM_DIVERGENCE_STATUS CDivergences::UpdateStatus(SDivergence &div)
{
   // Si déjà confirmée ou invalidée, ne pas changer
   if(div.status == DIV_STATUS_CONFIRMED)
   {
      // Vérifier l'invalidation post-confirmation
      if(CheckInvalidation(div))
      {
         div.status = DIV_STATUS_INVALIDATED;
      }
      return div.status;
   }

   if(div.status == DIV_STATUS_INVALIDATED || div.status == DIV_STATUS_EXPIRED)
   {
      return div.status;
   }

   // Mettre à jour le compteur de barres
   div.barsSinceDetection++;

   // Vérifier l'expiration
   if(IsExpired(div))
   {
      div.status = DIV_STATUS_EXPIRED;
      return div.status;
   }

   // Vérifier l'invalidation
   if(CheckInvalidation(div))
   {
      div.status = DIV_STATUS_INVALIDATED;
      return div.status;
   }

   // Vérifier la confirmation
   if(CheckConfirmation(div))
   {
      div.status = DIV_STATUS_CONFIRMED;
      div.isConfirmed = true;
      div.confirmationTime = TimeCurrent();
      div.score = CalculateScore(div);
      return div.status;
   }

   return div.status;
}

//+------------------------------------------------------------------+
//| Vérifier si la divergence est confirmée                           |
//+------------------------------------------------------------------+
bool CDivergences::CheckConfirmation(SDivergence &div)
{
   // Déjà confirmée
   if(div.isConfirmed) return true;

   // 1. Confirmation par cassure de structure
   if(HasStructureBreakConfirmation(div))
   {
      div.confirmationType = "Cassure de structure (BOS)";
      return true;
   }

   // 2. Confirmation par pattern de bougie
   if(HasCandlePatternConfirmation(div))
   {
      div.confirmationType = "Pattern de bougie";
      return true;
   }

   // 3. Confirmation par rejet de prix
   if(HasPriceRejection(div))
   {
      div.confirmationType = "Rejet de prix";
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si la divergence est invalidée                           |
//+------------------------------------------------------------------+
bool CDivergences::CheckInvalidation(SDivergence &div)
{
   double currentPrice = iClose(m_symbol, m_timeframe, 0);

   // Divergence haussière invalidée si le prix fait un nouveau low
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      double lowestLow = div.point2.price;
      for(int i = 0; i < div.barsSinceDetection; i++)
      {
         double low = iLow(m_symbol, m_timeframe, i);
         if(low < lowestLow * 0.998)  // 0.2% de marge
         {
            return true;  // Invalidé: nouveau low
         }
      }
   }

   // Divergence baissière invalidée si le prix fait un nouveau high
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      double highestHigh = div.point2.price;
      for(int i = 0; i < div.barsSinceDetection; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         if(high > highestHigh * 1.002)  // 0.2% de marge
         {
            return true;  // Invalidé: nouveau high
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si la divergence est expirée                             |
//+------------------------------------------------------------------+
bool CDivergences::IsExpired(SDivergence &div)
{
   return (div.barsSinceDetection > m_maxBarsToExpire);
}

//+------------------------------------------------------------------+
//| Confirmation par cassure de structure                             |
//+------------------------------------------------------------------+
bool CDivergences::HasStructureBreakConfirmation(SDivergence &div)
{
   if(m_marketStructure == NULL) return false;

   // Pour une divergence haussière, on attend un BOS haussier
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      return (*m_marketStructure).IsBullishBOS(1);
   }

   // Pour une divergence baissière, on attend un BOS baissier
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      return (*m_marketStructure).IsBearishBOS(1);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Confirmation par pattern de bougie                                |
//+------------------------------------------------------------------+
bool CDivergences::HasCandlePatternConfirmation(SDivergence &div)
{
   if(m_candleAnalysis == NULL) return false;

   // Pour une divergence haussière
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      return (*m_candleAnalysis).HasBullishConfirmation(1);
   }

   // Pour une divergence baissière
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      return (*m_candleAnalysis).HasBearishConfirmation(1);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Confirmation par rejet de prix                                    |
//+------------------------------------------------------------------+
bool CDivergences::HasPriceRejection(SDivergence &div)
{
   // Analyser les 3 dernières bougies pour un rejet
   double high1 = iHigh(m_symbol, m_timeframe, 1);
   double low1 = iLow(m_symbol, m_timeframe, 1);
   double close1 = iClose(m_symbol, m_timeframe, 1);
   double open1 = iOpen(m_symbol, m_timeframe, 1);

   double range = high1 - low1;
   if(range == 0) return false;

   // Divergence haussière: chercher un rejet par le bas (longue mèche basse)
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      double lowerWick = MathMin(open1, close1) - low1;
      double wickRatio = lowerWick / range;

      // Mèche basse > 60% de la bougie = rejet
      if(wickRatio > 0.6 && close1 > open1)
         return true;
   }

   // Divergence baissière: chercher un rejet par le haut (longue mèche haute)
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      double upperWick = high1 - MathMax(open1, close1);
      double wickRatio = upperWick / range;

      // Mèche haute > 60% de la bougie = rejet
      if(wickRatio > 0.6 && close1 < open1)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir les divergences multi-timeframe                           |
//+------------------------------------------------------------------+
bool CDivergences::GetMTFDivergence(SMTFDivergence &mtf)
{
   // Initialiser
   mtf.hasAlignment = false;
   mtf.alignmentDesc = "";

   // Cette fonction doit être appelée avec des instances différentes
   // pour chaque timeframe. Retourner les divergences actuelles.

   SDivergence div;
   if(DetectAny(div))
   {
      switch(m_timeframe)
      {
         case PERIOD_D1:  mtf.daily = div; break;
         case PERIOD_H4:  mtf.h4 = div; break;
         case PERIOD_H1:  mtf.h1 = div; break;
         case PERIOD_M15: mtf.m15 = div; break;
      }
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement MTF                                         |
//+------------------------------------------------------------------+
bool CDivergences::HasMTFAlignment(ENUM_DIVERGENCE_TYPE type)
{
   // Compter les divergences du même type dans le cache
   int count = 0;
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      if(m_activeDivergences[i].type == type &&
         m_activeDivergences[i].status != DIV_STATUS_INVALIDATED)
      {
         count++;
      }
   }

   return (count >= 2);  // Au moins 2 TF alignés
}

//+------------------------------------------------------------------+
//| Obtenir l'analyse MTF en texte                                    |
//+------------------------------------------------------------------+
string CDivergences::GetMTFAnalysis()
{
   string analysis = "📊 Analyse MTF Divergences:\n";

   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      SDivergence div = m_activeDivergences[i];
      analysis += StringFormat("  • %s [%s] - %s (Score: %d)\n",
                               TypeToString(div.type),
                               EnumToString(div.timeframe),
                               StatusToString(div.status),
                               div.score);
   }

   if(ArraySize(m_activeDivergences) == 0)
      analysis += "  Aucune divergence active\n";

   return analysis;
}

//+------------------------------------------------------------------+
//| Nombre de divergences actives                                     |
//+------------------------------------------------------------------+
int CDivergences::GetActiveDivergenceCount()
{
   UpdateCache();
   return ArraySize(m_activeDivergences);
}

//+------------------------------------------------------------------+
//| Obtenir une divergence active par index                           |
//+------------------------------------------------------------------+
bool CDivergences::GetActiveDivergence(int index, SDivergence &div)
{
   if(index < 0 || index >= ArraySize(m_activeDivergences))
      return false;

   div = m_activeDivergences[index];
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a une divergence en attente                       |
//+------------------------------------------------------------------+
bool CDivergences::HasPendingDivergence(ENUM_DIVERGENCE_TYPE type)
{
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      if(m_activeDivergences[i].type == type &&
         m_activeDivergences[i].status == DIV_STATUS_DETECTED)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a une divergence confirmée                        |
//+------------------------------------------------------------------+
bool CDivergences::HasConfirmedDivergence(ENUM_DIVERGENCE_TYPE type)
{
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      if(m_activeDivergences[i].type == type &&
         m_activeDivergences[i].status == DIV_STATUS_CONFIRMED)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| INTÉGRATION: Supporte un setup haussier?                          |
//+------------------------------------------------------------------+
bool CDivergences::SupportsBullishSetup()
{
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      SDivergence div = m_activeDivergences[i];

      // Divergence haussière régulière confirmée ou pending avec bon score
      if(div.type == DIV_BULLISH_REGULAR)
      {
         if(div.status == DIV_STATUS_CONFIRMED) return true;
         if(div.status == DIV_STATUS_DETECTED && div.score >= 50) return true;
      }

      // Divergence haussière cachée (continuation)
      if(div.type == DIV_BULLISH_HIDDEN && div.passedFilters)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| INTÉGRATION: Supporte un setup baissier?                          |
//+------------------------------------------------------------------+
bool CDivergences::SupportsBearishSetup()
{
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      SDivergence div = m_activeDivergences[i];

      // Divergence baissière régulière confirmée ou pending avec bon score
      if(div.type == DIV_BEARISH_REGULAR)
      {
         if(div.status == DIV_STATUS_CONFIRMED) return true;
         if(div.status == DIV_STATUS_DETECTED && div.score >= 50) return true;
      }

      // Divergence baissière cachée (continuation)
      if(div.type == DIV_BEARISH_HIDDEN && div.passedFilters)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| INTÉGRATION: Contredit une direction?                             |
//+------------------------------------------------------------------+
bool CDivergences::ContradictsDirection(bool isBullish)
{
   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      SDivergence div = m_activeDivergences[i];

      // Skip les divergences non confirmées ou faibles
      if(div.status != DIV_STATUS_CONFIRMED && div.score < 60)
         continue;

      // Setup haussier mais divergence baissière forte
      if(isBullish && (div.type == DIV_BEARISH_REGULAR) && div.score >= 60)
         return true;

      // Setup baissier mais divergence haussière forte
      if(!isBullish && (div.type == DIV_BULLISH_REGULAR) && div.score >= 60)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le meilleur score de divergence                           |
//+------------------------------------------------------------------+
int CDivergences::GetDivergenceScore()
{
   int bestScore = 0;

   for(int i = 0; i < ArraySize(m_activeDivergences); i++)
   {
      if(m_activeDivergences[i].score > bestScore)
         bestScore = m_activeDivergences[i].score;
   }

   return bestScore;
}

//+------------------------------------------------------------------+
//| Type vers String                                                  |
//+------------------------------------------------------------------+
string CDivergences::TypeToString(ENUM_DIVERGENCE_TYPE type)
{
   switch(type)
   {
      case DIV_NONE:            return "Aucune";
      case DIV_BULLISH_REGULAR: return "Haussière Régulière";
      case DIV_BEARISH_REGULAR: return "Baissière Régulière";
      case DIV_BULLISH_HIDDEN:  return "Haussière Cachée";
      case DIV_BEARISH_HIDDEN:  return "Baissière Cachée";
      default:                  return "Inconnue";
   }
}

//+------------------------------------------------------------------+
//| Statut vers String                                                |
//+------------------------------------------------------------------+
string CDivergences::StatusToString(ENUM_DIVERGENCE_STATUS status)
{
   switch(status)
   {
      case DIV_STATUS_NONE:        return "Aucun";
      case DIV_STATUS_DETECTED:    return "En Attente ⏳";
      case DIV_STATUS_CONFIRMED:   return "Confirmée ✅";
      case DIV_STATUS_INVALIDATED: return "Invalidée ❌";
      case DIV_STATUS_EXPIRED:     return "Expirée ⌛";
      default:                     return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Qualité vers String                                               |
//+------------------------------------------------------------------+
string CDivergences::QualityToString(ENUM_DIVERGENCE_QUALITY quality)
{
   switch(quality)
   {
      case DIV_QUALITY_WEAK:     return "Faible";
      case DIV_QUALITY_MODERATE: return "Modérée";
      case DIV_QUALITY_STRONG:   return "Forte";
      case DIV_QUALITY_EXTREME:  return "Extrême";
      default:                   return "Inconnue";
   }
}

//+------------------------------------------------------------------+
//| Description complète d'une divergence                             |
//+------------------------------------------------------------------+
string CDivergences::GetDivergenceDescription(SDivergence &div)
{
   string desc = "";

   desc += "📊 DIVERGENCE " + TypeToString(div.type) + "\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += "Statut: " + StatusToString(div.status) + "\n";
   desc += "Qualité: " + QualityToString(div.quality) + "\n";
   desc += "Score: " + IntegerToString(div.score) + "/100\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

   desc += StringFormat("Point 1: Bar %d, Prix %.5f, RSI %.1f\n",
                        div.point1.bar, div.point1.price, div.point1.rsiValue);
   desc += StringFormat("Point 2: Bar %d, Prix %.5f, RSI %.1f\n",
                        div.point2.bar, div.point2.price, div.point2.rsiValue);

   desc += StringFormat("Écart Prix: %.2f%%\n", div.priceDivergence * 100);
   desc += StringFormat("Écart Indicateur: %.1f points\n", div.indicatorDivergence);
   desc += StringFormat("Distance: %d barres\n", div.barsSpan);

   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

   if(div.passedFilters)
      desc += "✅ Filtres: OK\n";
   else
      desc += "❌ Filtres: " + div.filterMessage + "\n";

   if(div.isConfirmed)
      desc += "✅ Confirmation: " + div.confirmationType + "\n";
   else
      desc += "⏳ En attente de confirmation\n";

   return desc;
}

//+------------------------------------------------------------------+
//| Message d'alerte                                                  |
//| RÈGLE: Pas d'alerte instantanée, seulement contextuelle           |
//+------------------------------------------------------------------+
string CDivergences::GetAlertMessage(SDivergence &div)
{
   // Ne pas alerter si non confirmée ou score faible
   if(div.status != DIV_STATUS_CONFIRMED && div.score < 50)
      return "";

   string msg = "";

   if(div.status == DIV_STATUS_DETECTED)
   {
      msg = "⚠️ ANTICIPATION: " + TypeToString(div.type) + " détectée\n";
      msg += "Score: " + IntegerToString(div.score) + " - En attente de confirmation\n";
      msg += "Ne PAS entrer maintenant - Observer!";
   }
   else if(div.status == DIV_STATUS_CONFIRMED)
   {
      msg = "✅ DIVERGENCE CONFIRMÉE: " + TypeToString(div.type) + "\n";
      msg += "Confirmation: " + div.confirmationType + "\n";
      msg += "Score: " + IntegerToString(div.score) + "/100\n";
      msg += "Prêt pour confluence avec autres signaux";
   }

   return msg;
}

//+------------------------------------------------------------------+
