//+------------------------------------------------------------------+
//|                                                Divergences.mqh  |
//|                            CHAPITRE 9 - DIVERGENCES             |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

#include "CandleAnalysis.mqh"
#include "MarketStructure.mqh"

//+------------------------------------------------------------------+
//| Énumération des types de divergence                              |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
{
   DIV_NONE = 0,
   DIV_BULLISH_REGULAR,     // Divergence haussière régulière
   DIV_BEARISH_REGULAR,     // Divergence baissière régulière
   DIV_BULLISH_HIDDEN,      // Divergence haussière cachée
   DIV_BEARISH_HIDDEN       // Divergence baissière cachée
};

//+------------------------------------------------------------------+
//| Structure d'une divergence détectée                              |
//+------------------------------------------------------------------+
struct SDivergence
{
   ENUM_DIVERGENCE_TYPE  type;
   double                price1;          // Premier point prix
   double                price2;          // Deuxième point prix
   double                indicator1;      // Premier point indicateur
   double                indicator2;      // Deuxième point indicateur
   int                   bar1;            // Barre du premier point
   int                   bar2;            // Barre du deuxième point
   bool                  isConfirmed;     // Confirmé par cassure structure ou pattern bougie
   string                confirmationType; // Type de confirmation
};

//+------------------------------------------------------------------+
//| Classe de détection des divergences                               |
//+------------------------------------------------------------------+
class CDivergences
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_rsiHandle;
   double            m_rsiBuffer[];
   int               m_lookback;
   int               m_minBars;        // Écart minimum entre les points

   CCandleAnalysis   *m_candleAnalysis;
   CMarketStructure  *m_marketStructure;

   // Méthodes privées
   bool              LoadRSIBuffer(int count);
   void              FindSwingLows(double &prices[], double &rsiValues[], int &bars[], int count);
   void              FindSwingHighs(double &prices[], double &rsiValues[], int &bars[], int count);

public:
   CDivergences();
   ~CDivergences();

   // Initialisation
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int lookback, int minBars);
   void              SetAnalyzers(CCandleAnalysis *candle, CMarketStructure *structure);

   // ============ RÈGLE CHAPITRE 9 ============
   // Divergence haussière: Prix fait LL, RSI fait HL
   bool              DetectBullishDivergence(SDivergence &div);

   // Divergence baissière: Prix fait HH, RSI fait LH
   bool              DetectBearishDivergence(SDivergence &div);

   // Divergences cachées (continuation)
   bool              DetectHiddenBullishDivergence(SDivergence &div);
   bool              DetectHiddenBearishDivergence(SDivergence &div);

   // Détection automatique
   SDivergence       DetectDivergence();
   bool              HasDivergence(SDivergence &div);

   // RÈGLE: PAS d'alerte sans confirmation
   // - Cassure de structure OU
   // - Pattern de bougie (Chapitre 1)
   bool              IsConfirmed(SDivergence &div);
   bool              HasStructureBreakConfirmation(SDivergence &div);
   bool              HasCandlePatternConfirmation(SDivergence &div);

   // Utilitaires
   string            DivergenceTypeToString(ENUM_DIVERGENCE_TYPE type);
   string            GetDivergenceAlert(SDivergence &div);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CDivergences::CDivergences()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_rsiHandle = INVALID_HANDLE;
   m_lookback = 50;
   m_minBars = 5;
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
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CDivergences::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   // Créer handle RSI
   m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE)
   {
      Print("Erreur création handle RSI pour divergences");
      return false;
   }

   ArraySetAsSeries(m_rsiBuffer, true);

   return true;
}

//+------------------------------------------------------------------+
//| Configurer les paramètres                                         |
//+------------------------------------------------------------------+
void CDivergences::SetParameters(int lookback, int minBars)
{
   m_lookback = lookback;
   m_minBars = minBars;
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
//| Charger le buffer RSI                                             |
//+------------------------------------------------------------------+
bool CDivergences::LoadRSIBuffer(int count)
{
   if(m_rsiHandle == INVALID_HANDLE) return false;
   return (CopyBuffer(m_rsiHandle, 0, 0, count, m_rsiBuffer) >= count);
}

//+------------------------------------------------------------------+
//| Trouver les swing lows                                            |
//+------------------------------------------------------------------+
void CDivergences::FindSwingLows(double &prices[], double &rsiValues[], int &bars[], int count)
{
   ArrayResize(prices, 0);
   ArrayResize(rsiValues, 0);
   ArrayResize(bars, 0);

   if(!LoadRSIBuffer(m_lookback)) return;

   for(int i = 2; i < m_lookback - 2; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);

      // Vérifier si c'est un swing low
      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i - 2) &&
         low < iLow(m_symbol, m_timeframe, i + 1) &&
         low < iLow(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(prices);
         ArrayResize(prices, size + 1);
         ArrayResize(rsiValues, size + 1);
         ArrayResize(bars, size + 1);

         prices[size] = low;
         rsiValues[size] = m_rsiBuffer[i];
         bars[size] = i;

         if(ArraySize(prices) >= count) break;
      }
   }
}

//+------------------------------------------------------------------+
//| Trouver les swing highs                                           |
//+------------------------------------------------------------------+
void CDivergences::FindSwingHighs(double &prices[], double &rsiValues[], int &bars[], int count)
{
   ArrayResize(prices, 0);
   ArrayResize(rsiValues, 0);
   ArrayResize(bars, 0);

   if(!LoadRSIBuffer(m_lookback)) return;

   for(int i = 2; i < m_lookback - 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);

      // Vérifier si c'est un swing high
      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i - 2) &&
         high > iHigh(m_symbol, m_timeframe, i + 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(prices);
         ArrayResize(prices, size + 1);
         ArrayResize(rsiValues, size + 1);
         ArrayResize(bars, size + 1);

         prices[size] = high;
         rsiValues[size] = m_rsiBuffer[i];
         bars[size] = i;

         if(ArraySize(prices) >= count) break;
      }
   }
}

//+------------------------------------------------------------------+
//| RÈGLE: Divergence haussière                                       |
//| Prix fait LL (Lower Low), RSI fait HL (Higher Low)               |
//+------------------------------------------------------------------+
bool CDivergences::DetectBullishDivergence(SDivergence &div)
{
   double prices[], rsiValues[];
   int bars[];

   FindSwingLows(prices, rsiValues, bars, 3);

   if(ArraySize(prices) < 2) return false;

   // Vérifier l'écart minimum entre les points
   if(bars[0] - bars[1] < m_minBars) return false;

   // RÈGLE: Prix fait LL (nouveau bas plus bas)
   bool priceMakesLL = (prices[0] < prices[1]);

   // RÈGLE: RSI fait HL (nouveau bas plus haut)
   bool rsiMakesHL = (rsiValues[0] > rsiValues[1]);

   if(priceMakesLL && rsiMakesHL)
   {
      div.type = DIV_BULLISH_REGULAR;
      div.price1 = prices[1];
      div.price2 = prices[0];
      div.indicator1 = rsiValues[1];
      div.indicator2 = rsiValues[0];
      div.bar1 = bars[1];
      div.bar2 = bars[0];
      div.isConfirmed = IsConfirmed(div);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Divergence baissière                                       |
//| Prix fait HH (Higher High), RSI fait LH (Lower High)             |
//+------------------------------------------------------------------+
bool CDivergences::DetectBearishDivergence(SDivergence &div)
{
   double prices[], rsiValues[];
   int bars[];

   FindSwingHighs(prices, rsiValues, bars, 3);

   if(ArraySize(prices) < 2) return false;

   // Vérifier l'écart minimum entre les points
   if(bars[0] - bars[1] < m_minBars) return false;

   // RÈGLE: Prix fait HH (nouveau haut plus haut)
   bool priceMakesHH = (prices[0] > prices[1]);

   // RÈGLE: RSI fait LH (nouveau haut plus bas)
   bool rsiMakesLH = (rsiValues[0] < rsiValues[1]);

   if(priceMakesHH && rsiMakesLH)
   {
      div.type = DIV_BEARISH_REGULAR;
      div.price1 = prices[1];
      div.price2 = prices[0];
      div.indicator1 = rsiValues[1];
      div.indicator2 = rsiValues[0];
      div.bar1 = bars[1];
      div.bar2 = bars[0];
      div.isConfirmed = IsConfirmed(div);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Divergence haussière cachée (continuation haussière)              |
//| Prix fait HL, RSI fait LL                                         |
//+------------------------------------------------------------------+
bool CDivergences::DetectHiddenBullishDivergence(SDivergence &div)
{
   double prices[], rsiValues[];
   int bars[];

   FindSwingLows(prices, rsiValues, bars, 3);

   if(ArraySize(prices) < 2) return false;
   if(bars[0] - bars[1] < m_minBars) return false;

   // Prix fait HL (Higher Low)
   bool priceMakesHL = (prices[0] > prices[1]);

   // RSI fait LL (Lower Low)
   bool rsiMakesLL = (rsiValues[0] < rsiValues[1]);

   if(priceMakesHL && rsiMakesLL)
   {
      div.type = DIV_BULLISH_HIDDEN;
      div.price1 = prices[1];
      div.price2 = prices[0];
      div.indicator1 = rsiValues[1];
      div.indicator2 = rsiValues[0];
      div.bar1 = bars[1];
      div.bar2 = bars[0];
      div.isConfirmed = IsConfirmed(div);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Divergence baissière cachée (continuation baissière)              |
//| Prix fait LH, RSI fait HH                                         |
//+------------------------------------------------------------------+
bool CDivergences::DetectHiddenBearishDivergence(SDivergence &div)
{
   double prices[], rsiValues[];
   int bars[];

   FindSwingHighs(prices, rsiValues, bars, 3);

   if(ArraySize(prices) < 2) return false;
   if(bars[0] - bars[1] < m_minBars) return false;

   // Prix fait LH (Lower High)
   bool priceMakesLH = (prices[0] < prices[1]);

   // RSI fait HH (Higher High)
   bool rsiMakesHH = (rsiValues[0] > rsiValues[1]);

   if(priceMakesLH && rsiMakesHH)
   {
      div.type = DIV_BEARISH_HIDDEN;
      div.price1 = prices[1];
      div.price2 = prices[0];
      div.indicator1 = rsiValues[1];
      div.indicator2 = rsiValues[0];
      div.bar1 = bars[1];
      div.bar2 = bars[0];
      div.isConfirmed = IsConfirmed(div);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter toute divergence                                         |
//+------------------------------------------------------------------+
SDivergence CDivergences::DetectDivergence()
{
   SDivergence div;
   div.type = DIV_NONE;
   div.isConfirmed = false;

   // Priorité aux divergences régulières
   if(DetectBullishDivergence(div)) return div;
   if(DetectBearishDivergence(div)) return div;

   // Puis les divergences cachées
   if(DetectHiddenBullishDivergence(div)) return div;
   if(DetectHiddenBearishDivergence(div)) return div;

   return div;
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a une divergence                                  |
//+------------------------------------------------------------------+
bool CDivergences::HasDivergence(SDivergence &div)
{
   div = DetectDivergence();
   return (div.type != DIV_NONE);
}

//+------------------------------------------------------------------+
//| RÈGLE: PAS d'alerte sans confirmation                             |
//| - Cassure de structure OU                                         |
//| - Pattern de bougie (Chapitre 1)                                  |
//+------------------------------------------------------------------+
bool CDivergences::IsConfirmed(SDivergence &div)
{
   bool hasStructureBreak = HasStructureBreakConfirmation(div);
   bool hasCandlePattern = HasCandlePatternConfirmation(div);

   if(hasStructureBreak)
   {
      div.confirmationType = "Cassure de structure";
      return true;
   }

   if(hasCandlePattern)
   {
      div.confirmationType = "Pattern de bougie";
      return true;
   }

   div.confirmationType = "";
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation par cassure de structure                 |
//+------------------------------------------------------------------+
bool CDivergences::HasStructureBreakConfirmation(SDivergence &div)
{
   if(m_marketStructure == NULL) return false;

   // Pour une divergence haussière, on attend un BOS haussier
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      return m_marketStructure->IsBullishBOS(1);
   }

   // Pour une divergence baissière, on attend un BOS baissier
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      return m_marketStructure->IsBearishBOS(1);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation par pattern de bougie (Chapitre 1)       |
//+------------------------------------------------------------------+
bool CDivergences::HasCandlePatternConfirmation(SDivergence &div)
{
   if(m_candleAnalysis == NULL) return false;

   // Pour une divergence haussière, on attend une confirmation haussière
   if(div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN)
   {
      return m_candleAnalysis->HasBullishConfirmation(1);
   }

   // Pour une divergence baissière, on attend une confirmation baissière
   if(div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN)
   {
      return m_candleAnalysis->HasBearishConfirmation(1);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Convertir le type en string                                       |
//+------------------------------------------------------------------+
string CDivergences::DivergenceTypeToString(ENUM_DIVERGENCE_TYPE type)
{
   switch(type)
   {
      case DIV_NONE:             return "Aucune";
      case DIV_BULLISH_REGULAR:  return "Divergence Haussière (Prix LL / RSI HL)";
      case DIV_BEARISH_REGULAR:  return "Divergence Baissière (Prix HH / RSI LH)";
      case DIV_BULLISH_HIDDEN:   return "Divergence Cachée Haussière";
      case DIV_BEARISH_HIDDEN:   return "Divergence Cachée Baissière";
      default:                   return "Inconnue";
   }
}

//+------------------------------------------------------------------+
//| Générer une alerte divergence                                     |
//| RÈGLE: PAS d'alerte sans confirmation                             |
//+------------------------------------------------------------------+
string CDivergences::GetDivergenceAlert(SDivergence &div)
{
   // RÈGLE: Ne pas alerter si non confirmé
   if(!div.isConfirmed)
      return "";

   string alert = "";

   switch(div.type)
   {
      case DIV_BULLISH_REGULAR:
         alert = "📊 DIVERGENCE HAUSSIÈRE confirmée!\n" +
                 "Prix: LL (" + DoubleToString(div.price1, 5) + " → " + DoubleToString(div.price2, 5) + ")\n" +
                 "RSI: HL (" + DoubleToString(div.indicator1, 1) + " → " + DoubleToString(div.indicator2, 1) + ")\n" +
                 "Confirmation: " + div.confirmationType;
         break;

      case DIV_BEARISH_REGULAR:
         alert = "📊 DIVERGENCE BAISSIÈRE confirmée!\n" +
                 "Prix: HH (" + DoubleToString(div.price1, 5) + " → " + DoubleToString(div.price2, 5) + ")\n" +
                 "RSI: LH (" + DoubleToString(div.indicator1, 1) + " → " + DoubleToString(div.indicator2, 1) + ")\n" +
                 "Confirmation: " + div.confirmationType;
         break;

      case DIV_BULLISH_HIDDEN:
         alert = "📊 DIVERGENCE CACHÉE HAUSSIÈRE (continuation)\n" +
                 "Confirmation: " + div.confirmationType;
         break;

      case DIV_BEARISH_HIDDEN:
         alert = "📊 DIVERGENCE CACHÉE BAISSIÈRE (continuation)\n" +
                 "Confirmation: " + div.confirmationType;
         break;

      default:
         break;
   }

   return alert;
}
//+------------------------------------------------------------------+
