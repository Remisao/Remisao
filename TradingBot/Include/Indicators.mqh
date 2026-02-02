//+------------------------------------------------------------------+
//|                                                Indicators.mqh   |
//|                     CHAPITRE 8 - RSI & MACD PROFESSIONNEL       |
//|                     THERMOMÈTRE DU MARCHÉ - PAS UN SIGNAL       |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE:                                                      |
//| RSI + MACD ne sont PAS des signaux d'entrée                      |
//| Ce sont des CAPTEURS DE PRESSION du marché                       |
//| Ils servent à:                                                    |
//|   - Mesurer la force réelle du mouvement                         |
//|   - Détecter les zones de danger                                  |
//|   - Identifier l'essoufflement                                    |
//|   - Préparer les divergences                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Énumération des états RSI                                        |
//+------------------------------------------------------------------+
enum ENUM_RSI_STATE
{
   RSI_NEUTRAL = 0,          // Zone neutre (45-55)
   RSI_OVERBOUGHT,           // Surachat (> 70) - ZONE DE VIGILANCE
   RSI_OVERSOLD,             // Survente (< 30) - ZONE DE VIGILANCE
   RSI_EXTREME_OVERBOUGHT,   // Surachat extrême (> 80) - DANGER
   RSI_EXTREME_OVERSOLD,     // Survente extrême (< 20) - DANGER
   RSI_BULLISH_ZONE,         // Zone haussière (55-70)
   RSI_BEARISH_ZONE          // Zone baissière (30-45)
};

//+------------------------------------------------------------------+
//| Énumération du momentum RSI                                      |
//+------------------------------------------------------------------+
enum ENUM_RSI_MOMENTUM
{
   RSI_MOM_NEUTRAL = 0,      // Pas de momentum clair
   RSI_MOM_ACCELERATING_UP,  // RSI monte et accélère
   RSI_MOM_DECELERATING_UP,  // RSI monte mais ralentit (ATTENTION)
   RSI_MOM_ACCELERATING_DOWN,// RSI baisse et accélère
   RSI_MOM_DECELERATING_DOWN // RSI baisse mais ralentit (ATTENTION)
};

//+------------------------------------------------------------------+
//| Énumération des états MACD                                       |
//+------------------------------------------------------------------+
enum ENUM_MACD_STATE
{
   MACD_NEUTRAL = 0,
   MACD_BULLISH,             // MACD > Signal et > 0
   MACD_BEARISH,             // MACD < Signal et < 0
   MACD_BULLISH_CROSS,       // Croisement haussier (CONFIRMATION seulement)
   MACD_BEARISH_CROSS,       // Croisement baissier (CONFIRMATION seulement)
   MACD_BULLISH_EXHAUSTION,  // Essoufflement haussier - DANGER
   MACD_BEARISH_EXHAUSTION   // Essoufflement baissier - DANGER
};

//+------------------------------------------------------------------+
//| Énumération de la tendance de l'histogramme                      |
//+------------------------------------------------------------------+
enum ENUM_HISTOGRAM_TREND
{
   HIST_NEUTRAL = 0,
   HIST_GROWING,             // Barres qui grossissent
   HIST_SHRINKING,           // Barres qui rétrécissent (ATTENTION)
   HIST_PEAK,                // Pic atteint
   HIST_TROUGH               // Creux atteint
};

//+------------------------------------------------------------------+
//| Structure des données RSI - ANALYSE COMPLÈTE                     |
//+------------------------------------------------------------------+
struct SRSIData
{
   double            value;              // Valeur RSI actuelle
   double            valuePrev;          // Valeur RSI précédente
   double            velocity;           // Vitesse de changement
   double            acceleration;       // Accélération (changement de vitesse)
   ENUM_RSI_STATE    state;              // État actuel
   ENUM_RSI_MOMENTUM momentum;           // Momentum (accélération/décélération)
   bool              isInDangerZone;     // Zone critique (< 20 ou > 80)
   bool              isLosingMomentum;   // Perd de la vitesse
   bool              isDivergencePossible; // Préparation divergence
   int               barsInZone;         // Nombre de barres dans zone actuelle
};

//+------------------------------------------------------------------+
//| Structure des données MACD - ANALYSE COMPLÈTE                    |
//+------------------------------------------------------------------+
struct SMACDData
{
   double               macdLine;           // Ligne MACD
   double               signalLine;         // Ligne Signal
   double               histogram;          // Histogramme actuel
   double               histogramPrev;      // Histogramme précédent
   double               histogramPrev2;     // Histogramme N-2
   double               histogramSize;      // Taille absolue
   double               histogramChange;    // Changement en %
   ENUM_MACD_STATE      state;              // État MACD
   ENUM_HISTOGRAM_TREND histogramTrend;     // Tendance de l'histogramme
   bool                 isExhaustion;       // Essoufflement détecté
   bool                 isCrossover;        // Croisement en cours
   bool                 isHistogramPeak;    // Pic d'histogramme
   int                  barsSinceCross;     // Barres depuis dernier croisement
};

//+------------------------------------------------------------------+
//| Structure de pression du marché (THERMOMÈTRE)                    |
//+------------------------------------------------------------------+
struct SMarketPressure
{
   int               bullishPressure;    // Score pression haussière (0-100)
   int               bearishPressure;    // Score pression baissière (0-100)
   string            bias;               // "BULLISH", "BEARISH", "NEUTRAL"
   bool              isOverextended;     // Marché surextendu
   bool              isExhausted;        // Signes d'essoufflement
   bool              waitForPullback;    // Attendre un pullback
   string            warningMessage;     // Message d'avertissement
};

//+------------------------------------------------------------------+
//| Classe d'analyse RSI & MACD PROFESSIONNELLE                      |
//+------------------------------------------------------------------+
class CIndicators
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Handles indicateurs
   int               m_rsiHandle;
   int               m_macdHandle;

   // Buffers optimisés
   double            m_rsiBuffer[];
   double            m_macdBuffer[];
   double            m_signalBuffer[];
   double            m_histBuffer[];

   // Paramètres RSI (période 14 standard)
   int               m_rsiPeriod;
   double            m_rsiOverbought;       // 70
   double            m_rsiOversold;         // 30
   double            m_rsiExtremeHigh;      // 80
   double            m_rsiExtremeLow;       // 20

   // Paramètres MACD (12, 26, 9 standard)
   int               m_macdFast;
   int               m_macdSlow;
   int               m_macdSignal;

   // Cache pour éviter recalculs
   datetime          m_lastCalculation;
   int               m_barsCalculated;

   // Méthodes privées
   bool              LoadRSIBuffer(int count);
   bool              LoadMACDBuffers(int count);
   void              ReleaseHandles();
   double            CalculateVelocity(int shift, int lookback);
   double            CalculateAcceleration(int shift, int lookback);
   int               CountBarsInState(ENUM_RSI_STATE state, int maxBars);

public:
   CIndicators();
   ~CIndicators();

   // ============ INITIALISATION ============
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetRSIParameters(int period, double overbought, double oversold);
   void              SetMACDParameters(int fast, int slow, int signal);

   // ============ RSI - THERMOMÈTRE ============
   double            GetRSI(int shift = 0);
   ENUM_RSI_STATE    GetRSIState(int shift = 0);
   ENUM_RSI_MOMENTUM GetRSIMomentum(int shift = 0);
   SRSIData          AnalyzeRSI(int shift = 0);

   // RSI - Zones de vigilance (PAS des signaux!)
   bool              IsOverbought(int shift = 0);
   bool              IsOversold(int shift = 0);
   bool              IsExtremeOverbought(int shift = 0);
   bool              IsExtremeOversold(int shift = 0);
   bool              IsRSIInDangerZone(int shift = 0);

   // RSI - Momentum (clé pour anticipation)
   bool              IsRSILosingMomentum(int shift = 0);
   bool              IsRSIGainingMomentum(int shift = 0);
   double            GetRSIVelocity(int shift = 0);
   double            GetRSIAcceleration(int shift = 0);

   // ============ MACD - THERMOMÈTRE ============
   double            GetMACDLine(int shift = 0);
   double            GetSignalLine(int shift = 0);
   double            GetHistogram(int shift = 0);
   ENUM_MACD_STATE   GetMACDState(int shift = 0);
   ENUM_HISTOGRAM_TREND GetHistogramTrend(int shift = 0);
   SMACDData         AnalyzeMACD(int shift = 0);

   // MACD - Analyse histogramme (PRIORITÉ)
   bool              IsHistogramGrowing(int shift = 0);
   bool              IsHistogramShrinking(int shift = 0);
   bool              IsHistogramAtPeak(int shift = 0);
   bool              IsHistogramAtTrough(int shift = 0);
   double            GetHistogramChangePercent(int shift = 0);

   // MACD - Essoufflement (CRITIQUE)
   bool              IsBullishExhaustion(int shift = 0);
   bool              IsBearishExhaustion(int shift = 0);
   bool              IsExhaustionDetected(int shift = 0);

   // MACD - Croisements (CONFIRMATION seulement)
   bool              IsMACDBullishCross(int shift = 1);
   bool              IsMACDBearishCross(int shift = 1);

   // ============ ANALYSE COMBINÉE - PRESSION MARCHÉ ============
   SMarketPressure   GetMarketPressure(int shift = 0);
   bool              IsBullishMomentum(int shift = 0);
   bool              IsBearishMomentum(int shift = 0);
   bool              ShouldWaitForPullback(int shift = 0);
   int               GetBullishScore(int shift = 0);
   int               GetBearishScore(int shift = 0);

   // ============ FILTRES POUR CONFLUENCE ============
   bool              ConfirmsBullishSetup(int shift = 0);
   bool              ConfirmsBearishSetup(int shift = 0);
   bool              FiltersOutTrade(int shift = 0);

   // ============ UTILITAIRES ============
   string            RSIStateToString(ENUM_RSI_STATE state);
   string            RSIMomentumToString(ENUM_RSI_MOMENTUM momentum);
   string            MACDStateToString(ENUM_MACD_STATE state);
   string            HistogramTrendToString(ENUM_HISTOGRAM_TREND trend);
   string            GetRSIAlert(int shift = 0);
   string            GetMACDAlert(int shift = 0);
   string            GetMarketPressureAlert(int shift = 0);
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

   // Paramètres RSI standard
   m_rsiPeriod = 14;
   m_rsiOverbought = 70.0;
   m_rsiOversold = 30.0;
   m_rsiExtremeHigh = 80.0;
   m_rsiExtremeLow = 20.0;

   // Paramètres MACD standard
   m_macdFast = 12;
   m_macdSlow = 26;
   m_macdSignal = 9;

   m_lastCalculation = 0;
   m_barsCalculated = 0;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CIndicators::~CIndicators()
{
   ReleaseHandles();
}

//+------------------------------------------------------------------+
//| Libérer les handles proprement                                    |
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

   // Créer handle RSI (iRSI natif MQL5)
   m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE)
   {
      Print("ERREUR: Impossible de créer handle RSI pour ", m_symbol);
      return false;
   }

   // Créer handle MACD (iMACD natif MQL5)
   m_macdHandle = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
   if(m_macdHandle == INVALID_HANDLE)
   {
      Print("ERREUR: Impossible de créer handle MACD pour ", m_symbol);
      return false;
   }

   // Initialiser buffers comme séries (index 0 = plus récent)
   ArraySetAsSeries(m_rsiBuffer, true);
   ArraySetAsSeries(m_macdBuffer, true);
   ArraySetAsSeries(m_signalBuffer, true);
   ArraySetAsSeries(m_histBuffer, true);

   return true;
}

//+------------------------------------------------------------------+
//| Configuration RSI                                                 |
//+------------------------------------------------------------------+
void CIndicators::SetRSIParameters(int period, double overbought, double oversold)
{
   m_rsiPeriod = period;
   m_rsiOverbought = overbought;
   m_rsiOversold = oversold;
   m_rsiExtremeHigh = overbought + 10.0;
   m_rsiExtremeLow = oversold - 10.0;
}

//+------------------------------------------------------------------+
//| Configuration MACD                                                |
//+------------------------------------------------------------------+
void CIndicators::SetMACDParameters(int fast, int slow, int signal)
{
   m_macdFast = fast;
   m_macdSlow = slow;
   m_macdSignal = signal;
}

//+------------------------------------------------------------------+
//| Charger buffer RSI (optimisé)                                     |
//+------------------------------------------------------------------+
bool CIndicators::LoadRSIBuffer(int count)
{
   if(m_rsiHandle == INVALID_HANDLE) return false;
   int copied = CopyBuffer(m_rsiHandle, 0, 0, count, m_rsiBuffer);
   return (copied >= count);
}

//+------------------------------------------------------------------+
//| Charger buffers MACD (optimisé)                                   |
//+------------------------------------------------------------------+
bool CIndicators::LoadMACDBuffers(int count)
{
   if(m_macdHandle == INVALID_HANDLE) return false;

   if(CopyBuffer(m_macdHandle, 0, 0, count, m_macdBuffer) < count) return false;
   if(CopyBuffer(m_macdHandle, 1, 0, count, m_signalBuffer) < count) return false;

   // Calculer histogramme
   ArrayResize(m_histBuffer, count);
   for(int i = 0; i < count; i++)
   {
      m_histBuffer[i] = m_macdBuffer[i] - m_signalBuffer[i];
   }

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir valeur RSI                                                |
//+------------------------------------------------------------------+
double CIndicators::GetRSI(int shift)
{
   if(!LoadRSIBuffer(shift + 1)) return 50.0;
   return m_rsiBuffer[shift];
}

//+------------------------------------------------------------------+
//| État RSI - ZONES DE VIGILANCE                                     |
//+------------------------------------------------------------------+
ENUM_RSI_STATE CIndicators::GetRSIState(int shift)
{
   double rsi = GetRSI(shift);

   // Zones extrêmes (DANGER)
   if(rsi > m_rsiExtremeHigh) return RSI_EXTREME_OVERBOUGHT;
   if(rsi < m_rsiExtremeLow) return RSI_EXTREME_OVERSOLD;

   // Zones de vigilance
   if(rsi > m_rsiOverbought) return RSI_OVERBOUGHT;
   if(rsi < m_rsiOversold) return RSI_OVERSOLD;

   // Zones tendancielles
   if(rsi >= 55.0) return RSI_BULLISH_ZONE;
   if(rsi <= 45.0) return RSI_BEARISH_ZONE;

   return RSI_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Calculer vélocité RSI                                             |
//+------------------------------------------------------------------+
double CIndicators::CalculateVelocity(int shift, int lookback)
{
   if(!LoadRSIBuffer(shift + lookback + 1)) return 0;
   return m_rsiBuffer[shift] - m_rsiBuffer[shift + lookback];
}

//+------------------------------------------------------------------+
//| Calculer accélération RSI                                         |
//+------------------------------------------------------------------+
double CIndicators::CalculateAcceleration(int shift, int lookback)
{
   double velocity1 = CalculateVelocity(shift, lookback);
   double velocity2 = CalculateVelocity(shift + lookback, lookback);
   return velocity1 - velocity2;
}

//+------------------------------------------------------------------+
//| Obtenir vélocité RSI                                              |
//+------------------------------------------------------------------+
double CIndicators::GetRSIVelocity(int shift)
{
   return CalculateVelocity(shift, 3);
}

//+------------------------------------------------------------------+
//| Obtenir accélération RSI                                          |
//+------------------------------------------------------------------+
double CIndicators::GetRSIAcceleration(int shift)
{
   return CalculateAcceleration(shift, 3);
}

//+------------------------------------------------------------------+
//| Momentum RSI - CRITIQUE pour anticipation                        |
//+------------------------------------------------------------------+
ENUM_RSI_MOMENTUM CIndicators::GetRSIMomentum(int shift)
{
   double velocity = GetRSIVelocity(shift);
   double acceleration = GetRSIAcceleration(shift);

   // RSI monte
   if(velocity > 0)
   {
      if(acceleration > 0)
         return RSI_MOM_ACCELERATING_UP;    // Force qui augmente
      else if(acceleration < -1.0)
         return RSI_MOM_DECELERATING_UP;    // ATTENTION: perd de la vitesse
   }
   // RSI baisse
   else if(velocity < 0)
   {
      if(acceleration < 0)
         return RSI_MOM_ACCELERATING_DOWN;  // Force qui augmente
      else if(acceleration > 1.0)
         return RSI_MOM_DECELERATING_DOWN;  // ATTENTION: perd de la vitesse
   }

   return RSI_MOM_NEUTRAL;
}

//+------------------------------------------------------------------+
//| RSI perd son momentum (SIGNAL D'ATTENTION)                       |
//+------------------------------------------------------------------+
bool CIndicators::IsRSILosingMomentum(int shift)
{
   ENUM_RSI_MOMENTUM mom = GetRSIMomentum(shift);
   return (mom == RSI_MOM_DECELERATING_UP || mom == RSI_MOM_DECELERATING_DOWN);
}

//+------------------------------------------------------------------+
//| RSI gagne en momentum                                             |
//+------------------------------------------------------------------+
bool CIndicators::IsRSIGainingMomentum(int shift)
{
   ENUM_RSI_MOMENTUM mom = GetRSIMomentum(shift);
   return (mom == RSI_MOM_ACCELERATING_UP || mom == RSI_MOM_ACCELERATING_DOWN);
}

//+------------------------------------------------------------------+
//| Zones de vigilance RSI                                            |
//+------------------------------------------------------------------+
bool CIndicators::IsOverbought(int shift)
{
   return (GetRSI(shift) > m_rsiOverbought);
}

bool CIndicators::IsOversold(int shift)
{
   return (GetRSI(shift) < m_rsiOversold);
}

bool CIndicators::IsExtremeOverbought(int shift)
{
   return (GetRSI(shift) > m_rsiExtremeHigh);
}

bool CIndicators::IsExtremeOversold(int shift)
{
   return (GetRSI(shift) < m_rsiExtremeLow);
}

bool CIndicators::IsRSIInDangerZone(int shift)
{
   return (IsExtremeOverbought(shift) || IsExtremeOversold(shift));
}

//+------------------------------------------------------------------+
//| Compter barres dans un état                                       |
//+------------------------------------------------------------------+
int CIndicators::CountBarsInState(ENUM_RSI_STATE state, int maxBars)
{
   int count = 0;
   for(int i = 0; i < maxBars; i++)
   {
      if(GetRSIState(i) == state)
         count++;
      else
         break;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Analyse RSI complète                                              |
//+------------------------------------------------------------------+
SRSIData CIndicators::AnalyzeRSI(int shift)
{
   SRSIData data;

   if(!LoadRSIBuffer(shift + 10))
   {
      data.value = 50.0;
      data.valuePrev = 50.0;
      data.velocity = 0;
      data.acceleration = 0;
      data.state = RSI_NEUTRAL;
      data.momentum = RSI_MOM_NEUTRAL;
      data.isInDangerZone = false;
      data.isLosingMomentum = false;
      data.isDivergencePossible = false;
      data.barsInZone = 0;
      return data;
   }

   data.value = m_rsiBuffer[shift];
   data.valuePrev = m_rsiBuffer[shift + 1];
   data.velocity = GetRSIVelocity(shift);
   data.acceleration = GetRSIAcceleration(shift);
   data.state = GetRSIState(shift);
   data.momentum = GetRSIMomentum(shift);
   data.isInDangerZone = IsRSIInDangerZone(shift);
   data.isLosingMomentum = IsRSILosingMomentum(shift);
   data.barsInZone = CountBarsInState(data.state, 20);

   // Préparation divergence: RSI perd momentum dans zone extrême
   data.isDivergencePossible = (data.isInDangerZone && data.isLosingMomentum);

   return data;
}

//+------------------------------------------------------------------+
//| Obtenir ligne MACD                                                |
//+------------------------------------------------------------------+
double CIndicators::GetMACDLine(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_macdBuffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir ligne Signal                                              |
//+------------------------------------------------------------------+
double CIndicators::GetSignalLine(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_signalBuffer[shift];
}

//+------------------------------------------------------------------+
//| Obtenir histogramme                                               |
//+------------------------------------------------------------------+
double CIndicators::GetHistogram(int shift)
{
   if(!LoadMACDBuffers(shift + 1)) return 0;
   return m_histBuffer[shift];
}

//+------------------------------------------------------------------+
//| Changement histogramme en %                                       |
//+------------------------------------------------------------------+
double CIndicators::GetHistogramChangePercent(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return 0;

   double current = MathAbs(m_histBuffer[shift]);
   double previous = MathAbs(m_histBuffer[shift + 1]);

   if(previous == 0) return 0;

   return ((current - previous) / previous) * 100.0;
}

//+------------------------------------------------------------------+
//| Tendance de l'histogramme (PRIORITÉ)                              |
//+------------------------------------------------------------------+
ENUM_HISTOGRAM_TREND CIndicators::GetHistogramTrend(int shift)
{
   if(!LoadMACDBuffers(shift + 4)) return HIST_NEUTRAL;

   double h0 = MathAbs(m_histBuffer[shift]);
   double h1 = MathAbs(m_histBuffer[shift + 1]);
   double h2 = MathAbs(m_histBuffer[shift + 2]);
   double h3 = MathAbs(m_histBuffer[shift + 3]);

   // Histogramme qui grossit
   if(h0 > h1 && h1 > h2)
      return HIST_GROWING;

   // Histogramme qui rétrécit (ATTENTION!)
   if(h0 < h1 && h1 < h2)
      return HIST_SHRINKING;

   // Pic (était croissant, maintenant décroissant)
   if(h1 > h0 && h1 > h2)
      return HIST_PEAK;

   // Creux (était décroissant, maintenant croissant)
   if(h1 < h0 && h1 < h2)
      return HIST_TROUGH;

   return HIST_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Histogramme croissant                                             |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramGrowing(int shift)
{
   return (GetHistogramTrend(shift) == HIST_GROWING);
}

//+------------------------------------------------------------------+
//| Histogramme décroissant (ATTENTION!)                              |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramShrinking(int shift)
{
   return (GetHistogramTrend(shift) == HIST_SHRINKING);
}

//+------------------------------------------------------------------+
//| Histogramme au pic                                                |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramAtPeak(int shift)
{
   return (GetHistogramTrend(shift) == HIST_PEAK);
}

//+------------------------------------------------------------------+
//| Histogramme au creux                                              |
//+------------------------------------------------------------------+
bool CIndicators::IsHistogramAtTrough(int shift)
{
   return (GetHistogramTrend(shift) == HIST_TROUGH);
}

//+------------------------------------------------------------------+
//| Essoufflement haussier                                            |
//| RÈGLE: Prix monte MAIS histogramme diminue                        |
//+------------------------------------------------------------------+
bool CIndicators::IsBullishExhaustion(int shift)
{
   if(!LoadMACDBuffers(shift + 4)) return false;

   // Vérifier que l'histogramme est positif (tendance haussière)
   if(m_histBuffer[shift] <= 0) return false;

   // Vérifier que le prix monte
   double priceCurrent = iClose(m_symbol, m_timeframe, shift);
   double pricePrev = iClose(m_symbol, m_timeframe, shift + 3);
   bool priceRising = (priceCurrent > pricePrev);

   if(!priceRising) return false;

   // Vérifier que l'histogramme diminue
   bool histShrinking = IsHistogramShrinking(shift);

   return histShrinking;
}

//+------------------------------------------------------------------+
//| Essoufflement baissier                                            |
//| RÈGLE: Prix baisse MAIS histogramme diminue (en valeur absolue)  |
//+------------------------------------------------------------------+
bool CIndicators::IsBearishExhaustion(int shift)
{
   if(!LoadMACDBuffers(shift + 4)) return false;

   // Vérifier que l'histogramme est négatif (tendance baissière)
   if(m_histBuffer[shift] >= 0) return false;

   // Vérifier que le prix baisse
   double priceCurrent = iClose(m_symbol, m_timeframe, shift);
   double pricePrev = iClose(m_symbol, m_timeframe, shift + 3);
   bool priceFalling = (priceCurrent < pricePrev);

   if(!priceFalling) return false;

   // Vérifier que l'histogramme diminue (en valeur absolue)
   bool histShrinking = IsHistogramShrinking(shift);

   return histShrinking;
}

//+------------------------------------------------------------------+
//| Essoufflement détecté (haussier ou baissier)                     |
//+------------------------------------------------------------------+
bool CIndicators::IsExhaustionDetected(int shift)
{
   return (IsBullishExhaustion(shift) || IsBearishExhaustion(shift));
}

//+------------------------------------------------------------------+
//| Croisement MACD haussier (CONFIRMATION seulement!)               |
//+------------------------------------------------------------------+
bool CIndicators::IsMACDBullishCross(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return false;

   bool wasBelowSignal = (m_macdBuffer[shift + 1] < m_signalBuffer[shift + 1]);
   bool isAboveSignal = (m_macdBuffer[shift] > m_signalBuffer[shift]);

   return (wasBelowSignal && isAboveSignal);
}

//+------------------------------------------------------------------+
//| Croisement MACD baissier (CONFIRMATION seulement!)               |
//+------------------------------------------------------------------+
bool CIndicators::IsMACDBearishCross(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return false;

   bool wasAboveSignal = (m_macdBuffer[shift + 1] > m_signalBuffer[shift + 1]);
   bool isBelowSignal = (m_macdBuffer[shift] < m_signalBuffer[shift]);

   return (wasAboveSignal && isBelowSignal);
}

//+------------------------------------------------------------------+
//| État MACD                                                         |
//+------------------------------------------------------------------+
ENUM_MACD_STATE CIndicators::GetMACDState(int shift)
{
   if(!LoadMACDBuffers(shift + 2)) return MACD_NEUTRAL;

   // Essoufflement prioritaire
   if(IsBullishExhaustion(shift)) return MACD_BULLISH_EXHAUSTION;
   if(IsBearishExhaustion(shift)) return MACD_BEARISH_EXHAUSTION;

   // Croisements
   if(IsMACDBullishCross(shift)) return MACD_BULLISH_CROSS;
   if(IsMACDBearishCross(shift)) return MACD_BEARISH_CROSS;

   // État général
   double macd = m_macdBuffer[shift];
   double signal = m_signalBuffer[shift];

   if(macd > signal && macd > 0) return MACD_BULLISH;
   if(macd < signal && macd < 0) return MACD_BEARISH;

   return MACD_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Analyse MACD complète                                             |
//+------------------------------------------------------------------+
SMACDData CIndicators::AnalyzeMACD(int shift)
{
   SMACDData data;

   if(!LoadMACDBuffers(shift + 5))
   {
      data.macdLine = 0;
      data.signalLine = 0;
      data.histogram = 0;
      data.histogramPrev = 0;
      data.histogramPrev2 = 0;
      data.histogramSize = 0;
      data.histogramChange = 0;
      data.state = MACD_NEUTRAL;
      data.histogramTrend = HIST_NEUTRAL;
      data.isExhaustion = false;
      data.isCrossover = false;
      data.isHistogramPeak = false;
      data.barsSinceCross = 0;
      return data;
   }

   data.macdLine = m_macdBuffer[shift];
   data.signalLine = m_signalBuffer[shift];
   data.histogram = m_histBuffer[shift];
   data.histogramPrev = m_histBuffer[shift + 1];
   data.histogramPrev2 = m_histBuffer[shift + 2];
   data.histogramSize = MathAbs(data.histogram);
   data.histogramChange = GetHistogramChangePercent(shift);
   data.state = GetMACDState(shift);
   data.histogramTrend = GetHistogramTrend(shift);
   data.isExhaustion = IsExhaustionDetected(shift);
   data.isCrossover = (IsMACDBullishCross(shift) || IsMACDBearishCross(shift));
   data.isHistogramPeak = IsHistogramAtPeak(shift);

   // Compter barres depuis dernier croisement
   data.barsSinceCross = 0;
   for(int i = shift; i < shift + 50; i++)
   {
      if(IsMACDBullishCross(i) || IsMACDBearishCross(i))
         break;
      data.barsSinceCross++;
   }

   return data;
}

//+------------------------------------------------------------------+
//| Score haussier (0-100)                                            |
//+------------------------------------------------------------------+
int CIndicators::GetBullishScore(int shift)
{
   int score = 50; // Base neutre

   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   // RSI contributions
   if(rsi.state == RSI_BULLISH_ZONE) score += 10;
   if(rsi.momentum == RSI_MOM_ACCELERATING_UP) score += 15;
   if(rsi.isLosingMomentum && rsi.value > 50) score -= 10;
   if(rsi.isInDangerZone && rsi.value > 70) score -= 20;

   // MACD contributions
   if(macd.state == MACD_BULLISH) score += 10;
   if(macd.histogramTrend == HIST_GROWING && macd.histogram > 0) score += 15;
   if(macd.isExhaustion && macd.histogram > 0) score -= 25;
   if(macd.isCrossover && macd.histogram > 0) score += 10;

   return MathMax(0, MathMin(100, score));
}

//+------------------------------------------------------------------+
//| Score baissier (0-100)                                            |
//+------------------------------------------------------------------+
int CIndicators::GetBearishScore(int shift)
{
   int score = 50;

   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   // RSI contributions
   if(rsi.state == RSI_BEARISH_ZONE) score += 10;
   if(rsi.momentum == RSI_MOM_ACCELERATING_DOWN) score += 15;
   if(rsi.isLosingMomentum && rsi.value < 50) score -= 10;
   if(rsi.isInDangerZone && rsi.value < 30) score -= 20;

   // MACD contributions
   if(macd.state == MACD_BEARISH) score += 10;
   if(macd.histogramTrend == HIST_GROWING && macd.histogram < 0) score += 15;
   if(macd.isExhaustion && macd.histogram < 0) score -= 25;
   if(macd.isCrossover && macd.histogram < 0) score += 10;

   return MathMax(0, MathMin(100, score));
}

//+------------------------------------------------------------------+
//| Pression du marché (THERMOMÈTRE GLOBAL)                          |
//+------------------------------------------------------------------+
SMarketPressure CIndicators::GetMarketPressure(int shift)
{
   SMarketPressure pressure;

   pressure.bullishPressure = GetBullishScore(shift);
   pressure.bearishPressure = GetBearishScore(shift);

   // Déterminer biais
   if(pressure.bullishPressure > pressure.bearishPressure + 15)
      pressure.bias = "BULLISH";
   else if(pressure.bearishPressure > pressure.bullishPressure + 15)
      pressure.bias = "BEARISH";
   else
      pressure.bias = "NEUTRAL";

   // Vérifier surextension
   SRSIData rsi = AnalyzeRSI(shift);
   pressure.isOverextended = rsi.isInDangerZone;

   // Vérifier essoufflement
   SMACDData macd = AnalyzeMACD(shift);
   pressure.isExhausted = macd.isExhaustion || rsi.isLosingMomentum;

   // Recommandation pullback
   pressure.waitForPullback = (pressure.isOverextended || pressure.isExhausted);

   // Message d'avertissement
   pressure.warningMessage = "";
   if(pressure.isExhausted)
      pressure.warningMessage = "ATTENTION: Signes d'essoufflement détectés";
   else if(pressure.isOverextended)
      pressure.warningMessage = "ATTENTION: Marché surextendu, attendre pullback";

   return pressure;
}

//+------------------------------------------------------------------+
//| Momentum haussier confirmé                                        |
//+------------------------------------------------------------------+
bool CIndicators::IsBullishMomentum(int shift)
{
   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   return (rsi.value > 50 &&
           macd.macdLine > macd.signalLine &&
           macd.histogram > 0 &&
           !macd.isExhaustion);
}

//+------------------------------------------------------------------+
//| Momentum baissier confirmé                                        |
//+------------------------------------------------------------------+
bool CIndicators::IsBearishMomentum(int shift)
{
   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   return (rsi.value < 50 &&
           macd.macdLine < macd.signalLine &&
           macd.histogram < 0 &&
           !macd.isExhaustion);
}

//+------------------------------------------------------------------+
//| Devrait attendre un pullback                                      |
//+------------------------------------------------------------------+
bool CIndicators::ShouldWaitForPullback(int shift)
{
   SMarketPressure pressure = GetMarketPressure(shift);
   return pressure.waitForPullback;
}

//+------------------------------------------------------------------+
//| Confirme un setup haussier (pour confluence)                     |
//+------------------------------------------------------------------+
bool CIndicators::ConfirmsBullishSetup(int shift)
{
   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   // Ne PAS confirmer si:
   // - RSI en surachat extrême
   // - Essoufflement haussier détecté
   // - RSI perd momentum en zone haute
   if(rsi.state == RSI_EXTREME_OVERBOUGHT) return false;
   if(macd.state == MACD_BULLISH_EXHAUSTION) return false;
   if(rsi.isLosingMomentum && rsi.value > 60) return false;

   // Confirmer si momentum OK
   return (rsi.value > 45 && macd.histogram > macd.histogramPrev);
}

//+------------------------------------------------------------------+
//| Confirme un setup baissier (pour confluence)                     |
//+------------------------------------------------------------------+
bool CIndicators::ConfirmsBearishSetup(int shift)
{
   SRSIData rsi = AnalyzeRSI(shift);
   SMACDData macd = AnalyzeMACD(shift);

   if(rsi.state == RSI_EXTREME_OVERSOLD) return false;
   if(macd.state == MACD_BEARISH_EXHAUSTION) return false;
   if(rsi.isLosingMomentum && rsi.value < 40) return false;

   return (rsi.value < 55 && macd.histogram < macd.histogramPrev);
}

//+------------------------------------------------------------------+
//| Filtre un trade (retourne true si on doit ÉVITER le trade)      |
//+------------------------------------------------------------------+
bool CIndicators::FiltersOutTrade(int shift)
{
   SMarketPressure pressure = GetMarketPressure(shift);

   // Filtrer si essoufflement ou surextension
   return (pressure.isExhausted || pressure.isOverextended);
}

//+------------------------------------------------------------------+
//| Convertir état RSI en string                                      |
//+------------------------------------------------------------------+
string CIndicators::RSIStateToString(ENUM_RSI_STATE state)
{
   switch(state)
   {
      case RSI_NEUTRAL:             return "Neutre (45-55)";
      case RSI_OVERBOUGHT:          return "SURACHAT (>70)";
      case RSI_OVERSOLD:            return "SURVENTE (<30)";
      case RSI_EXTREME_OVERBOUGHT:  return "SURACHAT EXTRÊME (>80)";
      case RSI_EXTREME_OVERSOLD:    return "SURVENTE EXTRÊME (<20)";
      case RSI_BULLISH_ZONE:        return "Zone haussière (55-70)";
      case RSI_BEARISH_ZONE:        return "Zone baissière (30-45)";
      default:                      return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir momentum RSI en string                                  |
//+------------------------------------------------------------------+
string CIndicators::RSIMomentumToString(ENUM_RSI_MOMENTUM momentum)
{
   switch(momentum)
   {
      case RSI_MOM_NEUTRAL:           return "Neutre";
      case RSI_MOM_ACCELERATING_UP:   return "Accélération haussière";
      case RSI_MOM_DECELERATING_UP:   return "RALENTISSEMENT haussier";
      case RSI_MOM_ACCELERATING_DOWN: return "Accélération baissière";
      case RSI_MOM_DECELERATING_DOWN: return "RALENTISSEMENT baissier";
      default:                        return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir état MACD en string                                     |
//+------------------------------------------------------------------+
string CIndicators::MACDStateToString(ENUM_MACD_STATE state)
{
   switch(state)
   {
      case MACD_NEUTRAL:            return "Neutre";
      case MACD_BULLISH:            return "Haussier";
      case MACD_BEARISH:            return "Baissier";
      case MACD_BULLISH_CROSS:      return "Croisement haussier";
      case MACD_BEARISH_CROSS:      return "Croisement baissier";
      case MACD_BULLISH_EXHAUSTION: return "ESSOUFFLEMENT haussier";
      case MACD_BEARISH_EXHAUSTION: return "ESSOUFFLEMENT baissier";
      default:                      return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir tendance histogramme en string                          |
//+------------------------------------------------------------------+
string CIndicators::HistogramTrendToString(ENUM_HISTOGRAM_TREND trend)
{
   switch(trend)
   {
      case HIST_NEUTRAL:   return "Neutre";
      case HIST_GROWING:   return "Croissant";
      case HIST_SHRINKING: return "DÉCROISSANT";
      case HIST_PEAK:      return "PIC atteint";
      case HIST_TROUGH:    return "CREUX atteint";
      default:             return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Générer alerte RSI                                                |
//+------------------------------------------------------------------+
string CIndicators::GetRSIAlert(int shift)
{
   SRSIData data = AnalyzeRSI(shift);
   string alert = "";

   // Zones de danger
   if(data.state == RSI_EXTREME_OVERBOUGHT)
   {
      alert = "RSI EXTRÊME (" + DoubleToString(data.value, 1) + " > 80) - DANGER zone surachat";
   }
   else if(data.state == RSI_EXTREME_OVERSOLD)
   {
      alert = "RSI EXTRÊME (" + DoubleToString(data.value, 1) + " < 20) - DANGER zone survente";
   }
   else if(data.state == RSI_OVERBOUGHT)
   {
      alert = "RSI Surachat (" + DoubleToString(data.value, 1) + ") - Zone de vigilance";
   }
   else if(data.state == RSI_OVERSOLD)
   {
      alert = "RSI Survente (" + DoubleToString(data.value, 1) + ") - Zone de vigilance";
   }

   // Momentum
   if(data.isLosingMomentum)
   {
      alert += (alert != "" ? " | " : "") + "RSI perd son momentum";
   }

   // Divergence possible
   if(data.isDivergencePossible)
   {
      alert += (alert != "" ? " | " : "") + "Divergence possible";
   }

   return alert;
}

//+------------------------------------------------------------------+
//| Générer alerte MACD                                               |
//+------------------------------------------------------------------+
string CIndicators::GetMACDAlert(int shift)
{
   SMACDData data = AnalyzeMACD(shift);
   string alert = "";

   // Essoufflement (PRIORITÉ)
   if(data.state == MACD_BULLISH_EXHAUSTION)
   {
      alert = "MACD: ESSOUFFLEMENT HAUSSIER - Prix monte mais histogramme diminue";
   }
   else if(data.state == MACD_BEARISH_EXHAUSTION)
   {
      alert = "MACD: ESSOUFFLEMENT BAISSIER - Prix baisse mais histogramme diminue";
   }
   // Croisements (secondaire)
   else if(data.state == MACD_BULLISH_CROSS)
   {
      alert = "MACD: Croisement haussier (confirmation)";
   }
   else if(data.state == MACD_BEARISH_CROSS)
   {
      alert = "MACD: Croisement baissier (confirmation)";
   }

   // Tendance histogramme
   if(data.histogramTrend == HIST_SHRINKING)
   {
      alert += (alert != "" ? " | " : "") + "Histogramme décroissant";
   }
   else if(data.histogramTrend == HIST_PEAK)
   {
      alert += (alert != "" ? " | " : "") + "Pic histogramme atteint";
   }

   return alert;
}

//+------------------------------------------------------------------+
//| Générer alerte pression marché                                    |
//+------------------------------------------------------------------+
string CIndicators::GetMarketPressureAlert(int shift)
{
   SMarketPressure pressure = GetMarketPressure(shift);

   string alert = "Pression: " + pressure.bias +
                  " (Bull:" + IntegerToString(pressure.bullishPressure) +
                  " Bear:" + IntegerToString(pressure.bearishPressure) + ")";

   if(pressure.warningMessage != "")
   {
      alert += " | " + pressure.warningMessage;
   }

   return alert;
}
//+------------------------------------------------------------------+
