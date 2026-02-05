//+------------------------------------------------------------------+
//|                                               AlertSystem.mqh    |
//|                  SYSTÈME D'ALERTES PROFESSIONNEL - MACHINE À ÉTATS|
//|                     Bot Analyste Multi-Marchés Forex & Crypto     |
//+------------------------------------------------------------------+
#property copyright "Trading Bot - Professional Alert System"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE DU SYSTÈME:                                           |
//|                                                                   |
//| Le bot ne cherche PAS des trades                                  |
//| Il attend des opportunités de CLASSE A                            |
//|                                                                   |
//| ⚠️ PAS DE TRADE - Uniquement analyse et alertes                   |
//| ⚠️ PAS DE SPAM - Alertes disciplinées et hiérarchisées           |
//|                                                                   |
//| Machine à états: NEUTRAL → PRE_SIGNAL → SETUP_ACTIVE → EXIT      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ÉNUMÉRATIONS                                                      |
//+------------------------------------------------------------------+

//--- États de la machine (4 états exclusifs)
enum ENUM_BOT_STATE
{
   STATE_NEUTRAL,           // Pas d'opportunité en cours
   STATE_PRE_SIGNAL,        // Contexte en cours (3/5 conditions)
   STATE_SETUP_ACTIVE,      // Setup Classe A confirmé
   STATE_EXIT_PRIORITY      // Sortie recommandée (priorité max)
};

//--- Types d'alertes
enum ENUM_ALERT_TYPE
{
   ALERT_TYPE_NONE = 0,
   ALERT_TYPE_PRE_SIGNAL,   // Contexte en cours
   ALERT_TYPE_SETUP_SIGNAL, // Setup confirmé
   ALERT_TYPE_MJ_SETUP,     // Mise à jour setup
   ALERT_TYPE_EXIT,         // Sortie recommandée
   ALERT_TYPE_INFO          // Information
};

//--- Priorités
enum ENUM_ALERT_PRIORITY
{
   PRIORITY_INFO = 0,       // Information simple
   PRIORITY_LOW,            // Basse
   PRIORITY_MEDIUM,         // Moyenne
   PRIORITY_HIGH,           // Haute
   PRIORITY_CRITICAL        // Critique (sortie)
};

//--- Direction du setup
enum ENUM_SETUP_DIRECTION
{
   DIRECTION_NONE = 0,
   DIRECTION_BUY,           // Achat
   DIRECTION_SELL           // Vente
};

//--- Raisons de sortie
enum ENUM_EXIT_REASON
{
   EXIT_NONE = 0,
   EXIT_CHOCH_AGAINST,      // CHoCH contre position
   EXIT_BOS_INVERSE,        // BOS inverse HTF
   EXIT_DIVERGENCE,         // Divergence contraire confirmée
   EXIT_STRONG_CANDLE,      // Bougie opposée forte (>70%)
   EXIT_VOLUME_REVERSAL,    // Volume de retournement
   EXIT_EMA_BREAK,          // Cassure EMA 50/200
   EXIT_MTF_MISALIGNMENT,   // Désalignement MTF
   EXIT_ZONE_INVALIDATED    // Zone invalidée
};

//--- Raisons de PRE_SIGNAL
enum ENUM_PRESIGNAL_REASON
{
   PRESIGNAL_COMPRESSION,   // Compression détectée
   PRESIGNAL_ACCUMULATION,  // Accumulation/Distribution
   PRESIGNAL_ZONE_APPROACH, // Approche zone majeure
   PRESIGNAL_DIVERGENCE,    // Divergence non confirmée
   PRESIGNAL_EMA_CONFLUENCE // Confluence EMA
};

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES                                             |
//+------------------------------------------------------------------+

//--- Setup actif (stocke les infos d'un setup en cours)
struct SActiveSetup
{
   // Identification
   int                     id;              // ID unique
   string                  symbol;          // Symbole
   ENUM_TIMEFRAMES         timeframe;       // TF du setup
   ENUM_SETUP_DIRECTION    direction;       // BUY ou SELL

   // Prix
   double                  entryPrice;      // Prix d'entrée
   double                  stopLoss;        // Stop Loss
   double                  tp1;             // Take Profit 1
   double                  tp2;             // Take Profit 2

   // Contexte
   double                  riskPercent;     // Risque en %
   int                     conditionsValidated; // Conditions validées (sur 5)
   string                  reason;          // Raison du setup

   // Suivi
   datetime                createdAt;       // Date création
   datetime                lastUpdate;      // Dernière mise à jour
   int                     updateCount;     // Nombre de MJ
   bool                    isValid;         // Toujours valide

   void Reset()
   {
      id = 0;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      direction = DIRECTION_NONE;
      entryPrice = 0;
      stopLoss = 0;
      tp1 = 0;
      tp2 = 0;
      riskPercent = 0;
      conditionsValidated = 0;
      reason = "";
      createdAt = 0;
      lastUpdate = 0;
      updateCount = 0;
      isValid = false;
   }
};

//--- État d'un marché
struct SMarketState
{
   string                  symbol;
   ENUM_BOT_STATE          state;
   SActiveSetup            activeSetup;
   datetime                lastAlertTime;
   datetime                lastStateChange;
   ENUM_ALERT_TYPE         lastAlertType;
   int                     preSignalCount;  // Conditions PRE_SIGNAL validées
   bool                    preSignalReasons[5]; // Compression, Accumulation, Zone, Divergence, EMA

   void Reset()
   {
      symbol = "";
      state = STATE_NEUTRAL;
      activeSetup.Reset();
      lastAlertTime = 0;
      lastStateChange = 0;
      lastAlertType = ALERT_TYPE_NONE;
      preSignalCount = 0;
      for(int i = 0; i < 5; i++) preSignalReasons[i] = false;
   }
};

//--- Alerte complète
struct SAlertData
{
   ENUM_ALERT_TYPE         type;
   ENUM_ALERT_PRIORITY     priority;
   string                  symbol;
   ENUM_TIMEFRAMES         timeframe;
   ENUM_SETUP_DIRECTION    direction;
   string                  title;
   string                  body;
   double                  entryPrice;
   double                  stopLoss;
   double                  tp1;
   double                  tp2;
   double                  riskPercent;
   ENUM_EXIT_REASON        exitReason;
   datetime                time;
   bool                    isSent;

   void Reset()
   {
      type = ALERT_TYPE_NONE;
      priority = PRIORITY_INFO;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      direction = DIRECTION_NONE;
      title = "";
      body = "";
      entryPrice = 0;
      stopLoss = 0;
      tp1 = 0;
      tp2 = 0;
      riskPercent = 0;
      exitReason = EXIT_NONE;
      time = 0;
      isSent = false;
   }
};

//--- Conditions PRE_SIGNAL
struct SPreSignalConditions
{
   bool hasCompression;       // Range qui se resserre
   bool hasAccumulation;      // Accumulation/Distribution
   bool nearMajorZone;        // Proche zone majeure (SR/OB/FVG/Fibo)
   bool hasDivergence;        // Divergence NON confirmée
   bool hasEMAConfluence;     // Prix proche EMA 50/200
   int  validCount;           // Nombre validé (sur 5)

   void Reset()
   {
      hasCompression = false;
      hasAccumulation = false;
      nearMajorZone = false;
      hasDivergence = false;
      hasEMAConfluence = false;
      validCount = 0;
   }

   void Calculate()
   {
      validCount = 0;
      if(hasCompression) validCount++;
      if(hasAccumulation) validCount++;
      if(nearMajorZone) validCount++;
      if(hasDivergence) validCount++;
      if(hasEMAConfluence) validCount++;
   }
};

//--- Conditions SETUP_SIGNAL (Checklist)
struct SSetupConditions
{
   bool contextOK;            // Contexte MTF aligné
   bool confluenceOK;         // Zone de confluence
   bool candleSignalOK;       // Signal bougie (rejet/impulsion)
   bool volumeOK;             // Volume >= 150%
   bool structureOK;          // Structure SMC
   int  validCount;           // Nombre validé (sur 5)

   void Reset()
   {
      contextOK = false;
      confluenceOK = false;
      candleSignalOK = false;
      volumeOK = false;
      structureOK = false;
      validCount = 0;
   }

   void Calculate()
   {
      validCount = 0;
      if(contextOK) validCount++;
      if(confluenceOK) validCount++;
      if(candleSignalOK) validCount++;
      if(volumeOK) validCount++;
      if(structureOK) validCount++;
   }
};

//--- Conditions EXIT
struct SExitConditions
{
   bool hasChochAgainst;      // CHoCH contre position
   bool hasBosInverse;        // BOS inverse HTF
   bool hasDivergenceConfirmed; // Divergence contraire confirmée
   bool hasStrongOppositeCandle; // Bougie opposée > 70%
   bool hasVolumeReversal;    // Volume de retournement
   bool hasEMABreak;          // Cassure EMA 50/200
   bool hasMTFMisalignment;   // Désalignement MTF
   ENUM_EXIT_REASON mainReason;

   void Reset()
   {
      hasChochAgainst = false;
      hasBosInverse = false;
      hasDivergenceConfirmed = false;
      hasStrongOppositeCandle = false;
      hasVolumeReversal = false;
      hasEMABreak = false;
      hasMTFMisalignment = false;
      mainReason = EXIT_NONE;
   }

   bool HasAnyExitSignal()
   {
      return (hasChochAgainst || hasBosInverse || hasDivergenceConfirmed ||
              hasStrongOppositeCandle || hasVolumeReversal || hasEMABreak ||
              hasMTFMisalignment);
   }

   void DetermineMainReason()
   {
      // Priorité: CHoCH > BOS > Divergence > Candle > Volume > EMA > MTF
      if(hasChochAgainst) mainReason = EXIT_CHOCH_AGAINST;
      else if(hasBosInverse) mainReason = EXIT_BOS_INVERSE;
      else if(hasDivergenceConfirmed) mainReason = EXIT_DIVERGENCE;
      else if(hasStrongOppositeCandle) mainReason = EXIT_STRONG_CANDLE;
      else if(hasVolumeReversal) mainReason = EXIT_VOLUME_REVERSAL;
      else if(hasEMABreak) mainReason = EXIT_EMA_BREAK;
      else if(hasMTFMisalignment) mainReason = EXIT_MTF_MISALIGNMENT;
      else mainReason = EXIT_NONE;
   }
};

//+------------------------------------------------------------------+
//| CLASSE PRINCIPALE - Système d'Alertes avec Machine à États        |
//+------------------------------------------------------------------+
class CAlertSystem
{
private:
   //--- Configuration
   bool                    m_enablePush;
   bool                    m_enableEmail;
   bool                    m_enableSound;
   bool                    m_enablePopup;
   bool                    m_enableTelegram;
   string                  m_telegramBotToken;
   string                  m_telegramChatId;

   //--- Anti-spam
   int                     m_minAlertIntervalSec;    // Intervalle min entre alertes (même type)
   int                     m_preSignalCooldownSec;   // Cooldown PRE_SIGNAL
   int                     m_setupAlertCooldownSec;  // Cooldown SETUP

   //--- États des marchés
   SMarketState            m_marketStates[];
   int                     m_marketCount;

   //--- Historique
   SAlertData              m_alertHistory[];
   int                     m_maxHistory;

   //--- ID Generator
   int                     m_nextSetupId;

   //--- Méthodes privées - État
   int                     FindMarketIndex(string symbol);
   int                     AddMarket(string symbol);
   bool                    CanSendAlert(int marketIndex, ENUM_ALERT_TYPE type);
   void                    UpdateLastAlertTime(int marketIndex, ENUM_ALERT_TYPE type);

   //--- Méthodes privées - Formatage
   string                  FormatPreSignalAlert(string symbol, ENUM_TIMEFRAMES tf,
                                                ENUM_SETUP_DIRECTION dir, SPreSignalConditions &cond);
   string                  FormatSetupSignalAlert(SActiveSetup &setup, SSetupConditions &cond);
   string                  FormatMJSetupAlert(SActiveSetup &setup, string changes);
   string                  FormatExitAlert(SActiveSetup &setup, ENUM_EXIT_REASON reason);

   //--- Méthodes privées - Envoi
   void                    DoSendAlert(SAlertData &alert);
   void                    SendPushNotification(string title, string message);
   void                    SendEmailNotification(string subject, string body);
   void                    SendTelegramNotification(string message);
   void                    PlayAlertSound(ENUM_ALERT_PRIORITY priority);
   void                    ShowPopup(string message);

   //--- Méthodes privées - Historique
   void                    AddToHistory(SAlertData &alert);

   //--- Méthodes privées - Utilitaires
   string                  TimeframeToString(ENUM_TIMEFRAMES tf);
   string                  DirectionToString(ENUM_SETUP_DIRECTION dir);
   string                  StateToString(ENUM_BOT_STATE state);
   string                  ExitReasonToString(ENUM_EXIT_REASON reason);
   string                  DoubleToStr(double value, int digits);

public:
   //--- Constructeur/Destructeur
                           CAlertSystem();
                          ~CAlertSystem();

   //--- Initialisation
   bool                    Init();
   void                    Deinit();

   //--- Configuration
   void                    EnablePush(bool enable)      { m_enablePush = enable; }
   void                    EnableEmail(bool enable)     { m_enableEmail = enable; }
   void                    EnableSound(bool enable)     { m_enableSound = enable; }
   void                    EnablePopup(bool enable)     { m_enablePopup = enable; }
   void                    EnableTelegram(bool enable, string token, string chatId);
   void                    SetMinInterval(int seconds)  { m_minAlertIntervalSec = seconds; }
   void                    SetPreSignalCooldown(int seconds) { m_preSignalCooldownSec = seconds; }
   void                    SetSetupCooldown(int seconds) { m_setupAlertCooldownSec = seconds; }

   //--- ============ MACHINE À ÉTATS ============

   //--- Obtenir l'état actuel d'un marché
   ENUM_BOT_STATE          GetMarketState(string symbol);

   //--- Transition vers PRE_SIGNAL
   //--- CONDITIONS: 3 sur 5 minimum
   bool                    TransitionToPreSignal(string symbol, ENUM_TIMEFRAMES tf,
                                                 ENUM_SETUP_DIRECTION dir,
                                                 SPreSignalConditions &conditions);

   //--- Transition vers SETUP_ACTIVE
   //--- CONDITIONS: 4 sur 5 minimum + Volume >= 150% + Bougie clôturée
   bool                    TransitionToSetupActive(string symbol, ENUM_TIMEFRAMES tf,
                                                   ENUM_SETUP_DIRECTION dir,
                                                   SSetupConditions &conditions,
                                                   double entry, double sl, double tp1, double tp2,
                                                   double riskPct);

   //--- Mise à jour d'un setup existant (MJ_SETUP)
   //--- CONDITIONS: Setup existant + au moins 1 élément changé
   bool                    UpdateActiveSetup(string symbol,
                                             double newEntry = 0, double newSL = 0,
                                             double newTP1 = 0, double newTP2 = 0,
                                             string contextChange = "");

   //--- Transition vers EXIT_PRIORITY
   //--- CONDITIONS: Au moins 1 condition de sortie
   bool                    TransitionToExit(string symbol, SExitConditions &conditions);

   //--- Retour à NEUTRAL
   void                    ResetToNeutral(string symbol);

   //--- ============ GETTERS ============

   //--- Obtenir le setup actif d'un marché
   SActiveSetup            GetActiveSetup(string symbol);
   bool                    HasActiveSetup(string symbol);

   //--- Historique
   int                     GetHistoryCount();
   SAlertData              GetHistoryAlert(int index);
   void                    ClearHistory();

   //--- ============ VALIDATION CHECKLIST ============

   //--- Valider les conditions PRE_SIGNAL (3/5 minimum)
   bool                    ValidatePreSignalConditions(SPreSignalConditions &cond);

   //--- Valider les conditions SETUP (4/5 minimum)
   bool                    ValidateSetupConditions(SSetupConditions &cond);

   //--- Valider les conditions EXIT (au moins 1)
   bool                    ValidateExitConditions(SExitConditions &cond);

   //--- ============ COMPATIBILITÉ ANCIENNE API ============
   bool                    ValidateChecklist(bool contextOK, bool confluenceOK,
                                             bool candleSignalOK, bool volumeOK,
                                             bool structureOK, int &validatedCount);
   void                    SendSetupAlert(string symbol, ENUM_TIMEFRAMES tf, bool isBuy,
                                          string message, string details, int conditions);
   void                    SendPatternAlert(string symbol, ENUM_TIMEFRAMES tf,
                                            string patternName, string details);
   void                    SendSMCAlert(string symbol, ENUM_TIMEFRAMES tf, string smcType, string details);
   void                    SendDivergenceAlert(string symbol, ENUM_TIMEFRAMES tf, string divType, string details);
   void                    SendMTFAlert(string symbol, string alignment, string details);
   void                    SendVolumeAlert(string symbol, ENUM_TIMEFRAMES tf, string volumeState, string details);
   void                    SendRiskAlert(string symbol, string message);

   //--- ============ NOTIFICATION DÉMARRAGE ============
   void                    SendStartupAlert(string symbol, ENUM_TIMEFRAMES tf);

   //--- ============ UTILITAIRES ============
   string                  GetStateSummary(string symbol);
   string                  GetAllMarketsSummary();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CAlertSystem::CAlertSystem()
{
   m_enablePush = true;
   m_enableEmail = false;
   m_enableSound = true;
   m_enablePopup = true;
   m_enableTelegram = false;
   m_telegramBotToken = "";
   m_telegramChatId = "";

   m_minAlertIntervalSec = 0;        // PAS de limite - alertes immédiates
   m_preSignalCooldownSec = 0;       // PAS de limite - alertes immédiates
   m_setupAlertCooldownSec = 0;      // PAS de limite - alertes immédiates

   m_marketCount = 0;
   m_maxHistory = 100;
   m_nextSetupId = 1;

   ArrayResize(m_marketStates, 0);
   ArrayResize(m_alertHistory, 0);
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CAlertSystem::~CAlertSystem()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CAlertSystem::Init()
{
   ArrayResize(m_marketStates, 0);
   ArrayResize(m_alertHistory, 0);
   m_marketCount = 0;
   m_nextSetupId = 1;

   Print("AlertSystem initialisé - Machine à états active");
   return true;
}

//+------------------------------------------------------------------+
//| Libération des ressources                                         |
//+------------------------------------------------------------------+
void CAlertSystem::Deinit()
{
   ArrayFree(m_marketStates);
   ArrayFree(m_alertHistory);
   m_marketCount = 0;
}

//+------------------------------------------------------------------+
//| Configuration Telegram                                            |
//+------------------------------------------------------------------+
void CAlertSystem::EnableTelegram(bool enable, string token, string chatId)
{
   m_enableTelegram = enable;
   m_telegramBotToken = token;
   m_telegramChatId = chatId;
}

//+------------------------------------------------------------------+
//| Trouver l'index d'un marché                                       |
//+------------------------------------------------------------------+
int CAlertSystem::FindMarketIndex(string symbol)
{
   for(int i = 0; i < m_marketCount; i++)
   {
      if(m_marketStates[i].symbol == symbol)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Ajouter un nouveau marché                                         |
//+------------------------------------------------------------------+
int CAlertSystem::AddMarket(string symbol)
{
   int index = FindMarketIndex(symbol);
   if(index >= 0) return index;

   ArrayResize(m_marketStates, m_marketCount + 1);
   m_marketStates[m_marketCount].Reset();
   m_marketStates[m_marketCount].symbol = symbol;
   m_marketStates[m_marketCount].state = STATE_NEUTRAL;

   m_marketCount++;
   return m_marketCount - 1;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut envoyer une alerte (anti-spam)               |
//+------------------------------------------------------------------+
bool CAlertSystem::CanSendAlert(int marketIndex, ENUM_ALERT_TYPE type)
{
   if(marketIndex < 0 || marketIndex >= m_marketCount)
      return false;

   datetime now = TimeCurrent();
   datetime lastAlert = m_marketStates[marketIndex].lastAlertTime;

   int cooldown = m_minAlertIntervalSec;

   switch(type)
   {
      case ALERT_TYPE_PRE_SIGNAL:
         cooldown = m_preSignalCooldownSec;
         break;
      case ALERT_TYPE_SETUP_SIGNAL:
         cooldown = m_setupAlertCooldownSec;
         break;
      case ALERT_TYPE_EXIT:
         cooldown = 0; // EXIT toujours prioritaire
         break;
      default:
         cooldown = m_minAlertIntervalSec;
         break;
   }

   return (now - lastAlert >= cooldown);
}

//+------------------------------------------------------------------+
//| Mettre à jour le temps de dernière alerte                         |
//+------------------------------------------------------------------+
void CAlertSystem::UpdateLastAlertTime(int marketIndex, ENUM_ALERT_TYPE type)
{
   if(marketIndex >= 0 && marketIndex < m_marketCount)
   {
      m_marketStates[marketIndex].lastAlertTime = TimeCurrent();
      m_marketStates[marketIndex].lastAlertType = type;
   }
}

//+------------------------------------------------------------------+
//| Obtenir l'état d'un marché                                        |
//+------------------------------------------------------------------+
ENUM_BOT_STATE CAlertSystem::GetMarketState(string symbol)
{
   int index = FindMarketIndex(symbol);
   if(index < 0) return STATE_NEUTRAL;

   return m_marketStates[index].state;
}

//+------------------------------------------------------------------+
//| Valider conditions PRE_SIGNAL (3/5 minimum)                       |
//+------------------------------------------------------------------+
bool CAlertSystem::ValidatePreSignalConditions(SPreSignalConditions &cond)
{
   cond.Calculate();
   return (cond.validCount >= 3);
}

//+------------------------------------------------------------------+
//| Valider conditions SETUP (4/5 minimum)                            |
//+------------------------------------------------------------------+
bool CAlertSystem::ValidateSetupConditions(SSetupConditions &cond)
{
   cond.Calculate();
   return (cond.validCount >= 4);
}

//+------------------------------------------------------------------+
//| Valider conditions EXIT (au moins 1)                              |
//+------------------------------------------------------------------+
bool CAlertSystem::ValidateExitConditions(SExitConditions &cond)
{
   cond.DetermineMainReason();
   return cond.HasAnyExitSignal();
}

//+------------------------------------------------------------------+
//| TRANSITION: NEUTRAL/PRE_SIGNAL → PRE_SIGNAL                       |
//| 🟡 PRE_SIGNAL - Contexte en cours (pas d'engagement)              |
//+------------------------------------------------------------------+
bool CAlertSystem::TransitionToPreSignal(string symbol, ENUM_TIMEFRAMES tf,
                                         ENUM_SETUP_DIRECTION dir,
                                         SPreSignalConditions &conditions)
{
   // Valider les conditions (3/5 minimum)
   if(!ValidatePreSignalConditions(conditions))
   {
      Print("PRE_SIGNAL refusé pour ", symbol, " - Conditions: ", conditions.validCount, "/5 (min 3)");
      return false;
   }

   int index = AddMarket(symbol);

   // Si déjà en SETUP_ACTIVE, pas de PRE_SIGNAL
   if(m_marketStates[index].state == STATE_SETUP_ACTIVE)
   {
      Print("PRE_SIGNAL ignoré pour ", symbol, " - SETUP_ACTIVE en cours");
      return false;
   }

   // Anti-spam
   if(!CanSendAlert(index, ALERT_TYPE_PRE_SIGNAL))
   {
      return false;
   }

   // Mettre à jour l'état
   m_marketStates[index].state = STATE_PRE_SIGNAL;
   m_marketStates[index].lastStateChange = TimeCurrent();
   m_marketStates[index].preSignalCount = conditions.validCount;
   m_marketStates[index].preSignalReasons[0] = conditions.hasCompression;
   m_marketStates[index].preSignalReasons[1] = conditions.hasAccumulation;
   m_marketStates[index].preSignalReasons[2] = conditions.nearMajorZone;
   m_marketStates[index].preSignalReasons[3] = conditions.hasDivergence;
   m_marketStates[index].preSignalReasons[4] = conditions.hasEMAConfluence;

   // Créer et envoyer l'alerte
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_PRE_SIGNAL;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.direction = dir;
   alert.title = "🟡 PRE_SIGNAL";
   alert.body = FormatPreSignalAlert(symbol, tf, dir, conditions);
   alert.time = TimeCurrent();

   DoSendAlert(alert);
   UpdateLastAlertTime(index, ALERT_TYPE_PRE_SIGNAL);

   Print("✓ PRE_SIGNAL émis pour ", symbol, " - Direction: ", DirectionToString(dir));
   return true;
}

//+------------------------------------------------------------------+
//| TRANSITION: PRE_SIGNAL → SETUP_ACTIVE                             |
//| 🚨 SETUP_SIGNAL - Entrée potentielle confirmée                    |
//+------------------------------------------------------------------+
bool CAlertSystem::TransitionToSetupActive(string symbol, ENUM_TIMEFRAMES tf,
                                           ENUM_SETUP_DIRECTION dir,
                                           SSetupConditions &conditions,
                                           double entry, double sl, double tp1, double tp2,
                                           double riskPct)
{
   // Valider les conditions (4/5 minimum)
   if(!ValidateSetupConditions(conditions))
   {
      Print("SETUP refusé pour ", symbol, " - Conditions: ", conditions.validCount, "/5 (min 4)");
      return false;
   }

   // Valider le volume (>= 150%)
   if(!conditions.volumeOK)
   {
      Print("SETUP refusé pour ", symbol, " - Volume insuffisant (<150%)");
      return false;
   }

   // Valider la bougie (rejet ou impulsion)
   if(!conditions.candleSignalOK)
   {
      Print("SETUP refusé pour ", symbol, " - Pas de signal bougie valide");
      return false;
   }

   int index = AddMarket(symbol);

   // Vérifier qu'il n'y a pas déjà un setup actif sur ce marché
   if(m_marketStates[index].state == STATE_SETUP_ACTIVE &&
      m_marketStates[index].activeSetup.isValid)
   {
      Print("SETUP ignoré pour ", symbol, " - Un setup est déjà actif");
      return false;
   }

   // Anti-spam
   if(!CanSendAlert(index, ALERT_TYPE_SETUP_SIGNAL))
   {
      return false;
   }

   // Créer le setup actif
   SActiveSetup setup;
   setup.Reset();
   setup.id = m_nextSetupId++;
   setup.symbol = symbol;
   setup.timeframe = tf;
   setup.direction = dir;
   setup.entryPrice = entry;
   setup.stopLoss = sl;
   setup.tp1 = tp1;
   setup.tp2 = tp2;
   setup.riskPercent = riskPct;
   setup.conditionsValidated = conditions.validCount;
   setup.createdAt = TimeCurrent();
   setup.lastUpdate = TimeCurrent();
   setup.updateCount = 0;
   setup.isValid = true;

   // Construire la raison
   setup.reason = "";
   if(conditions.contextOK) setup.reason += "MTF+ ";
   if(conditions.confluenceOK) setup.reason += "Zone+ ";
   if(conditions.candleSignalOK) setup.reason += "Bougie+ ";
   if(conditions.volumeOK) setup.reason += "Volume+ ";
   if(conditions.structureOK) setup.reason += "Structure+ ";

   // Mettre à jour l'état
   m_marketStates[index].state = STATE_SETUP_ACTIVE;
   m_marketStates[index].lastStateChange = TimeCurrent();
   m_marketStates[index].activeSetup = setup;

   // Créer et envoyer l'alerte
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_SETUP_SIGNAL;
   alert.priority = PRIORITY_HIGH;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.direction = dir;
   alert.title = "🚨 SETUP_SIGNAL";
   alert.body = FormatSetupSignalAlert(setup, conditions);
   alert.entryPrice = entry;
   alert.stopLoss = sl;
   alert.tp1 = tp1;
   alert.tp2 = tp2;
   alert.riskPercent = riskPct;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
   UpdateLastAlertTime(index, ALERT_TYPE_SETUP_SIGNAL);

   Print("✓ SETUP_SIGNAL émis pour ", symbol, " - ID: ", setup.id, " - Direction: ", DirectionToString(dir));
   return true;
}

//+------------------------------------------------------------------+
//| MISE À JOUR: SETUP_ACTIVE (MJ_SETUP)                              |
//| 🔁 MJ_SETUP - Ajustement d'un setup existant                      |
//+------------------------------------------------------------------+
bool CAlertSystem::UpdateActiveSetup(string symbol,
                                     double newEntry, double newSL,
                                     double newTP1, double newTP2,
                                     string contextChange)
{
   int index = FindMarketIndex(symbol);
   if(index < 0)
   {
      Print("MJ_SETUP refusé - Marché ", symbol, " non trouvé");
      return false;
   }

   // Vérifier qu'un setup existe
   if(m_marketStates[index].state != STATE_SETUP_ACTIVE ||
      !m_marketStates[index].activeSetup.isValid)
   {
      Print("MJ_SETUP refusé pour ", symbol, " - Pas de setup actif");
      return false;
   }

   // Vérifier qu'au moins 1 élément a changé
   string changes = "";
   bool hasChange = false;

   if(newEntry > 0 && newEntry != m_marketStates[index].activeSetup.entryPrice)
   {
      changes += "Entry: " + DoubleToStr(m_marketStates[index].activeSetup.entryPrice, 5) + " → " + DoubleToStr(newEntry, 5) + "\n";
      m_marketStates[index].activeSetup.entryPrice = newEntry;
      hasChange = true;
   }

   if(newSL > 0 && newSL != m_marketStates[index].activeSetup.stopLoss)
   {
      changes += "SL: " + DoubleToStr(m_marketStates[index].activeSetup.stopLoss, 5) + " → " + DoubleToStr(newSL, 5) + "\n";
      m_marketStates[index].activeSetup.stopLoss = newSL;
      hasChange = true;
   }

   if(newTP1 > 0 && newTP1 != m_marketStates[index].activeSetup.tp1)
   {
      changes += "TP1: " + DoubleToStr(m_marketStates[index].activeSetup.tp1, 5) + " → " + DoubleToStr(newTP1, 5) + "\n";
      m_marketStates[index].activeSetup.tp1 = newTP1;
      hasChange = true;
   }

   if(newTP2 > 0 && newTP2 != m_marketStates[index].activeSetup.tp2)
   {
      changes += "TP2: " + DoubleToStr(m_marketStates[index].activeSetup.tp2, 5) + " → " + DoubleToStr(newTP2, 5) + "\n";
      m_marketStates[index].activeSetup.tp2 = newTP2;
      hasChange = true;
   }

   if(contextChange != "")
   {
      changes += "Contexte: " + contextChange + "\n";
      hasChange = true;
   }

   if(!hasChange)
   {
      Print("MJ_SETUP refusé pour ", symbol, " - Aucun changement détecté");
      return false;
   }

   // Anti-spam (plus court pour MJ)
   if(!CanSendAlert(index, ALERT_TYPE_MJ_SETUP))
   {
      // Mettre à jour quand même mais sans alerte
      m_marketStates[index].activeSetup.lastUpdate = TimeCurrent();
      m_marketStates[index].activeSetup.updateCount++;
      return true;
   }

   // Mettre à jour
   m_marketStates[index].activeSetup.lastUpdate = TimeCurrent();
   m_marketStates[index].activeSetup.updateCount++;

   // Créer et envoyer l'alerte
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_MJ_SETUP;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = setup.timeframe;
   alert.direction = setup.direction;
   alert.title = "🔁 MJ_SETUP";
   alert.body = FormatMJSetupAlert(setup, changes);
   alert.entryPrice = setup.entryPrice;
   alert.stopLoss = setup.stopLoss;
   alert.tp1 = setup.tp1;
   alert.tp2 = setup.tp2;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
   UpdateLastAlertTime(index, ALERT_TYPE_MJ_SETUP);

   Print("✓ MJ_SETUP émis pour ", symbol, " - Update #", setup.updateCount);
   return true;
}

//+------------------------------------------------------------------+
//| TRANSITION: SETUP_ACTIVE → EXIT_PRIORITY                          |
//| 🟢 EXIT_ALERT - Sortie recommandée (priorité max)                 |
//+------------------------------------------------------------------+
bool CAlertSystem::TransitionToExit(string symbol, SExitConditions &conditions)
{
   // Valider qu'au moins 1 condition de sortie
   if(!ValidateExitConditions(conditions))
   {
      return false;
   }

   int index = FindMarketIndex(symbol);
   if(index < 0)
   {
      Print("EXIT refusé - Marché ", symbol, " non trouvé");
      return false;
   }

   // Doit avoir un setup actif
   if(m_marketStates[index].state != STATE_SETUP_ACTIVE ||
      !m_marketStates[index].activeSetup.isValid)
   {
      Print("EXIT refusé pour ", symbol, " - Pas de setup actif");
      return false;
   }

   // Mettre à jour l'état (priorité max, pas de cooldown)
   m_marketStates[index].state = STATE_EXIT_PRIORITY;
   m_marketStates[index].lastStateChange = TimeCurrent();

   // Créer et envoyer l'alerte
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_EXIT;
   alert.priority = PRIORITY_CRITICAL;
   alert.symbol = symbol;
   alert.timeframe = m_marketStates[index].activeSetup.timeframe;
   alert.direction = m_marketStates[index].activeSetup.direction;
   alert.title = "EXIT_ALERT";
   alert.body = FormatExitAlert(m_marketStates[index].activeSetup, conditions.mainReason);
   alert.exitReason = conditions.mainReason;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
   UpdateLastAlertTime(index, ALERT_TYPE_EXIT);

   // Invalider le setup
   m_marketStates[index].activeSetup.isValid = false;

   // Retour automatique à NEUTRAL après EXIT
   m_marketStates[index].state = STATE_NEUTRAL;

   Print("✓ EXIT_ALERT émis pour ", symbol, " - Raison: ", ExitReasonToString(conditions.mainReason));
   return true;
}

//+------------------------------------------------------------------+
//| Retour à NEUTRAL (reset manuel ou après exit)                     |
//+------------------------------------------------------------------+
void CAlertSystem::ResetToNeutral(string symbol)
{
   int index = FindMarketIndex(symbol);
   if(index < 0) return;

   m_marketStates[index].state = STATE_NEUTRAL;
   m_marketStates[index].lastStateChange = TimeCurrent();
   m_marketStates[index].activeSetup.Reset();
   m_marketStates[index].preSignalCount = 0;
   for(int i = 0; i < 5; i++) m_marketStates[index].preSignalReasons[i] = false;

   Print("✓ ", symbol, " - Reset to NEUTRAL");
}

//+------------------------------------------------------------------+
//| Obtenir le setup actif                                            |
//+------------------------------------------------------------------+
SActiveSetup CAlertSystem::GetActiveSetup(string symbol)
{
   SActiveSetup empty;
   empty.Reset();

   int index = FindMarketIndex(symbol);
   if(index < 0) return empty;

   return m_marketStates[index].activeSetup;
}

//+------------------------------------------------------------------+
//| Vérifier si un setup est actif                                    |
//+------------------------------------------------------------------+
bool CAlertSystem::HasActiveSetup(string symbol)
{
   int index = FindMarketIndex(symbol);
   if(index < 0) return false;

   return (m_marketStates[index].state == STATE_SETUP_ACTIVE &&
           m_marketStates[index].activeSetup.isValid);
}

//+------------------------------------------------------------------+
//| Formatage alerte PRE_SIGNAL                                       |
//+------------------------------------------------------------------+
string CAlertSystem::FormatPreSignalAlert(string symbol, ENUM_TIMEFRAMES tf,
                                          ENUM_SETUP_DIRECTION dir,
                                          SPreSignalConditions &cond)
{
   string msg = "";

   msg += "🟡 PRE_SIGNAL\n";
   msg += "Marché: " + symbol + " " + TimeframeToString(tf) + "\n";
   msg += "Setup: " + DirectionToString(dir) + " (EN COURS)\n";
   msg += "\n";
   msg += "Conditions détectées (" + IntegerToString(cond.validCount) + "/5):\n";

   if(cond.hasCompression)   msg += "✅ Compression détectée\n";
   if(cond.hasAccumulation)  msg += "✅ Accumulation/Distribution\n";
   if(cond.nearMajorZone)    msg += "✅ Proche zone majeure\n";
   if(cond.hasDivergence)    msg += "✅ Divergence en formation\n";
   if(cond.hasEMAConfluence) msg += "✅ Confluence EMA\n";

   msg += "\n";
   msg += "⚠️ Attendre confirmation\n";
   msg += "⚠️ Pas d'entrée maintenant\n";

   return msg;
}

//+------------------------------------------------------------------+
//| Formatage alerte SETUP_SIGNAL                                     |
//+------------------------------------------------------------------+
string CAlertSystem::FormatSetupSignalAlert(SActiveSetup &setup, SSetupConditions &cond)
{
   string msg = "";
   string dirStr = (setup.direction == DIRECTION_BUY) ? "Buy" : "Sell";
   string entryType = (setup.direction == DIRECTION_BUY) ? "Buy Limit" : "Sell Limit";

   msg += "🚨 SETUP_SIGNAL\n";
   msg += "Marché: " + setup.symbol + "\n";
   msg += "\n";
   msg += entryType + " = " + DoubleToStr(setup.entryPrice, 5) + "\n";
   msg += "SL = " + DoubleToStr(setup.stopLoss, 5) + "\n";
   msg += "TP1 = " + DoubleToStr(setup.tp1, 5) + "\n";
   msg += "TP2 = " + DoubleToStr(setup.tp2, 5) + "\n";
   msg += "\n";
   msg += "Risque: " + DoubleToStr(setup.riskPercent, 1) + "%\n";
   msg += "\n";
   msg += "Checklist (" + IntegerToString(cond.validCount) + "/5):\n";
   msg += (cond.contextOK ? "✅" : "❌") + " Contexte MTF\n";
   msg += (cond.confluenceOK ? "✅" : "❌") + " Zone confluence\n";
   msg += (cond.candleSignalOK ? "✅" : "❌") + " Signal bougie\n";
   msg += (cond.volumeOK ? "✅" : "❌") + " Volume ≥150%\n";
   msg += (cond.structureOK ? "✅" : "❌") + " Structure SMC\n";

   return msg;
}

//+------------------------------------------------------------------+
//| Formatage alerte MJ_SETUP                                         |
//+------------------------------------------------------------------+
string CAlertSystem::FormatMJSetupAlert(SActiveSetup &setup, string changes)
{
   string msg = "";

   msg += "🔁 MJ_SETUP\n";
   msg += "Marché: " + setup.symbol + "\n";
   msg += "\n";
   msg += "Modifications:\n";
   msg += changes;
   msg += "\n";
   msg += "Setup actuel:\n";
   msg += "Entry = " + DoubleToStr(setup.entryPrice, 5) + "\n";
   msg += "SL = " + DoubleToStr(setup.stopLoss, 5) + "\n";
   msg += "TP1 = " + DoubleToStr(setup.tp1, 5) + "\n";
   msg += "TP2 = " + DoubleToStr(setup.tp2, 5) + "\n";

   return msg;
}

//+------------------------------------------------------------------+
//| Formatage alerte EXIT                                             |
//+------------------------------------------------------------------+
string CAlertSystem::FormatExitAlert(SActiveSetup &setup, ENUM_EXIT_REASON reason)
{
   string msg = "";

   msg += "🟢 EXIT_ALERT\n";
   msg += "Marché: " + setup.symbol + "\n";
   msg += "Position: " + DirectionToString(setup.direction) + "\n";
   msg += "\n";
   msg += "Décision: SORTIE RECOMMANDÉE\n";
   msg += "\n";
   msg += "Raison: " + ExitReasonToString(reason) + "\n";
   msg += "\n";
   msg += "⚠️ ACTION IMMÉDIATE REQUISE\n";

   return msg;
}

//+------------------------------------------------------------------+
//| Envoyer l'alerte (tous canaux)                                    |
//+------------------------------------------------------------------+
void CAlertSystem::DoSendAlert(SAlertData &alert)
{
   alert.time = TimeCurrent();
   alert.isSent = true;

   string fullMessage = alert.body;

   // Popup MT5
   if(m_enablePopup)
   {
      ShowPopup(fullMessage);
   }

   // Son
   if(m_enableSound)
   {
      PlayAlertSound(alert.priority);
   }

   // Push
   if(m_enablePush)
   {
      SendPushNotification(alert.title, alert.body);
   }

   // Email
   if(m_enableEmail)
   {
      string subject = alert.title + " - " + alert.symbol;
      SendEmailNotification(subject, fullMessage);
   }

   // Telegram
   if(m_enableTelegram)
   {
      SendTelegramNotification(fullMessage);
   }

   // Historique
   AddToHistory(alert);

   // Log
   Print("ALERTE [", alert.title, "] ", alert.symbol);
}

//+------------------------------------------------------------------+
//| Notification Push                                                 |
//+------------------------------------------------------------------+
void CAlertSystem::SendPushNotification(string title, string message)
{
   // Limiter la taille pour mobile
   string shortMsg = StringSubstr(message, 0, 200);
   if(!SendNotification(title + "\n" + shortMsg))
   {
      Print("Erreur envoi notification push");
   }
}

//+------------------------------------------------------------------+
//| Notification Email                                                |
//+------------------------------------------------------------------+
void CAlertSystem::SendEmailNotification(string subject, string body)
{
   if(!SendMail(subject, body))
   {
      Print("Erreur envoi email");
   }
}

//+------------------------------------------------------------------+
//| Notification Telegram                                             |
//+------------------------------------------------------------------+
void CAlertSystem::SendTelegramNotification(string message)
{
   if(m_telegramBotToken == "" || m_telegramChatId == "")
   {
      Print("Telegram non configuré");
      return;
   }

   // Encoder le message pour URL
   string encodedMsg = message;
   StringReplace(encodedMsg, " ", "%20");
   StringReplace(encodedMsg, "\n", "%0A");

   string url = "https://api.telegram.org/bot" + m_telegramBotToken +
                "/sendMessage?chat_id=" + m_telegramChatId +
                "&text=" + encodedMsg + "&parse_mode=HTML";

   char data[];
   char result[];
   string headers;

   int timeout = 5000;
   int res = WebRequest("GET", url, "", timeout, data, result, headers);

   if(res != 200)
   {
      Print("Erreur Telegram, code: ", res);
   }
}

//+------------------------------------------------------------------+
//| Son d'alerte                                                      |
//+------------------------------------------------------------------+
void CAlertSystem::PlayAlertSound(ENUM_ALERT_PRIORITY priority)
{
   string soundFile;

   switch(priority)
   {
      case PRIORITY_INFO:     soundFile = "tick.wav"; break;
      case PRIORITY_LOW:      soundFile = "tick.wav"; break;
      case PRIORITY_MEDIUM:   soundFile = "alert.wav"; break;
      case PRIORITY_HIGH:     soundFile = "alert2.wav"; break;
      case PRIORITY_CRITICAL: soundFile = "news.wav"; break;
      default:                soundFile = "alert.wav"; break;
   }

   PlaySound(soundFile);
}

//+------------------------------------------------------------------+
//| Popup MT5                                                         |
//+------------------------------------------------------------------+
void CAlertSystem::ShowPopup(string message)
{
   Alert(message);
}

//+------------------------------------------------------------------+
//| Ajouter à l'historique                                            |
//+------------------------------------------------------------------+
void CAlertSystem::AddToHistory(SAlertData &alert)
{
   int size = ArraySize(m_alertHistory);

   if(size >= m_maxHistory)
   {
      // FIFO - supprimer la plus ancienne
      for(int i = 0; i < size - 1; i++)
         m_alertHistory[i] = m_alertHistory[i + 1];
      ArrayResize(m_alertHistory, size);
   }
   else
   {
      ArrayResize(m_alertHistory, size + 1);
   }

   m_alertHistory[ArraySize(m_alertHistory) - 1] = alert;
}

//+------------------------------------------------------------------+
//| Getters historique                                                |
//+------------------------------------------------------------------+
int CAlertSystem::GetHistoryCount()
{
   return ArraySize(m_alertHistory);
}

SAlertData CAlertSystem::GetHistoryAlert(int index)
{
   SAlertData empty;
   empty.Reset();

   if(index < 0 || index >= ArraySize(m_alertHistory))
      return empty;

   return m_alertHistory[index];
}

void CAlertSystem::ClearHistory()
{
   ArrayFree(m_alertHistory);
   ArrayResize(m_alertHistory, 0);
}

//+------------------------------------------------------------------+
//| Conversion timeframe → string                                     |
//+------------------------------------------------------------------+
string CAlertSystem::TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "M1";
      case PERIOD_M5:   return "M5";
      case PERIOD_M15:  return "M15";
      case PERIOD_M30:  return "M30";
      case PERIOD_H1:   return "H1";
      case PERIOD_H4:   return "H4";
      case PERIOD_D1:   return "Daily";
      case PERIOD_W1:   return "Weekly";
      case PERIOD_MN1:  return "Monthly";
      default:          return "?";
   }
}

//+------------------------------------------------------------------+
//| Conversion direction → string                                     |
//+------------------------------------------------------------------+
string CAlertSystem::DirectionToString(ENUM_SETUP_DIRECTION dir)
{
   switch(dir)
   {
      case DIRECTION_BUY:  return "BUY";
      case DIRECTION_SELL: return "SELL";
      default:             return "NONE";
   }
}

//+------------------------------------------------------------------+
//| Conversion état → string                                          |
//+------------------------------------------------------------------+
string CAlertSystem::StateToString(ENUM_BOT_STATE state)
{
   switch(state)
   {
      case STATE_NEUTRAL:       return "NEUTRAL";
      case STATE_PRE_SIGNAL:    return "PRE_SIGNAL";
      case STATE_SETUP_ACTIVE:  return "SETUP_ACTIVE";
      case STATE_EXIT_PRIORITY: return "EXIT_PRIORITY";
      default:                  return "?";
   }
}

//+------------------------------------------------------------------+
//| Conversion raison sortie → string                                 |
//+------------------------------------------------------------------+
string CAlertSystem::ExitReasonToString(ENUM_EXIT_REASON reason)
{
   switch(reason)
   {
      case EXIT_CHOCH_AGAINST:      return "CHoCH contre position";
      case EXIT_BOS_INVERSE:        return "BOS inverse sur HTF";
      case EXIT_DIVERGENCE:         return "Divergence contraire confirmée";
      case EXIT_STRONG_CANDLE:      return "Bougie opposée forte (>70%)";
      case EXIT_VOLUME_REVERSAL:    return "Volume de retournement";
      case EXIT_EMA_BREAK:          return "Cassure EMA 50/200";
      case EXIT_MTF_MISALIGNMENT:   return "Désalignement MTF";
      case EXIT_ZONE_INVALIDATED:   return "Zone invalidée";
      default:                      return "?";
   }
}

//+------------------------------------------------------------------+
//| Double to String helper                                           |
//+------------------------------------------------------------------+
string CAlertSystem::DoubleToStr(double value, int digits)
{
   return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Résumé état d'un marché                                           |
//+------------------------------------------------------------------+
string CAlertSystem::GetStateSummary(string symbol)
{
   int index = FindMarketIndex(symbol);
   if(index < 0)
      return symbol + ": Non suivi";

   string summary = symbol + ": " + StateToString(m_marketStates[index].state);

   if(m_marketStates[index].state == STATE_SETUP_ACTIVE && m_marketStates[index].activeSetup.isValid)
   {
      summary += " | " + DirectionToString(m_marketStates[index].activeSetup.direction);
      summary += " | Entry: " + DoubleToStr(m_marketStates[index].activeSetup.entryPrice, 5);
   }
   else if(m_marketStates[index].state == STATE_PRE_SIGNAL)
   {
      summary += " | Conditions: " + IntegerToString(m_marketStates[index].preSignalCount) + "/5";
   }

   return summary;
}

//+------------------------------------------------------------------+
//| Résumé tous marchés                                               |
//+------------------------------------------------------------------+
string CAlertSystem::GetAllMarketsSummary()
{
   string summary = "══════ ÉTAT MARCHÉS ══════\n";

   for(int i = 0; i < m_marketCount; i++)
   {
      summary += GetStateSummary(m_marketStates[i].symbol) + "\n";
   }

   return summary;
}

//+------------------------------------------------------------------+
//| Notification de démarrage du bot sur une paire                    |
//+------------------------------------------------------------------+
void CAlertSystem::SendStartupAlert(string symbol, ENUM_TIMEFRAMES tf)
{
   // Obtenir date et heure
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Formater la date: DD/MM/YYYY
   string dateStr = StringFormat("%02d/%02d/%04d", dt.day, dt.mon, dt.year);

   // Formater l'heure: HHhMM
   string timeStr = StringFormat("%02dH%02d", dt.hour, dt.min);

   // Construire le message
   string msg = "";
   msg += "🚀 ANALYSE " + symbol + "\n";
   msg += "\n";
   msg += "Timeframe = " + TimeframeToString(tf) + "\n";
   msg += "Date = " + dateStr + "\n";
   msg += "Heure = " + timeStr + "\n";
   msg += "\n";
   msg += "✅ Bot analyste actif\n";
   msg += "⚠️ Analyse uniquement - Pas de trade auto";

   // Créer l'alerte
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_INFO;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.title = "🚀 DÉMARRAGE ANALYSE";
   alert.body = msg;
   alert.time = now;

   // Envoyer
   DoSendAlert(alert);

   Print("✓ Bot démarré sur ", symbol, " - TF: ", TimeframeToString(tf));
}

//+------------------------------------------------------------------+
//| ============ COMPATIBILITÉ ANCIENNE API ============              |
//+------------------------------------------------------------------+

bool CAlertSystem::ValidateChecklist(bool contextOK, bool confluenceOK,
                                     bool candleSignalOK, bool volumeOK,
                                     bool structureOK, int &validatedCount)
{
   SSetupConditions cond;
   cond.contextOK = contextOK;
   cond.confluenceOK = confluenceOK;
   cond.candleSignalOK = candleSignalOK;
   cond.volumeOK = volumeOK;
   cond.structureOK = structureOK;
   cond.Calculate();

   validatedCount = cond.validCount;
   return ValidateSetupConditions(cond);
}

void CAlertSystem::SendSetupAlert(string symbol, ENUM_TIMEFRAMES tf, bool isBuy,
                                  string message, string details, int conditions)
{
   // Créer les conditions
   SSetupConditions cond;
   cond.contextOK = true;
   cond.confluenceOK = true;
   cond.candleSignalOK = true;
   cond.volumeOK = (conditions >= 4);
   cond.structureOK = (conditions >= 3);
   cond.Calculate();

   // Utiliser la nouvelle API
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = isBuy ? price - 100 * SymbolInfoDouble(symbol, SYMBOL_POINT) :
                       price + 100 * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tp1 = isBuy ? price + 150 * SymbolInfoDouble(symbol, SYMBOL_POINT) :
                        price - 150 * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tp2 = isBuy ? price + 250 * SymbolInfoDouble(symbol, SYMBOL_POINT) :
                        price - 250 * SymbolInfoDouble(symbol, SYMBOL_POINT);

   TransitionToSetupActive(symbol, tf,
                           isBuy ? DIRECTION_BUY : DIRECTION_SELL,
                           cond, price, sl, tp1, tp2, 1.0);
}

void CAlertSystem::SendPatternAlert(string symbol, ENUM_TIMEFRAMES tf,
                                    string patternName, string details)
{
   // Envoyer comme info (pas de changement d'état)
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_LOW;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.title = "📊 PATTERN";
   alert.body = "Pattern: " + patternName + "\n" + details;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

void CAlertSystem::SendSMCAlert(string symbol, ENUM_TIMEFRAMES tf,
                                string smcType, string details)
{
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.title = "💰 SMART MONEY";
   alert.body = "SMC: " + smcType + "\n" + details;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

void CAlertSystem::SendDivergenceAlert(string symbol, ENUM_TIMEFRAMES tf,
                                       string divType, string details)
{
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.title = "📈 DIVERGENCE";
   alert.body = "Divergence: " + divType + "\n" + details;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

void CAlertSystem::SendMTFAlert(string symbol, string alignment, string details)
{
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_HIGH;
   alert.symbol = symbol;
   alert.title = "🎯 MTF ALIGNÉ";
   alert.body = "Alignement: " + alignment + "\n" + details;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

void CAlertSystem::SendVolumeAlert(string symbol, ENUM_TIMEFRAMES tf,
                                   string volumeState, string details)
{
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_LOW;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.title = "📊 VOLUME";
   alert.body = "Volume: " + volumeState + "\n" + details;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

void CAlertSystem::SendRiskAlert(string symbol, string message)
{
   SAlertData alert;
   alert.Reset();
   alert.type = ALERT_TYPE_INFO;
   alert.priority = PRIORITY_CRITICAL;
   alert.symbol = symbol;
   alert.title = "⚠️ RISQUE";
   alert.body = message;
   alert.time = TimeCurrent();

   DoSendAlert(alert);
}

//+------------------------------------------------------------------+
