//+------------------------------------------------------------------+
//|                                               AlertSystem.mqh   |
//|                        SYSTÈME D'ALERTES CENTRALISÉ             |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des types d'alertes                                  |
//+------------------------------------------------------------------+
enum ENUM_ALERT_TYPE
{
   ALERT_SETUP_BUY = 0,
   ALERT_SETUP_SELL,
   ALERT_PATTERN,
   ALERT_DIVERGENCE,
   ALERT_SMC,
   ALERT_MTF,
   ALERT_VOLUME,
   ALERT_RISK,
   ALERT_STRUCTURE,
   ALERT_INFO
};

enum ENUM_ALERT_PRIORITY
{
   PRIORITY_LOW = 0,
   PRIORITY_MEDIUM,
   PRIORITY_HIGH,
   PRIORITY_CRITICAL
};

//+------------------------------------------------------------------+
//| Structure d'une alerte                                           |
//+------------------------------------------------------------------+
struct SAlert
{
   ENUM_ALERT_TYPE      type;
   ENUM_ALERT_PRIORITY  priority;
   string               symbol;
   ENUM_TIMEFRAMES      timeframe;
   string               message;
   string               details;
   datetime             time;
   int                  conditionsValidated;   // Sur 5
   bool                 isSent;
};

//+------------------------------------------------------------------+
//| Classe système d'alertes                                          |
//+------------------------------------------------------------------+
class CAlertSystem
{
private:
   bool              m_enablePush;        // Notifications push
   bool              m_enableEmail;       // Notifications email
   bool              m_enableSound;       // Alertes sonores
   bool              m_enablePopup;       // Popups MT5
   bool              m_enableTelegram;    // Notifications Telegram

   string            m_telegramBotToken;
   string            m_telegramChatId;

   SAlert            m_alertHistory[];
   int               m_maxHistory;
   datetime          m_lastAlertTime;
   int               m_minAlertIntervalSec; // Intervalle minimum entre alertes

   // Méthodes privées
   void              AddToHistory(SAlert &alert);
   bool              CanSendAlert();
   string            GetAlertPrefix(ENUM_ALERT_TYPE type);
   string            GetPriorityString(ENUM_ALERT_PRIORITY priority);

public:
   CAlertSystem();
   ~CAlertSystem();

   // Configuration
   void              EnablePush(bool enable);
   void              EnableEmail(bool enable);
   void              EnableSound(bool enable);
   void              EnablePopup(bool enable);
   void              EnableTelegram(bool enable, string botToken, string chatId);
   void              SetMinInterval(int seconds);

   // ============ CHECKLIST FINALE ============
   // Une alerte n'est envoyée QUE SI minimum 4 conditions sur 5 validées
   bool              ValidateChecklist(bool contextOK, bool confluenceOK,
                                       bool candleSignalOK, bool volumeOK,
                                       bool structureOK, int &validatedCount);

   // Envoi d'alertes
   void              SendAlert(SAlert &alert);
   void              SendSetupAlert(string symbol, ENUM_TIMEFRAMES tf, bool isBuy,
                                   string message, string details, int conditions);
   void              SendPatternAlert(string symbol, ENUM_TIMEFRAMES tf,
                                      string patternName, string details);
   void              SendSMCAlert(string symbol, ENUM_TIMEFRAMES tf, string smcType, string details);
   void              SendDivergenceAlert(string symbol, ENUM_TIMEFRAMES tf, string divType, string details);
   void              SendMTFAlert(string symbol, string alignment, string details);
   void              SendVolumeAlert(string symbol, ENUM_TIMEFRAMES tf, string volumeState, string details);
   void              SendRiskAlert(string symbol, string message);

   // Envoi spécifique
   void              SendPushNotification(string title, string message);
   void              SendEmailNotification(string subject, string body);
   void              SendTelegramNotification(string message);
   void              PlayAlertSound(ENUM_ALERT_PRIORITY priority);
   void              ShowPopup(string title, string message);

   // Construction du message d'alerte complet
   string            BuildFullAlertMessage(SAlert &alert);
   string            BuildSetupMessage(string symbol, bool isBuy, string details, int conditions);

   // Historique
   int               GetHistoryCount();
   SAlert            GetHistoryAlert(int index);
   void              ClearHistory();

   // Utilitaires
   string            TimeframeToString(ENUM_TIMEFRAMES tf);
   string            AlertTypeToString(ENUM_ALERT_TYPE type);
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

   m_maxHistory = 100;
   m_lastAlertTime = 0;
   m_minAlertIntervalSec = 60; // 1 minute minimum entre alertes
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CAlertSystem::~CAlertSystem()
{
   ArrayFree(m_alertHistory);
}

//+------------------------------------------------------------------+
//| Configuration                                                     |
//+------------------------------------------------------------------+
void CAlertSystem::EnablePush(bool enable)        { m_enablePush = enable; }
void CAlertSystem::EnableEmail(bool enable)       { m_enableEmail = enable; }
void CAlertSystem::EnableSound(bool enable)       { m_enableSound = enable; }
void CAlertSystem::EnablePopup(bool enable)       { m_enablePopup = enable; }

void CAlertSystem::EnableTelegram(bool enable, string botToken, string chatId)
{
   m_enableTelegram = enable;
   m_telegramBotToken = botToken;
   m_telegramChatId = chatId;
}

void CAlertSystem::SetMinInterval(int seconds)
{
   m_minAlertIntervalSec = seconds;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut envoyer une alerte                            |
//+------------------------------------------------------------------+
bool CAlertSystem::CanSendAlert()
{
   datetime now = TimeCurrent();
   if(now - m_lastAlertTime < m_minAlertIntervalSec)
      return false;

   m_lastAlertTime = now;
   return true;
}

//+------------------------------------------------------------------+
//| Ajouter à l'historique                                            |
//+------------------------------------------------------------------+
void CAlertSystem::AddToHistory(SAlert &alert)
{
   int size = ArraySize(m_alertHistory);

   if(size >= m_maxHistory)
   {
      // Supprimer la plus ancienne
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
//| CHECKLIST FINALE - RÈGLE: Minimum 4 conditions sur 5             |
//| - Contexte OK                                                     |
//| - Zone de confluence OK                                           |
//| - Signal bougie + volume OK                                       |
//| - Minimum 4 conditions sur 5 validées                             |
//+------------------------------------------------------------------+
bool CAlertSystem::ValidateChecklist(bool contextOK, bool confluenceOK,
                                     bool candleSignalOK, bool volumeOK,
                                     bool structureOK, int &validatedCount)
{
   validatedCount = 0;

   if(contextOK) validatedCount++;
   if(confluenceOK) validatedCount++;
   if(candleSignalOK) validatedCount++;
   if(volumeOK) validatedCount++;
   if(structureOK) validatedCount++;

   // RÈGLE: Minimum 4 conditions sur 5 validées
   return (validatedCount >= 4);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte                                                |
//+------------------------------------------------------------------+
void CAlertSystem::SendAlert(SAlert &alert)
{
   // Vérifier l'intervalle minimum
   if(!CanSendAlert())
   {
      Print("Alerte ignorée - intervalle minimum non respecté");
      return;
   }

   alert.time = TimeCurrent();
   alert.isSent = true;

   string fullMessage = BuildFullAlertMessage(alert);

   // Popup MT5
   if(m_enablePopup)
   {
      ShowPopup(GetAlertPrefix(alert.type), fullMessage);
   }

   // Son
   if(m_enableSound)
   {
      PlayAlertSound(alert.priority);
   }

   // Notification push
   if(m_enablePush)
   {
      SendPushNotification(GetAlertPrefix(alert.type), alert.message);
   }

   // Email
   if(m_enableEmail)
   {
      SendEmailNotification(GetAlertPrefix(alert.type) + " - " + alert.symbol, fullMessage);
   }

   // Telegram
   if(m_enableTelegram)
   {
      SendTelegramNotification(fullMessage);
   }

   // Ajouter à l'historique
   AddToHistory(alert);

   // Log
   Print("ALERTE: ", fullMessage);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte de setup                                       |
//+------------------------------------------------------------------+
void CAlertSystem::SendSetupAlert(string symbol, ENUM_TIMEFRAMES tf, bool isBuy,
                                  string message, string details, int conditions)
{
   SAlert alert;

   alert.type = isBuy ? ALERT_SETUP_BUY : ALERT_SETUP_SELL;
   alert.priority = (conditions >= 5) ? PRIORITY_CRITICAL : PRIORITY_HIGH;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.message = message;
   alert.details = details;
   alert.conditionsValidated = conditions;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte de pattern                                     |
//+------------------------------------------------------------------+
void CAlertSystem::SendPatternAlert(string symbol, ENUM_TIMEFRAMES tf,
                                    string patternName, string details)
{
   SAlert alert;

   alert.type = ALERT_PATTERN;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.message = "Pattern détecté: " + patternName;
   alert.details = details;
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte SMC                                            |
//+------------------------------------------------------------------+
void CAlertSystem::SendSMCAlert(string symbol, ENUM_TIMEFRAMES tf,
                                string smcType, string details)
{
   SAlert alert;

   alert.type = ALERT_SMC;
   alert.priority = PRIORITY_HIGH;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.message = "SMC: " + smcType;
   alert.details = details;
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte de divergence                                  |
//+------------------------------------------------------------------+
void CAlertSystem::SendDivergenceAlert(string symbol, ENUM_TIMEFRAMES tf,
                                       string divType, string details)
{
   SAlert alert;

   alert.type = ALERT_DIVERGENCE;
   alert.priority = PRIORITY_MEDIUM;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.message = "Divergence: " + divType;
   alert.details = details;
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte MTF                                            |
//+------------------------------------------------------------------+
void CAlertSystem::SendMTFAlert(string symbol, string alignment, string details)
{
   SAlert alert;

   alert.type = ALERT_MTF;
   alert.priority = PRIORITY_HIGH;
   alert.symbol = symbol;
   alert.timeframe = PERIOD_CURRENT;
   alert.message = "MTF Aligné: " + alignment;
   alert.details = details;
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte volume                                         |
//+------------------------------------------------------------------+
void CAlertSystem::SendVolumeAlert(string symbol, ENUM_TIMEFRAMES tf,
                                   string volumeState, string details)
{
   SAlert alert;

   alert.type = ALERT_VOLUME;
   alert.priority = PRIORITY_LOW;
   alert.symbol = symbol;
   alert.timeframe = tf;
   alert.message = "Volume: " + volumeState;
   alert.details = details;
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Envoyer une alerte de risque                                      |
//+------------------------------------------------------------------+
void CAlertSystem::SendRiskAlert(string symbol, string message)
{
   SAlert alert;

   alert.type = ALERT_RISK;
   alert.priority = PRIORITY_CRITICAL;
   alert.symbol = symbol;
   alert.timeframe = PERIOD_CURRENT;
   alert.message = message;
   alert.details = "";
   alert.conditionsValidated = 0;

   SendAlert(alert);
}

//+------------------------------------------------------------------+
//| Notification push                                                 |
//+------------------------------------------------------------------+
void CAlertSystem::SendPushNotification(string title, string message)
{
   if(!SendNotification(title + ": " + message))
   {
      Print("Erreur envoi notification push");
   }
}

//+------------------------------------------------------------------+
//| Notification email                                                |
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

   string url = "https://api.telegram.org/bot" + m_telegramBotToken +
                "/sendMessage?chat_id=" + m_telegramChatId +
                "&text=" + message;

   // Note: WebRequest nécessite une autorisation dans les paramètres MT5
   char data[];
   char result[];
   string headers;

   int timeout = 5000;
   int res = WebRequest("GET", url, "", timeout, data, result, headers);

   if(res != 200)
   {
      Print("Erreur envoi Telegram, code: ", res);
   }
}

//+------------------------------------------------------------------+
//| Jouer un son d'alerte                                             |
//+------------------------------------------------------------------+
void CAlertSystem::PlayAlertSound(ENUM_ALERT_PRIORITY priority)
{
   string soundFile;

   switch(priority)
   {
      case PRIORITY_LOW:      soundFile = "tick.wav"; break;
      case PRIORITY_MEDIUM:   soundFile = "alert.wav"; break;
      case PRIORITY_HIGH:     soundFile = "alert2.wav"; break;
      case PRIORITY_CRITICAL: soundFile = "news.wav"; break;
      default:                soundFile = "alert.wav"; break;
   }

   PlaySound(soundFile);
}

//+------------------------------------------------------------------+
//| Afficher un popup                                                 |
//+------------------------------------------------------------------+
void CAlertSystem::ShowPopup(string title, string message)
{
   Alert(title, "\n", message);
}

//+------------------------------------------------------------------+
//| Construire le message complet                                     |
//+------------------------------------------------------------------+
string CAlertSystem::BuildFullAlertMessage(SAlert &alert)
{
   string msg = "";

   msg += "═══════════════════════════════\n";
   msg += GetAlertPrefix(alert.type) + "\n";
   msg += "═══════════════════════════════\n";
   msg += "Symbole: " + alert.symbol + "\n";
   msg += "Timeframe: " + TimeframeToString(alert.timeframe) + "\n";
   msg += "Priorité: " + GetPriorityString(alert.priority) + "\n";
   msg += "───────────────────────────────\n";
   msg += alert.message + "\n";

   if(alert.details != "")
   {
      msg += "───────────────────────────────\n";
      msg += alert.details + "\n";
   }

   if(alert.conditionsValidated > 0)
   {
      msg += "───────────────────────────────\n";
      msg += "Conditions validées: " + IntegerToString(alert.conditionsValidated) + "/5\n";
   }

   msg += "───────────────────────────────\n";
   msg += "Heure: " + TimeToString(alert.time, TIME_DATE | TIME_MINUTES) + "\n";
   msg += "═══════════════════════════════";

   return msg;
}

//+------------------------------------------------------------------+
//| Construire un message de setup                                    |
//+------------------------------------------------------------------+
string CAlertSystem::BuildSetupMessage(string symbol, bool isBuy, string details, int conditions)
{
   string direction = isBuy ? "ACHAT" : "VENTE";
   string emoji = isBuy ? "🟢" : "🔴";

   string msg = emoji + " SETUP " + direction + " DÉTECTÉ!\n\n";
   msg += "Symbole: " + symbol + "\n";
   msg += "Conditions: " + IntegerToString(conditions) + "/5 validées\n\n";
   msg += details;

   return msg;
}

//+------------------------------------------------------------------+
//| Getters historique                                                |
//+------------------------------------------------------------------+
int CAlertSystem::GetHistoryCount()
{
   return ArraySize(m_alertHistory);
}

SAlert CAlertSystem::GetHistoryAlert(int index)
{
   SAlert empty;
   if(index < 0 || index >= ArraySize(m_alertHistory)) return empty;
   return m_alertHistory[index];
}

void CAlertSystem::ClearHistory()
{
   ArrayFree(m_alertHistory);
   ArrayResize(m_alertHistory, 0);
}

//+------------------------------------------------------------------+
//| Obtenir le préfixe de l'alerte                                    |
//+------------------------------------------------------------------+
string CAlertSystem::GetAlertPrefix(ENUM_ALERT_TYPE type)
{
   switch(type)
   {
      case ALERT_SETUP_BUY:    return "🟢 SETUP ACHAT";
      case ALERT_SETUP_SELL:   return "🔴 SETUP VENTE";
      case ALERT_PATTERN:      return "📊 PATTERN";
      case ALERT_DIVERGENCE:   return "📈 DIVERGENCE";
      case ALERT_SMC:          return "💰 SMART MONEY";
      case ALERT_MTF:          return "🎯 MTF ALIGNÉ";
      case ALERT_VOLUME:       return "📊 VOLUME";
      case ALERT_RISK:         return "⚠️ RISQUE";
      case ALERT_STRUCTURE:    return "📐 STRUCTURE";
      case ALERT_INFO:         return "ℹ️ INFO";
      default:                 return "🔔 ALERTE";
   }
}

//+------------------------------------------------------------------+
//| Obtenir la priorité en string                                     |
//+------------------------------------------------------------------+
string CAlertSystem::GetPriorityString(ENUM_ALERT_PRIORITY priority)
{
   switch(priority)
   {
      case PRIORITY_LOW:      return "Basse";
      case PRIORITY_MEDIUM:   return "Moyenne";
      case PRIORITY_HIGH:     return "HAUTE";
      case PRIORITY_CRITICAL: return "⚡ CRITIQUE";
      default:                return "?";
   }
}

//+------------------------------------------------------------------+
//| Convertir timeframe en string                                     |
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
//| Convertir type d'alerte en string                                 |
//+------------------------------------------------------------------+
string CAlertSystem::AlertTypeToString(ENUM_ALERT_TYPE type)
{
   switch(type)
   {
      case ALERT_SETUP_BUY:    return "Setup Achat";
      case ALERT_SETUP_SELL:   return "Setup Vente";
      case ALERT_PATTERN:      return "Pattern";
      case ALERT_DIVERGENCE:   return "Divergence";
      case ALERT_SMC:          return "Smart Money";
      case ALERT_MTF:          return "Multi-Timeframe";
      case ALERT_VOLUME:       return "Volume";
      case ALERT_RISK:         return "Risque";
      case ALERT_STRUCTURE:    return "Structure";
      case ALERT_INFO:         return "Info";
      default:                 return "Inconnu";
   }
}
//+------------------------------------------------------------------+
