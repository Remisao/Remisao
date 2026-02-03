//+------------------------------------------------------------------+
//|                                              CandleAnalysis.mqh  |
//|                     CHAPITRE 1 - ANALYSE BOUGIES PROFESSIONNELLE |
//|                     FORCE & REJET - DÉCLENCHEUR FINAL            |
//|                     Bot Multi-Marchés Forex & Crypto             |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE:                                                      |
//| Une bougie raconte une bataille entre acheteurs et vendeurs      |
//|                                                                   |
//| Le module doit:                                                   |
//|   - Mesurer la conviction (force du mouvement)                   |
//|   - Détecter les manipulations (rejets de liquidité)             |
//|   - Confirmer ou invalider un scénario                           |
//|   - Servir de DÉCLENCHEUR FINAL, jamais de contexte seul         |
//|                                                                   |
//| RÈGLE D'OR:                                                       |
//|   On n'entre pas sur une idée, on entre sur une PREUVE           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Type de bougie                                                    |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_TYPE
{
   CANDLE_NEUTRAL = 0,         // Bougie neutre / indécision
   CANDLE_BULLISH_STRONG,      // Bougie haussière FORTE (corps >= 70%)
   CANDLE_BEARISH_STRONG,      // Bougie baissière FORTE (corps >= 70%)
   CANDLE_BULLISH_REJECTION,   // Rejet haussier (mèche basse >= 50%)
   CANDLE_BEARISH_REJECTION,   // Rejet baissier (mèche haute >= 50%)
   CANDLE_DOJI,                // Doji (indécision extrême)
   CANDLE_ENGULFING_BULL,      // Englobante haussière
   CANDLE_ENGULFING_BEAR,      // Englobante baissière
   CANDLE_INSIDE_BAR,          // Inside bar (compression)
   CANDLE_OUTSIDE_BAR          // Outside bar (expansion)
};

//+------------------------------------------------------------------+
//| Statut de confirmation                                            |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_STATUS
{
   STATUS_NONE = 0,
   STATUS_CONFIRMATION,        // Bougie de confirmation valide
   STATUS_REJECTION,           // Bougie de rejet détectée
   STATUS_NEUTRAL,             // Pas de signal clair
   STATUS_INVALIDATION         // Signal invalide / contraire
};

//+------------------------------------------------------------------+
//| Niveau d'alerte bougie                                            |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_ALERT
{
   CANDLE_ALERT_NONE = 0,
   CANDLE_ALERT_INFO,          // Information (rejet détecté, force sans contexte)
   CANDLE_ALERT_SETUP,         // Setup valide (confirmation)
   CANDLE_ALERT_INVALIDATION   // Invalidation (bougie contraire forte)
};

//+------------------------------------------------------------------+
//| Direction de la bougie                                            |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_DIRECTION
{
   DIR_NONE = 0,
   DIR_BULLISH,
   DIR_BEARISH
};

//+------------------------------------------------------------------+
//| Structure anatomie complète d'une bougie                          |
//+------------------------------------------------------------------+
struct SCandleAnatomy
{
   // Données OHLC brutes
   double            open;
   double            high;
   double            low;
   double            close;
   datetime          time;
   int               bar;              // Index de la barre

   // Mesures absolues
   double            totalSize;        // High - Low
   double            bodySize;         // |Close - Open|
   double            upperWick;        // High - max(Open, Close)
   double            lowerWick;        // min(Open, Close) - Low

   // Ratios normalisés (0-100%)
   double            bodyRatio;        // Corps en % de la taille totale
   double            upperWickRatio;   // Mèche haute en %
   double            lowerWickRatio;   // Mèche basse en %

   // Direction et position
   bool              isBullish;        // Close > Open
   double            closePosition;    // Position du close (0=low, 100=high)

   // Comparaison relative
   double            relativeSize;     // Taille vs moyenne récente
   bool              isLargerThanAvg;  // Plus grande que la moyenne
};

//+------------------------------------------------------------------+
//| Structure analyse complète d'une bougie                           |
//+------------------------------------------------------------------+
struct SCandleData
{
   // Anatomie
   SCandleAnatomy    anatomy;

   // Classification
   ENUM_CANDLE_TYPE  type;
   ENUM_CANDLE_DIRECTION direction;
   ENUM_CANDLE_STATUS status;

   // Score de confiance (0-100)
   int               score;
   string            scoreReason;

   // Qualité du signal
   bool              isValidSignal;    // Passe les filtres
   bool              hasContext;       // A un contexte (zone clé, etc.)
   string            filterMessage;    // Raison si filtré

   // Pour les patterns multi-bougies
   bool              isPartOfPattern;
   string            patternName;
};

//+------------------------------------------------------------------+
//| Structure pour le momentum (séquence de bougies)                  |
//+------------------------------------------------------------------+
struct SMomentum
{
   int               consecutiveBullish;   // Bougies haussières consécutives
   int               consecutiveBearish;   // Bougies baissières consécutives
   int               consecutiveStrong;    // Bougies fortes consécutives
   double            averageBodyRatio;     // Ratio corps moyen
   bool              isAccelerating;       // Momentum en accélération
   bool              isDecelerating;       // Momentum en décélération
   ENUM_CANDLE_DIRECTION dominantDirection;
};

//+------------------------------------------------------------------+
//| Structure d'alerte bougie                                         |
//+------------------------------------------------------------------+
struct SCandleAlert
{
   ENUM_CANDLE_ALERT level;
   ENUM_CANDLE_TYPE  candleType;
   ENUM_CANDLE_DIRECTION direction;
   string            message;
   int               score;
   datetime          time;
   ENUM_TIMEFRAMES   timeframe;
};

//+------------------------------------------------------------------+
//| Structure Multi-Timeframe                                         |
//+------------------------------------------------------------------+
struct SMTFCandle
{
   SCandleData       h4;
   SCandleData       h1;
   SCandleData       m15;
   bool              isAligned;        // Même direction sur toutes les UT
   bool              hasConfirmation;  // Au moins une confirmation
   string            description;
};

//+------------------------------------------------------------------+
//| Classe d'analyse des bougies PROFESSIONNELLE                      |
//+------------------------------------------------------------------+
class CCandleAnalysis
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Seuils configurables
   double            m_strongBodyThreshold;    // 70% pour bougie forte
   double            m_rejectionThreshold;     // 50% pour rejet
   double            m_dojiThreshold;          // 10% pour doji
   double            m_closePositionThreshold; // 80% pour close près de l'extrême

   // Paramètres de filtrage
   int               m_avgPeriod;              // Période pour moyenne (défaut: 20)
   double            m_minSizeMultiplier;      // Taille min vs moyenne (défaut: 0.5)

   // Cache
   double            m_avgCandleSize;          // Taille moyenne des bougies
   datetime          m_lastAvgCalcTime;        // Dernier calcul de moyenne

   // ============ MÉTHODES PRIVÉES ============

   // Calculs d'anatomie
   void              CalculateAnatomy(SCandleAnatomy &anatomy);
   double            CalculateClosePosition(const SCandleAnatomy &anatomy);
   double            CalculateRelativeSize(double size);

   // Moyenne mobile de la taille des bougies
   void              UpdateAverageCandleSize();
   double            GetAverageCandleSize(int period);

   // Classification
   ENUM_CANDLE_TYPE  ClassifyCandle(const SCandleAnatomy &anatomy);
   int               CalculateScore(const SCandleAnatomy &anatomy, ENUM_CANDLE_TYPE type);

   // Validation
   bool              ValidateStrongCandle(const SCandleAnatomy &anatomy);
   bool              ValidateRejection(const SCandleAnatomy &anatomy, bool isBullish);

public:
   CCandleAnalysis();
   ~CCandleAnalysis();

   // ============ INITIALISATION ============
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetThresholds(double strongBody, double rejection, double doji);
   void              SetFilterParams(int avgPeriod, double minSizeMultiplier);

   // ============ ANALYSE PRINCIPALE ============

   // Analyse d'une bougie
   SCandleData       AnalyzeCandle(int shift);
   SCandleAnatomy    GetCandleAnatomy(int shift);

   // Analyse multiple
   bool              AnalyzeMultiple(int startShift, int count, SCandleData &candles[]);

   // ============ DÉTECTION FORCE ============

   // Bougie de FORCE (Corps >= 70%)
   bool              IsStrongCandle(int shift);
   bool              IsStrongBullish(int shift);
   bool              IsStrongBearish(int shift);
   bool              ValidateStrength(int shift, bool requireCloseNearExtreme);

   // ============ DÉTECTION REJET ============

   // Bougie de REJET (Mèche >= 50%)
   bool              IsRejectionCandle(int shift);
   bool              IsBullishRejection(int shift);
   bool              IsBearishRejection(int shift);
   bool              ValidateRejectionContext(int shift, double zonePrice);

   // ============ PATTERNS ============

   // Patterns simples
   bool              IsDoji(int shift);
   bool              IsInsideBar(int shift);
   bool              IsOutsideBar(int shift);

   // Patterns multi-bougies
   bool              IsEngulfingBullish(int shift);
   bool              IsEngulfingBearish(int shift);
   bool              IsMorningStar(int shift);
   bool              IsEveningStar(int shift);
   bool              IsPinBar(int shift, bool &isBullish);
   bool              IsTweezerTop(int shift);
   bool              IsTweezerBottom(int shift);

   // ============ MOMENTUM ============

   SMomentum         GetMomentum(int lookback);
   bool              IsMomentumBullish(int lookback);
   bool              IsMomentumBearish(int lookback);
   bool              IsMomentumAccelerating(int lookback);

   // ============ CONFIRMATION ============

   // Confirmation finale du signal
   bool              HasBullishConfirmation(int shift);
   bool              HasBearishConfirmation(int shift);
   ENUM_CANDLE_STATUS GetConfirmationStatus(int shift, bool expectBullish);

   // ============ FILTRES ANTI-FAUX SIGNAUX ============

   // Filtres de qualité
   bool              IsValidSize(int shift);           // Taille suffisante
   bool              IsNotInRange(int shift);          // Pas en plein range
   bool              HasZoneContext(int shift, double zonePrice, double tolerance);
   bool              PassesAllFilters(int shift, SCandleData &candle);

   // ============ ALERTES ============

   SCandleAlert      GetCurrentAlert(int shift);
   string            GenerateAlertMessage(const SCandleData &candle);

   // ============ MULTI-TIMEFRAME ============

   // Note: Nécessite des instances séparées par TF
   bool              CheckMTFAlignment(ENUM_CANDLE_DIRECTION h4Dir,
                                       ENUM_CANDLE_DIRECTION h1Dir,
                                       ENUM_CANDLE_DIRECTION m15Dir);

   // ============ UTILITAIRES ============

   string            TypeToString(ENUM_CANDLE_TYPE type);
   string            StatusToString(ENUM_CANDLE_STATUS status);
   string            DirectionToString(ENUM_CANDLE_DIRECTION dir);
   string            GetCandleDescription(int shift);
   string            GetDetailedAnalysis(int shift);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CCandleAnalysis::CCandleAnalysis()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;

   // Seuils par défaut (RÈGLES Chapitre 1)
   m_strongBodyThreshold = 70.0;       // Corps >= 70% = Force
   m_rejectionThreshold = 50.0;        // Mèche >= 50% = Rejet
   m_dojiThreshold = 10.0;             // Corps <= 10% = Doji
   m_closePositionThreshold = 80.0;    // Close >= 80% vers l'extrême

   // Paramètres de filtrage
   m_avgPeriod = 20;
   m_minSizeMultiplier = 0.5;

   // Cache
   m_avgCandleSize = 0;
   m_lastAvgCalcTime = 0;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CCandleAnalysis::~CCandleAnalysis()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CCandleAnalysis::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_avgCandleSize = 0;
   m_lastAvgCalcTime = 0;

   Print("✅ Module Bougies initialisé: ", m_symbol, " ", EnumToString(m_timeframe));
}

//+------------------------------------------------------------------+
//| Configuration des seuils                                          |
//+------------------------------------------------------------------+
void CCandleAnalysis::SetThresholds(double strongBody, double rejection, double doji)
{
   m_strongBodyThreshold = MathMax(50.0, MathMin(90.0, strongBody));
   m_rejectionThreshold = MathMax(30.0, MathMin(70.0, rejection));
   m_dojiThreshold = MathMax(5.0, MathMin(20.0, doji));
}

//+------------------------------------------------------------------+
//| Configuration des paramètres de filtrage                          |
//+------------------------------------------------------------------+
void CCandleAnalysis::SetFilterParams(int avgPeriod, double minSizeMultiplier)
{
   m_avgPeriod = MathMax(10, avgPeriod);
   m_minSizeMultiplier = MathMax(0.3, MathMin(1.0, minSizeMultiplier));
}

//+------------------------------------------------------------------+
//| Mettre à jour la taille moyenne des bougies                       |
//+------------------------------------------------------------------+
void CCandleAnalysis::UpdateAverageCandleSize()
{
   datetime currentTime = iTime(m_symbol, m_timeframe, 0);

   // Recalculer toutes les 10 bougies
   if(m_lastAvgCalcTime != 0 && currentTime - m_lastAvgCalcTime < PeriodSeconds(m_timeframe) * 10)
      return;

   m_avgCandleSize = GetAverageCandleSize(m_avgPeriod);
   m_lastAvgCalcTime = currentTime;
}

//+------------------------------------------------------------------+
//| Calculer la taille moyenne des bougies                            |
//+------------------------------------------------------------------+
double CCandleAnalysis::GetAverageCandleSize(int period)
{
   double sum = 0;
   int count = 0;

   for(int i = 1; i <= period; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double size = high - low;

      if(size > 0)
      {
         sum += size;
         count++;
      }
   }

   return (count > 0) ? (sum / count) : 0;
}

//+------------------------------------------------------------------+
//| Calculer l'anatomie d'une bougie                                  |
//+------------------------------------------------------------------+
void CCandleAnalysis::CalculateAnatomy(SCandleAnatomy &anatomy)
{
   // Mesures absolues
   anatomy.totalSize = anatomy.high - anatomy.low;
   anatomy.bodySize = MathAbs(anatomy.close - anatomy.open);
   anatomy.upperWick = anatomy.high - MathMax(anatomy.open, anatomy.close);
   anatomy.lowerWick = MathMin(anatomy.open, anatomy.close) - anatomy.low;

   // Ratios normalisés
   if(anatomy.totalSize > 0)
   {
      anatomy.bodyRatio = (anatomy.bodySize / anatomy.totalSize) * 100.0;
      anatomy.upperWickRatio = (anatomy.upperWick / anatomy.totalSize) * 100.0;
      anatomy.lowerWickRatio = (anatomy.lowerWick / anatomy.totalSize) * 100.0;
   }
   else
   {
      anatomy.bodyRatio = 0;
      anatomy.upperWickRatio = 0;
      anatomy.lowerWickRatio = 0;
   }

   // Direction
   anatomy.isBullish = (anatomy.close > anatomy.open);

   // Position du close (0 = low, 100 = high)
   anatomy.closePosition = CalculateClosePosition(anatomy);

   // Taille relative
   UpdateAverageCandleSize();
   anatomy.relativeSize = CalculateRelativeSize(anatomy.totalSize);
   anatomy.isLargerThanAvg = (anatomy.relativeSize > 1.0);
}

//+------------------------------------------------------------------+
//| Calculer la position du close (0-100)                             |
//| 0 = close au low, 100 = close au high                             |
//+------------------------------------------------------------------+
double CCandleAnalysis::CalculateClosePosition(const SCandleAnatomy &anatomy)
{
   if(anatomy.totalSize == 0) return 50.0;
   return ((anatomy.close - anatomy.low) / anatomy.totalSize) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculer la taille relative vs moyenne                            |
//+------------------------------------------------------------------+
double CCandleAnalysis::CalculateRelativeSize(double size)
{
   if(m_avgCandleSize == 0) return 1.0;
   return size / m_avgCandleSize;
}

//+------------------------------------------------------------------+
//| Obtenir l'anatomie d'une bougie                                   |
//+------------------------------------------------------------------+
SCandleAnatomy CCandleAnalysis::GetCandleAnatomy(int shift)
{
   SCandleAnatomy anatomy;

   anatomy.open = iOpen(m_symbol, m_timeframe, shift);
   anatomy.high = iHigh(m_symbol, m_timeframe, shift);
   anatomy.low = iLow(m_symbol, m_timeframe, shift);
   anatomy.close = iClose(m_symbol, m_timeframe, shift);
   anatomy.time = iTime(m_symbol, m_timeframe, shift);
   anatomy.bar = shift;

   CalculateAnatomy(anatomy);

   return anatomy;
}

//+------------------------------------------------------------------+
//| Classifier une bougie                                             |
//+------------------------------------------------------------------+
ENUM_CANDLE_TYPE CCandleAnalysis::ClassifyCandle(const SCandleAnatomy &anatomy)
{
   // RÈGLE: Bougie forte si Corps >= 70%
   if(anatomy.bodyRatio >= m_strongBodyThreshold)
   {
      // Vérifier que le close est proche de l'extrémité
      if(anatomy.isBullish && anatomy.closePosition >= m_closePositionThreshold)
         return CANDLE_BULLISH_STRONG;

      if(!anatomy.isBullish && anatomy.closePosition <= (100.0 - m_closePositionThreshold))
         return CANDLE_BEARISH_STRONG;

      // Corps fort mais close pas optimal - toujours considéré fort
      return anatomy.isBullish ? CANDLE_BULLISH_STRONG : CANDLE_BEARISH_STRONG;
   }

   // RÈGLE: Rejet si mèche >= 50% ET petit corps ET close opposé à la mèche
   // Rejet haussier: longue mèche basse
   if(anatomy.lowerWickRatio >= m_rejectionThreshold &&
      anatomy.bodyRatio < 40.0 &&
      anatomy.closePosition >= 50.0)
   {
      return CANDLE_BULLISH_REJECTION;
   }

   // Rejet baissier: longue mèche haute
   if(anatomy.upperWickRatio >= m_rejectionThreshold &&
      anatomy.bodyRatio < 40.0 &&
      anatomy.closePosition <= 50.0)
   {
      return CANDLE_BEARISH_REJECTION;
   }

   // Doji
   if(anatomy.bodyRatio <= m_dojiThreshold)
   {
      return CANDLE_DOJI;
   }

   return CANDLE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Calculer le score de confiance (0-100)                            |
//+------------------------------------------------------------------+
int CCandleAnalysis::CalculateScore(const SCandleAnatomy &anatomy, ENUM_CANDLE_TYPE type)
{
   int score = 0;

   switch(type)
   {
      case CANDLE_BULLISH_STRONG:
      case CANDLE_BEARISH_STRONG:
      {
         // Base: ratio du corps
         score = (int)MathMin(40, anatomy.bodyRatio * 0.5);

         // Bonus: close proche de l'extrémité
         if(type == CANDLE_BULLISH_STRONG && anatomy.closePosition >= 85) score += 15;
         else if(type == CANDLE_BEARISH_STRONG && anatomy.closePosition <= 15) score += 15;

         // Bonus: peu de mèche contre la direction
         if(type == CANDLE_BULLISH_STRONG && anatomy.upperWickRatio < 10) score += 15;
         else if(type == CANDLE_BEARISH_STRONG && anatomy.lowerWickRatio < 10) score += 15;

         // Bonus: taille supérieure à la moyenne
         if(anatomy.isLargerThanAvg) score += 10;
         if(anatomy.relativeSize > 1.5) score += 10;

         break;
      }

      case CANDLE_BULLISH_REJECTION:
      case CANDLE_BEARISH_REJECTION:
      {
         // Base: ratio de la mèche de rejet
         double wickRatio = (type == CANDLE_BULLISH_REJECTION)
                           ? anatomy.lowerWickRatio
                           : anatomy.upperWickRatio;
         score = (int)MathMin(40, wickRatio * 0.7);

         // Bonus: petit corps
         if(anatomy.bodyRatio < 20) score += 15;

         // Bonus: close opposé à la mèche
         if(type == CANDLE_BULLISH_REJECTION && anatomy.closePosition >= 70) score += 15;
         else if(type == CANDLE_BEARISH_REJECTION && anatomy.closePosition <= 30) score += 15;

         // Bonus: taille significative
         if(anatomy.isLargerThanAvg) score += 10;

         // Bonus: mèche opposée très petite
         double oppositeWick = (type == CANDLE_BULLISH_REJECTION)
                              ? anatomy.upperWickRatio
                              : anatomy.lowerWickRatio;
         if(oppositeWick < 15) score += 10;

         break;
      }

      case CANDLE_DOJI:
      {
         score = 30;  // Score de base faible pour doji
         // Bonus si mèches significatives
         if(anatomy.upperWickRatio > 30 && anatomy.lowerWickRatio > 30) score += 20;
         break;
      }

      default:
         score = 20;  // Score neutre
         break;
   }

   return MathMin(100, MathMax(0, score));
}

//+------------------------------------------------------------------+
//| Valider une bougie de force                                       |
//+------------------------------------------------------------------+
bool CCandleAnalysis::ValidateStrongCandle(const SCandleAnatomy &anatomy)
{
   // Corps doit être >= seuil
   if(anatomy.bodyRatio < m_strongBodyThreshold) return false;

   // Taille doit être significative
   if(anatomy.relativeSize < m_minSizeMultiplier) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Valider un rejet                                                  |
//+------------------------------------------------------------------+
bool CCandleAnalysis::ValidateRejection(const SCandleAnatomy &anatomy, bool isBullish)
{
   if(isBullish)
   {
      // Mèche basse >= seuil
      if(anatomy.lowerWickRatio < m_rejectionThreshold) return false;

      // Close au-dessus de 50% de la bougie
      if(anatomy.closePosition < 50.0) return false;

      // Mèche haute petite
      if(anatomy.upperWickRatio > 30.0) return false;
   }
   else
   {
      // Mèche haute >= seuil
      if(anatomy.upperWickRatio < m_rejectionThreshold) return false;

      // Close en-dessous de 50% de la bougie
      if(anatomy.closePosition > 50.0) return false;

      // Mèche basse petite
      if(anatomy.lowerWickRatio > 30.0) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Analyse complète d'une bougie                                     |
//+------------------------------------------------------------------+
SCandleData CCandleAnalysis::AnalyzeCandle(int shift)
{
   SCandleData candle;

   // Anatomie
   candle.anatomy = GetCandleAnatomy(shift);

   // Classification
   candle.type = ClassifyCandle(candle.anatomy);

   // Direction
   if(candle.type == CANDLE_BULLISH_STRONG || candle.type == CANDLE_BULLISH_REJECTION ||
      candle.type == CANDLE_ENGULFING_BULL)
      candle.direction = DIR_BULLISH;
   else if(candle.type == CANDLE_BEARISH_STRONG || candle.type == CANDLE_BEARISH_REJECTION ||
           candle.type == CANDLE_ENGULFING_BEAR)
      candle.direction = DIR_BEARISH;
   else
      candle.direction = DIR_NONE;

   // Score
   candle.score = CalculateScore(candle.anatomy, candle.type);

   // Raison du score
   if(candle.score >= 70)
      candle.scoreReason = "Signal de haute qualité";
   else if(candle.score >= 50)
      candle.scoreReason = "Signal modéré";
   else
      candle.scoreReason = "Signal faible";

   // Statut
   if(candle.type == CANDLE_BULLISH_STRONG || candle.type == CANDLE_BEARISH_STRONG)
      candle.status = STATUS_CONFIRMATION;
   else if(candle.type == CANDLE_BULLISH_REJECTION || candle.type == CANDLE_BEARISH_REJECTION)
      candle.status = STATUS_REJECTION;
   else
      candle.status = STATUS_NEUTRAL;

   // Validation par les filtres
   candle.isValidSignal = PassesAllFilters(shift, candle);
   candle.hasContext = false;  // À définir par le contexte externe

   // Patterns
   candle.isPartOfPattern = false;
   candle.patternName = "";

   // Vérifier les patterns
   if(IsEngulfingBullish(shift))
   {
      candle.type = CANDLE_ENGULFING_BULL;
      candle.direction = DIR_BULLISH;
      candle.status = STATUS_CONFIRMATION;
      candle.isPartOfPattern = true;
      candle.patternName = "Englobante Haussière";
      candle.score = MathMax(candle.score, 75);
   }
   else if(IsEngulfingBearish(shift))
   {
      candle.type = CANDLE_ENGULFING_BEAR;
      candle.direction = DIR_BEARISH;
      candle.status = STATUS_CONFIRMATION;
      candle.isPartOfPattern = true;
      candle.patternName = "Englobante Baissière";
      candle.score = MathMax(candle.score, 75);
   }

   return candle;
}

//+------------------------------------------------------------------+
//| Analyser plusieurs bougies                                        |
//+------------------------------------------------------------------+
bool CCandleAnalysis::AnalyzeMultiple(int startShift, int count, SCandleData &candles[])
{
   ArrayResize(candles, count);

   for(int i = 0; i < count; i++)
   {
      candles[i] = AnalyzeCandle(startShift + i);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Bougie de force (Corps >= 70%)                                    |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsStrongCandle(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.bodyRatio >= m_strongBodyThreshold);
}

//+------------------------------------------------------------------+
//| Bougie haussière forte                                            |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsStrongBullish(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.bodyRatio >= m_strongBodyThreshold && anatomy.isBullish);
}

//+------------------------------------------------------------------+
//| Bougie baissière forte                                            |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsStrongBearish(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.bodyRatio >= m_strongBodyThreshold && !anatomy.isBullish);
}

//+------------------------------------------------------------------+
//| Valider la force avec close près de l'extrême                     |
//+------------------------------------------------------------------+
bool CCandleAnalysis::ValidateStrength(int shift, bool requireCloseNearExtreme)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);

   if(anatomy.bodyRatio < m_strongBodyThreshold)
      return false;

   if(requireCloseNearExtreme)
   {
      if(anatomy.isBullish && anatomy.closePosition < m_closePositionThreshold)
         return false;
      if(!anatomy.isBullish && anatomy.closePosition > (100.0 - m_closePositionThreshold))
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Bougie de rejet (Mèche >= 50%)                                    |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsRejectionCandle(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.upperWickRatio >= m_rejectionThreshold ||
           anatomy.lowerWickRatio >= m_rejectionThreshold);
}

//+------------------------------------------------------------------+
//| Rejet haussier (mèche basse >= 50%)                               |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsBullishRejection(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return ValidateRejection(anatomy, true);
}

//+------------------------------------------------------------------+
//| Rejet baissier (mèche haute >= 50%)                               |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsBearishRejection(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return ValidateRejection(anatomy, false);
}

//+------------------------------------------------------------------+
//| Valider un rejet avec contexte (zone clé)                         |
//+------------------------------------------------------------------+
bool CCandleAnalysis::ValidateRejectionContext(int shift, double zonePrice)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);

   // Vérifier que c'est bien un rejet
   bool isBullishRej = ValidateRejection(anatomy, true);
   bool isBearishRej = ValidateRejection(anatomy, false);

   if(!isBullishRej && !isBearishRej)
      return false;

   // Vérifier que le rejet a touché la zone
   double tolerance = anatomy.totalSize * 0.5;

   if(isBullishRej)
   {
      // La mèche basse doit avoir touché la zone
      if(anatomy.low <= zonePrice + tolerance && anatomy.low >= zonePrice - tolerance)
         return true;
   }

   if(isBearishRej)
   {
      // La mèche haute doit avoir touché la zone
      if(anatomy.high >= zonePrice - tolerance && anatomy.high <= zonePrice + tolerance)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Doji                                                              |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsDoji(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.bodyRatio <= m_dojiThreshold);
}

//+------------------------------------------------------------------+
//| Inside Bar (bougie contenue dans la précédente)                   |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsInsideBar(int shift)
{
   double currHigh = iHigh(m_symbol, m_timeframe, shift);
   double currLow = iLow(m_symbol, m_timeframe, shift);
   double prevHigh = iHigh(m_symbol, m_timeframe, shift + 1);
   double prevLow = iLow(m_symbol, m_timeframe, shift + 1);

   return (currHigh <= prevHigh && currLow >= prevLow);
}

//+------------------------------------------------------------------+
//| Outside Bar (bougie englobe la précédente)                        |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsOutsideBar(int shift)
{
   double currHigh = iHigh(m_symbol, m_timeframe, shift);
   double currLow = iLow(m_symbol, m_timeframe, shift);
   double prevHigh = iHigh(m_symbol, m_timeframe, shift + 1);
   double prevLow = iLow(m_symbol, m_timeframe, shift + 1);

   return (currHigh >= prevHigh && currLow <= prevLow);
}

//+------------------------------------------------------------------+
//| Englobante haussière                                              |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEngulfingBullish(int shift)
{
   SCandleAnatomy current = GetCandleAnatomy(shift);
   SCandleAnatomy previous = GetCandleAnatomy(shift + 1);

   // Bougie actuelle haussière
   if(!current.isBullish) return false;

   // Bougie précédente baissière
   if(previous.isBullish) return false;

   // Le corps actuel englobe le corps précédent
   double currBodyTop = MathMax(current.open, current.close);
   double currBodyBottom = MathMin(current.open, current.close);
   double prevBodyTop = MathMax(previous.open, previous.close);
   double prevBodyBottom = MathMin(previous.open, previous.close);

   if(currBodyBottom <= prevBodyBottom && currBodyTop >= prevBodyTop)
   {
      // Bonus: la bougie actuelle est significativement plus grande
      if(current.bodySize > previous.bodySize * 1.2)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Englobante baissière                                              |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEngulfingBearish(int shift)
{
   SCandleAnatomy current = GetCandleAnatomy(shift);
   SCandleAnatomy previous = GetCandleAnatomy(shift + 1);

   // Bougie actuelle baissière
   if(current.isBullish) return false;

   // Bougie précédente haussière
   if(!previous.isBullish) return false;

   // Le corps actuel englobe le corps précédent
   double currBodyTop = MathMax(current.open, current.close);
   double currBodyBottom = MathMin(current.open, current.close);
   double prevBodyTop = MathMax(previous.open, previous.close);
   double prevBodyBottom = MathMin(previous.open, previous.close);

   if(currBodyTop >= prevBodyTop && currBodyBottom <= prevBodyBottom)
   {
      if(current.bodySize > previous.bodySize * 1.2)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Morning Star (3 bougies)                                          |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsMorningStar(int shift)
{
   SCandleAnatomy candle1 = GetCandleAnatomy(shift + 2);  // Première
   SCandleAnatomy candle2 = GetCandleAnatomy(shift + 1);  // Milieu
   SCandleAnatomy candle3 = GetCandleAnatomy(shift);      // Dernière

   // Première: baissière forte
   if(candle1.isBullish || candle1.bodyRatio < 50.0) return false;

   // Deuxième: petit corps (gap down préféré)
   if(candle2.bodyRatio > 30.0) return false;

   // Troisième: haussière forte
   if(!candle3.isBullish || candle3.bodyRatio < 50.0) return false;

   // La troisième clôture au-dessus du milieu de la première
   double midPoint = (candle1.open + candle1.close) / 2.0;
   if(candle3.close < midPoint) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Evening Star (3 bougies)                                          |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEveningStar(int shift)
{
   SCandleAnatomy candle1 = GetCandleAnatomy(shift + 2);
   SCandleAnatomy candle2 = GetCandleAnatomy(shift + 1);
   SCandleAnatomy candle3 = GetCandleAnatomy(shift);

   // Première: haussière forte
   if(!candle1.isBullish || candle1.bodyRatio < 50.0) return false;

   // Deuxième: petit corps
   if(candle2.bodyRatio > 30.0) return false;

   // Troisième: baissière forte
   if(candle3.isBullish || candle3.bodyRatio < 50.0) return false;

   // La troisième clôture en-dessous du milieu de la première
   double midPoint = (candle1.open + candle1.close) / 2.0;
   if(candle3.close > midPoint) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Pin Bar                                                           |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsPinBar(int shift, bool &isBullish)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);

   // Pin Bar haussier (Hammer)
   if(anatomy.lowerWickRatio >= m_rejectionThreshold &&
      anatomy.upperWickRatio < 25.0 &&
      anatomy.bodyRatio < 40.0)
   {
      isBullish = true;
      return true;
   }

   // Pin Bar baissier (Shooting Star)
   if(anatomy.upperWickRatio >= m_rejectionThreshold &&
      anatomy.lowerWickRatio < 25.0 &&
      anatomy.bodyRatio < 40.0)
   {
      isBullish = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Tweezer Top                                                       |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsTweezerTop(int shift)
{
   double currHigh = iHigh(m_symbol, m_timeframe, shift);
   double prevHigh = iHigh(m_symbol, m_timeframe, shift + 1);

   SCandleAnatomy current = GetCandleAnatomy(shift);
   SCandleAnatomy previous = GetCandleAnatomy(shift + 1);

   // Mêmes hauts (tolérance 0.1%)
   double tolerance = currHigh * 0.001;
   if(MathAbs(currHigh - prevHigh) > tolerance) return false;

   // Première haussière, deuxième baissière
   if(!previous.isBullish || current.isBullish) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Tweezer Bottom                                                    |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsTweezerBottom(int shift)
{
   double currLow = iLow(m_symbol, m_timeframe, shift);
   double prevLow = iLow(m_symbol, m_timeframe, shift + 1);

   SCandleAnatomy current = GetCandleAnatomy(shift);
   SCandleAnatomy previous = GetCandleAnatomy(shift + 1);

   // Mêmes bas
   double tolerance = currLow * 0.001;
   if(MathAbs(currLow - prevLow) > tolerance) return false;

   // Première baissière, deuxième haussière
   if(previous.isBullish || !current.isBullish) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir le momentum sur N bougies                                 |
//+------------------------------------------------------------------+
SMomentum CCandleAnalysis::GetMomentum(int lookback)
{
   SMomentum momentum;
   momentum.consecutiveBullish = 0;
   momentum.consecutiveBearish = 0;
   momentum.consecutiveStrong = 0;
   momentum.averageBodyRatio = 0;
   momentum.isAccelerating = false;
   momentum.isDecelerating = false;
   momentum.dominantDirection = DIR_NONE;

   double sumBodyRatio = 0;
   int bullCount = 0;
   int bearCount = 0;

   // Compter les bougies consécutives
   bool firstDirection = true;
   bool lastWasBullish = false;

   for(int i = 1; i <= lookback; i++)
   {
      SCandleAnatomy anatomy = GetCandleAnatomy(i);
      sumBodyRatio += anatomy.bodyRatio;

      if(firstDirection)
      {
         lastWasBullish = anatomy.isBullish;
         firstDirection = false;
      }

      if(anatomy.isBullish)
      {
         bullCount++;
         if(lastWasBullish && i <= 5) momentum.consecutiveBullish++;
      }
      else
      {
         bearCount++;
         if(!lastWasBullish && i <= 5) momentum.consecutiveBearish++;
      }

      if(anatomy.bodyRatio >= m_strongBodyThreshold && i <= 5)
         momentum.consecutiveStrong++;

      lastWasBullish = anatomy.isBullish;
   }

   momentum.averageBodyRatio = sumBodyRatio / lookback;

   // Direction dominante
   if(bullCount > bearCount * 1.5)
      momentum.dominantDirection = DIR_BULLISH;
   else if(bearCount > bullCount * 1.5)
      momentum.dominantDirection = DIR_BEARISH;

   // Vérifier accélération/décélération
   if(lookback >= 3)
   {
      SCandleAnatomy recent = GetCandleAnatomy(1);
      SCandleAnatomy older = GetCandleAnatomy(3);

      if(recent.bodyRatio > older.bodyRatio * 1.3)
         momentum.isAccelerating = true;
      else if(recent.bodyRatio < older.bodyRatio * 0.7)
         momentum.isDecelerating = true;
   }

   return momentum;
}

//+------------------------------------------------------------------+
//| Momentum haussier                                                 |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsMomentumBullish(int lookback)
{
   SMomentum mom = GetMomentum(lookback);
   return (mom.dominantDirection == DIR_BULLISH && mom.consecutiveBullish >= 2);
}

//+------------------------------------------------------------------+
//| Momentum baissier                                                 |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsMomentumBearish(int lookback)
{
   SMomentum mom = GetMomentum(lookback);
   return (mom.dominantDirection == DIR_BEARISH && mom.consecutiveBearish >= 2);
}

//+------------------------------------------------------------------+
//| Momentum en accélération                                          |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsMomentumAccelerating(int lookback)
{
   SMomentum mom = GetMomentum(lookback);
   return mom.isAccelerating;
}

//+------------------------------------------------------------------+
//| Confirmation haussière                                            |
//+------------------------------------------------------------------+
bool CCandleAnalysis::HasBullishConfirmation(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);

   // Bougie forte haussière
   if(candle.type == CANDLE_BULLISH_STRONG && candle.score >= 50)
      return true;

   // Rejet haussier validé
   if(candle.type == CANDLE_BULLISH_REJECTION && candle.score >= 50)
      return true;

   // Englobante haussière
   if(candle.type == CANDLE_ENGULFING_BULL)
      return true;

   // Morning Star
   if(IsMorningStar(shift))
      return true;

   // Tweezer Bottom
   if(IsTweezerBottom(shift))
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Confirmation baissière                                            |
//+------------------------------------------------------------------+
bool CCandleAnalysis::HasBearishConfirmation(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);

   // Bougie forte baissière
   if(candle.type == CANDLE_BEARISH_STRONG && candle.score >= 50)
      return true;

   // Rejet baissier validé
   if(candle.type == CANDLE_BEARISH_REJECTION && candle.score >= 50)
      return true;

   // Englobante baissière
   if(candle.type == CANDLE_ENGULFING_BEAR)
      return true;

   // Evening Star
   if(IsEveningStar(shift))
      return true;

   // Tweezer Top
   if(IsTweezerTop(shift))
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le statut de confirmation                                 |
//+------------------------------------------------------------------+
ENUM_CANDLE_STATUS CCandleAnalysis::GetConfirmationStatus(int shift, bool expectBullish)
{
   SCandleData candle = AnalyzeCandle(shift);

   if(expectBullish)
   {
      if(HasBullishConfirmation(shift))
         return STATUS_CONFIRMATION;

      // Vérifier invalidation (bougie baissière forte)
      if(candle.type == CANDLE_BEARISH_STRONG && candle.score >= 60)
         return STATUS_INVALIDATION;
   }
   else
   {
      if(HasBearishConfirmation(shift))
         return STATUS_CONFIRMATION;

      // Vérifier invalidation (bougie haussière forte)
      if(candle.type == CANDLE_BULLISH_STRONG && candle.score >= 60)
         return STATUS_INVALIDATION;
   }

   return STATUS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| FILTRE: Taille suffisante                                         |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsValidSize(int shift)
{
   SCandleAnatomy anatomy = GetCandleAnatomy(shift);
   return (anatomy.relativeSize >= m_minSizeMultiplier);
}

//+------------------------------------------------------------------+
//| FILTRE: Pas en plein range (simplification)                       |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsNotInRange(int shift)
{
   // Vérifier si les dernières bougies ont un range serré
   double sumRange = 0;
   for(int i = shift; i < shift + 10; i++)
   {
      sumRange += iHigh(m_symbol, m_timeframe, i) - iLow(m_symbol, m_timeframe, i);
   }
   double avgRange = sumRange / 10;

   SCandleAnatomy current = GetCandleAnatomy(shift);

   // Si la bougie actuelle est significativement plus grande que la moyenne = pas en range
   return (current.totalSize > avgRange * 1.2);
}

//+------------------------------------------------------------------+
//| FILTRE: Contexte de zone clé                                      |
//+------------------------------------------------------------------+
bool CCandleAnalysis::HasZoneContext(int shift, double zonePrice, double tolerance)
{
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);

   // La bougie touche la zone
   return (low <= zonePrice + tolerance && high >= zonePrice - tolerance);
}

//+------------------------------------------------------------------+
//| Passer tous les filtres                                           |
//+------------------------------------------------------------------+
bool CCandleAnalysis::PassesAllFilters(int shift, SCandleData &candle)
{
   candle.filterMessage = "";

   // Filtre 1: Taille suffisante
   if(!IsValidSize(shift))
   {
      candle.filterMessage = "Bougie trop petite";
      return false;
   }

   // Les autres filtres nécessitent un contexte externe
   // (zone clé, trend, etc.) - à valider par le module appelant

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir l'alerte actuelle                                         |
//+------------------------------------------------------------------+
SCandleAlert CCandleAnalysis::GetCurrentAlert(int shift)
{
   SCandleAlert alert;
   alert.level = CANDLE_ALERT_NONE;
   alert.candleType = CANDLE_NEUTRAL;
   alert.direction = DIR_NONE;
   alert.message = "";
   alert.score = 0;
   alert.time = iTime(m_symbol, m_timeframe, shift);
   alert.timeframe = m_timeframe;

   SCandleData candle = AnalyzeCandle(shift);

   // Pas d'alerte pour les bougies neutres
   if(candle.type == CANDLE_NEUTRAL || candle.type == CANDLE_DOJI)
      return alert;

   // Filtrer les signaux invalides
   if(!candle.isValidSignal)
      return alert;

   alert.candleType = candle.type;
   alert.direction = candle.direction;
   alert.score = candle.score;

   // Déterminer le niveau d'alerte
   if(candle.score >= 70 && candle.status == STATUS_CONFIRMATION)
   {
      alert.level = CANDLE_ALERT_SETUP;
      alert.message = GenerateAlertMessage(candle);
   }
   else if(candle.score >= 50)
   {
      alert.level = CANDLE_ALERT_INFO;
      alert.message = GenerateAlertMessage(candle);
   }
   else if(candle.status == STATUS_INVALIDATION)
   {
      alert.level = CANDLE_ALERT_INVALIDATION;
      alert.message = "⚠️ INVALIDATION: " + TypeToString(candle.type) + " détectée";
   }

   return alert;
}

//+------------------------------------------------------------------+
//| Générer le message d'alerte                                       |
//+------------------------------------------------------------------+
string CCandleAnalysis::GenerateAlertMessage(const SCandleData &candle)
{
   string msg = "";

   switch(candle.type)
   {
      case CANDLE_BULLISH_STRONG:
         msg = "💪 Bougie HAUSSIÈRE FORTE - Score: " + IntegerToString(candle.score);
         break;

      case CANDLE_BEARISH_STRONG:
         msg = "💪 Bougie BAISSIÈRE FORTE - Score: " + IntegerToString(candle.score);
         break;

      case CANDLE_BULLISH_REJECTION:
         msg = "⬆️ REJET HAUSSIER (liquidité vendeurs) - Score: " + IntegerToString(candle.score);
         break;

      case CANDLE_BEARISH_REJECTION:
         msg = "⬇️ REJET BAISSIER (liquidité acheteurs) - Score: " + IntegerToString(candle.score);
         break;

      case CANDLE_ENGULFING_BULL:
         msg = "🔄 ENGLOBANTE HAUSSIÈRE - Score: " + IntegerToString(candle.score);
         break;

      case CANDLE_ENGULFING_BEAR:
         msg = "🔄 ENGLOBANTE BAISSIÈRE - Score: " + IntegerToString(candle.score);
         break;

      default:
         msg = TypeToString(candle.type) + " - Score: " + IntegerToString(candle.score);
         break;
   }

   return msg;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement MTF                                         |
//+------------------------------------------------------------------+
bool CCandleAnalysis::CheckMTFAlignment(ENUM_CANDLE_DIRECTION h4Dir,
                                         ENUM_CANDLE_DIRECTION h1Dir,
                                         ENUM_CANDLE_DIRECTION m15Dir)
{
   // Toutes dans la même direction
   if(h4Dir == h1Dir && h1Dir == m15Dir && h4Dir != DIR_NONE)
      return true;

   // H4 + H1 alignés, M15 neutre acceptable
   if(h4Dir == h1Dir && h4Dir != DIR_NONE && m15Dir == DIR_NONE)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Type vers String                                                  |
//+------------------------------------------------------------------+
string CCandleAnalysis::TypeToString(ENUM_CANDLE_TYPE type)
{
   switch(type)
   {
      case CANDLE_NEUTRAL:           return "Neutre";
      case CANDLE_BULLISH_STRONG:    return "Haussière Forte";
      case CANDLE_BEARISH_STRONG:    return "Baissière Forte";
      case CANDLE_BULLISH_REJECTION: return "Rejet Haussier";
      case CANDLE_BEARISH_REJECTION: return "Rejet Baissier";
      case CANDLE_DOJI:              return "Doji";
      case CANDLE_ENGULFING_BULL:    return "Englobante Haussière";
      case CANDLE_ENGULFING_BEAR:    return "Englobante Baissière";
      case CANDLE_INSIDE_BAR:        return "Inside Bar";
      case CANDLE_OUTSIDE_BAR:       return "Outside Bar";
      default:                       return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Statut vers String                                                |
//+------------------------------------------------------------------+
string CCandleAnalysis::StatusToString(ENUM_CANDLE_STATUS status)
{
   switch(status)
   {
      case STATUS_NONE:          return "Aucun";
      case STATUS_CONFIRMATION:  return "Confirmation ✅";
      case STATUS_REJECTION:     return "Rejet ⚠️";
      case STATUS_NEUTRAL:       return "Neutre";
      case STATUS_INVALIDATION:  return "Invalidation ❌";
      default:                   return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Direction vers String                                             |
//+------------------------------------------------------------------+
string CCandleAnalysis::DirectionToString(ENUM_CANDLE_DIRECTION dir)
{
   switch(dir)
   {
      case DIR_NONE:     return "Neutre";
      case DIR_BULLISH:  return "Haussier";
      case DIR_BEARISH:  return "Baissier";
      default:           return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Description courte d'une bougie                                   |
//+------------------------------------------------------------------+
string CCandleAnalysis::GetCandleDescription(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);
   return TypeToString(candle.type) + " [" + IntegerToString(candle.score) + "]";
}

//+------------------------------------------------------------------+
//| Analyse détaillée d'une bougie                                    |
//+------------------------------------------------------------------+
string CCandleAnalysis::GetDetailedAnalysis(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);
   SCandleAnatomy a = candle.anatomy;

   string desc = "";
   desc += "🕯️ ANALYSE BOUGIE DÉTAILLÉE\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += "Type: " + TypeToString(candle.type) + "\n";
   desc += "Direction: " + DirectionToString(candle.direction) + "\n";
   desc += "Statut: " + StatusToString(candle.status) + "\n";
   desc += "Score: " + IntegerToString(candle.score) + "/100\n";
   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

   desc += StringFormat("Open:  %.5f\n", a.open);
   desc += StringFormat("High:  %.5f\n", a.high);
   desc += StringFormat("Low:   %.5f\n", a.low);
   desc += StringFormat("Close: %.5f\n", a.close);

   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += StringFormat("Corps: %.1f%%\n", a.bodyRatio);
   desc += StringFormat("Mèche haute: %.1f%%\n", a.upperWickRatio);
   desc += StringFormat("Mèche basse: %.1f%%\n", a.lowerWickRatio);
   desc += StringFormat("Position close: %.1f%%\n", a.closePosition);

   desc += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
   desc += StringFormat("Taille relative: %.2fx moyenne\n", a.relativeSize);
   desc += "Signal valide: " + (candle.isValidSignal ? "OUI ✅" : "NON ❌") + "\n";

   if(candle.isPartOfPattern)
      desc += "Pattern: " + candle.patternName + "\n";

   if(candle.filterMessage != "")
      desc += "Filtre: " + candle.filterMessage + "\n";

   return desc;
}

//+------------------------------------------------------------------+
