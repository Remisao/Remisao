//+------------------------------------------------------------------+
//|                                            TradeManagement.mqh  |
//|                            CHAPITRE 11 - SL & TP                |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des modes de breakeven                               |
//+------------------------------------------------------------------+
enum ENUM_BE_MODE
{
   BE_DISABLED = 0,
   BE_AT_1R,              // RÈGLE: Breakeven à R:R = 1:1
   BE_AT_CUSTOM           // Breakeven personnalisé
};

//+------------------------------------------------------------------+
//| Structure des niveaux de trade                                   |
//+------------------------------------------------------------------+
struct STradeLevels
{
   double      entryPrice;
   double      stopLoss;
   double      tp1;            // TP1
   double      tp2;            // TP2
   double      tp3;            // TP3
   double      breakeven;
   double      riskReward;
};

//+------------------------------------------------------------------+
//| Structure de gestion d'un trade                                  |
//+------------------------------------------------------------------+
struct STradeInfo
{
   ulong       ticket;
   string      symbol;
   double      entryPrice;
   double      currentSL;
   double      currentTP;
   double      volume;
   bool        isBuy;
   bool        isBreakevenSet;
   int         tpLevel;        // Niveau TP atteint (0, 1, 2, 3)
};

//+------------------------------------------------------------------+
//| Classe de gestion des trades                                      |
//+------------------------------------------------------------------+
class CTradeManagement
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_BE_MODE      m_beMode;
   double            m_beRatio;           // Ratio pour breakeven
   double            m_tp1Percent;        // % de position à fermer à TP1
   double            m_tp2Percent;        // % de position à fermer à TP2
   double            m_tp3Percent;        // % de position à fermer à TP3

   // Méthodes privées
   double            GetPipValue();
   double            NormalizePrice(double price);

public:
   CTradeManagement();
   ~CTradeManagement();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetBreakevenMode(ENUM_BE_MODE mode, double ratio = 1.0);
   void              SetTPDistribution(double tp1Pct = 50.0, double tp2Pct = 30.0, double tp3Pct = 20.0);

   // ============ RÈGLE CHAPITRE 11: SL TECHNIQUE ============
   // Sous swing low (achat) / au-dessus swing high (vente)
   double            CalculateStopLoss(bool isBuy, double swingLow, double swingHigh, double buffer = 0);

   // ============ RÈGLE: MULTI-TP ============
   // TP1 / TP2 / TP3
   STradeLevels      CalculateTradeLevels(double entry, double stopLoss, bool isBuy,
                                          double tp1Ratio = 1.5, double tp2Ratio = 2.0, double tp3Ratio = 3.0);

   // ============ RÈGLE: BREAKEVEN à R:R = 1:1 ============
   double            CalculateBreakeven(double entry, double stopLoss, bool isBuy);
   bool              ShouldMoveToBreakeven(STradeInfo &trade);
   bool              MoveToBreakeven(ulong ticket);

   // Gestion des TPs multiples
   bool              ManageMultiTP(STradeInfo &trade, STradeLevels &levels);
   bool              ClosePartialPosition(ulong ticket, double percent);
   bool              MoveStopToTP1(ulong ticket, double tp1Price);

   // Trailing Stop
   bool              TrailingStop(ulong ticket, double trailPips);
   bool              TrailingStopATR(ulong ticket, double atrMultiplier = 1.5);

   // Gestion des ordres
   bool              ModifyStopLoss(ulong ticket, double newSL);
   bool              ModifyTakeProfit(ulong ticket, double newTP);
   bool              ClosePosition(ulong ticket);

   // Informations
   STradeInfo        GetTradeInfo(ulong ticket);
   double            GetCurrentProfit(ulong ticket);
   double            GetCurrentProfitPips(ulong ticket);
   bool              IsInProfit(ulong ticket);

   // Utilitaires
   string            GetTradeSummary(STradeLevels &levels, bool isBuy);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CTradeManagement::CTradeManagement()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_beMode = BE_AT_1R;      // RÈGLE: Breakeven à R:R = 1:1
   m_beRatio = 1.0;
   m_tp1Percent = 50.0;      // 50% à TP1
   m_tp2Percent = 30.0;      // 30% à TP2
   m_tp3Percent = 20.0;      // 20% à TP3
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CTradeManagement::~CTradeManagement()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CTradeManagement::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configurer le mode breakeven                                      |
//+------------------------------------------------------------------+
void CTradeManagement::SetBreakevenMode(ENUM_BE_MODE mode, double ratio = 1.0)
{
   m_beMode = mode;
   m_beRatio = ratio;
}

//+------------------------------------------------------------------+
//| Configurer la distribution des TPs                                |
//+------------------------------------------------------------------+
void CTradeManagement::SetTPDistribution(double tp1Pct = 50.0, double tp2Pct = 30.0, double tp3Pct = 20.0)
{
   // S'assurer que le total = 100%
   double total = tp1Pct + tp2Pct + tp3Pct;
   m_tp1Percent = (tp1Pct / total) * 100.0;
   m_tp2Percent = (tp2Pct / total) * 100.0;
   m_tp3Percent = (tp3Pct / total) * 100.0;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un pip                                        |
//+------------------------------------------------------------------+
double CTradeManagement::GetPipValue()
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

   if(digits == 5 || digits == 3)
      return point * 10;

   return point;
}

//+------------------------------------------------------------------+
//| Normaliser un prix                                                |
//+------------------------------------------------------------------+
double CTradeManagement::NormalizePrice(double price)
{
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| RÈGLE: SL technique sous swing low / au-dessus swing high        |
//+------------------------------------------------------------------+
double CTradeManagement::CalculateStopLoss(bool isBuy, double swingLow, double swingHigh, double buffer = 0)
{
   double pip = GetPipValue();
   double sl;

   if(buffer == 0)
      buffer = pip * 5; // Buffer de 5 pips par défaut

   if(isBuy)
   {
      // RÈGLE: SL sous le swing low
      sl = swingLow - buffer;
   }
   else
   {
      // RÈGLE: SL au-dessus du swing high
      sl = swingHigh + buffer;
   }

   return NormalizePrice(sl);
}

//+------------------------------------------------------------------+
//| RÈGLE: Calculer les niveaux avec Multi-TP                        |
//+------------------------------------------------------------------+
STradeLevels CTradeManagement::CalculateTradeLevels(double entry, double stopLoss, bool isBuy,
                                                    double tp1Ratio = 1.5, double tp2Ratio = 2.0, double tp3Ratio = 3.0)
{
   STradeLevels levels;

   levels.entryPrice = NormalizePrice(entry);
   levels.stopLoss = NormalizePrice(stopLoss);

   double risk = MathAbs(entry - stopLoss);

   if(isBuy)
   {
      // TPs au-dessus de l'entrée
      levels.tp1 = NormalizePrice(entry + (risk * tp1Ratio));
      levels.tp2 = NormalizePrice(entry + (risk * tp2Ratio));
      levels.tp3 = NormalizePrice(entry + (risk * tp3Ratio));
      levels.breakeven = NormalizePrice(entry + (risk * m_beRatio)); // RÈGLE: BE à 1:1
   }
   else
   {
      // TPs en-dessous de l'entrée
      levels.tp1 = NormalizePrice(entry - (risk * tp1Ratio));
      levels.tp2 = NormalizePrice(entry - (risk * tp2Ratio));
      levels.tp3 = NormalizePrice(entry - (risk * tp3Ratio));
      levels.breakeven = NormalizePrice(entry - (risk * m_beRatio));
   }

   levels.riskReward = tp3Ratio; // R:R global

   return levels;
}

//+------------------------------------------------------------------+
//| RÈGLE: Calculer le niveau de breakeven à R:R = 1:1               |
//+------------------------------------------------------------------+
double CTradeManagement::CalculateBreakeven(double entry, double stopLoss, bool isBuy)
{
   double risk = MathAbs(entry - stopLoss);

   if(isBuy)
      return NormalizePrice(entry + (risk * m_beRatio));
   else
      return NormalizePrice(entry - (risk * m_beRatio));
}

//+------------------------------------------------------------------+
//| Vérifier si on doit passer en breakeven                           |
//+------------------------------------------------------------------+
bool CTradeManagement::ShouldMoveToBreakeven(STradeInfo &trade)
{
   if(m_beMode == BE_DISABLED) return false;
   if(trade.isBreakevenSet) return false;

   double currentPrice = SymbolInfoDouble(trade.symbol, SYMBOL_BID);
   double risk = MathAbs(trade.entryPrice - trade.currentSL);
   double beLevel;

   if(trade.isBuy)
   {
      beLevel = trade.entryPrice + (risk * m_beRatio);
      return (currentPrice >= beLevel);
   }
   else
   {
      beLevel = trade.entryPrice - (risk * m_beRatio);
      return (currentPrice <= beLevel);
   }
}

//+------------------------------------------------------------------+
//| Déplacer le SL au breakeven                                       |
//+------------------------------------------------------------------+
bool CTradeManagement::MoveToBreakeven(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);

   // Ajouter un petit buffer pour couvrir le spread
   double newSL = NormalizePrice(entry + spread);

   return ModifyStopLoss(ticket, newSL);
}

//+------------------------------------------------------------------+
//| Gérer les TPs multiples                                           |
//+------------------------------------------------------------------+
bool CTradeManagement::ManageMultiTP(STradeInfo &trade, STradeLevels &levels)
{
   double currentPrice = SymbolInfoDouble(trade.symbol, trade.isBuy ? SYMBOL_BID : SYMBOL_ASK);
   bool success = true;

   // Vérifier TP1
   if(trade.tpLevel == 0)
   {
      bool tp1Hit = trade.isBuy ? (currentPrice >= levels.tp1) : (currentPrice <= levels.tp1);
      if(tp1Hit)
      {
         // Fermer m_tp1Percent de la position
         success = ClosePartialPosition(trade.ticket, m_tp1Percent);
         if(success)
         {
            // Déplacer le SL au breakeven
            MoveToBreakeven(trade.ticket);
            trade.tpLevel = 1;
         }
      }
   }
   // Vérifier TP2
   else if(trade.tpLevel == 1)
   {
      bool tp2Hit = trade.isBuy ? (currentPrice >= levels.tp2) : (currentPrice <= levels.tp2);
      if(tp2Hit)
      {
         // Fermer m_tp2Percent de la position restante
         double remainingPercent = (m_tp2Percent / (100 - m_tp1Percent)) * 100;
         success = ClosePartialPosition(trade.ticket, remainingPercent);
         if(success)
         {
            // Déplacer le SL au TP1
            MoveStopToTP1(trade.ticket, levels.tp1);
            trade.tpLevel = 2;
         }
      }
   }
   // TP3 sera géré par le SL ou manuellement

   return success;
}

//+------------------------------------------------------------------+
//| Fermer une partie de la position                                  |
//+------------------------------------------------------------------+
bool CTradeManagement::ClosePartialPosition(ulong ticket, double percent)
{
   if(!PositionSelectByTicket(ticket)) return false;

   double volume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = NormalizeDouble(volume * (percent / 100.0), 2);

   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
   if(closeVolume < minLot) closeVolume = minLot;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = m_symbol;
   request.volume = closeVolume;
   request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(m_symbol, request.type == ORDER_TYPE_SELL ? SYMBOL_BID : SYMBOL_ASK);
   request.deviation = 10;

   return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Déplacer le SL au niveau TP1                                      |
//+------------------------------------------------------------------+
bool CTradeManagement::MoveStopToTP1(ulong ticket, double tp1Price)
{
   return ModifyStopLoss(ticket, tp1Price);
}

//+------------------------------------------------------------------+
//| Trailing Stop en pips                                             |
//+------------------------------------------------------------------+
bool CTradeManagement::TrailingStop(ulong ticket, double trailPips)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double pip = GetPipValue();
   double trailDistance = trailPips * pip;

   double currentSL = PositionGetDouble(POSITION_SL);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   double currentPrice = SymbolInfoDouble(symbol, isBuy ? SYMBOL_BID : SYMBOL_ASK);
   double newSL;

   if(isBuy)
   {
      newSL = NormalizePrice(currentPrice - trailDistance);
      // Ne déplacer que si le nouveau SL est plus haut que l'actuel et au-dessus de l'entrée
      if(newSL > currentSL && newSL > entry)
      {
         return ModifyStopLoss(ticket, newSL);
      }
   }
   else
   {
      newSL = NormalizePrice(currentPrice + trailDistance);
      // Ne déplacer que si le nouveau SL est plus bas que l'actuel et en-dessous de l'entrée
      if(newSL < currentSL && newSL < entry)
      {
         return ModifyStopLoss(ticket, newSL);
      }
   }

   return false; // Pas besoin de modifier
}

//+------------------------------------------------------------------+
//| Trailing Stop basé sur l'ATR                                      |
//+------------------------------------------------------------------+
bool CTradeManagement::TrailingStopATR(ulong ticket, double atrMultiplier = 1.5)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);

   // Calculer l'ATR
   int atrHandle = iATR(symbol, m_timeframe, 14);
   if(atrHandle == INVALID_HANDLE) return false;

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle);

   double atr = atrBuffer[0];
   double trailDistance = atr * atrMultiplier;

   double currentSL = PositionGetDouble(POSITION_SL);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   double currentPrice = SymbolInfoDouble(symbol, isBuy ? SYMBOL_BID : SYMBOL_ASK);
   double newSL;

   if(isBuy)
   {
      newSL = NormalizePrice(currentPrice - trailDistance);
      if(newSL > currentSL && newSL > entry)
      {
         return ModifyStopLoss(ticket, newSL);
      }
   }
   else
   {
      newSL = NormalizePrice(currentPrice + trailDistance);
      if(newSL < currentSL && newSL < entry)
      {
         return ModifyStopLoss(ticket, newSL);
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Modifier le Stop Loss                                             |
//+------------------------------------------------------------------+
bool CTradeManagement::ModifyStopLoss(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.sl = NormalizePrice(newSL);
   request.tp = PositionGetDouble(POSITION_TP);

   return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Modifier le Take Profit                                           |
//+------------------------------------------------------------------+
bool CTradeManagement::ModifyTakeProfit(ulong ticket, double newTP)
{
   if(!PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.sl = PositionGetDouble(POSITION_SL);
   request.tp = NormalizePrice(newTP);

   return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Fermer une position                                               |
//+------------------------------------------------------------------+
bool CTradeManagement::ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   string symbol = PositionGetString(POSITION_SYMBOL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = symbol;
   request.volume = volume;
   request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(symbol, request.type == ORDER_TYPE_SELL ? SYMBOL_BID : SYMBOL_ASK);
   request.deviation = 10;

   return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Obtenir les informations d'un trade                               |
//+------------------------------------------------------------------+
STradeInfo CTradeManagement::GetTradeInfo(ulong ticket)
{
   STradeInfo info;
   ZeroMemory(info);

   if(!PositionSelectByTicket(ticket)) return info;

   info.ticket = ticket;
   info.symbol = PositionGetString(POSITION_SYMBOL);
   info.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   info.currentSL = PositionGetDouble(POSITION_SL);
   info.currentTP = PositionGetDouble(POSITION_TP);
   info.volume = PositionGetDouble(POSITION_VOLUME);
   info.isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // Vérifier si en breakeven
   info.isBreakevenSet = (info.isBuy && info.currentSL >= info.entryPrice) ||
                         (!info.isBuy && info.currentSL <= info.entryPrice);

   return info;
}

//+------------------------------------------------------------------+
//| Obtenir le profit actuel                                          |
//+------------------------------------------------------------------+
double CTradeManagement::GetCurrentProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT);
}

//+------------------------------------------------------------------+
//| Obtenir le profit en pips                                         |
//+------------------------------------------------------------------+
double CTradeManagement::GetCurrentProfitPips(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   double currentPrice = SymbolInfoDouble(symbol, isBuy ? SYMBOL_BID : SYMBOL_ASK);
   double pip = GetPipValue();

   if(isBuy)
      return (currentPrice - entry) / pip;
   else
      return (entry - currentPrice) / pip;
}

//+------------------------------------------------------------------+
//| Vérifier si le trade est en profit                                |
//+------------------------------------------------------------------+
bool CTradeManagement::IsInProfit(ulong ticket)
{
   return (GetCurrentProfit(ticket) > 0);
}

//+------------------------------------------------------------------+
//| Obtenir un résumé du trade                                        |
//+------------------------------------------------------------------+
string CTradeManagement::GetTradeSummary(STradeLevels &levels, bool isBuy)
{
   double risk = MathAbs(levels.entryPrice - levels.stopLoss);
   double pip = GetPipValue();
   double slPips = risk / pip;

   string summary = "═══════ TRADE SETUP ═══════\n";
   summary += "Direction: " + (isBuy ? "ACHAT" : "VENTE") + "\n";
   summary += "Entrée: " + DoubleToString(levels.entryPrice, 5) + "\n";
   summary += "Stop Loss: " + DoubleToString(levels.stopLoss, 5) +
              " (" + DoubleToString(slPips, 1) + " pips)\n";
   summary += "───── Multi-TP ─────\n";
   summary += "TP1: " + DoubleToString(levels.tp1, 5) +
              " (" + DoubleToString(m_tp1Percent, 0) + "%)\n";
   summary += "TP2: " + DoubleToString(levels.tp2, 5) +
              " (" + DoubleToString(m_tp2Percent, 0) + "%)\n";
   summary += "TP3: " + DoubleToString(levels.tp3, 5) +
              " (" + DoubleToString(m_tp3Percent, 0) + "%)\n";
   summary += "───────────────────\n";
   summary += "Breakeven à: " + DoubleToString(levels.breakeven, 5) + " (R:R 1:1)\n";
   summary += "R:R Global: 1:" + DoubleToString(levels.riskReward, 1) + "\n";
   summary += "═══════════════════════════";

   return summary;
}
//+------------------------------------------------------------------+
