//+------------------------------------------------------------------+
//|                                        MultiMarketAnalyzer.mq5   |
//|                    BOT ANALYSTE TRADING MULTI-MARCHÉS            |
//|                          Forex & Crypto                          |
//|                                                                  |
//|  ⚠️ CE BOT NE TRADE PAS - ANALYSE UNIQUEMENT                     |
//|  ⚠️ CE BOT NE SPAM PAS - ALERTES DISCIPLINÉES                    |
//|                                                                  |
//|  MARCHÉS: EURUSD, XAUUSD, BTCUSDT, ETHUSDT                       |
//|  TIMEFRAMES: Daily (Biais), H4 (Zones), H1/M15 (Timing)          |
//+------------------------------------------------------------------+
#property copyright "Trading Bot Analyste"
#property link      ""
#property version   "2.00"
#property description "Bot d'analyse - NE TRADE PAS"
#property description "Machine à états: NEUTRAL → PRE_SIGNAL → SETUP → EXIT"
#property description "Alertes disciplinées et hiérarchisées"
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

input group "═══════ ALERTES ═══════"
input bool      InpEnablePush       = true;       // Notifications Push
input bool      InpEnableEmail      = false;      // Notifications Email
input bool      InpEnableSound      = true;       // Alertes sonores
input bool      InpEnablePopup      = true;       // Popups MT5
input int       InpMinAlertInterval = 0;          // Intervalle min alertes (0=immédiat)
input int       InpPreSignalCooldown= 0;          // Cooldown PRE_SIGNAL (0=immédiat)
input int       InpSetupCooldown    = 0;          // Cooldown SETUP (0=immédiat)

input group "═══════ TELEGRAM (Optionnel) ═══════"
input bool      InpEnableTelegram   = false;      // Activer Telegram
input string    InpTelegramToken    = "";         // Token du Bot Telegram
input string    InpTelegramChatId   = "";         // Chat ID Telegram

input group "═══════ PARAMÈTRES ANALYSE ═══════"
input int       InpLookback         = 100;        // Barres à analyser
input double    InpSRTolerance      = 10.0;       // Tolérance S/R (pips)
input int       InpMinConditions    = 4;          // Conditions min SETUP (sur 5)
input int       InpMinPreSignal     = 3;          // Conditions min PRE_SIGNAL (sur 5)
input double    InpMinVolumeRatio   = 150.0;      // Volume min pour SETUP (%)

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
datetime g_lastBarTime[];        // Dernière barre analysée par symbole
datetime g_lastH4BarTime[];      // Dernière barre H4
datetime g_lastDailyBarTime[];   // Dernière barre Daily
bool     g_isInitialized = false;

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("     BOT ANALYSTE TRADING MULTI-MARCHÉS v2.0");
   Print("     ⚠️ NE TRADE PAS - ANALYSE UNIQUEMENT");
   Print("     Machine à états: NEUTRAL → PRE_SIGNAL → SETUP → EXIT");
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
   g_risk.SetRiskParameters(InpRiskPercent, InpMaxDailyDD, 5);

   // Configurer le système d'alertes avec machine à états
   ConfigureAlertSystem();

   Print("═══════════════════════════════════════════════════════════");
   Print("     INITIALISATION RÉUSSIE - ", g_symbolCount, " MARCHÉS ACTIFS");
   Print("═══════════════════════════════════════════════════════════");

   for(int i = 0; i < g_symbolCount; i++)
   {
      Print("  ✓ ", g_symbols[i], " - État: NEUTRAL");

      // Envoyer notification de démarrage pour chaque paire
      g_alerts.SendStartupAlert(g_symbols[i], PERIOD_H4);
   }

   g_isInitialized = true;

   // Timer pour analyse périodique
   EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_alerts.Deinit();
   Print("Bot analyste arrêté. Raison: ", reason);
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
   ArrayResize(g_lastH4BarTime, g_symbolCount);
   ArrayResize(g_lastDailyBarTime, g_symbolCount);

   for(int i = 0; i < g_symbolCount; i++)
   {
      g_lastBarTime[i] = 0;
      g_lastH4BarTime[i] = 0;
      g_lastDailyBarTime[i] = 0;
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

      // Bougies (M15 pour timing)
      g_candle[i].Init(symbol, PERIOD_M15);

      // S/R (H4 pour zones)
      g_sr[i].Init(symbol, PERIOD_H4);
      g_sr[i].SetParameters(InpLookback, InpSRTolerance, 20);

      // Structure (H4 pour contexte)
      g_structure[i].Init(symbol, PERIOD_H4);
      g_structure[i].SetParameters(3, InpLookback, 0.5, 0.3);

      // Volume (H1)
      g_volume[i].Init(symbol, PERIOD_H1);

      // Patterns (H4)
      g_patterns[i].Init(symbol, PERIOD_H4);
      g_patterns[i].SetParameters(50, 1.0);

      // Fibonacci (H4)
      g_fib[i].Init(symbol, PERIOD_H4);
      g_fib[i].SetLookback(InpLookback);

      // EMAs (H1)
      if(!g_ema[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init EMAs pour ", symbol);
         return false;
      }

      // RSI/MACD (H1)
      if(!g_indicators[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init Indicateurs pour ", symbol);
         return false;
      }

      // Divergences (H1)
      if(!g_divergences[i].Init(symbol, PERIOD_H1))
      {
         Print("ERREUR: Échec init Divergences pour ", symbol);
         return false;
      }
      g_divergences[i].SetAnalyzers(&g_candle[i], &g_structure[i]);

      // Trade Management
      g_trade[i].Init(symbol, PERIOD_H1);
      g_trade[i].SetBreakevenMode(BE_AT_1R, 1.0);
      g_trade[i].SetTPDistribution(50.0, 30.0, 20.0);

      // MTF
      if(!g_mtf[i].Init(symbol))
      {
         Print("ERREUR: Échec init MTF pour ", symbol);
         return false;
      }

      // Smart Money (H4)
      g_smc[i].Init(symbol, PERIOD_H4);
      g_smc[i].SetParameters(InpLookback, OB_MODE_WICK, 0.3, 0.05, 5.0);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurer le système d'alertes                                   |
//+------------------------------------------------------------------+
void ConfigureAlertSystem()
{
   g_alerts.Init();
   g_alerts.EnablePush(InpEnablePush);
   g_alerts.EnableEmail(InpEnableEmail);
   g_alerts.EnableSound(InpEnableSound);
   g_alerts.EnablePopup(InpEnablePopup);
   g_alerts.EnableTelegram(InpEnableTelegram, InpTelegramToken, InpTelegramChatId);
   g_alerts.SetMinInterval(InpMinAlertInterval);
   g_alerts.SetPreSignalCooldown(InpPreSignalCooldown);
   g_alerts.SetSetupCooldown(InpSetupCooldown);
}

//+------------------------------------------------------------------+
//| Fonction de tick                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized) return;

   // Analyser chaque symbole sur nouvelle bougie M15
   for(int i = 0; i < g_symbolCount; i++)
   {
      datetime currentBarTime = iTime(g_symbols[i], PERIOD_M15, 0);

      // Nouvelle bougie M15 = analyse complète
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
   // Mise à jour de l'affichage
   DisplayStatus();
}

//+------------------------------------------------------------------+
//| Analyser un symbole - MACHINE À ÉTATS                             |
//+------------------------------------------------------------------+
void AnalyzeSymbol(int index)
{
   string symbol = g_symbols[index];

   // Obtenir l'état actuel du marché
   ENUM_BOT_STATE currentState = g_alerts.GetMarketState(symbol);

   //=================================================================
   // ÉTAPE 1: Mise à jour des analyseurs (obligatoire à chaque tick)
   //=================================================================
   g_structure[index].Update();
   g_smc[index].Update();
   // EMA et Divergences sont mis à jour via leurs méthodes Analyze()

   //=================================================================
   // ÉTAPE 2: Vérifier les conditions de SORTIE (priorité max)
   //=================================================================
   if(currentState == STATE_SETUP_ACTIVE)
   {
      if(CheckExitConditions(index))
      {
         return; // Exit émis, pas besoin de continuer
      }

      // Vérifier si mise à jour nécessaire (MJ_SETUP)
      CheckSetupUpdate(index);
      return; // Ne pas chercher de nouveau setup si un est déjà actif
   }

   //=================================================================
   // ÉTAPE 3: Alignement MTF OBLIGATOIRE (Daily/H4/H1)
   //=================================================================
   SMTFAnalysis mtf = g_mtf[index].Analyze();

   if(!mtf.isValidSetup)
   {
      // RÈGLE: Pas d'alignement = Pas d'alerte
      // Mais on peut revenir à NEUTRAL si on était en PRE_SIGNAL
      if(currentState == STATE_PRE_SIGNAL)
      {
         // Si MTF n'est plus aligné, revenir à NEUTRAL
         g_alerts.ResetToNeutral(symbol);
      }
      return;
   }

   bool lookingForBuy = (mtf.direction == "BUY");

   //=================================================================
   // ÉTAPE 4: Évaluer les conditions PRE_SIGNAL (3/5)
   //=================================================================
   SPreSignalConditions preConditions;
   preConditions.Reset();
   EvaluatePreSignalConditions(index, lookingForBuy, preConditions);

   //=================================================================
   // ÉTAPE 5: Évaluer les conditions SETUP (4/5)
   //=================================================================
   SSetupConditions setupConditions;
   setupConditions.Reset();
   EvaluateSetupConditions(index, lookingForBuy, mtf, setupConditions);

   //=================================================================
   // ÉTAPE 6: Logique de transition d'état
   //=================================================================

   // Si conditions SETUP validées (4/5) → SETUP_SIGNAL
   if(g_alerts.ValidateSetupConditions(setupConditions))
   {
      // Calculer les niveaux
      double entry, sl, tp1, tp2, riskPct;
      CalculateTradeLevels(index, lookingForBuy, entry, sl, tp1, tp2, riskPct);

      g_alerts.TransitionToSetupActive(
         symbol,
         PERIOD_H1,
         lookingForBuy ? DIRECTION_BUY : DIRECTION_SELL,
         setupConditions,
         entry, sl, tp1, tp2, riskPct
      );
   }
   // Sinon si conditions PRE_SIGNAL validées (3/5) → PRE_SIGNAL
   else if(g_alerts.ValidatePreSignalConditions(preConditions))
   {
      g_alerts.TransitionToPreSignal(
         symbol,
         PERIOD_H1,
         lookingForBuy ? DIRECTION_BUY : DIRECTION_SELL,
         preConditions
      );
   }
}

//+------------------------------------------------------------------+
//| Évaluer les conditions PRE_SIGNAL (3/5 minimum)                   |
//| 1. Compression détectée                                           |
//| 2. Accumulation/Distribution                                      |
//| 3. Proche zone majeure (SR/OB/FVG/Fibo)                          |
//| 4. Divergence NON confirmée                                       |
//| 5. Confluence EMA (prix proche EMA 50/200)                        |
//+------------------------------------------------------------------+
void EvaluatePreSignalConditions(int index, bool lookingForBuy, SPreSignalConditions &cond)
{
   string symbol = g_symbols[index];
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);

   // 1. Compression détectée (ATR en baisse, Bollinger serrées)
   cond.hasCompression = DetectCompression(index);

   // 2. Accumulation/Distribution
   SVolumeData volData = g_volume[index].Analyze(1);
   cond.hasAccumulation = volData.isAccumulation;

   // 3. Proche zone majeure
   cond.nearMajorZone = IsNearMajorZone(index, price, lookingForBuy);

   // 4. Divergence NON confirmée (en formation)
   SDivergence div;
   if(g_divergences[index].GetActiveDivergenceCount() > 0 &&
      g_divergences[index].GetActiveDivergence(0, div))
   {
      // Divergence présente mais PAS encore confirmée
      cond.hasDivergence = !div.isConfirmed;
   }

   // 5. Confluence EMA (prix proche EMA 50 ou 200)
   cond.hasEMAConfluence = IsNearEMA(index, price);

   cond.Calculate();
}

//+------------------------------------------------------------------+
//| Évaluer les conditions SETUP (4/5 minimum)                        |
//| 1. Contexte MTF aligné                                            |
//| 2. Zone de confluence                                             |
//| 3. Signal bougie (rejet ≥50% ou impulsion ≥70%)                  |
//| 4. Volume ≥ 150%                                                  |
//| 5. Structure SMC (BOS/CHoCH)                                      |
//+------------------------------------------------------------------+
void EvaluateSetupConditions(int index, bool lookingForBuy, SMTFAnalysis &mtf, SSetupConditions &cond)
{
   string symbol = g_symbols[index];
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);

   // 1. Contexte MTF aligné
   cond.contextOK = mtf.isValidSetup;

   // 2. Zone de confluence (SR + Fibo + SMC)
   cond.confluenceOK = HasConfluenceZone(index, price, lookingForBuy);

   // 3. Signal bougie (rejet mèche ≥50% OU impulsion corps ≥70%)
   cond.candleSignalOK = HasValidCandleSignal(index, lookingForBuy);

   // 4. Volume ≥ 150%
   SVolumeData volData = g_volume[index].Analyze(1);
   cond.volumeOK = (volData.volumeRatio >= InpMinVolumeRatio);

   // 5. Structure SMC (BOS ou CHoCH aligné)
   cond.structureOK = HasValidStructure(index, lookingForBuy);

   cond.Calculate();
}

//+------------------------------------------------------------------+
//| Détecter la compression (range qui se resserre)                   |
//+------------------------------------------------------------------+
bool DetectCompression(int index)
{
   string symbol = g_symbols[index];

   // Vérifier que l'ATR diminue
   double atr5 = 0, atr20 = 0;

   for(int i = 1; i <= 5; i++)
   {
      double h = iHigh(symbol, PERIOD_H1, i);
      double l = iLow(symbol, PERIOD_H1, i);
      atr5 += (h - l);
   }
   atr5 /= 5;

   for(int i = 1; i <= 20; i++)
   {
      double h = iHigh(symbol, PERIOD_H1, i);
      double l = iLow(symbol, PERIOD_H1, i);
      atr20 += (h - l);
   }
   atr20 /= 20;

   // ATR récent < 70% de l'ATR moyen = compression
   return (atr5 < atr20 * 0.7);
}

//+------------------------------------------------------------------+
//| Vérifier si proche d'une zone majeure                             |
//+------------------------------------------------------------------+
bool IsNearMajorZone(int index, double price, bool lookingForBuy)
{
   string symbol = g_symbols[index];

   // Vérifier S/R
   g_sr[index].DetectLevels();
   double srLevel = 0;
   if(lookingForBuy)
   {
      if(g_sr[index].IsPriceAtSupport(price, srLevel))
         return true;
   }
   else
   {
      if(g_sr[index].IsPriceAtResistance(price, srLevel))
         return true;
   }

   // Vérifier Fibonacci Golden Zone
   g_fib[index].Analyze();
   if(g_fib[index].IsPriceInGoldenZone(price))
      return true;

   // Vérifier OB/FVG
   if(lookingForBuy)
   {
      if(g_smc[index].IsPriceInAnyBullishOB(price) ||
         g_smc[index].IsPriceInAnyBullishFVG(price))
         return true;
   }
   else
   {
      if(g_smc[index].IsPriceInAnyBearishOB(price) ||
         g_smc[index].IsPriceInAnyBearishFVG(price))
         return true;
   }

   // Vérifier proximité (dans les 1% de distance)
   double distBullish = g_smc[index].GetDistanceToNearestBullishZone(price);
   double distBearish = g_smc[index].GetDistanceToNearestBearishZone(price);

   if(lookingForBuy && distBullish < price * 0.01)
      return true;
   if(!lookingForBuy && distBearish < price * 0.01)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si prix proche EMA 50/200                                |
//+------------------------------------------------------------------+
bool IsNearEMA(int index, double price)
{
   double ema50 = g_ema[index].GetEMA50(1);
   double ema200 = g_ema[index].GetEMA200(1);

   double tolerance = price * 0.005; // 0.5%

   if(MathAbs(price - ema50) < tolerance)
      return true;
   if(MathAbs(price - ema200) < tolerance)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la confluence de zone                                    |
//+------------------------------------------------------------------+
bool HasConfluenceZone(int index, double price, bool lookingForBuy)
{
   int confluenceCount = 0;

   // S/R
   g_sr[index].DetectLevels();
   double srLevel = 0;
   if(lookingForBuy)
   {
      if(g_sr[index].IsPriceAtSupport(price, srLevel))
         confluenceCount++;
   }
   else
   {
      if(g_sr[index].IsPriceAtResistance(price, srLevel))
         confluenceCount++;
   }

   // Fibonacci
   g_fib[index].Analyze();
   if(g_fib[index].IsPriceInGoldenZone(price))
      confluenceCount++;

   // SMC (OB ou FVG)
   if(g_smc[index].HasSMCConfluence(price, lookingForBuy))
      confluenceCount++;

   // EMA
   if(IsNearEMA(index, price))
      confluenceCount++;

   // Au moins 2 confluences
   return (confluenceCount >= 2);
}

//+------------------------------------------------------------------+
//| Vérifier signal bougie valide                                     |
//| Rejet = mèche ≥ 50% du range                                      |
//| Impulsion = corps ≥ 70% du range                                  |
//+------------------------------------------------------------------+
bool HasValidCandleSignal(int index, bool lookingForBuy)
{
   SCandleData candle = g_candle[index].AnalyzeCandle(1);

   if(lookingForBuy)
   {
      // Rejet haussier (longue mèche basse) ou impulsion haussière
      bool isRejection = (candle.anatomy.lowerWickRatio >= 50.0 && candle.anatomy.isBullish);
      bool isImpulse = (candle.anatomy.bodyRatio >= 70.0 && candle.anatomy.isBullish);
      return (isRejection || isImpulse);
   }
   else
   {
      // Rejet baissier (longue mèche haute) ou impulsion baissière
      bool isRejection = (candle.anatomy.upperWickRatio >= 50.0 && !candle.anatomy.isBullish);
      bool isImpulse = (candle.anatomy.bodyRatio >= 70.0 && !candle.anatomy.isBullish);
      return (isRejection || isImpulse);
   }
}

//+------------------------------------------------------------------+
//| Vérifier structure SMC valide (BOS/CHoCH aligné)                  |
//+------------------------------------------------------------------+
bool HasValidStructure(int index, bool lookingForBuy)
{
   SStructureAnalysis structure = g_structure[index].GetFullAnalysis();

   if(lookingForBuy)
   {
      // Structure bullish ou transition bullish (CHoCH)
      if(structure.state == STRUCTURE_BULLISH)
         return true;

      // CHoCH bullish récent
      if(structure.lastEvent.eventType == EVENT_CHOCH_BULLISH &&
         structure.barsSinceEvent <= 5)
         return true;

      // BOS bullish récent
      if(structure.lastEvent.eventType == EVENT_BOS_BULLISH &&
         structure.barsSinceEvent <= 3)
         return true;
   }
   else
   {
      // Structure bearish ou transition bearish
      if(structure.state == STRUCTURE_BEARISH)
         return true;

      // CHoCH bearish récent
      if(structure.lastEvent.eventType == EVENT_CHOCH_BEARISH &&
         structure.barsSinceEvent <= 5)
         return true;

      // BOS bearish récent
      if(structure.lastEvent.eventType == EVENT_BOS_BEARISH &&
         structure.barsSinceEvent <= 3)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calculer les niveaux de trade (Entry, SL, TP1, TP2)               |
//+------------------------------------------------------------------+
void CalculateTradeLevels(int index, bool lookingForBuy,
                          double &entry, double &sl, double &tp1, double &tp2, double &riskPct)
{
   string symbol = g_symbols[index];
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Entry = prix actuel ou zone OB/FVG
   entry = price;

   // Chercher meilleure entrée dans zone OB
   if(lookingForBuy)
   {
      SOrderBlock ob = g_smc[index].GetNearestBullishOB(price);
      if(ob.isValid && ob.high > price * 0.99) // Zone proche
         entry = ob.midPoint;
   }
   else
   {
      SOrderBlock ob = g_smc[index].GetNearestBearishOB(price);
      if(ob.isValid && ob.low < price * 1.01)
         entry = ob.midPoint;
   }

   // SL basé sur structure (swing low/high)
   SStructureAnalysis structure = g_structure[index].GetFullAnalysis();

   if(lookingForBuy)
   {
      // SL sous le dernier swing low
      sl = structure.keyLowLevel - 10 * point;
   }
   else
   {
      // SL au-dessus du dernier swing high
      sl = structure.keyHighLevel + 10 * point;
   }

   // Calculer distance SL
   double slDistance = MathAbs(entry - sl);

   // TP basé sur Fibonacci extensions
   g_fib[index].Analyze();
   SFibLevels fibLevels = g_fib[index].GetFibLevels();

   if(lookingForBuy)
   {
      tp1 = entry + slDistance * 1.5;  // 1.5R
      tp2 = entry + slDistance * 2.5;  // 2.5R

      // Si Fibo disponible, utiliser extensions
      if(fibLevels.ext1272 > 0)
      {
         tp1 = g_fib[index].GetTP1();
         tp2 = g_fib[index].GetTP2();
      }
   }
   else
   {
      tp1 = entry - slDistance * 1.5;
      tp2 = entry - slDistance * 2.5;

      if(fibLevels.ext1272 > 0)
      {
         tp1 = g_fib[index].GetTP1();
         tp2 = g_fib[index].GetTP2();
      }
   }

   // Risque
   riskPct = InpRiskPercent;
}

//+------------------------------------------------------------------+
//| Vérifier conditions de SORTIE                                     |
//| Priorité maximale - annule tout le reste                          |
//+------------------------------------------------------------------+
bool CheckExitConditions(int index)
{
   string symbol = g_symbols[index];

   // Obtenir le setup actif
   SActiveSetup setup = g_alerts.GetActiveSetup(symbol);
   if(!setup.isValid) return false;

   bool lookingForBuy = (setup.direction == DIRECTION_BUY);

   SExitConditions exitCond;
   exitCond.Reset();

   // 1. CHoCH contre la position
   SStructureAnalysis structure = g_structure[index].GetFullAnalysis();
   if(lookingForBuy)
   {
      exitCond.hasChochAgainst = (structure.lastEvent.eventType == EVENT_CHOCH_BEARISH &&
                                  structure.barsSinceEvent <= 3);
   }
   else
   {
      exitCond.hasChochAgainst = (structure.lastEvent.eventType == EVENT_CHOCH_BULLISH &&
                                  structure.barsSinceEvent <= 3);
   }

   // 2. BOS inverse sur HTF (H4)
   if(lookingForBuy)
   {
      exitCond.hasBosInverse = (structure.lastEvent.eventType == EVENT_BOS_BEARISH &&
                                structure.barsSinceEvent <= 2);
   }
   else
   {
      exitCond.hasBosInverse = (structure.lastEvent.eventType == EVENT_BOS_BULLISH &&
                                structure.barsSinceEvent <= 2);
   }

   // 3. Divergence contraire confirmée
   SDivergence div;
   if(g_divergences[index].GetActiveDivergenceCount() > 0 &&
      g_divergences[index].GetActiveDivergence(0, div) && div.isConfirmed)
   {
      if(lookingForBuy && (div.type == DIV_BEARISH_REGULAR || div.type == DIV_BEARISH_HIDDEN))
         exitCond.hasDivergenceConfirmed = true;
      if(!lookingForBuy && (div.type == DIV_BULLISH_REGULAR || div.type == DIV_BULLISH_HIDDEN))
         exitCond.hasDivergenceConfirmed = true;
   }

   // 4. Bougie opposée forte (corps > 70%)
   SCandleData candle = g_candle[index].AnalyzeCandle(1);
   if(lookingForBuy)
   {
      exitCond.hasStrongOppositeCandle = (!candle.anatomy.isBullish && candle.anatomy.bodyRatio >= 70.0);
   }
   else
   {
      exitCond.hasStrongOppositeCandle = (candle.anatomy.isBullish && candle.anatomy.bodyRatio >= 70.0);
   }

   // 5. Volume de retournement anormal
   SVolumeData volData = g_volume[index].Analyze(1);
   if(volData.volumeRatio >= 250.0) // Spike de volume
   {
      // Si volume spike avec bougie opposée
      if((lookingForBuy && !candle.anatomy.isBullish) ||
         (!lookingForBuy && candle.anatomy.isBullish))
      {
         exitCond.hasVolumeReversal = true;
      }
   }

   // 6. Cassure EMA 50/200
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ema50 = g_ema[index].GetEMA50(1);
   double ema200 = g_ema[index].GetEMA200(1);

   if(lookingForBuy)
   {
      // Cassure sous EMA 50 ou 200
      exitCond.hasEMABreak = (price < ema50 && iClose(symbol, PERIOD_H1, 2) > ema50) ||
                             (price < ema200 && iClose(symbol, PERIOD_H1, 2) > ema200);
   }
   else
   {
      // Cassure au-dessus EMA 50 ou 200
      exitCond.hasEMABreak = (price > ema50 && iClose(symbol, PERIOD_H1, 2) < ema50) ||
                             (price > ema200 && iClose(symbol, PERIOD_H1, 2) < ema200);
   }

   // 7. Désalignement MTF
   SMTFAnalysis mtf = g_mtf[index].Analyze();
   if(!mtf.isValidSetup)
   {
      exitCond.hasMTFMisalignment = true;
   }
   else if((lookingForBuy && mtf.direction == "SELL") ||
           (!lookingForBuy && mtf.direction == "BUY"))
   {
      exitCond.hasMTFMisalignment = true;
   }

   // Déterminer la raison principale
   exitCond.DetermineMainReason();

   // Si au moins une condition de sortie
   if(exitCond.HasAnyExitSignal())
   {
      g_alerts.TransitionToExit(symbol, exitCond);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si mise à jour du setup nécessaire (MJ_SETUP)            |
//+------------------------------------------------------------------+
void CheckSetupUpdate(int index)
{
   string symbol = g_symbols[index];
   SActiveSetup setup = g_alerts.GetActiveSetup(symbol);

   if(!setup.isValid) return;

   bool lookingForBuy = (setup.direction == DIRECTION_BUY);

   // Calculer nouveaux niveaux
   double newEntry, newSL, newTP1, newTP2, riskPct;
   CalculateTradeLevels(index, lookingForBuy, newEntry, newSL, newTP1, newTP2, riskPct);

   // Vérifier si changements significatifs (> 0.1%)
   bool entryChanged = (MathAbs(newEntry - setup.entryPrice) / setup.entryPrice > 0.001);
   bool slChanged = (MathAbs(newSL - setup.stopLoss) / setup.stopLoss > 0.001);
   bool tp1Changed = (MathAbs(newTP1 - setup.tp1) / setup.tp1 > 0.001);
   bool tp2Changed = (MathAbs(newTP2 - setup.tp2) / setup.tp2 > 0.001);

   string contextChange = "";

   // Vérifier si contexte amélioré
   SSetupConditions cond;
   SMTFAnalysis mtf = g_mtf[index].Analyze();
   EvaluateSetupConditions(index, lookingForBuy, mtf, cond);

   if(cond.validCount > setup.conditionsValidated)
   {
      contextChange = "Conditions améliorées: " + IntegerToString(cond.validCount) + "/5";
   }

   // Mise à jour si changement
   if(entryChanged || slChanged || tp1Changed || tp2Changed || contextChange != "")
   {
      g_alerts.UpdateActiveSetup(
         symbol,
         entryChanged ? newEntry : 0,
         slChanged ? newSL : 0,
         tp1Changed ? newTP1 : 0,
         tp2Changed ? newTP2 : 0,
         contextChange
      );
   }
}

//+------------------------------------------------------------------+
//| Afficher le statut sur le graphique                               |
//+------------------------------------------------------------------+
void DisplayStatus()
{
   string status = "";
   status += "═══════════════════════════════════════════════════\n";
   status += "   BOT ANALYSTE v2.0 - MACHINE À ÉTATS\n";
   status += "   ⚠️ NE TRADE PAS - ANALYSE UNIQUEMENT\n";
   status += "═══════════════════════════════════════════════════\n\n";

   for(int i = 0; i < g_symbolCount; i++)
   {
      string symbol = g_symbols[i];
      ENUM_BOT_STATE state = g_alerts.GetMarketState(symbol);

      status += symbol + ": ";

      switch(state)
      {
         case STATE_NEUTRAL:
            status += "⚪ NEUTRAL";
            break;
         case STATE_PRE_SIGNAL:
            status += "🟡 PRE_SIGNAL";
            break;
         case STATE_SETUP_ACTIVE:
            {
               SActiveSetup setup = g_alerts.GetActiveSetup(symbol);
               string dir = (setup.direction == DIRECTION_BUY) ? "BUY" : "SELL";
               status += "🚨 SETUP_ACTIVE [" + dir + "]";
               status += "\n       Entry: " + DoubleToString(setup.entryPrice, 5);
               status += " SL: " + DoubleToString(setup.stopLoss, 5);
            }
            break;
         case STATE_EXIT_PRIORITY:
            status += "🟢 EXIT_PRIORITY";
            break;
      }
      status += "\n";
   }

   status += "\n───────────────────────────────────────────────────\n";
   status += "Risque/Trade: " + DoubleToString(InpRiskPercent, 1) + "%\n";
   status += "Volume min: " + DoubleToString(InpMinVolumeRatio, 0) + "%\n";
   status += "───────────────────────────────────────────────────\n";

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
