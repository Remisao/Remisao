//+------------------------------------------------------------------+
//|                                            RiskManagement.mqh   |
//|                        CHAPITRE 10 - RISK MANAGEMENT            |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Structure de calcul du risque                                    |
//+------------------------------------------------------------------+
struct SRiskCalculation
{
   double      accountBalance;
   double      riskPercent;
   double      riskAmount;        // Montant en devise du compte
   double      stopLossPips;
   double      positionSize;      // Taille de position en lots
   double      pipValue;
};

//+------------------------------------------------------------------+
//| Structure de corrélation                                         |
//+------------------------------------------------------------------+
struct SCorrelation
{
   string      symbol1;
   string      symbol2;
   double      coefficient;       // -1 à +1
   bool        isHighlyCorrelated; // > 0.7 ou < -0.7
};

//+------------------------------------------------------------------+
//| Classe de gestion du risque                                       |
//+------------------------------------------------------------------+
class CRiskManagement
{
private:
   double      m_maxRiskPercent;      // RÈGLE: 1% à 2%
   double      m_maxRiskPerTrade;     // Risque max par trade
   double      m_maxDailyDrawdown;    // Drawdown max journalier
   double      m_maxOpenPositions;    // Nombre max de positions
   double      m_correlationThreshold; // Seuil de corrélation

   // Corrélations connues
   SCorrelation m_correlations[];

   // État
   double      m_dailyLoss;
   double      m_dailyProfit;
   datetime    m_lastResetDate;

   // Méthodes privées
   double      GetPipValue(string symbol);
   double      GetPointValue(string symbol);
   void        InitCorrelations();
   void        ResetDailyStats();

public:
   CRiskManagement();
   ~CRiskManagement();

   // Initialisation
   void        Init();
   void        SetRiskParameters(double maxRiskPct = 1.0, double maxDailyDD = 5.0, int maxPositions = 5);

   // RÈGLE: Risque max par trade = 1% à 2%
   double      GetMaxRiskPercent();
   void        SetMaxRiskPercent(double percent);

   // RÈGLE: Calcul automatique du position sizing
   double      CalculatePositionSize(string symbol, double entryPrice, double stopLoss);
   double      CalculatePositionSizeByPips(string symbol, double stopLossPips);
   SRiskCalculation GetRiskCalculation(string symbol, double stopLossPips);

   // Calcul du risque
   double      CalculateRiskAmount();
   double      CalculateRiskReward(double entry, double stopLoss, double takeProfit);

   // RÈGLE: Limiter alertes corrélées (BTC ↔ ETH)
   bool        AreSymbolsCorrelated(string symbol1, string symbol2);
   double      GetCorrelation(string symbol1, string symbol2);
   bool        CanOpenPosition(string symbol);
   bool        HasCorrelatedPosition(string symbol);

   // Gestion du drawdown
   void        UpdateDailyStats(double profit);
   bool        IsDailyDrawdownExceeded();
   double      GetDailyLoss();
   double      GetDailyProfit();

   // Vérifications
   bool        IsRiskAcceptable(double positionSize, string symbol);
   bool        IsMaxPositionsReached();
   int         GetOpenPositionsCount();

   // Utilitaires
   string      GetRiskSummary(string symbol, double stopLossPips);
   string      GetCorrelationWarning(string symbol);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CRiskManagement::CRiskManagement()
{
   m_maxRiskPercent = 1.0;        // RÈGLE: 1% par défaut
   m_maxRiskPerTrade = 2.0;       // Max 2%
   m_maxDailyDrawdown = 5.0;      // 5% max par jour
   m_maxOpenPositions = 5;
   m_correlationThreshold = 0.7;

   m_dailyLoss = 0;
   m_dailyProfit = 0;
   m_lastResetDate = 0;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CRiskManagement::~CRiskManagement()
{
   ArrayFree(m_correlations);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CRiskManagement::Init()
{
   InitCorrelations();
   ResetDailyStats();
}

//+------------------------------------------------------------------+
//| Initialiser les corrélations connues                              |
//| RÈGLE: Limiter alertes corrélées (BTC ↔ ETH)                      |
//+------------------------------------------------------------------+
void CRiskManagement::InitCorrelations()
{
   ArrayResize(m_correlations, 0);

   // Corrélations Crypto
   int size = ArraySize(m_correlations);
   ArrayResize(m_correlations, size + 1);
   m_correlations[size].symbol1 = "BTCUSDT";
   m_correlations[size].symbol2 = "ETHUSDT";
   m_correlations[size].coefficient = 0.85;    // Haute corrélation
   m_correlations[size].isHighlyCorrelated = true;

   // Corrélations Forex
   size = ArraySize(m_correlations);
   ArrayResize(m_correlations, size + 1);
   m_correlations[size].symbol1 = "EURUSD";
   m_correlations[size].symbol2 = "GBPUSD";
   m_correlations[size].coefficient = 0.75;
   m_correlations[size].isHighlyCorrelated = true;

   size = ArraySize(m_correlations);
   ArrayResize(m_correlations, size + 1);
   m_correlations[size].symbol1 = "EURUSD";
   m_correlations[size].symbol2 = "USDCHF";
   m_correlations[size].coefficient = -0.80;   // Corrélation négative
   m_correlations[size].isHighlyCorrelated = true;

   // Gold et USD
   size = ArraySize(m_correlations);
   ArrayResize(m_correlations, size + 1);
   m_correlations[size].symbol1 = "XAUUSD";
   m_correlations[size].symbol2 = "EURUSD";
   m_correlations[size].coefficient = 0.50;
   m_correlations[size].isHighlyCorrelated = false;
}

//+------------------------------------------------------------------+
//| Réinitialiser les stats journalières                              |
//+------------------------------------------------------------------+
void CRiskManagement::ResetDailyStats()
{
   datetime today = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(today, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(m_lastResetDate < todayStart)
   {
      m_dailyLoss = 0;
      m_dailyProfit = 0;
      m_lastResetDate = todayStart;
   }
}

//+------------------------------------------------------------------+
//| Configuration des paramètres de risque                            |
//+------------------------------------------------------------------+
void CRiskManagement::SetRiskParameters(double maxRiskPct = 1.0, double maxDailyDD = 5.0, int maxPositions = 5)
{
   m_maxRiskPercent = MathMin(maxRiskPct, 2.0);  // RÈGLE: Max 2%
   m_maxDailyDrawdown = maxDailyDD;
   m_maxOpenPositions = maxPositions;
}

//+------------------------------------------------------------------+
//| RÈGLE: Risque max par trade = 1% à 2%                            |
//+------------------------------------------------------------------+
double CRiskManagement::GetMaxRiskPercent()
{
   return m_maxRiskPercent;
}

void CRiskManagement::SetMaxRiskPercent(double percent)
{
   // RÈGLE: Limiter entre 1% et 2%
   m_maxRiskPercent = MathMax(0.5, MathMin(percent, 2.0));
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un pip                                        |
//+------------------------------------------------------------------+
double CRiskManagement::GetPipValue(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Pour les paires avec 5 décimales (EURUSD) ou 3 (USDJPY)
   if(digits == 5 || digits == 3)
      return point * 10;

   return point;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un point                                      |
//+------------------------------------------------------------------+
double CRiskManagement::GetPointValue(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Calculer le montant à risquer                                     |
//+------------------------------------------------------------------+
double CRiskManagement::CalculateRiskAmount()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return balance * (m_maxRiskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| RÈGLE: Calcul automatique du position sizing                     |
//+------------------------------------------------------------------+
double CRiskManagement::CalculatePositionSize(string symbol, double entryPrice, double stopLoss)
{
   double stopLossPips = MathAbs(entryPrice - stopLoss) / GetPipValue(symbol);
   return CalculatePositionSizeByPips(symbol, stopLossPips);
}

//+------------------------------------------------------------------+
//| Calculer la taille de position par pips de SL                    |
//+------------------------------------------------------------------+
double CRiskManagement::CalculatePositionSizeByPips(string symbol, double stopLossPips)
{
   if(stopLossPips <= 0) return 0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (m_maxRiskPercent / 100.0);

   // Valeur d'un pip pour 1 lot standard
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = GetPipValue(symbol);

   double pipValuePerLot = (pipValue / tickSize) * tickValue;

   if(pipValuePerLot <= 0) return 0;

   // Taille de position = Montant risqué / (SL en pips * Valeur pip par lot)
   double lotSize = riskAmount / (stopLossPips * pipValuePerLot);

   // Arrondir au lot minimum
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(lotSize, maxLot));

   return lotSize;
}

//+------------------------------------------------------------------+
//| Obtenir le calcul complet du risque                               |
//+------------------------------------------------------------------+
SRiskCalculation CRiskManagement::GetRiskCalculation(string symbol, double stopLossPips)
{
   SRiskCalculation calc;

   calc.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   calc.riskPercent = m_maxRiskPercent;
   calc.riskAmount = calc.accountBalance * (m_maxRiskPercent / 100.0);
   calc.stopLossPips = stopLossPips;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   calc.pipValue = (GetPipValue(symbol) / tickSize) * tickValue;

   calc.positionSize = CalculatePositionSizeByPips(symbol, stopLossPips);

   return calc;
}

//+------------------------------------------------------------------+
//| Calculer le ratio Risk:Reward                                     |
//+------------------------------------------------------------------+
double CRiskManagement::CalculateRiskReward(double entry, double stopLoss, double takeProfit)
{
   double risk = MathAbs(entry - stopLoss);
   double reward = MathAbs(takeProfit - entry);

   if(risk == 0) return 0;

   return reward / risk;
}

//+------------------------------------------------------------------+
//| RÈGLE: Vérifier si deux symboles sont corrélés                    |
//+------------------------------------------------------------------+
bool CRiskManagement::AreSymbolsCorrelated(string symbol1, string symbol2)
{
   double corr = GetCorrelation(symbol1, symbol2);
   return (MathAbs(corr) >= m_correlationThreshold);
}

//+------------------------------------------------------------------+
//| Obtenir la corrélation entre deux symboles                        |
//+------------------------------------------------------------------+
double CRiskManagement::GetCorrelation(string symbol1, string symbol2)
{
   for(int i = 0; i < ArraySize(m_correlations); i++)
   {
      if((m_correlations[i].symbol1 == symbol1 && m_correlations[i].symbol2 == symbol2) ||
         (m_correlations[i].symbol1 == symbol2 && m_correlations[i].symbol2 == symbol1))
      {
         return m_correlations[i].coefficient;
      }
   }

   return 0; // Pas de corrélation connue
}

//+------------------------------------------------------------------+
//| Vérifier si on peut ouvrir une position                           |
//+------------------------------------------------------------------+
bool CRiskManagement::CanOpenPosition(string symbol)
{
   // Vérifier le drawdown journalier
   if(IsDailyDrawdownExceeded())
      return false;

   // Vérifier le nombre max de positions
   if(IsMaxPositionsReached())
      return false;

   // RÈGLE: Vérifier les corrélations
   if(HasCorrelatedPosition(symbol))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| RÈGLE: Vérifier s'il y a une position corrélée ouverte           |
//+------------------------------------------------------------------+
bool CRiskManagement::HasCorrelatedPosition(string symbol)
{
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(AreSymbolsCorrelated(symbol, posSymbol))
         {
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Mettre à jour les stats journalières                              |
//+------------------------------------------------------------------+
void CRiskManagement::UpdateDailyStats(double profit)
{
   ResetDailyStats();

   if(profit > 0)
      m_dailyProfit += profit;
   else
      m_dailyLoss += MathAbs(profit);
}

//+------------------------------------------------------------------+
//| Vérifier si le drawdown journalier est dépassé                    |
//+------------------------------------------------------------------+
bool CRiskManagement::IsDailyDrawdownExceeded()
{
   ResetDailyStats();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxLoss = balance * (m_maxDailyDrawdown / 100.0);

   return (m_dailyLoss >= maxLoss);
}

//+------------------------------------------------------------------+
//| Obtenir la perte journalière                                      |
//+------------------------------------------------------------------+
double CRiskManagement::GetDailyLoss()
{
   ResetDailyStats();
   return m_dailyLoss;
}

//+------------------------------------------------------------------+
//| Obtenir le profit journalier                                      |
//+------------------------------------------------------------------+
double CRiskManagement::GetDailyProfit()
{
   ResetDailyStats();
   return m_dailyProfit;
}

//+------------------------------------------------------------------+
//| Vérifier si le risque est acceptable                              |
//+------------------------------------------------------------------+
bool CRiskManagement::IsRiskAcceptable(double positionSize, string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   return (positionSize >= minLot && positionSize <= maxLot);
}

//+------------------------------------------------------------------+
//| Vérifier si le max de positions est atteint                       |
//+------------------------------------------------------------------+
bool CRiskManagement::IsMaxPositionsReached()
{
   return (GetOpenPositionsCount() >= (int)m_maxOpenPositions);
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de positions ouvertes                           |
//+------------------------------------------------------------------+
int CRiskManagement::GetOpenPositionsCount()
{
   return PositionsTotal();
}

//+------------------------------------------------------------------+
//| Obtenir un résumé du risque                                       |
//+------------------------------------------------------------------+
string CRiskManagement::GetRiskSummary(string symbol, double stopLossPips)
{
   SRiskCalculation calc = GetRiskCalculation(symbol, stopLossPips);

   string summary = "═══════ RISK MANAGEMENT ═══════\n";
   summary += "Balance: " + DoubleToString(calc.accountBalance, 2) + "\n";
   summary += "Risque: " + DoubleToString(calc.riskPercent, 1) + "% = " +
              DoubleToString(calc.riskAmount, 2) + "\n";
   summary += "Stop Loss: " + DoubleToString(calc.stopLossPips, 1) + " pips\n";
   summary += "Position Size: " + DoubleToString(calc.positionSize, 2) + " lots\n";
   summary += "═══════════════════════════════";

   return summary;
}

//+------------------------------------------------------------------+
//| Obtenir un avertissement de corrélation                           |
//+------------------------------------------------------------------+
string CRiskManagement::GetCorrelationWarning(string symbol)
{
   string warning = "";

   // Vérifier les positions existantes
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         double corr = GetCorrelation(symbol, posSymbol);

         if(MathAbs(corr) >= m_correlationThreshold)
         {
            warning = "⚠️ ATTENTION: " + symbol + " est corrélé à " + posSymbol +
                      " (corrélation: " + DoubleToString(corr * 100, 0) + "%).\n" +
                      "Position existante sur " + posSymbol + ". Risque de double exposition!";
            break;
         }
      }
   }

   return warning;
}
//+------------------------------------------------------------------+
