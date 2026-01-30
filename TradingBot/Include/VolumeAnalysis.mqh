//+------------------------------------------------------------------+
//|                                             VolumeAnalysis.mqh  |
//|                            CHAPITRE 4 - ANALYSE DU VOLUME       |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des états de volume                                  |
//+------------------------------------------------------------------+
enum ENUM_VOLUME_STATE
{
   VOLUME_NORMAL = 0,        // Volume normal
   VOLUME_HIGH,              // Volume élevé (≥ 150%)
   VOLUME_VERY_HIGH,         // Volume très élevé (≥ 200%)
   VOLUME_LOW,               // Volume faible (< 80%)
   VOLUME_ACCUMULATION       // Accumulation détectée
};

//+------------------------------------------------------------------+
//| Structure d'analyse du volume                                    |
//+------------------------------------------------------------------+
struct SVolumeData
{
   long     currentVolume;    // Volume actuel
   double   averageVolume;    // SMA(20) du volume
   double   volumeRatio;      // Ratio volume actuel / moyenne
   ENUM_VOLUME_STATE state;   // État du volume
   bool     isValidBreakout;  // Cassure valide (volume suffisant)
   bool     isAccumulation;   // Phase d'accumulation
};

//+------------------------------------------------------------------+
//| Classe d'analyse du volume                                       |
//+------------------------------------------------------------------+
class CVolumeAnalysis
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_maPeriod;         // Période pour la moyenne (défaut: 20)
   double            m_breakoutThreshold; // Seuil de cassure valide (défaut: 150%)
   double            m_idealThreshold;    // Seuil idéal (défaut: 200%)
   int               m_accumulationBars;  // Barres pour détecter accumulation

public:
   CVolumeAnalysis();
   ~CVolumeAnalysis();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int maPeriod = 20, double breakoutPct = 150.0, double idealPct = 200.0);

   // Analyse du volume
   SVolumeData       Analyze(int shift = 0);

   // RÈGLE: Moyenne du volume = SMA(20)
   double            GetVolumeMA(int shift = 0);

   // RÈGLE: Cassure valide UNIQUEMENT si Volume ≥ 150% de la moyenne
   bool              IsValidBreakoutVolume(int shift = 0);

   // RÈGLE: Cassure idéale si Volume ≥ 200%
   bool              IsIdealBreakoutVolume(int shift = 0);

   // RÈGLE: Accumulation = Prix stable + Volume croissant
   bool              IsAccumulation(int lookback = 10);

   // Volume relatif
   double            GetVolumeRatio(int shift = 0);

   // État du volume
   ENUM_VOLUME_STATE GetVolumeState(int shift = 0);

   // Confirmations
   bool              ConfirmBreakout(int shift = 0);
   bool              HasVolumeSpike(int shift = 0);

   // Divergence volume/prix
   bool              IsVolumePriceDivergence(int lookback = 5);

   // Utilitaires
   string            VolumeStateToString(ENUM_VOLUME_STATE state);
   string            GetVolumeAlert(int shift = 0);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CVolumeAnalysis::CVolumeAnalysis()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_maPeriod = 20;              // RÈGLE: SMA(20)
   m_breakoutThreshold = 150.0;  // RÈGLE: ≥ 150%
   m_idealThreshold = 200.0;     // RÈGLE: Idéal ≥ 200%
   m_accumulationBars = 10;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CVolumeAnalysis::~CVolumeAnalysis()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CVolumeAnalysis::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CVolumeAnalysis::SetParameters(int maPeriod = 20, double breakoutPct = 150.0, double idealPct = 200.0)
{
   m_maPeriod = maPeriod;
   m_breakoutThreshold = breakoutPct;
   m_idealThreshold = idealPct;
}

//+------------------------------------------------------------------+
//| RÈGLE: Calcul de la moyenne du volume SMA(20)                    |
//+------------------------------------------------------------------+
double CVolumeAnalysis::GetVolumeMA(int shift)
{
   double sum = 0;

   for(int i = shift; i < shift + m_maPeriod; i++)
   {
      sum += (double)iVolume(m_symbol, m_timeframe, i);
   }

   return sum / m_maPeriod;
}

//+------------------------------------------------------------------+
//| Calcul du ratio volume actuel / moyenne                          |
//+------------------------------------------------------------------+
double CVolumeAnalysis::GetVolumeRatio(int shift)
{
   double avgVolume = GetVolumeMA(shift + 1); // Moyenne des barres précédentes
   if(avgVolume == 0) return 0;

   long currentVolume = iVolume(m_symbol, m_timeframe, shift);
   return ((double)currentVolume / avgVolume) * 100.0;
}

//+------------------------------------------------------------------+
//| RÈGLE: Cassure valide UNIQUEMENT si Volume ≥ 150% de la moyenne  |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::IsValidBreakoutVolume(int shift)
{
   double ratio = GetVolumeRatio(shift);
   return (ratio >= m_breakoutThreshold);
}

//+------------------------------------------------------------------+
//| RÈGLE: Cassure idéale si Volume ≥ 200%                           |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::IsIdealBreakoutVolume(int shift)
{
   double ratio = GetVolumeRatio(shift);
   return (ratio >= m_idealThreshold);
}

//+------------------------------------------------------------------+
//| RÈGLE: Accumulation = Prix stable + Volume croissant             |
//| → Alerte "Accumulation détectée"                                  |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::IsAccumulation(int lookback = 10)
{
   if(lookback < 5) lookback = 5;

   // 1. Vérifier que le prix est stable (range)
   double highestHigh = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, lookback, 1));
   double lowestLow = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, lookback, 1));

   double priceRange = highestHigh - lowestLow;
   double avgPrice = (highestHigh + lowestLow) / 2.0;

   // Le range doit être inférieur à 2% du prix moyen pour être considéré comme "stable"
   double rangePercent = (priceRange / avgPrice) * 100.0;
   bool isPriceStable = (rangePercent < 2.0);

   if(!isPriceStable) return false;

   // 2. Vérifier que le volume est croissant
   double volumeStart = 0;
   double volumeEnd = 0;

   // Moyenne du volume début de période
   for(int i = lookback - 3; i < lookback; i++)
   {
      volumeStart += (double)iVolume(m_symbol, m_timeframe, i);
   }
   volumeStart /= 3;

   // Moyenne du volume fin de période
   for(int i = 1; i <= 3; i++)
   {
      volumeEnd += (double)iVolume(m_symbol, m_timeframe, i);
   }
   volumeEnd /= 3;

   bool isVolumeCroissant = (volumeEnd > volumeStart * 1.2); // +20% minimum

   return (isPriceStable && isVolumeCroissant);
}

//+------------------------------------------------------------------+
//| Déterminer l'état du volume                                       |
//+------------------------------------------------------------------+
ENUM_VOLUME_STATE CVolumeAnalysis::GetVolumeState(int shift)
{
   // Vérifier d'abord l'accumulation
   if(IsAccumulation(10))
      return VOLUME_ACCUMULATION;

   double ratio = GetVolumeRatio(shift);

   if(ratio >= m_idealThreshold)
      return VOLUME_VERY_HIGH;
   else if(ratio >= m_breakoutThreshold)
      return VOLUME_HIGH;
   else if(ratio < 80.0)
      return VOLUME_LOW;
   else
      return VOLUME_NORMAL;
}

//+------------------------------------------------------------------+
//| Analyse complète du volume                                        |
//+------------------------------------------------------------------+
SVolumeData CVolumeAnalysis::Analyze(int shift)
{
   SVolumeData data;

   data.currentVolume = iVolume(m_symbol, m_timeframe, shift);
   data.averageVolume = GetVolumeMA(shift + 1);
   data.volumeRatio = GetVolumeRatio(shift);
   data.state = GetVolumeState(shift);
   data.isValidBreakout = IsValidBreakoutVolume(shift);
   data.isAccumulation = IsAccumulation(10);

   return data;
}

//+------------------------------------------------------------------+
//| Confirmer une cassure par le volume                               |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::ConfirmBreakout(int shift)
{
   return IsValidBreakoutVolume(shift);
}

//+------------------------------------------------------------------+
//| Détecter un pic de volume                                         |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::HasVolumeSpike(int shift)
{
   double ratio = GetVolumeRatio(shift);
   return (ratio >= 250.0); // 250% de la moyenne
}

//+------------------------------------------------------------------+
//| Détecter une divergence volume/prix                               |
//| Prix monte mais volume diminue = essoufflement                    |
//+------------------------------------------------------------------+
bool CVolumeAnalysis::IsVolumePriceDivergence(int lookback = 5)
{
   if(lookback < 3) lookback = 3;

   // Direction du prix
   double priceStart = iClose(m_symbol, m_timeframe, lookback);
   double priceEnd = iClose(m_symbol, m_timeframe, 1);
   bool priceUp = (priceEnd > priceStart);
   bool priceDown = (priceEnd < priceStart);

   // Direction du volume
   double volumeStart = 0;
   double volumeEnd = 0;

   for(int i = lookback - 2; i <= lookback; i++)
   {
      volumeStart += (double)iVolume(m_symbol, m_timeframe, i);
   }
   volumeStart /= 3;

   for(int i = 1; i <= 3; i++)
   {
      volumeEnd += (double)iVolume(m_symbol, m_timeframe, i);
   }
   volumeEnd /= 3;

   bool volumeUp = (volumeEnd > volumeStart);
   bool volumeDown = (volumeEnd < volumeStart);

   // Divergence: prix monte et volume baisse (ou inverse)
   if((priceUp && volumeDown) || (priceDown && volumeUp))
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Convertir l'état en string                                        |
//+------------------------------------------------------------------+
string CVolumeAnalysis::VolumeStateToString(ENUM_VOLUME_STATE state)
{
   switch(state)
   {
      case VOLUME_NORMAL:       return "Normal";
      case VOLUME_HIGH:         return "Élevé (≥150%)";
      case VOLUME_VERY_HIGH:    return "Très élevé (≥200%)";
      case VOLUME_LOW:          return "Faible";
      case VOLUME_ACCUMULATION: return "Accumulation";
      default:                  return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Générer une alerte volume                                         |
//+------------------------------------------------------------------+
string CVolumeAnalysis::GetVolumeAlert(int shift)
{
   SVolumeData data = Analyze(shift);

   if(data.isAccumulation)
      return "📊 ALERTE: Accumulation détectée - Prix stable + Volume croissant";

   if(data.state == VOLUME_VERY_HIGH)
      return "📊 Volume idéal pour cassure (≥200%)";

   if(data.state == VOLUME_HIGH)
      return "📊 Volume valide pour cassure (≥150%)";

   if(HasVolumeSpike(shift))
      return "📊 PIC DE VOLUME détecté!";

   if(IsVolumePriceDivergence(5))
      return "📊 Divergence volume/prix - Possible essoufflement";

   return "";
}
//+------------------------------------------------------------------+
