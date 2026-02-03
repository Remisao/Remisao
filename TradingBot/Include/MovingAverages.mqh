//+------------------------------------------------------------------+
//|                                            MovingAverages.mqh    |
//|                     CHAPITRE 7 - EMA / TREND FILTER PROFESSIONNEL|
//|                     FILTRE DIRECTIONNEL - PAS UN SIGNAL          |
//|                     Bot Multi-Marchés Forex & Crypto             |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE:                                                      |
//| Les EMA ne servent PAS à entrer en position                      |
//| Elles servent à DÉFINIR LE SENS AUTORISÉ DU MARCHÉ               |
//|                                                                   |
//| Le module doit:                                                   |
//|   - Filtrer les trades contre-tendance                           |
//|   - Identifier les zones dynamiques clés                         |
//|   - Qualifier la force réelle de la tendance                     |
//|   - Améliorer la patience et la discipline du bot                |
//|                                                                   |
//| RÈGLES D'OR:                                                      |
//|   - On ne trade JAMAIS contre l'EMA 200                          |
//|   - On n'entre QUE sur repli en tendance                         |
//|   - Les EMA filtrent, elles ne déclenchent pas                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| État de tendance principal                                        |
//+------------------------------------------------------------------+
enum ENUM_TREND_STATE
{
   TREND_BULLISH = 0,      // Tendance haussière confirmée
   TREND_BEARISH,          // Tendance baissière confirmée
   TREND_NEUTRAL,          // Range / Pas de tendance claire
   TREND_TRANSITION        // En transition (changement de régime)
};

//+------------------------------------------------------------------+
//| Force de la tendance                                              |
//+------------------------------------------------------------------+
enum ENUM_TREND_STRENGTH
{
   STRENGTH_NONE = 0,      // Pas de tendance
   STRENGTH_WEAK,          // Faible (EMA entrelacées)
   STRENGTH_MODERATE,      // Modérée (partiellement alignées)
   STRENGTH_STRONG,        // Forte (ribbon aligné)
   STRENGTH_EXTREME        // Extrême (ribbon en expansion)
};

//+------------------------------------------------------------------+
//| Type d'événement EMA                                              |
//+------------------------------------------------------------------+
enum ENUM_EMA_EVENT
{
   EMA_EVENT_NONE = 0,

   // Croisements majeurs
   EMA_GOLDEN_CROSS,       // EMA 50 croise EMA 200 vers le haut
   EMA_DEATH_CROSS,        // EMA 50 croise EMA 200 vers le bas
   EMA_FAST_GOLDEN,        // EMA 9 croise EMA 21 vers le haut
   EMA_FAST_DEATH,         // EMA 9 croise EMA 21 vers le bas

   // Ribbon
   EMA_RIBBON_BULLISH,     // Ribbon aligné haussier
   EMA_RIBBON_BEARISH,     // Ribbon aligné baissier
   EMA_RIBBON_COMPRESSION, // EMA se compriment
   EMA_RIBBON_EXPANSION,   // EMA s'écartent

   // Rejets
   EMA_REJECTION_21,       // Rejet sur EMA 21
   EMA_REJECTION_50,       // Rejet sur EMA 50
   EMA_REJECTION_200,      // Rejet sur EMA 200

   // Cassures
   EMA_BREAK_50,           // Cassure EMA 50
   EMA_BREAK_200           // Cassure EMA 200
};

//+------------------------------------------------------------------+
//| Niveau d'alerte                                                   |
//+------------------------------------------------------------------+
enum ENUM_EMA_ALERT_LEVEL
{
   ALERT_INFO = 0,         // Information (touche EMA, compression)
   ALERT_SETUP,            // Setup valide (alignement, zone dynamique)
   ALERT_DANGER            // Danger (cassure, perte alignement)
};

//+------------------------------------------------------------------+
//| Structure des valeurs EMA                                         |
//+------------------------------------------------------------------+
struct SEMAValues
{
   double            ema9;
   double            ema21;
   double            ema50;
   double            ema200;
   double            price;           // Prix actuel
};

//+------------------------------------------------------------------+
//| Structure des pentes EMA                                          |
//+------------------------------------------------------------------+
struct SEMASlopes
{
   double            slope9;          // Pente EMA 9
   double            slope21;         // Pente EMA 21
   double            slope50;         // Pente EMA 50
   double            slope200;        // Pente EMA 200
   bool              allUp;           // Toutes les pentes positives
   bool              allDown;         // Toutes les pentes négatives
};

//+------------------------------------------------------------------+
//| Structure de rejet EMA                                            |
//+------------------------------------------------------------------+
struct SEMARejection
{
   bool              detected;        // Rejet détecté
   int               emaPeriod;       // Période de l'EMA (21, 50, 200)
   double            emaValue;        // Valeur de l'EMA
   double            wickSize;        // Taille de la mèche
   double            bodySize;        // Taille du corps
   bool              isBullish;       // Rejet haussier (mèche basse)
   int               bar;             // Barre du rejet
};

//+------------------------------------------------------------------+
//| Structure d'état du Ribbon                                        |
//+------------------------------------------------------------------+
struct SRibbonState
{
   bool              isAligned;       // EMAs alignées
   bool              isBullish;       // Direction haussière
   bool              isCompressed;    // EMAs compressées
   bool              isExpanding;     // EMAs en expansion
   double            width;           // Largeur du ribbon (EMA9 - EMA200)
   double            widthPercent;    // Largeur en % du prix
   ENUM_TREND_STRENGTH strength;      // Force de la tendance
};

//+------------------------------------------------------------------+
//| Structure de croisement mémorisé                                  |
//+------------------------------------------------------------------+
struct SCrossEvent
{
   ENUM_EMA_EVENT    type;            // Type de croisement
   datetime          time;            // Timestamp
   int               barsAgo;         // Barres depuis l'événement
   double            price;           // Prix au moment du croisement
   bool              isValid;         // Encore valide
};

//+------------------------------------------------------------------+
//| Structure d'alerte EMA                                            |
//+------------------------------------------------------------------+
struct SEMAAlert
{
   ENUM_EMA_ALERT_LEVEL level;        // Niveau d'alerte
   ENUM_EMA_EVENT    event;           // Événement déclencheur
   string            message;         // Message d'alerte
   datetime          time;            // Timestamp
};

//+------------------------------------------------------------------+
//| Structure d'analyse tendance complète                             |
//+------------------------------------------------------------------+
struct STrendAnalysis
{
   // État principal
   ENUM_TREND_STATE     state;           // État de tendance
   ENUM_TREND_STRENGTH  strength;        // Force

   // Valeurs EMA
   SEMAValues           values;          // Valeurs actuelles
   SEMASlopes           slopes;          // Pentes
   SRibbonState         ribbon;          // État du ribbon

   // Événements récents
   SCrossEvent          lastCross;       // Dernier croisement majeur
   SEMARejection        lastRejection;   // Dernier rejet

   // Filtres de trading
   bool                 allowLong;       // Long autorisé
   bool                 allowShort;      // Short autorisé
   bool                 isPullback;      // En pullback

   // Support/Résistance dynamique
   double               dynamicSupport;  // Support dynamique
   double               dynamicResistance; // Résistance dynamique

   // Alerte
   SEMAAlert            alert;           // Alerte actuelle
};

//+------------------------------------------------------------------+
//| Structure Multi-Timeframe                                         |
//+------------------------------------------------------------------+
struct SMTFTrend
{
   STrendAnalysis       daily;           // Analyse Daily
   STrendAnalysis       h4;              // Analyse H4
   STrendAnalysis       h1;              // Analyse H1
   STrendAnalysis       m15;             // Analyse M15

   // Alignement
   bool                 isAligned;       // Toutes les UT alignées
   ENUM_TREND_STATE     globalTrend;     // Tendance globale
   bool                 allowTrading;    // Trading autorisé
   string               alignmentDesc;   // Description
};

//+------------------------------------------------------------------+
//| Classe EMA / Trend Filter PROFESSIONNELLE                         |
//+------------------------------------------------------------------+
class CMovingAverages
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Handles EMA
   int               m_ema9Handle;
   int               m_ema21Handle;
   int               m_ema50Handle;
   int               m_ema200Handle;

   // Buffers optimisés
   double            m_ema9Buffer[];
   double            m_ema21Buffer[];
   double            m_ema50Buffer[];
   double            m_ema200Buffer[];

   // Paramètres
   int               m_slopeLookback;     // Barres pour calcul pente (défaut: 5)
   double            m_compressionThreshold; // Seuil compression % (défaut: 0.5%)
   double            m_rejectionWickRatio;   // Ratio mèche/range pour rejet (défaut: 0.5)

   // Cache des événements
   SCrossEvent       m_lastGoldenCross;
   SCrossEvent       m_lastDeathCross;
   SEMARejection     m_recentRejections[];
   int               m_maxRejections;

   // ============ MÉTHODES PRIVÉES ============

   bool              LoadBuffers(int count);
   void              ReleaseHandles();

   // Calculs internes
   double            CalculateSlope(double &buffer[], int lookback);
   double            GetRibbonWidth(int shift);
   bool              IsEMACompressed(int shift);
   bool              IsEMAExpanding(int shift);

   // Détection de rejet
   bool              DetectRejection(int shift, int emaPeriod, SEMARejection &rejection);
   bool              IsWickRejection(int shift, double emaValue, bool checkBullish);

   // Gestion du cache
   void              UpdateCrossEvents();
   void              AddRejection(SEMARejection &rejection);

public:
   CMovingAverages();
   ~CMovingAverages();

   // ============ INITIALISATION ============
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetSlopeLookback(int bars);
   void              SetCompressionThreshold(double percent);
   void              SetRejectionRatio(double ratio);

   // ============ VALEURS EMA BRUTES ============
   double            GetEMA9(int shift);
   double            GetEMA21(int shift);
   double            GetEMA50(int shift);
   double            GetEMA200(int shift);
   SEMAValues        GetAllEMAs(int shift);

   // ============ ÉTAT DE TENDANCE ============

   // Direction principale (PRIORITÉ)
   ENUM_TREND_STATE  GetTrendState(int shift);
   ENUM_TREND_STRENGTH GetTrendStrength(int shift);
   bool              IsBullishTrend(int shift);
   bool              IsBearishTrend(int shift);
   bool              IsRanging(int shift);

   // Pentes
   SEMASlopes        GetSlopes(int shift);
   bool              IsAllSlopesUp(int shift);
   bool              IsAllSlopesDown(int shift);

   // ============ EMA RIBBON ============

   SRibbonState      GetRibbonState(int shift);
   bool              IsRibbonAligned(int shift, bool &isBullish);
   bool              IsRibbonBullish(int shift);
   bool              IsRibbonBearish(int shift);
   bool              IsCompressed(int shift);
   bool              IsExpanding(int shift);

   // ============ CROISEMENTS ============

   // Golden Cross / Death Cross (SIGNAL MAJEUR)
   bool              IsGoldenCross(int shift);
   bool              IsDeathCross(int shift);
   bool              IsFastGoldenCross(int shift);
   bool              IsFastDeathCross(int shift);

   // Mémoire des croisements
   SCrossEvent       GetLastGoldenCross();
   SCrossEvent       GetLastDeathCross();
   int               BarsSinceGoldenCross();
   int               BarsSinceDeathCross();

   // ============ SUPPORT/RÉSISTANCE DYNAMIQUE ============

   // Rejet sur EMA
   bool              DetectEMARejection(int shift, SEMARejection &rejection);
   bool              HasRecentRejection(int emaPeriod, int maxBars);

   // Zones dynamiques
   double            GetDynamicSupport(int shift);
   double            GetDynamicResistance(int shift);
   double            GetNearestEMA(int shift, bool above);

   // ============ FILTRAGE TRADES ============

   // RÈGLE: On ne trade JAMAIS contre l'EMA 200
   bool              AllowLong(int shift);
   bool              AllowShort(int shift);
   bool              IsPullbackZone(int shift, bool forLong);
   bool              IsCounterTrend(bool wantLong, int shift);

   // ============ ANALYSE COMPLÈTE ============

   STrendAnalysis    Analyze(int shift);
   SEMAAlert         GetCurrentAlert(int shift);

   // ============ MULTI-TIMEFRAME ============

   // Note: Ces fonctions nécessitent des instances séparées par TF
   bool              CheckMTFAlignment(ENUM_TREND_STATE dailyTrend,
                                       ENUM_TREND_STATE h4Trend);

   // ============ UTILITAIRES ============

   string            TrendStateToString(ENUM_TREND_STATE state);
   string            StrengthToString(ENUM_TREND_STRENGTH strength);
   string            EventToString(ENUM_EMA_EVENT event);
   string            GetTrendDescription(int shift);
   string            GetAlertMessage(int shift);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CMovingAverages::CMovingAverages()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_ema9Handle = INVALID_HANDLE;
   m_ema21Handle = INVALID_HANDLE;
   m_ema50Handle = INVALID_HANDLE;
   m_ema200Handle = INVALID_HANDLE;

   // Paramètres par défaut
   m_slopeLookback = 5;
   m_compressionThreshold = 0.005;  // 0.5%
   m_rejectionWickRatio = 0.5;      // Mèche >= 50% du range

   // Cache
   m_maxRejections = 10;
   ArrayResize(m_recentRejections, 0);

   // Initialiser les événements
   m_lastGoldenCross.isValid = false;
   m_lastDeathCross.isValid = false;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CMovingAverages::~CMovingAverages()
{
   ReleaseHandles();
}

//+------------------------------------------------------------------+
//| Libérer les handles                                               |
//+------------------------------------------------------------------+
void CMovingAverages::ReleaseHandles()
{
   if(m_ema9Handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ema9Handle);
      m_ema9Handle = INVALID_HANDLE;
   }
   if(m_ema21Handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ema21Handle);
      m_ema21Handle = INVALID_HANDLE;
   }
   if(m_ema50Handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ema50Handle);
      m_ema50Handle = INVALID_HANDLE;
   }
   if(m_ema200Handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_ema200Handle);
      m_ema200Handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CMovingAverages::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   // Libérer les anciens handles
   ReleaseHandles();

   // Créer les handles EMA (MODE_EMA natif MQL5)
   m_ema9Handle = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   m_ema21Handle = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_ema50Handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_ema200Handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(m_ema9Handle == INVALID_HANDLE ||
      m_ema21Handle == INVALID_HANDLE ||
      m_ema50Handle == INVALID_HANDLE ||
      m_ema200Handle == INVALID_HANDLE)
   {
      Print("❌ Erreur création handles EMA pour ", m_symbol);
      return false;
   }

   // Initialiser les buffers
   ArraySetAsSeries(m_ema9Buffer, true);
   ArraySetAsSeries(m_ema21Buffer, true);
   ArraySetAsSeries(m_ema50Buffer, true);
   ArraySetAsSeries(m_ema200Buffer, true);

   Print("✅ Module EMA initialisé: ", m_symbol, " ", EnumToString(m_timeframe));
   return true;
}

//+------------------------------------------------------------------+
//| Configuration du lookback pour les pentes                         |
//+------------------------------------------------------------------+
void CMovingAverages::SetSlopeLookback(int bars)
{
   m_slopeLookback = MathMax(3, bars);
}

//+------------------------------------------------------------------+
//| Configuration du seuil de compression                             |
//+------------------------------------------------------------------+
void CMovingAverages::SetCompressionThreshold(double percent)
{
   m_compressionThreshold = MathMax(0.001, percent);
}

//+------------------------------------------------------------------+
//| Configuration du ratio de rejet                                   |
//+------------------------------------------------------------------+
void CMovingAverages::SetRejectionRatio(double ratio)
{
   m_rejectionWickRatio = MathMax(0.3, MathMin(0.8, ratio));
}

//+------------------------------------------------------------------+
//| Charger les buffers                                               |
//+------------------------------------------------------------------+
bool CMovingAverages::LoadBuffers(int count)
{
   if(m_ema9Handle == INVALID_HANDLE) return false;

   int available = Bars(m_symbol, m_timeframe);
   if(available < count) return false;

   if(CopyBuffer(m_ema9Handle, 0, 0, count, m_ema9Buffer) < count) return false;
   if(CopyBuffer(m_ema21Handle, 0, 0, count, m_ema21Buffer) < count) return false;
   if(CopyBuffer(m_ema50Handle, 0, 0, count, m_ema50Buffer) < count) return false;
   if(CopyBuffer(m_ema200Handle, 0, 0, count, m_ema200Buffer) < count) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir EMA 9                                                     |
//+------------------------------------------------------------------+
double CMovingAverages::GetEMA9(int shift)
{
   if(!LoadBuffers(shift + 1)) return 0;
   return m_ema9Buffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir EMA 21                                                    |
//+------------------------------------------------------------------+
double CMovingAverages::GetEMA21(int shift)
{
   if(!LoadBuffers(shift + 1)) return 0;
   return m_ema21Buffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir EMA 50                                                    |
//+------------------------------------------------------------------+
double CMovingAverages::GetEMA50(int shift)
{
   if(!LoadBuffers(shift + 1)) return 0;
   return m_ema50Buffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir EMA 200                                                   |
//+------------------------------------------------------------------+
double CMovingAverages::GetEMA200(int shift)
{
   if(!LoadBuffers(shift + 1)) return 0;
   return m_ema200Buffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir toutes les EMAs                                           |
//+------------------------------------------------------------------+
SEMAValues CMovingAverages::GetAllEMAs(int shift)
{
   SEMAValues values;
   values.ema9 = 0;
   values.ema21 = 0;
   values.ema50 = 0;
   values.ema200 = 0;
   values.price = 0;

   if(!LoadBuffers(shift + 1)) return values;

   values.ema9 = m_ema9Buffer[shift];
   values.ema21 = m_ema21Buffer[shift];
   values.ema50 = m_ema50Buffer[shift];
   values.ema200 = m_ema200Buffer[shift];
   values.price = iClose(m_symbol, m_timeframe, shift);

   return values;
}

//+------------------------------------------------------------------+
//| Calculer la pente d'un buffer                                     |
//+------------------------------------------------------------------+
double CMovingAverages::CalculateSlope(double &buffer[], int lookback)
{
   if(ArraySize(buffer) < lookback + 1) return 0;
   return (buffer[0] - buffer[lookback]) / lookback;
}

//+------------------------------------------------------------------+
//| Obtenir les pentes de toutes les EMAs                             |
//+------------------------------------------------------------------+
SEMASlopes CMovingAverages::GetSlopes(int shift)
{
   SEMASlopes slopes;
   slopes.slope9 = 0;
   slopes.slope21 = 0;
   slopes.slope50 = 0;
   slopes.slope200 = 0;
   slopes.allUp = false;
   slopes.allDown = false;

   if(!LoadBuffers(shift + m_slopeLookback + 1)) return slopes;

   // Calculer les pentes
   slopes.slope9 = (m_ema9Buffer[shift] - m_ema9Buffer[shift + m_slopeLookback]) / m_slopeLookback;
   slopes.slope21 = (m_ema21Buffer[shift] - m_ema21Buffer[shift + m_slopeLookback]) / m_slopeLookback;
   slopes.slope50 = (m_ema50Buffer[shift] - m_ema50Buffer[shift + m_slopeLookback]) / m_slopeLookback;
   slopes.slope200 = (m_ema200Buffer[shift] - m_ema200Buffer[shift + m_slopeLookback]) / m_slopeLookback;

   // Vérifier la direction
   slopes.allUp = (slopes.slope9 > 0 && slopes.slope21 > 0 &&
                   slopes.slope50 > 0 && slopes.slope200 > 0);
   slopes.allDown = (slopes.slope9 < 0 && slopes.slope21 < 0 &&
                     slopes.slope50 < 0 && slopes.slope200 < 0);

   return slopes;
}

//+------------------------------------------------------------------+
//| Vérifier si toutes les pentes sont positives                      |
//+------------------------------------------------------------------+
bool CMovingAverages::IsAllSlopesUp(int shift)
{
   SEMASlopes slopes = GetSlopes(shift);
   return slopes.allUp;
}

//+------------------------------------------------------------------+
//| Vérifier si toutes les pentes sont négatives                      |
//+------------------------------------------------------------------+
bool CMovingAverages::IsAllSlopesDown(int shift)
{
   SEMASlopes slopes = GetSlopes(shift);
   return slopes.allDown;
}

//+------------------------------------------------------------------+
//| Obtenir la largeur du ribbon                                      |
//+------------------------------------------------------------------+
double CMovingAverages::GetRibbonWidth(int shift)
{
   if(!LoadBuffers(shift + 1)) return 0;
   return MathAbs(m_ema9Buffer[shift] - m_ema200Buffer[shift]);
}

//+------------------------------------------------------------------+
//| Vérifier si les EMAs sont compressées                             |
//+------------------------------------------------------------------+
bool CMovingAverages::IsEMACompressed(int shift)
{
   if(!LoadBuffers(shift + 1)) return false;

   double price = iClose(m_symbol, m_timeframe, shift);
   double width = GetRibbonWidth(shift);
   double widthPercent = width / price;

   return (widthPercent < m_compressionThreshold);
}

//+------------------------------------------------------------------+
//| Vérifier si les EMAs sont en expansion                            |
//+------------------------------------------------------------------+
bool CMovingAverages::IsEMAExpanding(int shift)
{
   if(!LoadBuffers(shift + m_slopeLookback + 1)) return false;

   double widthNow = GetRibbonWidth(shift);
   double widthPrev = MathAbs(m_ema9Buffer[shift + m_slopeLookback] -
                              m_ema200Buffer[shift + m_slopeLookback]);

   // Expansion si la largeur augmente de plus de 20%
   return (widthNow > widthPrev * 1.2);
}

//+------------------------------------------------------------------+
//| ÉTAT DE TENDANCE PRINCIPAL                                        |
//| Tendance haussière: Prix > EMA50 & EMA200, EMA50 > EMA200        |
//| Tendance baissière: Prix < EMA50 & EMA200, EMA50 < EMA200        |
//+------------------------------------------------------------------+
ENUM_TREND_STATE CMovingAverages::GetTrendState(int shift)
{
   if(!LoadBuffers(shift + 1)) return TREND_NEUTRAL;

   double price = iClose(m_symbol, m_timeframe, shift);
   double ema50 = m_ema50Buffer[shift];
   double ema200 = m_ema200Buffer[shift];

   // Tendance haussière
   if(price > ema50 && price > ema200 && ema50 > ema200)
   {
      return TREND_BULLISH;
   }

   // Tendance baissière
   if(price < ema50 && price < ema200 && ema50 < ema200)
   {
      return TREND_BEARISH;
   }

   // Vérifier la transition (croisement récent)
   if(IsGoldenCross(shift) || IsDeathCross(shift))
   {
      return TREND_TRANSITION;
   }

   // Range / Neutre (EMA entrelacées ou prix oscillant)
   return TREND_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Obtenir la force de la tendance                                   |
//+------------------------------------------------------------------+
ENUM_TREND_STRENGTH CMovingAverages::GetTrendStrength(int shift)
{
   SRibbonState ribbon = GetRibbonState(shift);

   if(!ribbon.isAligned)
      return STRENGTH_NONE;

   if(ribbon.isCompressed)
      return STRENGTH_WEAK;

   if(ribbon.isExpanding)
      return STRENGTH_EXTREME;

   // Vérifier les pentes
   SEMASlopes slopes = GetSlopes(shift);
   if(slopes.allUp || slopes.allDown)
      return STRENGTH_STRONG;

   return STRENGTH_MODERATE;
}

//+------------------------------------------------------------------+
//| Vérifier si tendance haussière                                    |
//+------------------------------------------------------------------+
bool CMovingAverages::IsBullishTrend(int shift)
{
   return (GetTrendState(shift) == TREND_BULLISH);
}

//+------------------------------------------------------------------+
//| Vérifier si tendance baissière                                    |
//+------------------------------------------------------------------+
bool CMovingAverages::IsBearishTrend(int shift)
{
   return (GetTrendState(shift) == TREND_BEARISH);
}

//+------------------------------------------------------------------+
//| Vérifier si range                                                 |
//+------------------------------------------------------------------+
bool CMovingAverages::IsRanging(int shift)
{
   ENUM_TREND_STATE state = GetTrendState(shift);
   return (state == TREND_NEUTRAL || state == TREND_TRANSITION);
}

//+------------------------------------------------------------------+
//| Obtenir l'état du Ribbon                                          |
//+------------------------------------------------------------------+
SRibbonState CMovingAverages::GetRibbonState(int shift)
{
   SRibbonState ribbon;
   ribbon.isAligned = false;
   ribbon.isBullish = false;
   ribbon.isCompressed = false;
   ribbon.isExpanding = false;
   ribbon.width = 0;
   ribbon.widthPercent = 0;
   ribbon.strength = STRENGTH_NONE;

   if(!LoadBuffers(shift + m_slopeLookback + 1)) return ribbon;

   double price = iClose(m_symbol, m_timeframe, shift);

   // Calculer la largeur
   ribbon.width = GetRibbonWidth(shift);
   ribbon.widthPercent = ribbon.width / price;

   // Vérifier l'alignement haussier: EMA9 > EMA21 > EMA50 > EMA200
   bool bullishRibbon = (m_ema9Buffer[shift] > m_ema21Buffer[shift] &&
                         m_ema21Buffer[shift] > m_ema50Buffer[shift] &&
                         m_ema50Buffer[shift] > m_ema200Buffer[shift]);

   // Vérifier l'alignement baissier: EMA9 < EMA21 < EMA50 < EMA200
   bool bearishRibbon = (m_ema9Buffer[shift] < m_ema21Buffer[shift] &&
                         m_ema21Buffer[shift] < m_ema50Buffer[shift] &&
                         m_ema50Buffer[shift] < m_ema200Buffer[shift]);

   if(bullishRibbon)
   {
      ribbon.isAligned = true;
      ribbon.isBullish = true;
   }
   else if(bearishRibbon)
   {
      ribbon.isAligned = true;
      ribbon.isBullish = false;
   }

   // Compression et expansion
   ribbon.isCompressed = IsEMACompressed(shift);
   ribbon.isExpanding = IsEMAExpanding(shift);

   // Force
   if(!ribbon.isAligned)
      ribbon.strength = STRENGTH_NONE;
   else if(ribbon.isCompressed)
      ribbon.strength = STRENGTH_WEAK;
   else if(ribbon.isExpanding)
      ribbon.strength = STRENGTH_EXTREME;
   else
      ribbon.strength = STRENGTH_STRONG;

   return ribbon;
}

//+------------------------------------------------------------------+
//| Vérifier si le Ribbon est aligné                                  |
//+------------------------------------------------------------------+
bool CMovingAverages::IsRibbonAligned(int shift, bool &isBullish)
{
   SRibbonState ribbon = GetRibbonState(shift);
   isBullish = ribbon.isBullish;
   return ribbon.isAligned;
}

//+------------------------------------------------------------------+
//| Ribbon haussier                                                   |
//+------------------------------------------------------------------+
bool CMovingAverages::IsRibbonBullish(int shift)
{
   SRibbonState ribbon = GetRibbonState(shift);
   return (ribbon.isAligned && ribbon.isBullish);
}

//+------------------------------------------------------------------+
//| Ribbon baissier                                                   |
//+------------------------------------------------------------------+
bool CMovingAverages::IsRibbonBearish(int shift)
{
   SRibbonState ribbon = GetRibbonState(shift);
   return (ribbon.isAligned && !ribbon.isBullish);
}

//+------------------------------------------------------------------+
//| EMAs compressées                                                  |
//+------------------------------------------------------------------+
bool CMovingAverages::IsCompressed(int shift)
{
   return IsEMACompressed(shift);
}

//+------------------------------------------------------------------+
//| EMAs en expansion                                                 |
//+------------------------------------------------------------------+
bool CMovingAverages::IsExpanding(int shift)
{
   return IsEMAExpanding(shift);
}

//+------------------------------------------------------------------+
//| GOLDEN CROSS (EMA 50 croise EMA 200 vers le haut)                |
//| SIGNAL MAJEUR - Changement de régime                              |
//+------------------------------------------------------------------+
bool CMovingAverages::IsGoldenCross(int shift)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasBelowPrev = (m_ema50Buffer[shift + 1] < m_ema200Buffer[shift + 1]);
   bool isAboveNow = (m_ema50Buffer[shift] > m_ema200Buffer[shift]);

   if(wasBelowPrev && isAboveNow)
   {
      // Mémoriser l'événement
      m_lastGoldenCross.type = EMA_GOLDEN_CROSS;
      m_lastGoldenCross.time = iTime(m_symbol, m_timeframe, shift);
      m_lastGoldenCross.barsAgo = shift;
      m_lastGoldenCross.price = iClose(m_symbol, m_timeframe, shift);
      m_lastGoldenCross.isValid = true;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DEATH CROSS (EMA 50 croise EMA 200 vers le bas)                  |
//| SIGNAL MAJEUR - Changement de régime                              |
//+------------------------------------------------------------------+
bool CMovingAverages::IsDeathCross(int shift)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasAbovePrev = (m_ema50Buffer[shift + 1] > m_ema200Buffer[shift + 1]);
   bool isBelowNow = (m_ema50Buffer[shift] < m_ema200Buffer[shift]);

   if(wasAbovePrev && isBelowNow)
   {
      // Mémoriser l'événement
      m_lastDeathCross.type = EMA_DEATH_CROSS;
      m_lastDeathCross.time = iTime(m_symbol, m_timeframe, shift);
      m_lastDeathCross.barsAgo = shift;
      m_lastDeathCross.price = iClose(m_symbol, m_timeframe, shift);
      m_lastDeathCross.isValid = true;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Golden Cross rapide (EMA 9 croise EMA 21)                        |
//+------------------------------------------------------------------+
bool CMovingAverages::IsFastGoldenCross(int shift)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasBelowPrev = (m_ema9Buffer[shift + 1] < m_ema21Buffer[shift + 1]);
   bool isAboveNow = (m_ema9Buffer[shift] > m_ema21Buffer[shift]);

   return (wasBelowPrev && isAboveNow);
}

//+------------------------------------------------------------------+
//| Death Cross rapide (EMA 9 croise EMA 21)                         |
//+------------------------------------------------------------------+
bool CMovingAverages::IsFastDeathCross(int shift)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasAbovePrev = (m_ema9Buffer[shift + 1] > m_ema21Buffer[shift + 1]);
   bool isBelowNow = (m_ema9Buffer[shift] < m_ema21Buffer[shift]);

   return (wasAbovePrev && isBelowNow);
}

//+------------------------------------------------------------------+
//| Obtenir le dernier Golden Cross                                   |
//+------------------------------------------------------------------+
SCrossEvent CMovingAverages::GetLastGoldenCross()
{
   return m_lastGoldenCross;
}

//+------------------------------------------------------------------+
//| Obtenir le dernier Death Cross                                    |
//+------------------------------------------------------------------+
SCrossEvent CMovingAverages::GetLastDeathCross()
{
   return m_lastDeathCross;
}

//+------------------------------------------------------------------+
//| Barres depuis le dernier Golden Cross                             |
//+------------------------------------------------------------------+
int CMovingAverages::BarsSinceGoldenCross()
{
   if(!m_lastGoldenCross.isValid) return -1;

   datetime currentTime = iTime(m_symbol, m_timeframe, 0);
   int bars = Bars(m_symbol, m_timeframe, m_lastGoldenCross.time, currentTime);
   return bars;
}

//+------------------------------------------------------------------+
//| Barres depuis le dernier Death Cross                              |
//+------------------------------------------------------------------+
int CMovingAverages::BarsSinceDeathCross()
{
   if(!m_lastDeathCross.isValid) return -1;

   datetime currentTime = iTime(m_symbol, m_timeframe, 0);
   int bars = Bars(m_symbol, m_timeframe, m_lastDeathCross.time, currentTime);
   return bars;
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un rejet par mèche sur une EMA                  |
//+------------------------------------------------------------------+
bool CMovingAverages::IsWickRejection(int shift, double emaValue, bool checkBullish)
{
   double open = iOpen(m_symbol, m_timeframe, shift);
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);

   double range = high - low;
   if(range == 0) return false;

   double body = MathAbs(close - open);
   double bodyTop = MathMax(open, close);
   double bodyBottom = MathMin(open, close);

   if(checkBullish)
   {
      // Rejet haussier: mèche basse touche l'EMA, clôture au-dessus
      double lowerWick = bodyBottom - low;
      double wickRatio = lowerWick / range;

      // L'EMA doit être dans la zone de la mèche basse
      if(emaValue >= low && emaValue <= bodyBottom && wickRatio >= m_rejectionWickRatio)
      {
         // Clôture doit être positive ou neutre
         if(close >= open) return true;
      }
   }
   else
   {
      // Rejet baissier: mèche haute touche l'EMA, clôture en-dessous
      double upperWick = high - bodyTop;
      double wickRatio = upperWick / range;

      // L'EMA doit être dans la zone de la mèche haute
      if(emaValue <= high && emaValue >= bodyTop && wickRatio >= m_rejectionWickRatio)
      {
         // Clôture doit être négative ou neutre
         if(close <= open) return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter un rejet sur une EMA spécifique                          |
//+------------------------------------------------------------------+
bool CMovingAverages::DetectRejection(int shift, int emaPeriod, SEMARejection &rejection)
{
   rejection.detected = false;
   rejection.emaPeriod = emaPeriod;
   rejection.bar = shift;

   if(!LoadBuffers(shift + 1)) return false;

   double emaValue = 0;
   switch(emaPeriod)
   {
      case 21:  emaValue = m_ema21Buffer[shift]; break;
      case 50:  emaValue = m_ema50Buffer[shift]; break;
      case 200: emaValue = m_ema200Buffer[shift]; break;
      default:  return false;
   }

   rejection.emaValue = emaValue;

   double open = iOpen(m_symbol, m_timeframe, shift);
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);

   rejection.bodySize = MathAbs(close - open);

   // Vérifier rejet haussier
   if(IsWickRejection(shift, emaValue, true))
   {
      rejection.detected = true;
      rejection.isBullish = true;
      rejection.wickSize = MathMin(open, close) - low;
      AddRejection(rejection);
      return true;
   }

   // Vérifier rejet baissier
   if(IsWickRejection(shift, emaValue, false))
   {
      rejection.detected = true;
      rejection.isBullish = false;
      rejection.wickSize = high - MathMax(open, close);
      AddRejection(rejection);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter un rejet sur n'importe quelle EMA                        |
//+------------------------------------------------------------------+
bool CMovingAverages::DetectEMARejection(int shift, SEMARejection &rejection)
{
   // Priorité: EMA 21 > EMA 50 > EMA 200
   if(DetectRejection(shift, 21, rejection)) return true;
   if(DetectRejection(shift, 50, rejection)) return true;
   if(DetectRejection(shift, 200, rejection)) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Ajouter un rejet au cache                                         |
//+------------------------------------------------------------------+
void CMovingAverages::AddRejection(SEMARejection &rejection)
{
   int size = ArraySize(m_recentRejections);

   if(size >= m_maxRejections)
   {
      // Décaler pour faire de la place
      for(int i = 0; i < size - 1; i++)
      {
         m_recentRejections[i] = m_recentRejections[i + 1];
      }
      m_recentRejections[size - 1] = rejection;
   }
   else
   {
      ArrayResize(m_recentRejections, size + 1);
      m_recentRejections[size] = rejection;
   }
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a un rejet récent sur une EMA                     |
//+------------------------------------------------------------------+
bool CMovingAverages::HasRecentRejection(int emaPeriod, int maxBars)
{
   for(int i = ArraySize(m_recentRejections) - 1; i >= 0; i--)
   {
      if(m_recentRejections[i].emaPeriod == emaPeriod &&
         m_recentRejections[i].bar <= maxBars)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le support dynamique (EMA la plus proche sous le prix)    |
//+------------------------------------------------------------------+
double CMovingAverages::GetDynamicSupport(int shift)
{
   SEMAValues emas = GetAllEMAs(shift);
   double price = emas.price;
   double support = 0;

   // Trouver l'EMA la plus proche en dessous du prix
   if(emas.ema9 < price && emas.ema9 > support) support = emas.ema9;
   if(emas.ema21 < price && emas.ema21 > support) support = emas.ema21;
   if(emas.ema50 < price && emas.ema50 > support) support = emas.ema50;
   if(emas.ema200 < price && emas.ema200 > support) support = emas.ema200;

   return support;
}

//+------------------------------------------------------------------+
//| Obtenir la résistance dynamique (EMA la plus proche au-dessus)    |
//+------------------------------------------------------------------+
double CMovingAverages::GetDynamicResistance(int shift)
{
   SEMAValues emas = GetAllEMAs(shift);
   double price = emas.price;
   double resistance = DBL_MAX;

   // Trouver l'EMA la plus proche au-dessus du prix
   if(emas.ema9 > price && emas.ema9 < resistance) resistance = emas.ema9;
   if(emas.ema21 > price && emas.ema21 < resistance) resistance = emas.ema21;
   if(emas.ema50 > price && emas.ema50 < resistance) resistance = emas.ema50;
   if(emas.ema200 > price && emas.ema200 < resistance) resistance = emas.ema200;

   return (resistance == DBL_MAX) ? 0 : resistance;
}

//+------------------------------------------------------------------+
//| Obtenir l'EMA la plus proche                                      |
//+------------------------------------------------------------------+
double CMovingAverages::GetNearestEMA(int shift, bool above)
{
   return above ? GetDynamicResistance(shift) : GetDynamicSupport(shift);
}

//+------------------------------------------------------------------+
//| RÈGLE: LONG autorisé seulement si tendance le permet              |
//| On ne trade JAMAIS contre l'EMA 200                               |
//+------------------------------------------------------------------+
bool CMovingAverages::AllowLong(int shift)
{
   if(!LoadBuffers(shift + 1)) return false;

   double price = iClose(m_symbol, m_timeframe, shift);
   double ema200 = m_ema200Buffer[shift];
   double ema50 = m_ema50Buffer[shift];

   // RÈGLE ABSOLUE: Prix doit être au-dessus de l'EMA 200
   if(price < ema200) return false;

   // EMA 50 doit être au-dessus ou proche de l'EMA 200
   if(ema50 < ema200 * 0.99) return false;  // 1% de tolérance

   return true;
}

//+------------------------------------------------------------------+
//| RÈGLE: SHORT autorisé seulement si tendance le permet             |
//| On ne trade JAMAIS contre l'EMA 200                               |
//+------------------------------------------------------------------+
bool CMovingAverages::AllowShort(int shift)
{
   if(!LoadBuffers(shift + 1)) return false;

   double price = iClose(m_symbol, m_timeframe, shift);
   double ema200 = m_ema200Buffer[shift];
   double ema50 = m_ema50Buffer[shift];

   // RÈGLE ABSOLUE: Prix doit être en-dessous de l'EMA 200
   if(price > ema200) return false;

   // EMA 50 doit être en-dessous ou proche de l'EMA 200
   if(ema50 > ema200 * 1.01) return false;  // 1% de tolérance

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est en zone de pullback                       |
//+------------------------------------------------------------------+
bool CMovingAverages::IsPullbackZone(int shift, bool forLong)
{
   if(!LoadBuffers(shift + 1)) return false;

   double price = iClose(m_symbol, m_timeframe, shift);
   double ema21 = m_ema21Buffer[shift];
   double ema50 = m_ema50Buffer[shift];

   if(forLong)
   {
      // Pullback haussier: prix revient vers EMA 21 ou 50
      ENUM_TREND_STATE trend = GetTrendState(shift);
      if(trend != TREND_BULLISH) return false;

      // Prix proche de EMA 21 ou 50 (dans les 1%)
      double distTo21 = MathAbs(price - ema21) / price;
      double distTo50 = MathAbs(price - ema50) / price;

      return (distTo21 < 0.01 || distTo50 < 0.01);
   }
   else
   {
      // Pullback baissier: prix remonte vers EMA 21 ou 50
      ENUM_TREND_STATE trend = GetTrendState(shift);
      if(trend != TREND_BEARISH) return false;

      double distTo21 = MathAbs(price - ema21) / price;
      double distTo50 = MathAbs(price - ema50) / price;

      return (distTo21 < 0.01 || distTo50 < 0.01);
   }
}

//+------------------------------------------------------------------+
//| Vérifier si la direction demandée est contre-tendance             |
//+------------------------------------------------------------------+
bool CMovingAverages::IsCounterTrend(bool wantLong, int shift)
{
   ENUM_TREND_STATE trend = GetTrendState(shift);

   if(wantLong && trend == TREND_BEARISH) return true;
   if(!wantLong && trend == TREND_BULLISH) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement MTF                                         |
//| RÈGLE: Si Daily et H4 sont opposés → aucune alerte               |
//+------------------------------------------------------------------+
bool CMovingAverages::CheckMTFAlignment(ENUM_TREND_STATE dailyTrend,
                                         ENUM_TREND_STATE h4Trend)
{
   // Si l'un est neutre, on peut trader avec prudence
   if(dailyTrend == TREND_NEUTRAL || h4Trend == TREND_NEUTRAL)
      return true;

   // Si transition, attendre
   if(dailyTrend == TREND_TRANSITION || h4Trend == TREND_TRANSITION)
      return false;

   // Les deux doivent être dans la même direction
   return (dailyTrend == h4Trend);
}

//+------------------------------------------------------------------+
//| Analyse complète                                                  |
//+------------------------------------------------------------------+
STrendAnalysis CMovingAverages::Analyze(int shift)
{
   STrendAnalysis analysis;

   // État principal
   analysis.state = GetTrendState(shift);
   analysis.strength = GetTrendStrength(shift);

   // Valeurs
   analysis.values = GetAllEMAs(shift);
   analysis.slopes = GetSlopes(shift);
   analysis.ribbon = GetRibbonState(shift);

   // Croisements
   analysis.lastCross = (m_lastGoldenCross.isValid &&
                         (!m_lastDeathCross.isValid ||
                          m_lastGoldenCross.time > m_lastDeathCross.time))
                        ? m_lastGoldenCross : m_lastDeathCross;

   // Rejet
   DetectEMARejection(shift, analysis.lastRejection);

   // Filtres
   analysis.allowLong = AllowLong(shift);
   analysis.allowShort = AllowShort(shift);
   analysis.isPullback = IsPullbackZone(shift, analysis.state == TREND_BULLISH);

   // Support/Résistance
   analysis.dynamicSupport = GetDynamicSupport(shift);
   analysis.dynamicResistance = GetDynamicResistance(shift);

   // Alerte
   analysis.alert = GetCurrentAlert(shift);

   return analysis;
}

//+------------------------------------------------------------------+
//| Obtenir l'alerte actuelle                                         |
//+------------------------------------------------------------------+
SEMAAlert CMovingAverages::GetCurrentAlert(int shift)
{
   SEMAAlert alert;
   alert.level = ALERT_INFO;
   alert.event = EMA_EVENT_NONE;
   alert.message = "";
   alert.time = TimeCurrent();

   // DANGER: Croisements majeurs
   if(IsGoldenCross(shift))
   {
      alert.level = ALERT_DANGER;
      alert.event = EMA_GOLDEN_CROSS;
      alert.message = "GOLDEN CROSS! EMA 50 croise EMA 200 vers le haut - Changement de régime";
      return alert;
   }

   if(IsDeathCross(shift))
   {
      alert.level = ALERT_DANGER;
      alert.event = EMA_DEATH_CROSS;
      alert.message = "DEATH CROSS! EMA 50 croise EMA 200 vers le bas - Changement de régime";
      return alert;
   }

   // DANGER: Cassure EMA 200
   double price = iClose(m_symbol, m_timeframe, shift);
   double pricePrev = iClose(m_symbol, m_timeframe, shift + 1);
   double ema200 = GetEMA200(shift);
   double ema200Prev = GetEMA200(shift + 1);

   if(pricePrev > ema200Prev && price < ema200)
   {
      alert.level = ALERT_DANGER;
      alert.event = EMA_BREAK_200;
      alert.message = "DANGER! Prix casse sous EMA 200 - Sortir des longs";
      return alert;
   }

   if(pricePrev < ema200Prev && price > ema200)
   {
      alert.level = ALERT_DANGER;
      alert.event = EMA_BREAK_200;
      alert.message = "ATTENTION! Prix casse au-dessus EMA 200 - Sortir des shorts";
      return alert;
   }

   // SETUP: Ribbon aligné
   SRibbonState ribbon = GetRibbonState(shift);
   if(ribbon.isAligned)
   {
      alert.level = ALERT_SETUP;
      alert.event = ribbon.isBullish ? EMA_RIBBON_BULLISH : EMA_RIBBON_BEARISH;
      alert.message = ribbon.isBullish
                     ? "SETUP: EMA Ribbon aligné HAUSSIER - Chercher des achats sur repli"
                     : "SETUP: EMA Ribbon aligné BAISSIER - Chercher des ventes sur repli";
      return alert;
   }

   // INFO: Compression
   if(ribbon.isCompressed)
   {
      alert.level = ALERT_INFO;
      alert.event = EMA_RIBBON_COMPRESSION;
      alert.message = "INFO: EMAs compressées - Perte de momentum, attendre breakout";
      return alert;
   }

   // INFO: Rejet
   SEMARejection rejection;
   if(DetectEMARejection(shift, rejection))
   {
      alert.level = ALERT_INFO;
      if(rejection.emaPeriod == 21) alert.event = EMA_REJECTION_21;
      else if(rejection.emaPeriod == 50) alert.event = EMA_REJECTION_50;
      else alert.event = EMA_REJECTION_200;

      alert.message = StringFormat("INFO: Rejet %s sur EMA %d",
                                   rejection.isBullish ? "haussier" : "baissier",
                                   rejection.emaPeriod);
      return alert;
   }

   return alert;
}

//+------------------------------------------------------------------+
//| Convertir l'état de tendance en string                            |
//+------------------------------------------------------------------+
string CMovingAverages::TrendStateToString(ENUM_TREND_STATE state)
{
   switch(state)
   {
      case TREND_BULLISH:    return "HAUSSIER";
      case TREND_BEARISH:    return "BAISSIER";
      case TREND_NEUTRAL:    return "NEUTRE/RANGE";
      case TREND_TRANSITION: return "EN TRANSITION";
      default:               return "INCONNU";
   }
}

//+------------------------------------------------------------------+
//| Convertir la force en string                                      |
//+------------------------------------------------------------------+
string CMovingAverages::StrengthToString(ENUM_TREND_STRENGTH strength)
{
   switch(strength)
   {
      case STRENGTH_NONE:     return "Aucune";
      case STRENGTH_WEAK:     return "Faible";
      case STRENGTH_MODERATE: return "Modérée";
      case STRENGTH_STRONG:   return "Forte";
      case STRENGTH_EXTREME:  return "Extrême";
      default:                return "Inconnue";
   }
}

//+------------------------------------------------------------------+
//| Convertir l'événement en string                                   |
//+------------------------------------------------------------------+
string CMovingAverages::EventToString(ENUM_EMA_EVENT event)
{
   switch(event)
   {
      case EMA_EVENT_NONE:        return "Aucun";
      case EMA_GOLDEN_CROSS:      return "Golden Cross";
      case EMA_DEATH_CROSS:       return "Death Cross";
      case EMA_FAST_GOLDEN:       return "Golden Cross Rapide";
      case EMA_FAST_DEATH:        return "Death Cross Rapide";
      case EMA_RIBBON_BULLISH:    return "Ribbon Haussier";
      case EMA_RIBBON_BEARISH:    return "Ribbon Baissier";
      case EMA_RIBBON_COMPRESSION:return "Compression";
      case EMA_RIBBON_EXPANSION:  return "Expansion";
      case EMA_REJECTION_21:      return "Rejet EMA 21";
      case EMA_REJECTION_50:      return "Rejet EMA 50";
      case EMA_REJECTION_200:     return "Rejet EMA 200";
      case EMA_BREAK_50:          return "Cassure EMA 50";
      case EMA_BREAK_200:         return "Cassure EMA 200";
      default:                    return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Obtenir la description complète de la tendance                    |
//+------------------------------------------------------------------+
string CMovingAverages::GetTrendDescription(int shift)
{
   STrendAnalysis a = Analyze(shift);

   string desc = "";
   desc += "📊 ANALYSE EMA / TREND FILTER\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += "Tendance: " + TrendStateToString(a.state) + "\n";
   desc += "Force: " + StrengthToString(a.strength) + "\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

   desc += StringFormat("EMA 9:   %.5f\n", a.values.ema9);
   desc += StringFormat("EMA 21:  %.5f\n", a.values.ema21);
   desc += StringFormat("EMA 50:  %.5f\n", a.values.ema50);
   desc += StringFormat("EMA 200: %.5f\n", a.values.ema200);
   desc += StringFormat("Prix:    %.5f\n", a.values.price);

   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += "Ribbon: " + (a.ribbon.isAligned ? (a.ribbon.isBullish ? "Aligné HAUSSIER" : "Aligné BAISSIER") : "Non aligné") + "\n";
   desc += StringFormat("Largeur Ribbon: %.2f%%\n", a.ribbon.widthPercent * 100);

   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += "Long autorisé: " + (a.allowLong ? "OUI ✅" : "NON ❌") + "\n";
   desc += "Short autorisé: " + (a.allowShort ? "OUI ✅" : "NON ❌") + "\n";

   if(a.dynamicSupport > 0)
      desc += StringFormat("Support dynamique: %.5f\n", a.dynamicSupport);
   if(a.dynamicResistance > 0)
      desc += StringFormat("Résistance dynamique: %.5f\n", a.dynamicResistance);

   return desc;
}

//+------------------------------------------------------------------+
//| Obtenir le message d'alerte                                       |
//+------------------------------------------------------------------+
string CMovingAverages::GetAlertMessage(int shift)
{
   SEMAAlert alert = GetCurrentAlert(shift);

   if(alert.event == EMA_EVENT_NONE)
      return "";

   string prefix = "";
   switch(alert.level)
   {
      case ALERT_INFO:   prefix = "ℹ️ "; break;
      case ALERT_SETUP:  prefix = "📈 "; break;
      case ALERT_DANGER: prefix = "🔴 "; break;
   }

   return prefix + alert.message;
}

//+------------------------------------------------------------------+
