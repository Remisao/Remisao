//+------------------------------------------------------------------+
//|                                                  SmartMoney.mqh |
//|                        CHAPITRE 13 - SMART MONEY CONCEPTS       |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des types d'Order Block                              |
//+------------------------------------------------------------------+
enum ENUM_OB_TYPE
{
   OB_NONE = 0,
   OB_BULLISH,              // Order Block haussier (demande)
   OB_BEARISH               // Order Block baissier (offre)
};

//+------------------------------------------------------------------+
//| Énumération des types de structure break                         |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_BREAK
{
   SB_NONE = 0,
   SB_BOS_BULLISH,          // Break of Structure haussier
   SB_BOS_BEARISH,          // Break of Structure baissier
   SB_CHOCH_BULLISH,        // Change of Character haussier
   SB_CHOCH_BEARISH         // Change of Character baissier
};

//+------------------------------------------------------------------+
//| Structure d'un Order Block                                       |
//+------------------------------------------------------------------+
struct SOrderBlock
{
   ENUM_OB_TYPE      type;
   double            high;
   double            low;
   double            midPoint;
   datetime          time;
   int               barIndex;
   bool              isMitigated;     // A été testé/invalidé
   bool              isValid;
};

//+------------------------------------------------------------------+
//| Structure d'un Fair Value Gap                                    |
//+------------------------------------------------------------------+
struct SFairValueGap
{
   bool              isBullish;       // FVG haussier ou baissier
   double            high;            // Haut du gap
   double            low;             // Bas du gap
   double            midPoint;
   datetime          time;
   int               barIndex;
   bool              isFilled;        // Le gap a été comblé
   bool              isValid;
};

//+------------------------------------------------------------------+
//| Structure de liquidité                                           |
//+------------------------------------------------------------------+
struct SLiquidity
{
   double            level;           // Niveau de liquidité
   bool              isHighLiquidity; // Equal highs ou equal lows
   int               touchCount;      // Nombre de touches
   datetime          lastTouch;
   bool              isSwept;         // Liquidité prise
};

//+------------------------------------------------------------------+
//| Classe Smart Money Concepts                                       |
//+------------------------------------------------------------------+
class CSmartMoney
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   double            m_tolerance;     // Tolérance pour equal H/L (en %)

   SOrderBlock       m_orderBlocks[];
   SFairValueGap     m_fvgs[];
   SLiquidity        m_liquidityLevels[];

   // Méthodes privées
   double            GetTolerance();
   bool              ArePricesEqual(double price1, double price2);

public:
   CSmartMoney();
   ~CSmartMoney();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int lookback, double tolerancePct);

   // ============ RÈGLE CHAPITRE 13: BOS / CHoCH ============
   ENUM_STRUCTURE_BREAK DetectStructureBreak(int shift = 1);
   bool              IsBOS(int shift, bool &isBullish);
   bool              IsCHoCH(int shift, bool &isBullish);

   // ============ RÈGLE: ORDER BLOCKS ============
   void              DetectOrderBlocks();
   bool              DetectBullishOB(int shift, SOrderBlock &ob);
   bool              DetectBearishOB(int shift, SOrderBlock &ob);
   int               GetOrderBlockCount();
   SOrderBlock       GetOrderBlock(int index);
   SOrderBlock       GetNearestBullishOB(double price);
   SOrderBlock       GetNearestBearishOB(double price);
   bool              IsPriceInOB(double price, SOrderBlock &ob);

   // ============ RÈGLE: FAIR VALUE GAPS ============
   void              DetectFVGs();
   bool              DetectBullishFVG(int shift, SFairValueGap &fvg);
   bool              DetectBearishFVG(int shift, SFairValueGap &fvg);
   int               GetFVGCount();
   SFairValueGap     GetFVG(int index);
   SFairValueGap     GetNearestBullishFVG(double price);
   SFairValueGap     GetNearestBearishFVG(double price);
   bool              IsPriceInFVG(double price, SFairValueGap &fvg);

   // ============ RÈGLE: EQUAL HIGHS / EQUAL LOWS (Liquidité) ============
   void              DetectLiquidity();
   bool              DetectEqualHighs(SLiquidity &liq);
   bool              DetectEqualLows(SLiquidity &liq);
   int               GetLiquidityCount();
   SLiquidity        GetLiquidity(int index);
   bool              IsLiquiditySwept(double level);

   // Analyse complète
   void              AnalyzeAll();

   // Zones de confluence SMC
   bool              HasSMCConfluence(double price, bool lookingForBuy);

   // Utilitaires
   string            StructureBreakToString(ENUM_STRUCTURE_BREAK sb);
   string            OrderBlockToString(SOrderBlock &ob);
   string            FVGToString(SFairValueGap &fvg);
   string            GetSMCAlert();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CSmartMoney::CSmartMoney()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookback = 100;
   m_tolerance = 0.1; // 0.1%
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CSmartMoney::~CSmartMoney()
{
   ArrayFree(m_orderBlocks);
   ArrayFree(m_fvgs);
   ArrayFree(m_liquidityLevels);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CSmartMoney::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CSmartMoney::SetParameters(int lookback, double tolerancePct)
{
   m_lookback = lookback;
   m_tolerance = tolerancePct;
}

//+------------------------------------------------------------------+
//| Obtenir la tolérance en valeur de prix                           |
//+------------------------------------------------------------------+
double CSmartMoney::GetTolerance()
{
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return price * (m_tolerance / 100.0);
}

//+------------------------------------------------------------------+
//| Vérifier si deux prix sont égaux (dans la tolérance)             |
//+------------------------------------------------------------------+
bool CSmartMoney::ArePricesEqual(double price1, double price2)
{
   return (MathAbs(price1 - price2) <= GetTolerance());
}

//+------------------------------------------------------------------+
//| RÈGLE: Détecter BOS / CHoCH                                       |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_BREAK CSmartMoney::DetectStructureBreak(int shift = 1)
{
   // Trouver les swing highs et lows précédents
   double lastSwingHigh = 0;
   double lastSwingLow = DBL_MAX;
   double prevSwingHigh = 0;
   double prevSwingLow = DBL_MAX;

   int highCount = 0, lowCount = 0;

   for(int i = shift + 1; i < m_lookback; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);

      // Swing High
      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 1))
      {
         if(highCount == 0) lastSwingHigh = high;
         else if(highCount == 1) prevSwingHigh = high;
         highCount++;
      }

      // Swing Low
      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i + 1))
      {
         if(lowCount == 0) lastSwingLow = low;
         else if(lowCount == 1) prevSwingLow = low;
         lowCount++;
      }

      if(highCount >= 2 && lowCount >= 2) break;
   }

   double currentClose = iClose(m_symbol, m_timeframe, shift);

   // BOS Haussier: le prix casse le dernier swing high
   if(currentClose > lastSwingHigh)
   {
      // Si le swing high précédent était plus haut (tendance haussière), c'est un BOS
      if(prevSwingHigh > 0 && lastSwingHigh > prevSwingHigh)
         return SB_BOS_BULLISH;
      // Sinon c'est un CHoCH (changement de structure)
      else
         return SB_CHOCH_BULLISH;
   }

   // BOS Baissier: le prix casse le dernier swing low
   if(currentClose < lastSwingLow)
   {
      // Si le swing low précédent était plus bas (tendance baissière), c'est un BOS
      if(prevSwingLow < DBL_MAX && lastSwingLow < prevSwingLow)
         return SB_BOS_BEARISH;
      // Sinon c'est un CHoCH
      else
         return SB_CHOCH_BEARISH;
   }

   return SB_NONE;
}

//+------------------------------------------------------------------+
//| Détecter un BOS                                                   |
//+------------------------------------------------------------------+
bool CSmartMoney::IsBOS(int shift, bool &isBullish)
{
   ENUM_STRUCTURE_BREAK sb = DetectStructureBreak(shift);

   if(sb == SB_BOS_BULLISH)
   {
      isBullish = true;
      return true;
   }
   if(sb == SB_BOS_BEARISH)
   {
      isBullish = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter un CHoCH                                                 |
//+------------------------------------------------------------------+
bool CSmartMoney::IsCHoCH(int shift, bool &isBullish)
{
   ENUM_STRUCTURE_BREAK sb = DetectStructureBreak(shift);

   if(sb == SB_CHOCH_BULLISH)
   {
      isBullish = true;
      return true;
   }
   if(sb == SB_CHOCH_BEARISH)
   {
      isBullish = false;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Détecter les Order Blocks                                  |
//+------------------------------------------------------------------+
void CSmartMoney::DetectOrderBlocks()
{
   ArrayFree(m_orderBlocks);
   ArrayResize(m_orderBlocks, 0);

   for(int i = 2; i < m_lookback - 1; i++)
   {
      SOrderBlock ob;

      if(DetectBullishOB(i, ob))
      {
         int size = ArraySize(m_orderBlocks);
         ArrayResize(m_orderBlocks, size + 1);
         m_orderBlocks[size] = ob;
      }

      if(DetectBearishOB(i, ob))
      {
         int size = ArraySize(m_orderBlocks);
         ArrayResize(m_orderBlocks, size + 1);
         m_orderBlocks[size] = ob;
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter un Order Block haussier                                  |
//| Dernière bougie baissière avant un mouvement haussier impulsif   |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBullishOB(int shift, SOrderBlock &ob)
{
   // Bougie actuelle
   double open = iOpen(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);

   // Bougie suivante (plus récente)
   double nextOpen = iOpen(m_symbol, m_timeframe, shift - 1);
   double nextClose = iClose(m_symbol, m_timeframe, shift - 1);
   double nextHigh = iHigh(m_symbol, m_timeframe, shift - 1);

   // Bougie précédente
   double prevClose = iClose(m_symbol, m_timeframe, shift + 1);

   // La bougie doit être baissière
   if(close >= open) return false;

   // La bougie suivante doit être fortement haussière
   double nextBody = MathAbs(nextClose - nextOpen);
   double nextRange = nextHigh - iLow(m_symbol, m_timeframe, shift - 1);
   if(nextClose <= nextOpen || nextBody < nextRange * 0.6) return false;

   // La bougie suivante doit clôturer au-dessus du high de l'OB
   if(nextClose <= high) return false;

   // Créer l'OB
   ob.type = OB_BULLISH;
   ob.high = high;
   ob.low = low;
   ob.midPoint = (high + low) / 2.0;
   ob.time = iTime(m_symbol, m_timeframe, shift);
   ob.barIndex = shift;
   ob.isMitigated = false;
   ob.isValid = true;

   return true;
}

//+------------------------------------------------------------------+
//| Détecter un Order Block baissier                                  |
//| Dernière bougie haussière avant un mouvement baissier impulsif   |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBearishOB(int shift, SOrderBlock &ob)
{
   double open = iOpen(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);

   double nextOpen = iOpen(m_symbol, m_timeframe, shift - 1);
   double nextClose = iClose(m_symbol, m_timeframe, shift - 1);
   double nextLow = iLow(m_symbol, m_timeframe, shift - 1);

   // La bougie doit être haussière
   if(close <= open) return false;

   // La bougie suivante doit être fortement baissière
   double nextBody = MathAbs(nextClose - nextOpen);
   double nextRange = iHigh(m_symbol, m_timeframe, shift - 1) - nextLow;
   if(nextClose >= nextOpen || nextBody < nextRange * 0.6) return false;

   // La bougie suivante doit clôturer en-dessous du low de l'OB
   if(nextClose >= low) return false;

   // Créer l'OB
   ob.type = OB_BEARISH;
   ob.high = high;
   ob.low = low;
   ob.midPoint = (high + low) / 2.0;
   ob.time = iTime(m_symbol, m_timeframe, shift);
   ob.barIndex = shift;
   ob.isMitigated = false;
   ob.isValid = true;

   return true;
}

//+------------------------------------------------------------------+
//| Getters Order Block                                               |
//+------------------------------------------------------------------+
int CSmartMoney::GetOrderBlockCount()
{
   return ArraySize(m_orderBlocks);
}

SOrderBlock CSmartMoney::GetOrderBlock(int index)
{
   SOrderBlock empty;
   empty.isValid = false;
   if(index < 0 || index >= ArraySize(m_orderBlocks)) return empty;
   return m_orderBlocks[index];
}

SOrderBlock CSmartMoney::GetNearestBullishOB(double price)
{
   SOrderBlock nearest;
   nearest.isValid = false;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BULLISH &&
         !m_orderBlocks[i].isMitigated &&
         m_orderBlocks[i].high < price)
      {
         double distance = price - m_orderBlocks[i].high;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_orderBlocks[i];
         }
      }
   }

   return nearest;
}

SOrderBlock CSmartMoney::GetNearestBearishOB(double price)
{
   SOrderBlock nearest;
   nearest.isValid = false;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BEARISH &&
         !m_orderBlocks[i].isMitigated &&
         m_orderBlocks[i].low > price)
      {
         double distance = m_orderBlocks[i].low - price;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_orderBlocks[i];
         }
      }
   }

   return nearest;
}

bool CSmartMoney::IsPriceInOB(double price, SOrderBlock &ob)
{
   return (price >= ob.low && price <= ob.high);
}

//+------------------------------------------------------------------+
//| RÈGLE: Détecter les Fair Value Gaps                               |
//+------------------------------------------------------------------+
void CSmartMoney::DetectFVGs()
{
   ArrayFree(m_fvgs);
   ArrayResize(m_fvgs, 0);

   for(int i = 2; i < m_lookback; i++)
   {
      SFairValueGap fvg;

      if(DetectBullishFVG(i, fvg))
      {
         int size = ArraySize(m_fvgs);
         ArrayResize(m_fvgs, size + 1);
         m_fvgs[size] = fvg;
      }

      if(DetectBearishFVG(i, fvg))
      {
         int size = ArraySize(m_fvgs);
         ArrayResize(m_fvgs, size + 1);
         m_fvgs[size] = fvg;
      }
   }
}

//+------------------------------------------------------------------+
//| FVG Haussier: Gap entre le high de bougie 3 et le low de bougie 1|
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBullishFVG(int shift, SFairValueGap &fvg)
{
   // Bougie 1 (la plus récente)
   double low1 = iLow(m_symbol, m_timeframe, shift - 1);

   // Bougie 2 (du milieu - doit être haussière impulsive)
   double open2 = iOpen(m_symbol, m_timeframe, shift);
   double close2 = iClose(m_symbol, m_timeframe, shift);

   // Bougie 3 (la plus ancienne)
   double high3 = iHigh(m_symbol, m_timeframe, shift + 1);

   // Vérifier qu'il y a un gap (FVG)
   if(low1 > high3)
   {
      // La bougie du milieu doit être haussière
      if(close2 <= open2) return false;

      fvg.isBullish = true;
      fvg.high = low1;
      fvg.low = high3;
      fvg.midPoint = (low1 + high3) / 2.0;
      fvg.time = iTime(m_symbol, m_timeframe, shift);
      fvg.barIndex = shift;
      fvg.isFilled = false;
      fvg.isValid = true;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| FVG Baissier: Gap entre le low de bougie 3 et le high de bougie 1|
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBearishFVG(int shift, SFairValueGap &fvg)
{
   double high1 = iHigh(m_symbol, m_timeframe, shift - 1);
   double open2 = iOpen(m_symbol, m_timeframe, shift);
   double close2 = iClose(m_symbol, m_timeframe, shift);
   double low3 = iLow(m_symbol, m_timeframe, shift + 1);

   if(high1 < low3)
   {
      if(close2 >= open2) return false;

      fvg.isBullish = false;
      fvg.high = low3;
      fvg.low = high1;
      fvg.midPoint = (low3 + high1) / 2.0;
      fvg.time = iTime(m_symbol, m_timeframe, shift);
      fvg.barIndex = shift;
      fvg.isFilled = false;
      fvg.isValid = true;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Getters FVG                                                       |
//+------------------------------------------------------------------+
int CSmartMoney::GetFVGCount()
{
   return ArraySize(m_fvgs);
}

SFairValueGap CSmartMoney::GetFVG(int index)
{
   SFairValueGap empty;
   empty.isValid = false;
   if(index < 0 || index >= ArraySize(m_fvgs)) return empty;
   return m_fvgs[index];
}

SFairValueGap CSmartMoney::GetNearestBullishFVG(double price)
{
   SFairValueGap nearest;
   nearest.isValid = false;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(m_fvgs[i].isBullish && !m_fvgs[i].isFilled && m_fvgs[i].high < price)
      {
         double distance = price - m_fvgs[i].high;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_fvgs[i];
         }
      }
   }

   return nearest;
}

SFairValueGap CSmartMoney::GetNearestBearishFVG(double price)
{
   SFairValueGap nearest;
   nearest.isValid = false;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(!m_fvgs[i].isBullish && !m_fvgs[i].isFilled && m_fvgs[i].low > price)
      {
         double distance = m_fvgs[i].low - price;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_fvgs[i];
         }
      }
   }

   return nearest;
}

bool CSmartMoney::IsPriceInFVG(double price, SFairValueGap &fvg)
{
   return (price >= fvg.low && price <= fvg.high);
}

//+------------------------------------------------------------------+
//| RÈGLE: Détecter Equal Highs / Equal Lows (Liquidité)              |
//+------------------------------------------------------------------+
void CSmartMoney::DetectLiquidity()
{
   ArrayFree(m_liquidityLevels);
   ArrayResize(m_liquidityLevels, 0);

   SLiquidity liq;

   if(DetectEqualHighs(liq))
   {
      int size = ArraySize(m_liquidityLevels);
      ArrayResize(m_liquidityLevels, size + 1);
      m_liquidityLevels[size] = liq;
   }

   if(DetectEqualLows(liq))
   {
      int size = ArraySize(m_liquidityLevels);
      ArrayResize(m_liquidityLevels, size + 1);
      m_liquidityLevels[size] = liq;
   }
}

//+------------------------------------------------------------------+
//| Détecter Equal Highs (liquidité au-dessus)                        |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectEqualHighs(SLiquidity &liq)
{
   // Collecter les swing highs
   double highs[];
   int bars[];
   ArrayResize(highs, 0);
   ArrayResize(bars, 0);

   for(int i = 2; i < m_lookback - 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);

      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(highs);
         ArrayResize(highs, size + 1);
         ArrayResize(bars, size + 1);
         highs[size] = high;
         bars[size] = i;
      }
   }

   // Chercher des highs égaux
   for(int i = 0; i < ArraySize(highs) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(highs); j++)
      {
         if(ArePricesEqual(highs[i], highs[j]))
         {
            liq.level = (highs[i] + highs[j]) / 2.0;
            liq.isHighLiquidity = true;
            liq.touchCount = 2;
            liq.lastTouch = iTime(m_symbol, m_timeframe, bars[i]);
            liq.isSwept = false;

            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter Equal Lows (liquidité en-dessous)                        |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectEqualLows(SLiquidity &liq)
{
   double lows[];
   int bars[];
   ArrayResize(lows, 0);
   ArrayResize(bars, 0);

   for(int i = 2; i < m_lookback - 2; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);

      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(lows);
         ArrayResize(lows, size + 1);
         ArrayResize(bars, size + 1);
         lows[size] = low;
         bars[size] = i;
      }
   }

   for(int i = 0; i < ArraySize(lows) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(lows); j++)
      {
         if(ArePricesEqual(lows[i], lows[j]))
         {
            liq.level = (lows[i] + lows[j]) / 2.0;
            liq.isHighLiquidity = false;
            liq.touchCount = 2;
            liq.lastTouch = iTime(m_symbol, m_timeframe, bars[i]);
            liq.isSwept = false;

            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Getters Liquidité                                                 |
//+------------------------------------------------------------------+
int CSmartMoney::GetLiquidityCount()
{
   return ArraySize(m_liquidityLevels);
}

SLiquidity CSmartMoney::GetLiquidity(int index)
{
   SLiquidity empty;
   empty.level = 0;
   empty.isHighLiquidity = false;
   empty.touchCount = 0;
   empty.lastTouch = 0;
   empty.isSwept = false;
   if(index < 0 || index >= ArraySize(m_liquidityLevels)) return empty;
   return m_liquidityLevels[index];
}

bool CSmartMoney::IsLiquiditySwept(double level)
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return (currentPrice > level || currentPrice < level);
}

//+------------------------------------------------------------------+
//| Analyse complète SMC                                              |
//+------------------------------------------------------------------+
void CSmartMoney::AnalyzeAll()
{
   DetectOrderBlocks();
   DetectFVGs();
   DetectLiquidity();
}

//+------------------------------------------------------------------+
//| Vérifier une confluence SMC                                       |
//+------------------------------------------------------------------+
bool CSmartMoney::HasSMCConfluence(double price, bool lookingForBuy)
{
   if(lookingForBuy)
   {
      // Chercher OB haussier ou FVG haussier
      SOrderBlock ob = GetNearestBullishOB(price);
      if(ob.isValid && IsPriceInOB(price, ob))
         return true;

      SFairValueGap fvg = GetNearestBullishFVG(price);
      if(fvg.isValid && IsPriceInFVG(price, fvg))
         return true;
   }
   else
   {
      // Chercher OB baissier ou FVG baissier
      SOrderBlock ob = GetNearestBearishOB(price);
      if(ob.isValid && IsPriceInOB(price, ob))
         return true;

      SFairValueGap fvg = GetNearestBearishFVG(price);
      if(fvg.isValid && IsPriceInFVG(price, fvg))
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Convertir le type de structure break en string                    |
//+------------------------------------------------------------------+
string CSmartMoney::StructureBreakToString(ENUM_STRUCTURE_BREAK sb)
{
   switch(sb)
   {
      case SB_NONE:          return "Aucun";
      case SB_BOS_BULLISH:   return "BOS Haussier";
      case SB_BOS_BEARISH:   return "BOS Baissier";
      case SB_CHOCH_BULLISH: return "CHoCH Haussier";
      case SB_CHOCH_BEARISH: return "CHoCH Baissier";
      default:               return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir un OB en string                                         |
//+------------------------------------------------------------------+
string CSmartMoney::OrderBlockToString(SOrderBlock &ob)
{
   if(!ob.isValid) return "OB invalide";

   string type = (ob.type == OB_BULLISH) ? "HAUSSIER" : "BAISSIER";
   return "OB " + type + ": " +
          DoubleToString(ob.low, 5) + " - " + DoubleToString(ob.high, 5);
}

//+------------------------------------------------------------------+
//| Convertir un FVG en string                                        |
//+------------------------------------------------------------------+
string CSmartMoney::FVGToString(SFairValueGap &fvg)
{
   if(!fvg.isValid) return "FVG invalide";

   string type = fvg.isBullish ? "HAUSSIER" : "BAISSIER";
   return "FVG " + type + ": " +
          DoubleToString(fvg.low, 5) + " - " + DoubleToString(fvg.high, 5);
}

//+------------------------------------------------------------------+
//| Générer une alerte SMC                                            |
//+------------------------------------------------------------------+
string CSmartMoney::GetSMCAlert()
{
   string alert = "";

   // Vérifier BOS / CHoCH
   ENUM_STRUCTURE_BREAK sb = DetectStructureBreak(1);

   if(sb == SB_BOS_BULLISH || sb == SB_CHOCH_BULLISH)
   {
      alert = "📈 SMC: " + StructureBreakToString(sb) + " détecté!\n";
   }
   else if(sb == SB_BOS_BEARISH || sb == SB_CHOCH_BEARISH)
   {
      alert = "📉 SMC: " + StructureBreakToString(sb) + " détecté!\n";
   }

   // Ajouter info sur les OB proches
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   SOrderBlock obBull = GetNearestBullishOB(price);
   SOrderBlock obBear = GetNearestBearishOB(price);

   if(obBull.isValid)
      alert += "Zone de demande (OB): " + DoubleToString(obBull.low, 5) + " - " + DoubleToString(obBull.high, 5) + "\n";

   if(obBear.isValid)
      alert += "Zone d'offre (OB): " + DoubleToString(obBear.low, 5) + " - " + DoubleToString(obBear.high, 5) + "\n";

   // Ajouter info sur les FVG proches
   SFairValueGap fvgBull = GetNearestBullishFVG(price);
   SFairValueGap fvgBear = GetNearestBearishFVG(price);

   if(fvgBull.isValid)
      alert += "FVG Haussier: " + DoubleToString(fvgBull.low, 5) + " - " + DoubleToString(fvgBull.high, 5) + "\n";

   if(fvgBear.isValid)
      alert += "FVG Baissier: " + DoubleToString(fvgBear.low, 5) + " - " + DoubleToString(fvgBear.high, 5) + "\n";

   return alert;
}
//+------------------------------------------------------------------+
