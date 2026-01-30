//+------------------------------------------------------------------+
//|                                            MovingAverages.mqh   |
//|                        CHAPITRE 7 - MOYENNES MOBILES (EMA)      |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des signaux EMA                                      |
//+------------------------------------------------------------------+
enum ENUM_EMA_SIGNAL
{
   EMA_SIGNAL_NONE = 0,
   EMA_GOLDEN_CROSS,        // Golden Cross (EMA rapide croise EMA lente vers le haut)
   EMA_DEATH_CROSS,         // Death Cross (EMA rapide croise EMA lente vers le bas)
   EMA_RIBBON_BULLISH,      // EMA Ribbon aligné haussier
   EMA_RIBBON_BEARISH,      // EMA Ribbon aligné baissier
   EMA_PRICE_ABOVE_200,     // Prix au-dessus EMA 200
   EMA_PRICE_BELOW_200      // Prix en-dessous EMA 200
};

//+------------------------------------------------------------------+
//| Structure des valeurs EMA                                        |
//+------------------------------------------------------------------+
struct SEMAValues
{
   double   ema9;
   double   ema21;
   double   ema50;
   double   ema200;
};

//+------------------------------------------------------------------+
//| Structure d'analyse EMA                                          |
//+------------------------------------------------------------------+
struct SEMAAnalysis
{
   SEMAValues        current;       // Valeurs actuelles
   SEMAValues        previous;      // Valeurs précédentes
   bool              isBullishBias; // Prix au-dessus EMA 200
   bool              isRibbonAligned;
   bool              isRibbonBullish;
   ENUM_EMA_SIGNAL   signal;
};

//+------------------------------------------------------------------+
//| Classe d'analyse des moyennes mobiles                             |
//+------------------------------------------------------------------+
class CMovingAverages
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_ema9Handle;
   int               m_ema21Handle;
   int               m_ema50Handle;
   int               m_ema200Handle;

   // Buffers
   double            m_ema9Buffer[];
   double            m_ema21Buffer[];
   double            m_ema50Buffer[];
   double            m_ema200Buffer[];

   // Méthodes privées
   bool              LoadBuffers(int count);
   void              ReleaseHandles();

public:
   CMovingAverages();
   ~CMovingAverages();

   // Initialisation
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);

   // RÈGLE: Utiliser EMA 9 / 21 / 50 / 200
   double            GetEMA9(int shift = 0);
   double            GetEMA21(int shift = 0);
   double            GetEMA50(int shift = 0);
   double            GetEMA200(int shift = 0);
   SEMAValues        GetAllEMAs(int shift = 0);

   // RÈGLE: Prix au-dessus EMA 200 → Bias haussier
   bool              IsBullishBias(int shift = 0);
   bool              IsBearishBias(int shift = 0);

   // RÈGLE: Golden Cross / Death Cross → Alerte majeure
   bool              IsGoldenCross(int shift = 1);    // EMA 50 croise EMA 200 vers le haut
   bool              IsDeathCross(int shift = 1);     // EMA 50 croise EMA 200 vers le bas
   bool              IsFastGoldenCross(int shift = 1); // EMA 9 croise EMA 21 vers le haut
   bool              IsFastDeathCross(int shift = 1);  // EMA 9 croise EMA 21 vers le bas

   // RÈGLE: EMA Ribbon aligné → "Tendance forte"
   bool              IsRibbonAligned(int shift, bool &isBullish);

   // Analyse des croisements
   bool              IsPriceCrossingEMA(int shift, double emaValue, bool &crossUp);
   bool              IsEMACrossing(int shift, double fastEMA1, double fastEMA2,
                                   double slowEMA1, double slowEMA2, bool &crossUp);

   // Analyse complète
   SEMAAnalysis      Analyze(int shift = 0);

   // Support/Résistance dynamique
   double            GetDynamicSupport(int shift = 0);
   double            GetDynamicResistance(int shift = 0);

   // Pente des EMAs
   double            GetEMASlope(int period, int lookback = 5);
   bool              IsEMATrendingUp(int period, int lookback = 5);
   bool              IsEMATrendingDown(int period, int lookback = 5);

   // Utilitaires
   string            GetBiasString(int shift = 0);
   string            GetEMAAlert(int shift = 0);
   ENUM_EMA_SIGNAL   GetCurrentSignal(int shift = 0);
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

   // Créer les handles EMA
   m_ema9Handle = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   m_ema21Handle = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_ema50Handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_ema200Handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(m_ema9Handle == INVALID_HANDLE ||
      m_ema21Handle == INVALID_HANDLE ||
      m_ema50Handle == INVALID_HANDLE ||
      m_ema200Handle == INVALID_HANDLE)
   {
      Print("Erreur création handles EMA");
      return false;
   }

   // Initialiser les buffers
   ArraySetAsSeries(m_ema9Buffer, true);
   ArraySetAsSeries(m_ema21Buffer, true);
   ArraySetAsSeries(m_ema50Buffer, true);
   ArraySetAsSeries(m_ema200Buffer, true);

   return true;
}

//+------------------------------------------------------------------+
//| Charger les buffers                                               |
//+------------------------------------------------------------------+
bool CMovingAverages::LoadBuffers(int count)
{
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
   LoadBuffers(shift + 1);

   values.ema9 = m_ema9Buffer[shift];
   values.ema21 = m_ema21Buffer[shift];
   values.ema50 = m_ema50Buffer[shift];
   values.ema200 = m_ema200Buffer[shift];

   return values;
}

//+------------------------------------------------------------------+
//| RÈGLE: Prix au-dessus EMA 200 → Bias haussier                    |
//+------------------------------------------------------------------+
bool CMovingAverages::IsBullishBias(int shift)
{
   double price = iClose(m_symbol, m_timeframe, shift);
   double ema200 = GetEMA200(shift);

   return (price > ema200);
}

//+------------------------------------------------------------------+
//| Prix en-dessous EMA 200 → Bias baissier                          |
//+------------------------------------------------------------------+
bool CMovingAverages::IsBearishBias(int shift)
{
   double price = iClose(m_symbol, m_timeframe, shift);
   double ema200 = GetEMA200(shift);

   return (price < ema200);
}

//+------------------------------------------------------------------+
//| RÈGLE: Golden Cross (EMA 50 croise EMA 200 vers le haut)         |
//| → Alerte majeure                                                  |
//+------------------------------------------------------------------+
bool CMovingAverages::IsGoldenCross(int shift = 1)
{
   if(!LoadBuffers(shift + 2)) return false;

   // EMA 50 était en-dessous de EMA 200 et passe au-dessus
   bool wasBelowPrev = (m_ema50Buffer[shift + 1] < m_ema200Buffer[shift + 1]);
   bool isAboveNow = (m_ema50Buffer[shift] > m_ema200Buffer[shift]);

   return (wasBelowPrev && isAboveNow);
}

//+------------------------------------------------------------------+
//| RÈGLE: Death Cross (EMA 50 croise EMA 200 vers le bas)           |
//| → Alerte majeure                                                  |
//+------------------------------------------------------------------+
bool CMovingAverages::IsDeathCross(int shift = 1)
{
   if(!LoadBuffers(shift + 2)) return false;

   // EMA 50 était au-dessus de EMA 200 et passe en-dessous
   bool wasAbovePrev = (m_ema50Buffer[shift + 1] > m_ema200Buffer[shift + 1]);
   bool isBelowNow = (m_ema50Buffer[shift] < m_ema200Buffer[shift]);

   return (wasAbovePrev && isBelowNow);
}

//+------------------------------------------------------------------+
//| Golden Cross rapide (EMA 9 croise EMA 21)                        |
//+------------------------------------------------------------------+
bool CMovingAverages::IsFastGoldenCross(int shift = 1)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasBelowPrev = (m_ema9Buffer[shift + 1] < m_ema21Buffer[shift + 1]);
   bool isAboveNow = (m_ema9Buffer[shift] > m_ema21Buffer[shift]);

   return (wasBelowPrev && isAboveNow);
}

//+------------------------------------------------------------------+
//| Death Cross rapide (EMA 9 croise EMA 21)                         |
//+------------------------------------------------------------------+
bool CMovingAverages::IsFastDeathCross(int shift = 1)
{
   if(!LoadBuffers(shift + 2)) return false;

   bool wasAbovePrev = (m_ema9Buffer[shift + 1] > m_ema21Buffer[shift + 1]);
   bool isBelowNow = (m_ema9Buffer[shift] < m_ema21Buffer[shift]);

   return (wasAbovePrev && isBelowNow);
}

//+------------------------------------------------------------------+
//| RÈGLE: EMA Ribbon aligné → "Tendance forte"                      |
//| Ordre haussier: Prix > EMA9 > EMA21 > EMA50 > EMA200             |
//| Ordre baissier: Prix < EMA9 < EMA21 < EMA50 < EMA200             |
//+------------------------------------------------------------------+
bool CMovingAverages::IsRibbonAligned(int shift, bool &isBullish)
{
   if(!LoadBuffers(shift + 1)) return false;

   double price = iClose(m_symbol, m_timeframe, shift);

   // Vérifier l'alignement haussier
   bool bullishRibbon = (price > m_ema9Buffer[shift] &&
                         m_ema9Buffer[shift] > m_ema21Buffer[shift] &&
                         m_ema21Buffer[shift] > m_ema50Buffer[shift] &&
                         m_ema50Buffer[shift] > m_ema200Buffer[shift]);

   if(bullishRibbon)
   {
      isBullish = true;
      return true;
   }

   // Vérifier l'alignement baissier
   bool bearishRibbon = (price < m_ema9Buffer[shift] &&
                         m_ema9Buffer[shift] < m_ema21Buffer[shift] &&
                         m_ema21Buffer[shift] < m_ema50Buffer[shift] &&
                         m_ema50Buffer[shift] < m_ema200Buffer[shift]);

   if(bearishRibbon)
   {
      isBullish = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix croise une EMA                                |
//+------------------------------------------------------------------+
bool CMovingAverages::IsPriceCrossingEMA(int shift, double emaValue, bool &crossUp)
{
   double closeCurrent = iClose(m_symbol, m_timeframe, shift);
   double closePrev = iClose(m_symbol, m_timeframe, shift + 1);

   // Croisement vers le haut
   if(closePrev < emaValue && closeCurrent > emaValue)
   {
      crossUp = true;
      return true;
   }

   // Croisement vers le bas
   if(closePrev > emaValue && closeCurrent < emaValue)
   {
      crossUp = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier le croisement de deux EMAs                               |
//+------------------------------------------------------------------+
bool CMovingAverages::IsEMACrossing(int shift, double fastEMA1, double fastEMA2,
                                    double slowEMA1, double slowEMA2, bool &crossUp)
{
   // Croisement vers le haut (Golden Cross)
   if(fastEMA2 < slowEMA2 && fastEMA1 > slowEMA1)
   {
      crossUp = true;
      return true;
   }

   // Croisement vers le bas (Death Cross)
   if(fastEMA2 > slowEMA2 && fastEMA1 < slowEMA1)
   {
      crossUp = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Analyse complète des EMAs                                         |
//+------------------------------------------------------------------+
SEMAAnalysis CMovingAverages::Analyze(int shift)
{
   SEMAAnalysis analysis;

   analysis.current = GetAllEMAs(shift);
   analysis.previous = GetAllEMAs(shift + 1);

   // Bias basé sur EMA 200
   double price = iClose(m_symbol, m_timeframe, shift);
   analysis.isBullishBias = (price > analysis.current.ema200);

   // Ribbon
   analysis.isRibbonAligned = IsRibbonAligned(shift, analysis.isRibbonBullish);

   // Signal
   analysis.signal = GetCurrentSignal(shift);

   return analysis;
}

//+------------------------------------------------------------------+
//| Obtenir le support dynamique (EMA la plus proche en dessous)      |
//+------------------------------------------------------------------+
double CMovingAverages::GetDynamicSupport(int shift)
{
   double price = iClose(m_symbol, m_timeframe, shift);
   SEMAValues emas = GetAllEMAs(shift);

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
   double price = iClose(m_symbol, m_timeframe, shift);
   SEMAValues emas = GetAllEMAs(shift);

   double resistance = DBL_MAX;

   // Trouver l'EMA la plus proche au-dessus du prix
   if(emas.ema9 > price && emas.ema9 < resistance) resistance = emas.ema9;
   if(emas.ema21 > price && emas.ema21 < resistance) resistance = emas.ema21;
   if(emas.ema50 > price && emas.ema50 < resistance) resistance = emas.ema50;
   if(emas.ema200 > price && emas.ema200 < resistance) resistance = emas.ema200;

   if(resistance == DBL_MAX) resistance = 0;

   return resistance;
}

//+------------------------------------------------------------------+
//| Calculer la pente d'une EMA                                       |
//+------------------------------------------------------------------+
double CMovingAverages::GetEMASlope(int period, int lookback = 5)
{
   if(!LoadBuffers(lookback + 1)) return 0;

   double emaStart, emaEnd;

   switch(period)
   {
      case 9:   emaStart = m_ema9Buffer[lookback];  emaEnd = m_ema9Buffer[0];   break;
      case 21:  emaStart = m_ema21Buffer[lookback]; emaEnd = m_ema21Buffer[0];  break;
      case 50:  emaStart = m_ema50Buffer[lookback]; emaEnd = m_ema50Buffer[0];  break;
      case 200: emaStart = m_ema200Buffer[lookback];emaEnd = m_ema200Buffer[0]; break;
      default:  return 0;
   }

   return (emaEnd - emaStart) / lookback;
}

//+------------------------------------------------------------------+
//| Vérifier si une EMA est en tendance haussière                     |
//+------------------------------------------------------------------+
bool CMovingAverages::IsEMATrendingUp(int period, int lookback = 5)
{
   return (GetEMASlope(period, lookback) > 0);
}

//+------------------------------------------------------------------+
//| Vérifier si une EMA est en tendance baissière                     |
//+------------------------------------------------------------------+
bool CMovingAverages::IsEMATrendingDown(int period, int lookback = 5)
{
   return (GetEMASlope(period, lookback) < 0);
}

//+------------------------------------------------------------------+
//| Obtenir le signal actuel                                          |
//+------------------------------------------------------------------+
ENUM_EMA_SIGNAL CMovingAverages::GetCurrentSignal(int shift)
{
   // Vérifier les croix majeures d'abord
   if(IsGoldenCross(shift))
      return EMA_GOLDEN_CROSS;

   if(IsDeathCross(shift))
      return EMA_DEATH_CROSS;

   // Vérifier le ribbon
   bool isBullish;
   if(IsRibbonAligned(shift, isBullish))
   {
      return isBullish ? EMA_RIBBON_BULLISH : EMA_RIBBON_BEARISH;
   }

   // Vérifier le bias
   if(IsBullishBias(shift))
      return EMA_PRICE_ABOVE_200;

   if(IsBearishBias(shift))
      return EMA_PRICE_BELOW_200;

   return EMA_SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Obtenir le bias en string                                         |
//+------------------------------------------------------------------+
string CMovingAverages::GetBiasString(int shift)
{
   if(IsBullishBias(shift))
      return "HAUSSIER (Prix > EMA 200)";
   else
      return "BAISSIER (Prix < EMA 200)";
}

//+------------------------------------------------------------------+
//| Générer une alerte EMA                                            |
//+------------------------------------------------------------------+
string CMovingAverages::GetEMAAlert(int shift)
{
   string alert = "";

   // RÈGLE: Golden Cross / Death Cross → Alerte majeure
   if(IsGoldenCross(shift))
   {
      alert = "📈 ALERTE MAJEURE: GOLDEN CROSS détecté! (EMA 50 > EMA 200)";
      return alert;
   }

   if(IsDeathCross(shift))
   {
      alert = "📉 ALERTE MAJEURE: DEATH CROSS détecté! (EMA 50 < EMA 200)";
      return alert;
   }

   // Croix rapides
   if(IsFastGoldenCross(shift))
   {
      alert = "📈 Golden Cross rapide (EMA 9 > EMA 21)";
      return alert;
   }

   if(IsFastDeathCross(shift))
   {
      alert = "📉 Death Cross rapide (EMA 9 < EMA 21)";
      return alert;
   }

   // RÈGLE: EMA Ribbon aligné → "Tendance forte"
   bool isBullish;
   if(IsRibbonAligned(shift, isBullish))
   {
      if(isBullish)
         alert = "📊 EMA Ribbon aligné HAUSSIER - Tendance forte";
      else
         alert = "📊 EMA Ribbon aligné BAISSIER - Tendance forte";
      return alert;
   }

   return alert;
}
//+------------------------------------------------------------------+
