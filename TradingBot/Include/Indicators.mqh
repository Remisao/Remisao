//+------------------------------------------------------------------+
//|                                                Indicators.mqh   |
//|                            CHAPITRE 8 - RSI & MACD              |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des états RSI                                        |
//+------------------------------------------------------------------+
enum ENUM_RSI_STATE
{
   RSI_NEUTRAL = 0,
   RSI_OVERBOUGHT,      // > 70 - Surachat
   RSI_OVERSOLD,        // < 30 - Survente
   RSI_BULLISH_ZONE,    // 50-70
   RSI_BEARISH_ZONE     // 30-50
};

//+------------------------------------------------------------------+
//| Énumération des états MACD                                       |
//+------------------------------------------------------------------+
enum ENUM_MACD_STATE
{
   MACD_NEUTRAL = 0,
   MACD_BULLISH,        // MACD > Signal et > 0
   MACD_BEARISH,        // MACD < Signal et < 0
   MACD_BULLISH_CROSS,  // Croisement haussier
   MACD_BEARISH_CROSS,  // Croisement baissier
   MACD_EXHAUSTION      // Essoufflement détecté
};

//+------------------------------------------------------------------+
//| Structure des données RSI                                        |
//+------------------------------------------------------------------+
struct SRSIData
{
   double         value;
   ENUM_RSI_STATE state;
   bool           isDivergence;
   bool           isBullishDiv;
};

//+------------------------------------------------------------------+
//| Structure des données MACD                                       |
//+------------------------------------------------------------------+
struct SMACDData
{
   double            macdLine;
   double            signalLine;
   double            histogram;
   double            histogramPrev;
   ENUM_MACD_STATE   state;
   bool              isExhaustion;
};

//+------------------------------------------------------------------+
//| Classe d'analyse RSI & MACD                                       |
//+------------------------------------------------------------------+
class CIndicators
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Handles
   int               m_rsiHandle;
   int               m_macdHandle;

   // Buffers
   double            m_rsiBuffer[];
   double            m_macdBuffer[];
   double            m_signalBuffer[];
   double            m_histBuffer[];

   // Paramètres RSI
   int               m_rsiPeriod;
   double            m_rsiOverbought;  // RÈGLE: > 70
   double            m_rsiOversold;    // RÈGLE: < 30

   // Paramètres MACD
   int               m_macdFast;
   int               m_macdSlow;
   int               m_macdSignal;

   // Méthodes privées
   bool              LoadRSIBuffer(int count);
   bool              LoadMACDBuffers(int count);
   void              ReleaseHandles();

public:
   CIndicators();
   ~CIndicators();

   // Initialisation
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetRSIParameters(int period = 14, double overbought = 70.0, double oversold = 30.0);
   void              SetMACDParameters(int fast = 12, int slow = 26, int signal = 9);

   // ============ RSI ============
   // RÈGLE: Surachat > 70, Survente < 30
   double            GetRSI(int shift = 0);
   ENUM_RSI_STATE    GetRSIState(int shift = 0);
   bool              IsOverbought(int shift = 0);
   bool              IsOversold(int shift = 0);
   SRSIData          AnalyzeRSI(int shift = 0);

   // ============ MACD ============
   double            GetMACDLine(int shift = 0);
   double            GetSignalLine(int shift = 0);
   double            GetHistogram(int shift = 0);
   ENUM_MACD_STATE   GetMACDState(int shift = 0);
   SMACDData         AnalyzeMACD(int shift = 0);

   // RÈGLE: Diminution histogramme + prix monte → Essoufflement
   bool              IsExhaustionDetected(int shift = 0);

   // Croisements MACD
   bool              IsMACDBullishCross(int shift = 1);
   bool              IsMACDBearishCross(int shift = 1);
   bool              IsHistogramIncreasing(int shift = 0);
   bool              IsHistogramDecreasing(int shift = 0);

   // Analyse combinée
   bool              IsBullishMomentum(int shift = 0);
   bool              IsBearishMomentum(int shift = 0);

   // Utilitaires
   string            RSIStateToString(ENUM_RSI_STATE state);
   string            MACDStateToString(ENUM_MACD_STATE state);
   string            GetRSIAlert(int shift = 0);
   string            GetMACDAlert(int shift = 0);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CIndicators::CIndicators()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_rsiHandle = INVALID_HANDLE;
   m_macdHandle = INVALID_HANDLE;

   // Paramètres par défaut
   m_rsiPeriod = 14;
   m_rsiOverbought = 70.0;  // RÈGLE: > 70
   m_rsiOversold = 30.0;    // RÈGLE: < 30

   m_macdFast = 12;
   m_macdSlow = 26;
   m_macdSignal = 9;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CIndicators::~CIndicators()
{
   ReleaseHandles();
}

//+------------------------------------------------------------------+
//| Libérer les handles                                               |
//+------------------------------------------------------------------+
void CIndicators::ReleaseHandles()
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
bool CIndicators::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   ReleaseHandles();

   // Créer handle RSI
   m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE)
   {
      Print("Erreur création handle RSI");
      return false;
   }

   // Créer handle MACD
   m_macdHandle = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
   if(m_macdHandle == INVALID_HANDLE)
   {
      Print("Erreur création handle MACD");
      return false;
   }

   // Initialiser les buffers
   ArraySetAsSeries(m_rsiBuffer, true);
   ArraySetAsSeries(m_macdBuffer, true);
   ArraySetAsSeries(m_signalBuffer, true);
   ArraySetAsSeries(m_histBuffer, true);

   return true;
}

//+------------------------------------------------------------------+
//| Configurer les paramètres RSI                                     |
//+------------------------------------------------------------------+
void CIndicators::SetRSIParameters(int period = 14, double overbought = 70.0, double oversold = 30.0)
{
   m_rsiPeriod = period;
   m_rsiOverbought = overbought;
   m_rsiOversold = oversold;
}

//+------------------------------------------------------------------+
//| Configurer les paramètres MACD                                    |
//+------------------------------------------------------------------+
void CIndicators::SetMACDParameters(int fast = 12, int slow = 26, int signal = 9)
{
   m_macdFast = fast;
   m_macdSlow = slow;
   m_macdSignal = signal;
}

//+------------------------------------------------------------------+
//| Charger le buffer RSI                                             |
//+------------------------------------------------------------------+
bool CIndicators::LoadRSIBuffer(int count)
{
   if(m_rsiHandle == INVALID_HANDLE) return false;
   return (CopyBuffer(m_rsiHandle, 0, 0, count, m_rsiBuffer) >= count);
}

//+------------------------------------------------------------------+
//| Charger les buffers MACD                                          |
//+------------------------------------------------------------------+
bool CIndicators::LoadMACDBuffers(int count)
{
   if(m_macdHandle == INVALID_HANDLE) return false;

   if(CopyBuffer(m_macdHandle, 0, 0, count, m_macdBuffer) < count) return false;
   if(CopyBuffer(m_macdHandle, 1, 0, count, m_signalBuffer) < count) return false;

   // Calculer l'histogramme manuellement
   ArrayResize(m_histBuffer, count);
   for(int i = 0; i < count; i++)
   {
      m_histBuffer[i] = m_macdBuffer[i] - m_signalBuffer[i];
   }

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur RSI                                             |
//+------------------------------------------------------------------+
double CIndicators::GetRSI(int shift)
{
   if(!LoadRSIBuffer(shift + 1)) return 50.0; // Valeur neutre par défaut
   return m_rsiBuffer[shift];
}

//+------------------------------------------------------------------+
//| RÈGLE: État du RSI                                                |
//| Surachat > 70, Survente < 30                                      |
//+------------------------------------------------------------------+
ENUM_RSI_STATE CIndicators::GetRSIState(int shift)
{
   double rsi = GetRSI(shift);

   if(rsi > m_rsiOverbought)
      return RSI_OVERBOUGHT;

   if(rsi < m_rsiOversold)
      return RSI_OVERSOLD;

   if(rsi >= 50.0)
      return RSI_BULLISH_ZONE;

   return RSI_BEARISH_ZONE;
}

//+------------------------------------------------------------------+
//| RÈGLE: RSI > 70 = Surachat                                        |
//+------------------------------------------------------------------+
bool CIndicators::IsOverbought(int shift)
{
   return (GetRSI(shift) > m_rsiOverbought);
}

//+------------------------------------------------------------------+
//| RÈGLE: RSI < 30 = Survente                                        |
//+------------------------------------------------------------------+
bool CIndicators::IsOversold(int shift)
{
   return (GetRSI(shift) < m_rsiOversold);
}

//+------------------------------------------------------------------+
//| Analyse complète du RSI                                           |
//+------------------------------------------------------------------+
SRSIData CIndicators::AnalyzeRSI(int shift)
{
   SRSIData data;

   data.value = GetRSI(shift);
   data.state = GetRSIState(shift);
   data.isDivergence = false;  // Sera calculé par le module Divergences
   data.isBullishDiv = false;

   return data;
}

//+------------------------------------------------------------------+
//| Obtenir la ligne MACD                                             |
//+------------------------------------------------------------------+
double CIndicators::GetMACDLine(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_macdBuffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir la ligne Signal                                           |
//+------------------------------------------------------------------+
double CIndicators::GetSignalLine(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_signalBuffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir l'histogramme                                             |
//+------------------------------------------------------------------+
double CIndicators::GetHistogram(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_histBuffer[shift];
}

//+------------------------------------------------------------------+
//| État du MACD                                                      |
//+------------------------------------------------------------------+
ENUM_MACD_STATE CIndicators::GetMACDState(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return MACD_NEUTRAL;

   double macd = m_macdBuffer[shift];
   double signal = m_signalBuffer[shift];
   double macdPrev = m_macdBuffer[shift + 1];
   double signalPrev = m_signalBuffer[shift + 1];

   // Vérifier les croisements
   if(macdPrev < signalPrev && macd > signal)
      return MACD_BULLISH_CROSS;

   if(macdPrev > signalPrev && macd < signal)
      return MACD_BEARISH_CROSS;

   // Vérifier l'essoufflement
   if(IsExhaustionDetected(shift))
      return MACD_EXHAUSTION;

   // État général
   if(macd > signal && macd > 0)
      return MACD_BULLISH;

   if(macd < signal && macd < 0)
      return MACD_BEARISH;

   return MACD_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Analyse complète du MACD                                          |
//+------------------------------------------------------------------+
SMACDData CIndicators::AnalyzeMACD(int shift)
{
   SMACDData data;

   if(!LoadMACDBuffers(shift + 2))
   {
      data.macdLine = 0;
      data.signalLine = 0;
      data.histogram = 0;
      data.histogramPrev = 0;
      data.state = MACD_NEUTRAL;
      data.isExhaustion = false;
      return data;
   }

   data.macdLine = m_macdBuffer[shift];
   data.signalLine = m_signalBuffer[shift];
   data.histogram = m_histBuffer[shift];
   data.histogramPrev = m_histBuffer[shift + 1];
   data.state = GetMACDState(shift);
   data.isExhaustion = IsExhaustionDetected(shift);

   return data;
}

//+------------------------------------------------------------------+
//| RÈGLE: Diminution histogramme + prix monte → Essoufflement       |
//+------------------------------------------------------------------+
bool CIndicators::IsExhaustionDetected(int shift)
{
   if(!LoadMACDBuffers(shift + 3)) return false;

   // Vérifier la direction du prix
   double priceCurrent = iClose(m_symbol, m_timeframe, shift);
   double pricePrev = iClose(m_symbol, m_timeframe, shift + 2);
   bool priceRising = (priceCurrent > pricePrev);
   bool priceFalling = (priceCurrent < pricePrev);

   // Vérifier la direction de l'histogramme
   double hist1 = MathAbs(m_histBuffer[shift]);
   double hist2 = MathAbs(m_histBuffer[shift + 1]);
   double hist3 = MathAbs(m_histBuffer[shift + 2]);

   bool histogramDecreasing = (hist1 < hist2 && hist2 < hist3);

   // RÈGLE: Prix monte mais histogramme diminue = essoufflement haussier
   if(priceRising && histogramDecreasing && m_histBuffer[shift] > 0)
      return true;

   // Prix baisse mais histogramme diminue (en valeur absolue) = essoufflement baissier
   if(priceFalling && histogramDecreasing && m_histBuffer[shift] < 0)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Croisement MACD haussier                                          |
//+------------------------------------------------------------------+
bool CIndicators::IsMACDBullishCross(int shift = 1)
{
   if(!LoadMACDBuffers(shift + 2)) return false;

   return (m_macdBuffer[shift + 1] < m_signalBuffer[shift + 1] &&
           m_macdBuffer[shift] > m_signalBuffer[shift]);
}

//+------------------------------------------------------------------+
//| Croisement MACD baissier                                          |
//+------------------------------------------------------------------+
bool CIndicators::IsMACDBearishCross(int shift = 1)
{
   if(!LoadMACDBuffers(shift + 2)) return false;

   return (m_macdBuffer[shift + 1] > m_signalBuffer[shift + 1] &&
           m_macdBuffer[shift] < m_signalBuffer[shift]);
}

//+------------------------------------------------------------------+
//| Histogramme croissant                                             |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramIncreasing(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return false;
   return (m_histBuffer[shift] > m_histBuffer[shift + 1]);
}

//+------------------------------------------------------------------+
//| Histogramme décroissant                                           |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramDecreasing(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return false;
   return (m_histBuffer[shift] < m_histBuffer[shift + 1]);
}

//+------------------------------------------------------------------+
//| Momentum haussier (RSI + MACD alignés)                            |
//+------------------------------------------------------------------+
bool CIndicators::IsBullishMomentum(int shift)
{
   double rsi = GetRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   // RSI au-dessus de 50 et MACD positif
   return (rsi > 50.0 && macd.macdLine > macd.signalLine && macd.histogram > 0);
}

//+------------------------------------------------------------------+
//| Momentum baissier (RSI + MACD alignés)                            |
//+------------------------------------------------------------------+
bool CIndicators::IsBearishMomentum(int shift)
{
   double rsi = GetRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   // RSI en-dessous de 50 et MACD négatif
   return (rsi < 50.0 && macd.macdLine < macd.signalLine && macd.histogram < 0);
}

//+------------------------------------------------------------------+
//| Convertir l'état RSI en string                                    |
//+------------------------------------------------------------------+
string CIndicators::RSIStateToString(ENUM_RSI_STATE state)
{
   switch(state)
   {
      case RSI_NEUTRAL:      return "Neutre";
      case RSI_OVERBOUGHT:   return "SURACHAT (>70)";
      case RSI_OVERSOLD:     return "SURVENTE (<30)";
      case RSI_BULLISH_ZONE: return "Zone haussière (50-70)";
      case RSI_BEARISH_ZONE: return "Zone baissière (30-50)";
      default:               return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir l'état MACD en string                                   |
//+------------------------------------------------------------------+
string CIndicators::MACDStateToString(ENUM_MACD_STATE state)
{
   switch(state)
   {
      case MACD_NEUTRAL:       return "Neutre";
      case MACD_BULLISH:       return "Haussier";
      case MACD_BEARISH:       return "Baissier";
      case MACD_BULLISH_CROSS: return "Croisement haussier";
      case MACD_BEARISH_CROSS: return "Croisement baissier";
      case MACD_EXHAUSTION:    return "Essoufflement";
      default:                 return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Générer une alerte RSI                                            |
//+------------------------------------------------------------------+
string CIndicators::GetRSIAlert(int shift)
{
   SRSIData data = AnalyzeRSI(shift);
   string alert = "";

   switch(data.state)
   {
      case RSI_OVERBOUGHT:
         alert = "⚠️ RSI en SURACHAT (" + DoubleToString(data.value, 1) + " > 70) - Attention au retournement";
         break;
      case RSI_OVERSOLD:
         alert = "⚠️ RSI en SURVENTE (" + DoubleToString(data.value, 1) + " < 30) - Attention au rebond";
         break;
      default:
         break;
   }

   return alert;
}

//+------------------------------------------------------------------+
//| Générer une alerte MACD                                           |
//+------------------------------------------------------------------+
string CIndicators::GetMACDAlert(int shift)
{
   SMACDData data = AnalyzeMACD(shift);
   string alert = "";

   switch(data.state)
   {
      case MACD_BULLISH_CROSS:
         alert = "📈 MACD: Croisement HAUSSIER détecté!";
         break;
      case MACD_BEARISH_CROSS:
         alert = "📉 MACD: Croisement BAISSIER détecté!";
         break;
      case MACD_EXHAUSTION:
         // RÈGLE: Diminution histogramme + prix monte → Essoufflement
         alert = "⚠️ MACD: ESSOUFFLEMENT détecté - L'histogramme diminue alors que le prix continue";
         break;
      default:
         break;
   }

   return alert;
}
//+------------------------------------------------------------------+
