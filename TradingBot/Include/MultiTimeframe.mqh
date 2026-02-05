//+------------------------------------------------------------------+
//|                                            MultiTimeframe.mqh   |
//|                        CHAPITRE 12 - MULTI TIMEFRAME            |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

#include "MarketStructure.mqh"
#include "MovingAverages.mqh"

//+------------------------------------------------------------------+
//| Énumération de l'alignement MTF                                  |
//+------------------------------------------------------------------+
enum ENUM_MTF_ALIGNMENT
{
   MTF_NOT_ALIGNED = 0,
   MTF_BULLISH_ALIGNED,     // Tous TF haussiers
   MTF_BEARISH_ALIGNED,     // Tous TF baissiers
   MTF_CONFLICTING          // Conflit entre TF
};

//+------------------------------------------------------------------+
//| Structure d'analyse d'un timeframe                               |
//+------------------------------------------------------------------+
struct STimeframeAnalysis
{
   ENUM_TIMEFRAMES         timeframe;
   ENUM_STRUCTURE_STATE   structure;
   bool                    isBullishBias;    // Prix > EMA 200
   bool                    isRibbonAligned;
   bool                    isRibbonBullish;
   double                  ema200;
   string                  summary;
};

//+------------------------------------------------------------------+
//| Structure d'analyse MTF complète                                 |
//+------------------------------------------------------------------+
struct SMTFAnalysis
{
   STimeframeAnalysis      daily;
   STimeframeAnalysis      h4;
   STimeframeAnalysis      h1;
   STimeframeAnalysis      m15;
   ENUM_MTF_ALIGNMENT      alignment;
   bool                    isValidSetup;
   string                  direction;        // "BUY", "SELL", "NONE"
};

//+------------------------------------------------------------------+
//| Classe d'analyse Multi-Timeframe                                  |
//+------------------------------------------------------------------+
class CMultiTimeframe
{
private:
   string            m_symbol;

   // Analyseurs par timeframe
   CMarketStructure  m_structureDaily;
   CMarketStructure  m_structureH4;
   CMarketStructure  m_structureH1;
   CMarketStructure  m_structureM15;

   CMovingAverages   m_emaDaily;
   CMovingAverages   m_emaH4;
   CMovingAverages   m_emaH1;
   CMovingAverages   m_emaM15;

   // Méthodes privées
   STimeframeAnalysis AnalyzeTimeframe(ENUM_TIMEFRAMES tf, CMarketStructure &structure, CMovingAverages &ema);

public:
   CMultiTimeframe();
   ~CMultiTimeframe();

   // Initialisation
   bool              Init(string symbol);

   // ============ RÈGLE CHAPITRE 12: ALIGNEMENT OBLIGATOIRE ============
   // Daily = Direction, H4 = Zone & structure, H1/M15 = Entrée
   // Sinon → AUCUNE ALERTE
   SMTFAnalysis      Analyze();
   bool              IsAligned();
   ENUM_MTF_ALIGNMENT GetAlignment();

   // Analyse par timeframe
   STimeframeAnalysis AnalyzeDaily();
   STimeframeAnalysis AnalyzeH4();
   STimeframeAnalysis AnalyzeH1();
   STimeframeAnalysis AnalyzeM15();

   // RÈGLE: Daily = Direction principale
   bool              IsDailyBullish();
   bool              IsDailyBearish();
   ENUM_STRUCTURE_STATE GetDailyStructure();

   // RÈGLE: H4 = Zone & structure
   bool              IsH4Bullish();
   bool              IsH4Bearish();
   ENUM_STRUCTURE_STATE GetH4Structure();

   // RÈGLE: H1/M15 = Déclenchement (scalping)
   bool              IsEntryTimeframeBullish();
   bool              IsEntryTimeframeBearish();

   // Validation du setup
   bool              ValidateBuySetup();
   bool              ValidateSellSetup();

   // Utilitaires
   string            GetAlignmentString(ENUM_MTF_ALIGNMENT alignment);
   string            GetMTFSummary();
   string            GetMTFAlert();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CMultiTimeframe::CMultiTimeframe()
{
   m_symbol = "";
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CMultiTimeframe::~CMultiTimeframe()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CMultiTimeframe::Init(string symbol)
{
   m_symbol = symbol;

   // Initialiser les structures de marché
   m_structureDaily.Init(symbol, PERIOD_D1);
   m_structureH4.Init(symbol, PERIOD_H4);
   m_structureH1.Init(symbol, PERIOD_H1);
   m_structureM15.Init(symbol, PERIOD_M15);

   // Initialiser les EMAs
   if(!m_emaDaily.Init(symbol, PERIOD_D1)) return false;
   if(!m_emaH4.Init(symbol, PERIOD_H4)) return false;
   if(!m_emaH1.Init(symbol, PERIOD_H1)) return false;
   if(!m_emaM15.Init(symbol, PERIOD_M15)) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Analyser un timeframe spécifique                                  |
//+------------------------------------------------------------------+
STimeframeAnalysis CMultiTimeframe::AnalyzeTimeframe(ENUM_TIMEFRAMES tf,
                                                      CMarketStructure &structure,
                                                      CMovingAverages &ema)
{
   STimeframeAnalysis analysis;
   analysis.timeframe = tf;

   // Analyser la structure
   structure.Analyze();
   analysis.structure = structure.GetStructure();

   // Analyser les EMAs
   STrendAnalysis emaAnalysis = ema.Analyze(0);
   analysis.isBullishBias = emaAnalysis.allowLong;
   analysis.isRibbonAligned = emaAnalysis.ribbon.isAligned;
   analysis.isRibbonBullish = emaAnalysis.ribbon.isBullish;
   analysis.ema200 = emaAnalysis.values.ema200;

   // Résumé
   string tfName;
   switch(tf)
   {
      case PERIOD_D1:  tfName = "Daily"; break;
      case PERIOD_H4:  tfName = "H4";    break;
      case PERIOD_H1:  tfName = "H1";    break;
      case PERIOD_M15: tfName = "M15";   break;
      default:         tfName = "?";     break;
   }

   analysis.summary = tfName + ": " +
                      structure.StructureToString(analysis.structure) +
                      (analysis.isBullishBias ? " | Bias HAUSSIER" : " | Bias BAISSIER");

   return analysis;
}

//+------------------------------------------------------------------+
//| Analyser Daily                                                    |
//+------------------------------------------------------------------+
STimeframeAnalysis CMultiTimeframe::AnalyzeDaily()
{
   return AnalyzeTimeframe(PERIOD_D1, m_structureDaily, m_emaDaily);
}

//+------------------------------------------------------------------+
//| Analyser H4                                                       |
//+------------------------------------------------------------------+
STimeframeAnalysis CMultiTimeframe::AnalyzeH4()
{
   return AnalyzeTimeframe(PERIOD_H4, m_structureH4, m_emaH4);
}

//+------------------------------------------------------------------+
//| Analyser H1                                                       |
//+------------------------------------------------------------------+
STimeframeAnalysis CMultiTimeframe::AnalyzeH1()
{
   return AnalyzeTimeframe(PERIOD_H1, m_structureH1, m_emaH1);
}

//+------------------------------------------------------------------+
//| Analyser M15                                                      |
//+------------------------------------------------------------------+
STimeframeAnalysis CMultiTimeframe::AnalyzeM15()
{
   return AnalyzeTimeframe(PERIOD_M15, m_structureM15, m_emaM15);
}

//+------------------------------------------------------------------+
//| RÈGLE: Analyse MTF complète avec ALIGNEMENT OBLIGATOIRE          |
//+------------------------------------------------------------------+
SMTFAnalysis CMultiTimeframe::Analyze()
{
   SMTFAnalysis mtf;

   // Analyser chaque timeframe
   mtf.daily = AnalyzeDaily();
   mtf.h4 = AnalyzeH4();
   mtf.h1 = AnalyzeH1();
   mtf.m15 = AnalyzeM15();

   // Déterminer l'alignement
   mtf.alignment = GetAlignment();

   // Valider le setup selon les règles
   mtf.isValidSetup = false;
   mtf.direction = "NONE";

   if(mtf.alignment == MTF_BULLISH_ALIGNED)
   {
      mtf.isValidSetup = true;
      mtf.direction = "BUY";
   }
   else if(mtf.alignment == MTF_BEARISH_ALIGNED)
   {
      mtf.isValidSetup = true;
      mtf.direction = "SELL";
   }

   return mtf;
}

//+------------------------------------------------------------------+
//| Vérifier si les timeframes sont alignés                           |
//+------------------------------------------------------------------+
bool CMultiTimeframe::IsAligned()
{
   ENUM_MTF_ALIGNMENT alignment = GetAlignment();
   return (alignment == MTF_BULLISH_ALIGNED || alignment == MTF_BEARISH_ALIGNED);
}

//+------------------------------------------------------------------+
//| RÈGLE: Obtenir l'alignement MTF                                   |
//| Daily = Direction, H4 = Zone & structure, H1/M15 = Entrée        |
//+------------------------------------------------------------------+
ENUM_MTF_ALIGNMENT CMultiTimeframe::GetAlignment()
{
   // Analyser chaque TF
   STimeframeAnalysis daily = AnalyzeDaily();
   STimeframeAnalysis h4 = AnalyzeH4();
   STimeframeAnalysis h1 = AnalyzeH1();
   STimeframeAnalysis m15 = AnalyzeM15();

   // RÈGLE: Daily donne la direction principale
   bool dailyBullish = (daily.structure == STRUCTURE_BULLISH || daily.isBullishBias);
   bool dailyBearish = (daily.structure == STRUCTURE_BEARISH || !daily.isBullishBias);

   // RÈGLE: H4 confirme la zone et structure
   bool h4Bullish = (h4.structure == STRUCTURE_BULLISH || h4.isBullishBias);
   bool h4Bearish = (h4.structure == STRUCTURE_BEARISH || !h4.isBullishBias);

   // RÈGLE: H1/M15 pour l'entrée
   bool entryBullish = (h1.isBullishBias || m15.isBullishBias);
   bool entryBearish = (!h1.isBullishBias || !m15.isBullishBias);

   // Vérifier l'alignement complet haussier
   if(dailyBullish && h4Bullish && entryBullish)
   {
      return MTF_BULLISH_ALIGNED;
   }

   // Vérifier l'alignement complet baissier
   if(dailyBearish && h4Bearish && entryBearish)
   {
      return MTF_BEARISH_ALIGNED;
   }

   // S'il y a des conflits
   if((dailyBullish && h4Bearish) || (dailyBearish && h4Bullish))
   {
      return MTF_CONFLICTING;
   }

   return MTF_NOT_ALIGNED;
}

//+------------------------------------------------------------------+
//| RÈGLE: Daily = Direction principale                               |
//+------------------------------------------------------------------+
bool CMultiTimeframe::IsDailyBullish()
{
   STimeframeAnalysis daily = AnalyzeDaily();
   return (daily.structure == STRUCTURE_BULLISH && daily.isBullishBias);
}

bool CMultiTimeframe::IsDailyBearish()
{
   STimeframeAnalysis daily = AnalyzeDaily();
   return (daily.structure == STRUCTURE_BEARISH && !daily.isBullishBias);
}

ENUM_STRUCTURE_STATE CMultiTimeframe::GetDailyStructure()
{
   m_structureDaily.Analyze();
   return m_structureDaily.GetStructure();
}

//+------------------------------------------------------------------+
//| RÈGLE: H4 = Zone & structure                                      |
//+------------------------------------------------------------------+
bool CMultiTimeframe::IsH4Bullish()
{
   STimeframeAnalysis h4 = AnalyzeH4();
   return (h4.structure == STRUCTURE_BULLISH || h4.isBullishBias);
}

bool CMultiTimeframe::IsH4Bearish()
{
   STimeframeAnalysis h4 = AnalyzeH4();
   return (h4.structure == STRUCTURE_BEARISH || !h4.isBullishBias);
}

ENUM_STRUCTURE_STATE CMultiTimeframe::GetH4Structure()
{
   m_structureH4.Analyze();
   return m_structureH4.GetStructure();
}

//+------------------------------------------------------------------+
//| RÈGLE: H1/M15 = Déclenchement                                     |
//+------------------------------------------------------------------+
bool CMultiTimeframe::IsEntryTimeframeBullish()
{
   STimeframeAnalysis h1 = AnalyzeH1();
   STimeframeAnalysis m15 = AnalyzeM15();

   // Au moins un des deux doit être haussier
   return (h1.isBullishBias || m15.isBullishBias);
}

bool CMultiTimeframe::IsEntryTimeframeBearish()
{
   STimeframeAnalysis h1 = AnalyzeH1();
   STimeframeAnalysis m15 = AnalyzeM15();

   // Au moins un des deux doit être baissier
   return (!h1.isBullishBias || !m15.isBullishBias);
}

//+------------------------------------------------------------------+
//| Valider un setup d'achat                                          |
//+------------------------------------------------------------------+
bool CMultiTimeframe::ValidateBuySetup()
{
   // RÈGLE: Daily haussier
   if(!IsDailyBullish())
      return false;

   // RÈGLE: H4 haussier ou neutre
   STimeframeAnalysis h4 = AnalyzeH4();
   if(h4.structure == STRUCTURE_BEARISH)
      return false;

   // RÈGLE: TF d'entrée aligné
   if(!IsEntryTimeframeBullish())
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Valider un setup de vente                                         |
//+------------------------------------------------------------------+
bool CMultiTimeframe::ValidateSellSetup()
{
   // RÈGLE: Daily baissier
   if(!IsDailyBearish())
      return false;

   // RÈGLE: H4 baissier ou neutre
   STimeframeAnalysis h4 = AnalyzeH4();
   if(h4.structure == STRUCTURE_BULLISH)
      return false;

   // RÈGLE: TF d'entrée aligné
   if(!IsEntryTimeframeBearish())
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Convertir l'alignement en string                                  |
//+------------------------------------------------------------------+
string CMultiTimeframe::GetAlignmentString(ENUM_MTF_ALIGNMENT alignment)
{
   switch(alignment)
   {
      case MTF_NOT_ALIGNED:     return "Non aligné";
      case MTF_BULLISH_ALIGNED: return "ALIGNÉ HAUSSIER";
      case MTF_BEARISH_ALIGNED: return "ALIGNÉ BAISSIER";
      case MTF_CONFLICTING:     return "CONFLIT";
      default:                  return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Obtenir un résumé MTF                                             |
//+------------------------------------------------------------------+
string CMultiTimeframe::GetMTFSummary()
{
   SMTFAnalysis mtf = Analyze();

   string summary = "═══════ ANALYSE MTF ═══════\n";
   summary += mtf.daily.summary + "\n";
   summary += mtf.h4.summary + "\n";
   summary += mtf.h1.summary + "\n";
   summary += mtf.m15.summary + "\n";
   summary += "─────────────────────────────\n";
   summary += "ALIGNEMENT: " + GetAlignmentString(mtf.alignment) + "\n";
   summary += "SETUP VALIDE: " + (mtf.isValidSetup ? "OUI" : "NON") + "\n";
   if(mtf.isValidSetup)
      summary += "DIRECTION: " + mtf.direction + "\n";
   summary += "═══════════════════════════════";

   return summary;
}

//+------------------------------------------------------------------+
//| RÈGLE: Générer une alerte MTF                                     |
//| Sinon → AUCUNE ALERTE                                             |
//+------------------------------------------------------------------+
string CMultiTimeframe::GetMTFAlert()
{
   SMTFAnalysis mtf = Analyze();

   // RÈGLE: Pas d'alerte si pas aligné
   if(!mtf.isValidSetup)
      return "";

   string alert = "";

   if(mtf.alignment == MTF_BULLISH_ALIGNED)
   {
      alert = "🎯 MTF ALIGNÉ HAUSSIER\n";
      alert += "Daily: Direction haussière\n";
      alert += "H4: Zone de demande / structure haussière\n";
      alert += "H1/M15: Prêt pour entrée LONG\n";
      alert += "→ Chercher setup d'ACHAT";
   }
   else if(mtf.alignment == MTF_BEARISH_ALIGNED)
   {
      alert = "🎯 MTF ALIGNÉ BAISSIER\n";
      alert += "Daily: Direction baissière\n";
      alert += "H4: Zone d'offre / structure baissière\n";
      alert += "H1/M15: Prêt pour entrée SHORT\n";
      alert += "→ Chercher setup de VENTE";
   }

   return alert;
}
//+------------------------------------------------------------------+
