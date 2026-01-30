//+------------------------------------------------------------------+
//|                                              CandleAnalysis.mqh |
//|                         CHAPITRE 1 - ANATOMIE DES BOUGIES       |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des types de bougies                                 |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_TYPE
{
   CANDLE_NEUTRAL = 0,      // Bougie neutre
   CANDLE_BULLISH_STRONG,   // Bougie haussière forte
   CANDLE_BEARISH_STRONG,   // Bougie baissière forte
   CANDLE_BULLISH_REJECTION,// Rejet haussier (hammer)
   CANDLE_BEARISH_REJECTION,// Rejet baissier (shooting star)
   CANDLE_DOJI,             // Doji
   CANDLE_ENGULFING_BULL,   // Englobante haussière
   CANDLE_ENGULFING_BEAR    // Englobante baissière
};

//+------------------------------------------------------------------+
//| Structure d'analyse d'une bougie                                 |
//+------------------------------------------------------------------+
struct SCandleData
{
   double   open;
   double   high;
   double   low;
   double   close;
   double   totalSize;      // High - Low
   double   bodySize;       // |Close - Open|
   double   upperWick;      // Mèche haute
   double   lowerWick;      // Mèche basse
   double   bodyPercent;    // Corps en % de la taille totale
   double   upperWickPercent;
   double   lowerWickPercent;
   bool     isBullish;
   ENUM_CANDLE_TYPE type;
};

//+------------------------------------------------------------------+
//| Classe d'analyse des bougies                                     |
//+------------------------------------------------------------------+
class CCandleAnalysis
{
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   // Seuils configurables (selon Chapitre 1)
   double   m_strongBodyThreshold;    // 70% pour bougie forte
   double   m_rejectionThreshold;     // 50% pour rejet
   double   m_dojiThreshold;          // 10% pour doji

public:
   CCandleAnalysis();
   ~CCandleAnalysis();

   // Initialisation
   void     Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void     SetThresholds(double strongBody = 70.0, double rejection = 50.0, double doji = 10.0);

   // Analyse d'une bougie
   SCandleData AnalyzeCandle(int shift);
   SCandleData AnalyzeCandleByData(double open, double high, double low, double close);

   // Détection des types de bougies
   ENUM_CANDLE_TYPE GetCandleType(const SCandleData &candle);

   // Vérifications spécifiques (RÈGLES Chapitre 1)
   bool     IsStrongCandle(const SCandleData &candle);        // Corps ≥ 70%
   bool     IsBullishRejection(const SCandleData &candle);    // Mèche basse ≥ 50%
   bool     IsBearishRejection(const SCandleData &candle);    // Mèche haute ≥ 50%
   bool     IsDoji(const SCandleData &candle);

   // Patterns de confirmation
   bool     IsEngulfingBullish(int shift);
   bool     IsEngulfingBearish(int shift);
   bool     IsMorningStar(int shift);
   bool     IsEveningStar(int shift);
   bool     IsPinBar(int shift, bool &isBullish);

   // Confirmation finale du signal
   bool     HasBullishConfirmation(int shift);
   bool     HasBearishConfirmation(int shift);

   // Utilitaires
   string   CandleTypeToString(ENUM_CANDLE_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CCandleAnalysis::CCandleAnalysis()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_strongBodyThreshold = 70.0;    // RÈGLE: Corps ≥ 70%
   m_rejectionThreshold = 50.0;     // RÈGLE: Mèche ≥ 50%
   m_dojiThreshold = 10.0;
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
}

//+------------------------------------------------------------------+
//| Configuration des seuils                                          |
//+------------------------------------------------------------------+
void CCandleAnalysis::SetThresholds(double strongBody = 70.0, double rejection = 50.0, double doji = 10.0)
{
   m_strongBodyThreshold = strongBody;
   m_rejectionThreshold = rejection;
   m_dojiThreshold = doji;
}

//+------------------------------------------------------------------+
//| Analyse d'une bougie par shift                                    |
//+------------------------------------------------------------------+
SCandleData CCandleAnalysis::AnalyzeCandle(int shift)
{
   double open = iOpen(m_symbol, m_timeframe, shift);
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);

   return AnalyzeCandleByData(open, high, low, close);
}

//+------------------------------------------------------------------+
//| Analyse d'une bougie par données OHLC                             |
//| RÈGLES CHAPITRE 1:                                                |
//| - Taille totale = High - Low                                      |
//| - Corps = |Close - Open|                                          |
//| - Mèche haute = High - max(Open, Close)                           |
//| - Mèche basse = min(Open, Close) - Low                            |
//+------------------------------------------------------------------+
SCandleData CCandleAnalysis::AnalyzeCandleByData(double open, double high, double low, double close)
{
   SCandleData candle;

   candle.open = open;
   candle.high = high;
   candle.low = low;
   candle.close = close;

   // Calculs selon Chapitre 1
   candle.totalSize = high - low;
   candle.bodySize = MathAbs(close - open);
   candle.upperWick = high - MathMax(open, close);
   candle.lowerWick = MathMin(open, close) - low;

   // Calcul des pourcentages
   if(candle.totalSize > 0)
   {
      candle.bodyPercent = (candle.bodySize / candle.totalSize) * 100.0;
      candle.upperWickPercent = (candle.upperWick / candle.totalSize) * 100.0;
      candle.lowerWickPercent = (candle.lowerWick / candle.totalSize) * 100.0;
   }
   else
   {
      candle.bodyPercent = 0;
      candle.upperWickPercent = 0;
      candle.lowerWickPercent = 0;
   }

   // Direction
   candle.isBullish = (close > open);

   // Type de bougie
   candle.type = GetCandleType(candle);

   return candle;
}

//+------------------------------------------------------------------+
//| Déterminer le type de bougie                                      |
//+------------------------------------------------------------------+
ENUM_CANDLE_TYPE CCandleAnalysis::GetCandleType(const SCandleData &candle)
{
   // RÈGLE: Bougie forte si Corps ≥ 70%
   if(IsStrongCandle(candle))
   {
      return candle.isBullish ? CANDLE_BULLISH_STRONG : CANDLE_BEARISH_STRONG;
   }

   // RÈGLE: Rejet haussier si mèche basse ≥ 50%
   if(IsBullishRejection(candle))
   {
      return CANDLE_BULLISH_REJECTION;
   }

   // RÈGLE: Rejet baissier si mèche haute ≥ 50%
   if(IsBearishRejection(candle))
   {
      return CANDLE_BEARISH_REJECTION;
   }

   // Doji
   if(IsDoji(candle))
   {
      return CANDLE_DOJI;
   }

   return CANDLE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| RÈGLE: Bougie forte = Corps ≥ 70% de la taille totale            |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsStrongCandle(const SCandleData &candle)
{
   return (candle.bodyPercent >= m_strongBodyThreshold);
}

//+------------------------------------------------------------------+
//| RÈGLE: Rejet haussier = Mèche basse ≥ 50% de la taille totale    |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsBullishRejection(const SCandleData &candle)
{
   return (candle.lowerWickPercent >= m_rejectionThreshold);
}

//+------------------------------------------------------------------+
//| RÈGLE: Rejet baissier = Mèche haute ≥ 50% de la taille totale    |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsBearishRejection(const SCandleData &candle)
{
   return (candle.upperWickPercent >= m_rejectionThreshold);
}

//+------------------------------------------------------------------+
//| Doji = Corps très petit                                           |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsDoji(const SCandleData &candle)
{
   return (candle.bodyPercent <= m_dojiThreshold);
}

//+------------------------------------------------------------------+
//| Englobante haussière                                              |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEngulfingBullish(int shift)
{
   SCandleData current = AnalyzeCandle(shift);
   SCandleData previous = AnalyzeCandle(shift + 1);

   // La bougie actuelle doit être haussière
   if(!current.isBullish) return false;

   // La bougie précédente doit être baissière
   if(previous.isBullish) return false;

   // Le corps actuel englobe le corps précédent
   if(current.open <= previous.close && current.close >= previous.open)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Englobante baissière                                              |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEngulfingBearish(int shift)
{
   SCandleData current = AnalyzeCandle(shift);
   SCandleData previous = AnalyzeCandle(shift + 1);

   // La bougie actuelle doit être baissière
   if(current.isBullish) return false;

   // La bougie précédente doit être haussière
   if(!previous.isBullish) return false;

   // Le corps actuel englobe le corps précédent
   if(current.open >= previous.close && current.close <= previous.open)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Morning Star (3 bougies)                                          |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsMorningStar(int shift)
{
   SCandleData candle1 = AnalyzeCandle(shift + 2);  // Première bougie
   SCandleData candle2 = AnalyzeCandle(shift + 1);  // Bougie du milieu
   SCandleData candle3 = AnalyzeCandle(shift);      // Dernière bougie

   // Première bougie: baissière forte
   if(candle1.isBullish || !IsStrongCandle(candle1)) return false;

   // Deuxième bougie: petit corps (doji ou petite bougie)
   if(candle2.bodyPercent > 30.0) return false;

   // Troisième bougie: haussière forte
   if(!candle3.isBullish || !IsStrongCandle(candle3)) return false;

   // La troisième bougie doit clôturer au-dessus du milieu de la première
   double midPoint = (candle1.open + candle1.close) / 2.0;
   if(candle3.close < midPoint) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Evening Star (3 bougies)                                          |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsEveningStar(int shift)
{
   SCandleData candle1 = AnalyzeCandle(shift + 2);
   SCandleData candle2 = AnalyzeCandle(shift + 1);
   SCandleData candle3 = AnalyzeCandle(shift);

   // Première bougie: haussière forte
   if(!candle1.isBullish || !IsStrongCandle(candle1)) return false;

   // Deuxième bougie: petit corps
   if(candle2.bodyPercent > 30.0) return false;

   // Troisième bougie: baissière forte
   if(candle3.isBullish || !IsStrongCandle(candle3)) return false;

   // La troisième bougie doit clôturer en-dessous du milieu de la première
   double midPoint = (candle1.open + candle1.close) / 2.0;
   if(candle3.close > midPoint) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Pin Bar (Hammer / Shooting Star)                                  |
//+------------------------------------------------------------------+
bool CCandleAnalysis::IsPinBar(int shift, bool &isBullish)
{
   SCandleData candle = AnalyzeCandle(shift);

   // Pin Bar haussier (Hammer)
   if(IsBullishRejection(candle) && candle.upperWickPercent < 20.0)
   {
      isBullish = true;
      return true;
   }

   // Pin Bar baissier (Shooting Star)
   if(IsBearishRejection(candle) && candle.lowerWickPercent < 20.0)
   {
      isBullish = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Confirmation haussière (pour validation finale du signal)        |
//| Utilisé comme confirmation finale selon Chapitre 1                |
//+------------------------------------------------------------------+
bool CCandleAnalysis::HasBullishConfirmation(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);

   // Bougie forte haussière
   if(candle.type == CANDLE_BULLISH_STRONG)
      return true;

   // Rejet haussier
   if(candle.type == CANDLE_BULLISH_REJECTION)
      return true;

   // Englobante haussière
   if(IsEngulfingBullish(shift))
      return true;

   // Morning Star
   if(IsMorningStar(shift))
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Confirmation baissière (pour validation finale du signal)        |
//| Utilisé comme confirmation finale selon Chapitre 1                |
//+------------------------------------------------------------------+
bool CCandleAnalysis::HasBearishConfirmation(int shift)
{
   SCandleData candle = AnalyzeCandle(shift);

   // Bougie forte baissière
   if(candle.type == CANDLE_BEARISH_STRONG)
      return true;

   // Rejet baissier
   if(candle.type == CANDLE_BEARISH_REJECTION)
      return true;

   // Englobante baissière
   if(IsEngulfingBearish(shift))
      return true;

   // Evening Star
   if(IsEveningStar(shift))
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Convertir le type de bougie en string                             |
//+------------------------------------------------------------------+
string CCandleAnalysis::CandleTypeToString(ENUM_CANDLE_TYPE type)
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
      default:                       return "Inconnu";
   }
}
//+------------------------------------------------------------------+
