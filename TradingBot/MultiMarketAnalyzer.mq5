//+------------------------------------------------------------------+
//|                                        MultiMarketAnalyzer.mq5  |
//|                     BOT D'ANALYSE TRADING MULTI-MARCHÉS         |
//|                          Forex & Crypto                         |
//|                                                                 |
//|  MARCHÉS: EURUSD, XAUUSD, BTCUSDT, ETHUSDT                      |
//|  TIMEFRAMES: Daily (Direction), H4 (Structure), H1/M15 (Entrée) |
//+------------------------------------------------------------------+
#property copyright "Trading Bot Multi-Marchés"
#property link      ""
#property version   "1.00"
#property description "Bot d'analyse de trading multi-marchés (Forex & Crypto)"
#property description "Détecte UNIQUEMENT des setups à haute probabilité"
#property description "et envoie des alertes"
#property strict

//+------------------------------------------------------------------+
//| Includes - Tous les modules                                       |
//+------------------------------------------------------------------+
#include "Include/CandleAnalysis.mqh"
#include "Include/SupportResistance.mqh"
#include "Include/MarketStructure.mqh"
#include "Include/VolumeAnalysis.mqh"
#include "Include/ChartPatterns.mqh"
#include "Include/FibonacciZones.mqh"
#include "Include/MovingAverages.mqh"
#include "Include/Indicators.mqh"
#include "Include/Divergences.mqh"
#include "Include/RiskManagement.mqh"
#include "Include/TradeManagement.mqh"
#include "Include/MultiTimeframe.mqh"
#include "Include/SmartMoney.mqh"
#include "Include/AlertSystem.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                               |
//+------------------------------------------------------------------+
input group "═══════ MARCHÉS ═══════"
input bool      InpAnalyzeEURUSD    = true;       // Analyser EURUSD
input bool      InpAnalyzeXAUUSD    = true;       // Analyser XAUUSD (Gold)
input bool      InpAnalyzeBTCUSDT   = true;       // Analyser BTCUSDT
input bool      InpAnalyzeETHUSDT   = true;       // Analyser ETHUSDT

input group "═══════ RISK MANAGEMENT ═══════"
input double    InpRiskPercent      = 1.0;        // Risque par trade (%)
input double    InpMaxDailyDD       = 5.0;        // Drawdown max journalier (%)
input int       InpMaxPositions     = 5;          // Positions max simultanées

input group "═══════ ALERTES ═══════"
input bool      InpEnablePush       = true;       // Notifications Push
input bool      InpEnableEmail      = false;      // Notifications Email
input bool      InpEnableSound      = true;       // Alertes sonores
input bool      InpEnablePopup      = true;       // Popups MT5
input int       InpAlertInterval    = 60;         // Intervalle min entre alertes (sec)

input group "═══════ TELEGRAM (Optionnel) ═══════"
input bool      InpEnableTelegram   = false;      // Activer Telegram
input string    InpTelegramToken    = "";         // Token du Bot Telegram
input string    InpTelegramChatId   = "";         // Chat ID Telegram

input group "═══════ PARAMÈTRES ANALYSE ═══════"
input int       InpLookback         = 100;        // Barres à analyser
input double    InpSRTolerance      = 10.0;       // Tolérance S/R (pips)
input int       InpMinConditions    = 4;          // Conditions min pour alerte (sur 5)

//+------------------------------------------------------------------+
//| Variables globales                                                |
//+------------------------------------------------------------------+
// Symboles à analyser
string   g_symbols[];
int      g_symbolCount = 0;

// Analyseurs par symbole
CCandleAnalysis     g_candle[];
CSupportResistance  g_sr[];
CMarketStructure    g_structure[];
CVolumeAnalysis     g_volume[];
CChartPatterns      g_patterns[];
CFibonacciZones     g_fib[];
CMovingAverages     g_ema[];
CIndicators         g_indicators[];
CDivergences        g_divergences[];
CMultiTimeframe     g_mtf[];
CSmartMoney         g_smc[];

// Gestionnaires
CRiskManagement     g_risk;
CTradeManagement    g_trade[];
CAlertSystem        g_alerts;

// État
datetime g_lastBarTime[];
bool     g_isInitialized = false;

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("     BOT D'ANALYSE TRADING MULTI-MARCHÉS");
   Print("     Forex & Crypto - Haute Probabilité");
   Print("═══════════════════════════════════════════════════════════");

   // Construire la liste des symboles
   BuildSymbolList();

   if(g_symbolCount == 0)
   {
      Print("ERREUR: Aucun symbole sélectionné!");
      return INIT_FAILED;
   }

   // Initialiser les tableaux
   if(!InitializeArrays())
   {
      Print("ERREUR: Échec de l'initialisation des tableaux");
      return INIT_FAILED;
   }

   // Initialiser les analyseurs pour chaque symbole
   if(!InitializeAnalyzers())
   {
      Print("ERREUR: Échec de l'initialisation des analyseurs");
      return INIT_FAILED;
   }

   // Configurer le Risk Management
   g_risk.Init();
   g_risk.SetRiskParameters(InpRiskPercent, InpMaxDailyDD, InpMaxPositions);

   // Configurer le système d'alertes
   ConfigureAlertSystem();

   Print("═══════════════════════════════════════════════════════════");
   Print("     INITIALISATION RÉUSSIE - ", g_symbolCount, " MARCHÉS ACTIFS");
   Print("═══════════════════════════════════════════════════════════");

   for(int i = 0; i < g_symbolCount; i++)
   {
      Print("  ✓ ", g_symbols[i]);
   }

   g_isInitialized = true;

   // Timer pour analyse périodique
   EventSetTimer(1); // Chaque seconde

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("Bot d'analyse arrêté. Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Construire la liste des symboles                                  |
//+------------------------------------------------------------------+
void BuildSymbolList()
{
   g_symbolCount = 0;
   ArrayResize(g_symbols, 0);

   if(InpAnalyzeEURUSD && SymbolSelect("EURUSD", true))
   {
      ArrayResize(g_symbols, g_symbolCount + 1);
      g_symbols[g_symbolCount++] = "EURUSD";
   }

   if(InpAnalyzeXAUUSD && SymbolSelect("XAUUSD", true))
   {
      ArrayResize(g_symbols, g_symbolCount + 1);
      g_symbols[g_symbolCount++] = "XAUUSD";
   }

   if(InpAnalyzeBTCUSDT && SymbolSelect("BTCUSDT", true))
   {
      ArrayResize(g_symbols, g_symbolCount + 1);
      g_symbols[g_symbolCount++] = "BTCUSDT";
   }

   if(InpAnalyzeETHUSDT && SymbolSelect("ETHUSDT", true))
   {
      ArrayResize(g_symbols, g_symbolCount + 1);
      g_symbols[g_symbolCount++] = "ETHUSDT";
   }
}

//+------------------------------------------------------------------+
//| Initialiser les tableaux                                          |
//+------------------------------------------------------------------+
bool InitializeArrays()
{
   ArrayResize(g_candle, g_symbolCount);
   ArrayResize(g_sr, g_symbolCount);
   ArrayResize(g_structure, g_symbolCount);
   ArrayResize(g_volume, g_symbolCount);
   ArrayResize(g_patterns, g_symbolCount);
   ArrayResize(g_fib, g_symbolCount);
   ArrayResize(g_ema, g_symbolCount);
   ArrayResize(g_indicators, g_symbolCount);
   ArrayResize(g_divergences, g_symbolCount);
   ArrayResize(g_mtf, g_symbolCount);
   ArrayResize(g_smc, g_symbolCount);
   ArrayResize(g_trade, g_symbolCount);
   ArrayResize(g_lastBarTime, g_symbolCount);

   for(int i = 0; i < g_symbolCount; i++)
   {
      g_lastBarTime[i] = 0;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Initialiser les analyseurs                                        |
//+------------------------------------------------------------------+
bool InitializeAnalyzers()
{
   for(int i = 0; i < g_symbolCount; i++)
   {
      string symbol = g_symbols[i];

      // Chapitre 1 - Bougies
      g_candle[i].Init(symbol, PERIOD_H1);

      // Chapitre 2 - S/R
      g_sr[i].Init(symbol, PERIOD_H4);
      g_sr[i].SetParameters(InpLookback, InpSRTolerance, 20);

      // Chapitre 3 - Structure
      g_structure[i].Init(symbol, PERIOD_H4);
      g_structure[i].SetParameters(InpLookback, 3);

      // Chapitre 4 - Volume
      g_volume[i].Init(symbol, PERIOD_H1);

      // Chapitre 5 - Patterns
      g_patterns[i].Init(symbol, PERIOD_H4);
      g_patterns[i].SetParameters(50, 1.0);

      // Chapitre 6 - Fibonacci
      g_fib[i].Init(symbol, PERIOD_H4);
      g_fib[i].SetLookback(InpLookback);

      // Chapitre 7 - EMAs
      if(!g_ema[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init EMAs pour ", symbol);
         return false;
      }

      // Chapitre 8 - RSI/MACD
      if(!g_indicators[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init Indicateurs pour ", symbol);
         return false;
      }

      // Chapitre 9 - Divergences
      if(!g_divergences[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init Divergences pour ", symbol);
         return false;
      }
      g_divergences[i].SetAnalyzers(&g_candle[i], &g_structure[i]);

      // Chapitre 11 - Trade Management
      g_trade[i].Init(symbol, PERIOD_H1);
      g_trade[i].SetBreakevenMode(BE_AT_1R, 1.0);
      g_trade[i].SetTPDistribution(50.0, 30.0, 20.0);

      // Chapitre 12 - MTF
      if(!g_mtf[i].Init(symbol))
      {
         Print("ERREUR: Échec init MTF pour ", symbol);
         return false;
      }

      // Chapitre 13 - Smart Money
      g_smc[i].Init(symbol, PERIOD_H4);
      g_smc[i].SetParameters(InpLookback, 0.1);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurer le système d'alertes                                   |
//+------------------------------------------------------------------+
void ConfigureAlertSystem()
{
   g_alerts.EnablePush(InpEnablePush);
   g_alerts.EnableEmail(InpEnableEmail);
   g_alerts.EnableSound(InpEnableSound);
   g_alerts.EnablePopup(InpEnablePopup);
   g_alerts.EnableTelegram(InpEnableTelegram, InpTelegramToken, InpTelegramChatId);
   g_alerts.SetMinInterval(InpAlertInterval);
}

//+------------------------------------------------------------------+
//| Fonction de tick                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized) return;

   // Analyser chaque symbole sur nouvelle bougie
   for(int i = 0; i < g_symbolCount; i++)
   {
      datetime currentBarTime = iTime(g_symbols[i], PERIOD_M15, 0);

      if(currentBarTime != g_lastBarTime[i])
      {
         g_lastBarTime[i] = currentBarTime;
         AnalyzeSymbol(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Mise à jour périodique si nécessaire
}

//+------------------------------------------------------------------+
//| Analyser un symbole                                               |
//+------------------------------------------------------------------+
void AnalyzeSymbol(int index)
{
   string symbol = g_symbols[index];

   // Vérifier les corrélations (Chapitre 10)
   if(g_risk.HasCorrelatedPosition(symbol))
   {
      // Ne pas analyser si position corrélée ouverte
      return;
   }

   // ══════════════════════════════════════════════════════════════
   // CHAPITRE 12: ALIGNEMENT MTF OBLIGATOIRE
   // Daily = Direction, H4 = Zone & structure, H1/M15 = Entrée
   // ══════════════════════════════════════════════════════════════
   SMTFAnalysis mtf = g_mtf[index].Analyze();

   if(!mtf.isValidSetup)
   {
      // RÈGLE: Si pas aligné → AUCUNE ALERTE
      return;
   }

   // Déterminer la direction basée sur le MTF
   bool lookingForBuy = (mtf.direction == "BUY");

   // ══════════════════════════════════════════════════════════════
   // CHECKLIST FINALE - Validation des 5 conditions
   // ══════════════════════════════════════════════════════════════
   bool contextOK = false;
   bool confluenceOK = false;
   bool candleSignalOK = false;
   bool volumeOK = false;
   bool structureOK = false;

   // 1. CONTEXTE OK (MTF aligné + Structure)
   g_structure[index].Analyze();
   ENUM_MARKET_STRUCTURE structure = g_structure[index].GetStructure();

   if(lookingForBuy)
      contextOK = (structure == STRUCTURE_BULLISH || structure == STRUCTURE_RANGING);
   else
      contextOK = (structure == STRUCTURE_BEARISH || structure == STRUCTURE_RANGING);

   // 2. ZONE DE CONFLUENCE OK (Fib + S/R + SMC)
   g_sr[index].DetectLevels();
   g_fib[index].Analyze();
   g_smc[index].AnalyzeAll();

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

   // Confluence Fibonacci + S/R
   double srLevel = 0;
   bool atSR = false;
   if(lookingForBuy)
      atSR = g_sr[index].IsPriceAtSupport(currentPrice, srLevel);
   else
      atSR = g_sr[index].IsPriceAtResistance(currentPrice, srLevel);

   bool inGoldenZone = g_fib[index].IsPriceInGoldenZone(currentPrice);
   bool smcConfluence = g_smc[index].HasSMCConfluence(currentPrice, lookingForBuy);

   confluenceOK = (atSR || inGoldenZone || smcConfluence);

   // 3. SIGNAL BOUGIE OK (Chapitre 1)
   if(lookingForBuy)
      candleSignalOK = g_candle[index].HasBullishConfirmation(1);
   else
      candleSignalOK = g_candle[index].HasBearishConfirmation(1);

   // 4. VOLUME OK (Chapitre 4)
   SVolumeData volData = g_volume[index].Analyze(1);
   volumeOK = volData.isValidBreakout || volData.state == VOLUME_HIGH || volData.state == VOLUME_VERY_HIGH;

   // 5. STRUCTURE OK (BOS/CHoCH confirme)
   bool isBullishBOS;
   if(lookingForBuy)
      structureOK = g_smc[index].IsBOS(1, isBullishBOS) && isBullishBOS;
   else
      structureOK = g_smc[index].IsBOS(1, isBullishBOS) && !isBullishBOS;

   // Si pas de BOS, vérifier CHoCH
   if(!structureOK)
   {
      bool isBullishCHoCH;
      if(lookingForBuy)
         structureOK = g_smc[index].IsCHoCH(1, isBullishCHoCH) && isBullishCHoCH;
      else
         structureOK = g_smc[index].IsCHoCH(1, isBullishCHoCH) && !isBullishCHoCH;
   }

   // ══════════════════════════════════════════════════════════════
   // VALIDATION CHECKLIST FINALE
   // RÈGLE: Minimum 4 conditions sur 5 validées
   // ══════════════════════════════════════════════════════════════
   int validatedCount;
   bool isValidSetup = g_alerts.ValidateChecklist(
      contextOK,
      confluenceOK,
      candleSignalOK,
      volumeOK,
      structureOK,
      validatedCount
   );

   if(isValidSetup && validatedCount >= InpMinConditions)
   {
      // GÉNÉRER L'ALERTE
      GenerateSetupAlert(index, lookingForBuy, validatedCount,
                         contextOK, confluenceOK, candleSignalOK, volumeOK, structureOK);
   }

   // Vérifier aussi les divergences confirmées
   CheckDivergences(index);

   // Vérifier les patterns
   CheckPatterns(index);
}

//+------------------------------------------------------------------+
//| Générer une alerte de setup                                       |
//+------------------------------------------------------------------+
void GenerateSetupAlert(int index, bool isBuy, int conditions,
                        bool contextOK, bool confluenceOK,
                        bool candleOK, bool volumeOK, bool structureOK)
{
   string symbol = g_symbols[index];
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

   // Construire les détails
   string details = "";
   details += "───── CHECKLIST ─────\n";
   details += "Contexte MTF: " + (contextOK ? "✅" : "❌") + "\n";
   details += "Zone Confluence: " + (confluenceOK ? "✅" : "❌") + "\n";
   details += "Signal Bougie: " + (candleOK ? "✅" : "❌") + "\n";
   details += "Volume: " + (volumeOK ? "✅" : "❌") + "\n";
   details += "Structure SMC: " + (structureOK ? "✅" : "❌") + "\n";
   details += "─────────────────────\n";

   // Infos SMC
   g_smc[index].AnalyzeAll();
   if(isBuy)
   {
      SOrderBlock ob = g_smc[index].GetNearestBullishOB(currentPrice);
      if(ob.isValid)
         details += "OB Zone: " + DoubleToString(ob.low, 5) + " - " + DoubleToString(ob.high, 5) + "\n";

      SFairValueGap fvg = g_smc[index].GetNearestBullishFVG(currentPrice);
      if(fvg.isValid)
         details += "FVG Zone: " + DoubleToString(fvg.low, 5) + " - " + DoubleToString(fvg.high, 5) + "\n";
   }
   else
   {
      SOrderBlock ob = g_smc[index].GetNearestBearishOB(currentPrice);
      if(ob.isValid)
         details += "OB Zone: " + DoubleToString(ob.low, 5) + " - " + DoubleToString(ob.high, 5) + "\n";

      SFairValueGap fvg = g_smc[index].GetNearestBearishFVG(currentPrice);
      if(fvg.isValid)
         details += "FVG Zone: " + DoubleToString(fvg.low, 5) + " - " + DoubleToString(fvg.high, 5) + "\n";
   }

   // Fibonacci
   SFibLevels fibLevels = g_fib[index].GetFibLevels();
   details += "─────────────────────\n";
   details += "Golden Zone: " + DoubleToString(fibLevels.goldenZoneLow, 5) +
              " - " + DoubleToString(fibLevels.goldenZoneHigh, 5) + "\n";
   details += "TP1 (127.2%): " + DoubleToString(g_fib[index].GetTP1(), 5) + "\n";
   details += "TP2 (161.8%): " + DoubleToString(g_fib[index].GetTP2(), 5) + "\n";

   // SL/TP calculés
   double swingLow = g_structure[index].GetLastSwingLow();
   double swingHigh = g_structure[index].GetLastSwingHigh();

   double sl = g_trade[index].CalculateStopLoss(isBuy, swingLow, swingHigh);
   STradeLevels levels = g_trade[index].CalculateTradeLevels(currentPrice, sl, isBuy);

   details += "─────────────────────\n";
   details += "SL Technique: " + DoubleToString(sl, 5) + "\n";
   details += "Multi-TP:\n";
   details += "  TP1: " + DoubleToString(levels.tp1, 5) + " (50%)\n";
   details += "  TP2: " + DoubleToString(levels.tp2, 5) + " (30%)\n";
   details += "  TP3: " + DoubleToString(levels.tp3, 5) + " (20%)\n";
   details += "BE à: " + DoubleToString(levels.breakeven, 5) + " (R:R 1:1)\n";

   // Position sizing
   double slPips = MathAbs(currentPrice - sl) / SymbolInfoDouble(symbol, SYMBOL_POINT) / 10;
   SRiskCalculation risk = g_risk.GetRiskCalculation(symbol, slPips);
   details += "─────────────────────\n";
   details += "Risque: " + DoubleToString(risk.riskPercent, 1) + "% = " +
              DoubleToString(risk.riskAmount, 2) + "\n";
   details += "Position: " + DoubleToString(risk.positionSize, 2) + " lots\n";

   // Message principal
   string message = "SETUP " + (isBuy ? "ACHAT" : "VENTE") + " HAUTE PROBABILITÉ\n";
   message += "Prix: " + DoubleToString(currentPrice, 5);

   // Envoyer l'alerte
   g_alerts.SendSetupAlert(symbol, PERIOD_H1, isBuy, message, details, conditions);
}

//+------------------------------------------------------------------+
//| Vérifier les divergences                                          |
//+------------------------------------------------------------------+
void CheckDivergences(int index)
{
   string symbol = g_symbols[index];

   SDivergence div;
   if(g_divergences[index].HasDivergence(div))
   {
      // RÈGLE: PAS d'alerte sans confirmation
      if(div.isConfirmed)
      {
         string alert = g_divergences[index].GetDivergenceAlert(div);
         if(alert != "")
         {
            g_alerts.SendDivergenceAlert(symbol, PERIOD_H1,
               g_divergences[index].DivergenceTypeToString(div.type), alert);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier les patterns                                             |
//+------------------------------------------------------------------+
void CheckPatterns(int index)
{
   string symbol = g_symbols[index];

   g_patterns[index].DetectAllPatterns();

   for(int i = 0; i < g_patterns[index].GetPatternCount(); i++)
   {
      SChartPattern pattern = g_patterns[index].GetPattern(i);

      // RÈGLE: Double Top/Bottom - Alerte UNIQUEMENT à cassure neckline
      if(pattern.type == PATTERN_DOUBLE_TOP || pattern.type == PATTERN_DOUBLE_BOTTOM)
      {
         if(pattern.status == STATUS_NECKLINE_BREAK)
         {
            string alert = g_patterns[index].GetPatternAlert(pattern);
            if(alert != "")
            {
               g_alerts.SendPatternAlert(symbol, PERIOD_H4,
                  g_patterns[index].PatternTypeToString(pattern.type), alert);
            }
         }
      }
      // RÈGLE: Patterns continuation - Alerte "Compression"
      else if(pattern.type == PATTERN_TRIANGLE_ASCENDING ||
              pattern.type == PATTERN_TRIANGLE_DESCENDING ||
              pattern.type == PATTERN_TRIANGLE_SYMMETRIC ||
              pattern.type == PATTERN_FLAG_BULLISH ||
              pattern.type == PATTERN_FLAG_BEARISH)
      {
         string alert = g_patterns[index].GetPatternAlert(pattern);
         if(alert != "")
         {
            g_alerts.SendPatternAlert(symbol, PERIOD_H4,
               g_patterns[index].PatternTypeToString(pattern.type), alert);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Afficher le statut sur le graphique                               |
//+------------------------------------------------------------------+
void DisplayStatus()
{
   string status = "";
   status += "═══════════════════════════════════════\n";
   status += "   BOT ANALYSE MULTI-MARCHÉS ACTIF\n";
   status += "═══════════════════════════════════════\n\n";

   for(int i = 0; i < g_symbolCount; i++)
   {
      string symbol = g_symbols[i];
      SMTFAnalysis mtf = g_mtf[i].Analyze();

      status += symbol + ": ";
      if(mtf.isValidSetup)
         status += "✅ " + mtf.direction;
      else
         status += "⏸ En attente";
      status += "\n";
   }

   status += "\n───────────────────────────────────────\n";
   status += "Risque/Trade: " + DoubleToString(InpRiskPercent, 1) + "%\n";
   status += "Positions ouvertes: " + IntegerToString(g_risk.GetOpenPositionsCount()) + "/" +
             IntegerToString(InpMaxPositions) + "\n";
   status += "───────────────────────────────────────\n";

   Comment(status);
}

//+------------------------------------------------------------------+
//| Fonction de gestion des événements graphiques                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Gestion des boutons ou interactions si nécessaire
}
//+------------------------------------------------------------------+
