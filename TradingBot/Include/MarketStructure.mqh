//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                     MODULE STRUCTURE DE MARCHÉ INSTITUTIONNELLE  |
//|                        Smart Money Concepts - BOS / CHoCH        |
//+------------------------------------------------------------------+
#property copyright "Trading Bot - SMC Structure"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE:                                                      |
//| La structure de marché est la BOUSSOLE DIRECTIONNELLE             |
//| - Elle définit le régime du marché (haussier/baissier/range)     |
//| - Elle détecte les changements de contrôle                        |
//| - Elle filtre les setups contre-tendance                          |
//|                                                                   |
//| RÈGLES FONDAMENTALES:                                             |
//| - BOS = Break of Structure = CONTINUATION                         |
//| - CHoCH = Change of Character = ALERTE RETOURNEMENT               |
//| - Seule la CLÔTURE valide une cassure (pas les mèches)           |
//| - Structure HTF > Structure LTF                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ÉNUMÉRATIONS                                                      |
//+------------------------------------------------------------------+

// État structurel du marché
enum ENUM_STRUCTURE_STATE
{
   STRUCTURE_BULLISH,        // Tendance haussière confirmée
   STRUCTURE_BEARISH,        // Tendance baissière confirmée
   STRUCTURE_RANGE,          // Consolidation / Indécision
   STRUCTURE_TRANSITION      // En transition (CHoCH récent)
};

// Type de swing point
enum ENUM_SWING_TYPE
{
   SWING_NONE,
   SWING_HIGH,               // Point haut
   SWING_LOW                 // Point bas
};

// Label du swing dans la structure
enum ENUM_SWING_LABEL
{
   LABEL_NONE,
   LABEL_HH,                 // Higher High
   LABEL_HL,                 // Higher Low
   LABEL_LH,                 // Lower High
   LABEL_LL,                 // Lower Low
   LABEL_EQUAL_HIGH,         // Equal High (range)
   LABEL_EQUAL_LOW           // Equal Low (range)
};

// Type d'événement structurel
enum ENUM_STRUCTURE_EVENT
{
   EVENT_NONE,
   EVENT_BOS_BULLISH,        // Break of Structure haussier (continuation)
   EVENT_BOS_BEARISH,        // Break of Structure baissier (continuation)
   EVENT_CHOCH_BULLISH,      // Change of Character haussier (retournement)
   EVENT_CHOCH_BEARISH,      // Change of Character baissier (retournement)
   EVENT_SWING_FORMED,       // Nouveau swing formé
   EVENT_STRUCTURE_CONFIRMED // Structure confirmée
};

// Qualité de l'événement
enum ENUM_STRUCTURE_QUALITY
{
   QUALITY_HIGH,             // Haute qualité (forte impulsion)
   QUALITY_MEDIUM,           // Qualité moyenne
   QUALITY_LOW,              // Faible qualité (à confirmer)
   QUALITY_INVALID           // Invalide (fakeout probable)
};

// Niveau d'alerte
enum ENUM_STRUCTURE_ALERT
{
   ALERT_NONE,
   ALERT_INFO,               // Information (BOS détecté)
   ALERT_SETUP,              // Setup potentiel (structure alignée)
   ALERT_DANGER,             // Danger (CHoCH, invalidation)
   ALERT_CRITICAL            // Critique (structure HTF cassée)
};

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES                                             |
//+------------------------------------------------------------------+

// Point de swing avec métadonnées complètes
struct SSwingPoint
{
   ENUM_SWING_TYPE     type;           // HIGH ou LOW
   ENUM_SWING_LABEL    label;          // HH, HL, LH, LL
   double              price;          // Prix du swing
   datetime            time;           // Horodatage
   int                 barIndex;       // Index de la barre
   int                 strength;       // Force (nb bougies gauche/droite)
   bool                isConfirmed;    // Confirmé (barre fermée)
   bool                isBroken;       // A été cassé
   datetime            brokenTime;     // Quand il a été cassé
   bool                isValid;        // Valide pour analyse

   void Reset()
   {
      type = SWING_NONE;
      label = LABEL_NONE;
      price = 0;
      time = 0;
      barIndex = -1;
      strength = 0;
      isConfirmed = false;
      isBroken = false;
      brokenTime = 0;
      isValid = false;
   }
};

// Événement structurel (BOS/CHoCH)
struct SStructureEvent
{
   ENUM_STRUCTURE_EVENT   eventType;      // Type d'événement
   ENUM_STRUCTURE_QUALITY quality;        // Qualité
   double                 breakPrice;     // Prix de cassure
   double                 swingPrice;     // Prix du swing cassé
   datetime               time;           // Horodatage
   int                    barIndex;       // Index barre
   double                 displacement;   // Déplacement en points
   double                 displacementPct;// Déplacement en %
   bool                   isValid;

   void Reset()
   {
      eventType = EVENT_NONE;
      quality = QUALITY_INVALID;
      breakPrice = 0;
      swingPrice = 0;
      time = 0;
      barIndex = -1;
      displacement = 0;
      displacementPct = 0;
      isValid = false;
   }
};

// État complet de la structure
struct SStructureAnalysis
{
   // État actuel
   ENUM_STRUCTURE_STATE   state;          // État du marché
   ENUM_STRUCTURE_STATE   previousState;  // État précédent

   // Derniers swings
   SSwingPoint            lastHigh;       // Dernier swing high
   SSwingPoint            lastLow;        // Dernier swing low
   SSwingPoint            prevHigh;       // Swing high précédent
   SSwingPoint            prevLow;        // Swing low précédent

   // Événements récents
   SStructureEvent        lastEvent;      // Dernier événement
   int                    barsSinceEvent; // Barres depuis l'événement

   // Niveaux clés
   double                 keyHighLevel;   // Niveau haut clé à surveiller
   double                 keyLowLevel;    // Niveau bas clé à surveiller

   // Métriques
   int                    swingCount;     // Nombre de swings détectés
   int                    bosCount;       // Nombre de BOS
   int                    chochCount;     // Nombre de CHoCH
   double                 avgSwingSize;   // Taille moyenne des swings

   // Alertes
   ENUM_STRUCTURE_ALERT   alertLevel;
   string                 alertMessage;

   void Reset()
   {
      state = STRUCTURE_RANGE;
      previousState = STRUCTURE_RANGE;
      lastHigh.Reset();
      lastLow.Reset();
      prevHigh.Reset();
      prevLow.Reset();
      lastEvent.Reset();
      barsSinceEvent = 0;
      keyHighLevel = 0;
      keyLowLevel = 0;
      swingCount = 0;
      bosCount = 0;
      chochCount = 0;
      avgSwingSize = 0;
      alertLevel = ALERT_NONE;
      alertMessage = "";
   }
};

// Structure multi-timeframe
struct SMTFStructure
{
   ENUM_TIMEFRAMES        timeframe;
   SStructureAnalysis     analysis;
   bool                   isValid;
   datetime               lastUpdate;

   void Reset()
   {
      timeframe = PERIOD_CURRENT;
      analysis.Reset();
      isValid = false;
      lastUpdate = 0;
   }
};

// Alignement MTF
struct SMTFAlignment
{
   bool                   isAligned;         // Toutes les UT alignées
   ENUM_STRUCTURE_STATE   htfState;          // État HTF dominant
   ENUM_STRUCTURE_STATE   mtfState;          // État MTF
   ENUM_STRUCTURE_STATE   ltfState;          // État LTF
   int                    alignmentScore;    // Score 0-100
   bool                   allowLong;         // Longs autorisés
   bool                   allowShort;        // Shorts autorisés
   string                 reason;            // Raison

   void Reset()
   {
      isAligned = false;
      htfState = STRUCTURE_RANGE;
      mtfState = STRUCTURE_RANGE;
      ltfState = STRUCTURE_RANGE;
      alignmentScore = 0;
      allowLong = false;
      allowShort = false;
      reason = "";
   }
};

//+------------------------------------------------------------------+
//| CLASSE PRINCIPALE - Market Structure                              |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   //--- Paramètres
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_swingStrength;     // Bougies gauche/droite pour swing
   int                  m_lookbackBars;      // Barres à analyser
   double               m_minDisplacement;   // Déplacement min pour valider (%)
   double               m_equalTolerance;    // Tolérance pour equal H/L (%)

   //--- Données internes
   SSwingPoint          m_swings[];          // Historique des swings
   SSwingPoint          m_swingHighs[];      // Swing highs séparés
   SSwingPoint          m_swingLows[];       // Swing lows séparés
   int                  m_maxSwings;         // Max swings à garder
   SStructureAnalysis   m_analysis;          // Analyse courante
   datetime             m_lastBarTime;       // Dernière barre traitée
   bool                 m_initialized;

   //--- Multi-timeframe
   SMTFStructure        m_htfStructure;      // Structure HTF (Daily/H4)
   SMTFStructure        m_mtfStructure;      // Structure MTF (H4/H1)
   SMTFStructure        m_ltfStructure;      // Structure LTF (H1/M15)

   //--- Méthodes privées - Détection Swings
   bool                 IsSwingHigh(int index);
   bool                 IsSwingLow(int index);
   int                  DetectAllSwings();
   void                 LabelSwings();
   ENUM_SWING_LABEL     DetermineHighLabel(double currentPrice, double prevPrice);
   ENUM_SWING_LABEL     DetermineLowLabel(double currentPrice, double prevPrice);

   //--- Méthodes privées - Analyse Structure
   void                 AnalyzeStructure();
   ENUM_STRUCTURE_STATE DetermineState();
   bool                 CheckForBOS(SStructureEvent &event);
   bool                 CheckForCHoCH(SStructureEvent &event);
   ENUM_STRUCTURE_QUALITY EvaluateEventQuality(SStructureEvent &event);

   //--- Méthodes privées - Filtres
   bool                 IsValidBreak(double breakPrice, double swingPrice, bool isBullish);
   bool                 IsInTightRange();
   double               CalculateDisplacement(double price1, double price2);
   double               GetAverageSwingSize();

   //--- Méthodes privées - Utilitaires
   void                 AddSwing(SSwingPoint &swing);
   void                 UpdateKeyLevels();
   void                 GenerateAlert();
   double               GetPointValue();

public:
   //--- Constructeur/Destructeur
                        CMarketStructure();
                       ~CMarketStructure();

   //--- Initialisation
   bool                 Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void                 SetParameters(int swingStrength, int lookback, double minDisplacement, double equalTolerance);
   void                 Deinit();

   //--- Mise à jour (appeler à chaque tick/barre)
   bool                 Update();
   bool                 ForceUpdate();

   //--- ============ ÉTAT DE LA STRUCTURE ============
   ENUM_STRUCTURE_STATE GetState();
   string               GetStateString();
   bool                 IsBullish();
   bool                 IsBearish();
   bool                 IsRange();
   bool                 IsInTransition();

   //--- ============ ÉVÉNEMENTS BOS / CHoCH ============
   bool                 HasBOS();
   bool                 HasBOSBullish();
   bool                 HasBOSBearish();
   bool                 HasCHoCH();
   bool                 HasCHoCHBullish();
   bool                 HasCHoCHBearish();
   SStructureEvent      GetLastEvent();
   int                  GetBarsSinceEvent();

   //--- ============ SWINGS ============
   SSwingPoint          GetLastHigh();
   SSwingPoint          GetLastLow();
   SSwingPoint          GetPrevHigh();
   SSwingPoint          GetPrevLow();
   int                  GetSwingCount();
   int                  GetSwingHighCount();
   int                  GetSwingLowCount();
   SSwingPoint          GetSwing(int index);
   SSwingPoint          GetSwingHigh(int index);
   SSwingPoint          GetSwingLow(int index);
   double               GetLastSwingHighPrice();
   double               GetLastSwingLowPrice();

   //--- ============ NIVEAUX CLÉS ============
   double               GetKeyHighLevel();
   double               GetKeyLowLevel();
   bool                 IsPriceNearKeyLevel(double price, double tolerancePct);
   bool                 IsPriceAboveStructure(double price);
   bool                 IsPriceBelowStructure(double price);

   //--- ============ FILTRAGE TRADES ============
   bool                 AllowLong();
   bool                 AllowShort();
   bool                 IsCounterTrend(bool wantLong);
   bool                 IsWithTrend(bool wantLong);
   int                  GetTrendScore();  // -100 à +100

   //--- ============ MULTI-TIMEFRAME ============
   bool                 UpdateMTF(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES mtf, ENUM_TIMEFRAMES ltf);
   SMTFAlignment        GetMTFAlignment();
   ENUM_STRUCTURE_STATE GetHTFState();
   ENUM_STRUCTURE_STATE GetMTFState();
   ENUM_STRUCTURE_STATE GetLTFState();
   bool                 IsMTFAligned();
   bool                 IsHTFBullish();
   bool                 IsHTFBearish();

   //--- ============ ALERTES ============
   ENUM_STRUCTURE_ALERT GetAlertLevel();
   string               GetAlertMessage();
   SStructureAnalysis   GetFullAnalysis();

   //--- ============ COMPATIBILITÉ ANCIENNE API ============
   void                 Analyze() { ForceUpdate(); }
   ENUM_STRUCTURE_STATE GetStructure() { return GetState(); }
   bool                 IsHigherHigh(int index);
   bool                 IsHigherLow(int index);
   bool                 IsLowerHigh(int index);
   bool                 IsLowerLow(int index);
   bool                 IsBullishBOS(int shift);
   bool                 IsBearishBOS(int shift);
   bool                 IsBullishCHoCH(int shift);
   bool                 IsBearishCHoCH(int shift);

   //--- ============ UTILITAIRES ============
   string               SwingToString(SSwingPoint &swing);
   string               EventToString(SStructureEvent &event);
   string               StateToString(ENUM_STRUCTURE_STATE state);
   string               StructureToString(ENUM_STRUCTURE_STATE state) { return StateToString(state); }
   string               GetStructureSummary();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_swingStrength = 3;        // 3 bougies de chaque côté
   m_lookbackBars = 200;
   m_minDisplacement = 0.1;    // 0.1% minimum pour valider
   m_equalTolerance = 0.05;    // 0.05% tolérance pour equal H/L
   m_maxSwings = 50;
   m_lastBarTime = 0;
   m_initialized = false;

   ArrayResize(m_swings, 0);
   ArrayResize(m_swingHighs, 0);
   ArrayResize(m_swingLows, 0);
   m_analysis.Reset();
   m_htfStructure.Reset();
   m_mtfStructure.Reset();
   m_ltfStructure.Reset();
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CMarketStructure::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   // Vérifier que le symbole existe
   if(!SymbolSelect(m_symbol, true))
   {
      Print("MarketStructure: Symbole invalide - ", m_symbol);
      return false;
   }

   ArrayResize(m_swings, 0);
   ArrayResize(m_swingHighs, 0);
   ArrayResize(m_swingLows, 0);
   m_analysis.Reset();
   m_initialized = true;

   // Premier calcul
   ForceUpdate();

   return true;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CMarketStructure::SetParameters(int swingStrength, int lookback, double minDisplacement, double equalTolerance)
{
   m_swingStrength = MathMax(2, swingStrength);
   m_lookbackBars = MathMax(50, lookback);
   m_minDisplacement = MathMax(0.01, minDisplacement);
   m_equalTolerance = MathMax(0.01, equalTolerance);
}

//+------------------------------------------------------------------+
//| Libération des ressources                                         |
//+------------------------------------------------------------------+
void CMarketStructure::Deinit()
{
   ArrayFree(m_swings);
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un point                                      |
//+------------------------------------------------------------------+
double CMarketStructure::GetPointValue()
{
   return SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Mise à jour (optimisée - uniquement sur nouvelle barre)           |
//+------------------------------------------------------------------+
bool CMarketStructure::Update()
{
   if(!m_initialized) return false;

   // Vérifier si nouvelle barre
   datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
   if(currentBarTime == m_lastBarTime) return true;  // Pas de nouvelle barre

   m_lastBarTime = currentBarTime;
   return ForceUpdate();
}

//+------------------------------------------------------------------+
//| Mise à jour forcée (recalcul complet)                             |
//+------------------------------------------------------------------+
bool CMarketStructure::ForceUpdate()
{
   if(!m_initialized) return false;

   // Sauvegarder l'état précédent
   m_analysis.previousState = m_analysis.state;

   // 1. Détecter tous les swings
   int swingCount = DetectAllSwings();
   if(swingCount < 4)
   {
      m_analysis.state = STRUCTURE_RANGE;
      return true;
   }

   // 2. Labéliser les swings (HH/HL/LH/LL)
   LabelSwings();

   // 3. Analyser la structure
   AnalyzeStructure();

   // 4. Mettre à jour les niveaux clés
   UpdateKeyLevels();

   // 5. Générer les alertes
   GenerateAlert();

   return true;
}

//+------------------------------------------------------------------+
//| Détecter un swing high                                            |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(int index)
{
   if(index < m_swingStrength || index >= m_lookbackBars - m_swingStrength)
      return false;

   double high = iHigh(m_symbol, m_timeframe, index);

   // Vérifier N bougies à gauche (plus récentes)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, index - i) >= high)
         return false;
   }

   // Vérifier N bougies à droite (plus anciennes)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, index + i) >= high)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Détecter un swing low                                             |
//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(int index)
{
   if(index < m_swingStrength || index >= m_lookbackBars - m_swingStrength)
      return false;

   double low = iLow(m_symbol, m_timeframe, index);

   // Vérifier N bougies à gauche (plus récentes)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iLow(m_symbol, m_timeframe, index - i) <= low)
         return false;
   }

   // Vérifier N bougies à droite (plus anciennes)
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iLow(m_symbol, m_timeframe, index + i) <= low)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Détecter tous les swings                                          |
//+------------------------------------------------------------------+
int CMarketStructure::DetectAllSwings()
{
   ArrayFree(m_swings);
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);
   ArrayResize(m_swings, 0);
   ArrayResize(m_swingHighs, 0);
   ArrayResize(m_swingLows, 0);

   int bars = MathMin(iBars(m_symbol, m_timeframe), m_lookbackBars);

   // Scanner depuis la barre la plus récente (mais confirmée)
   for(int i = m_swingStrength; i < bars - m_swingStrength; i++)
   {
      // Swing High
      if(IsSwingHigh(i))
      {
         SSwingPoint swing;
         swing.Reset();
         swing.type = SWING_HIGH;
         swing.price = iHigh(m_symbol, m_timeframe, i);
         swing.time = iTime(m_symbol, m_timeframe, i);
         swing.barIndex = i;
         swing.strength = m_swingStrength;
         swing.isConfirmed = true;
         swing.isValid = true;

         AddSwing(swing);

         // Ajouter aux highs séparés
         int hSize = ArraySize(m_swingHighs);
         ArrayResize(m_swingHighs, hSize + 1);
         m_swingHighs[hSize] = swing;
      }

      // Swing Low
      if(IsSwingLow(i))
      {
         SSwingPoint swing;
         swing.Reset();
         swing.type = SWING_LOW;
         swing.price = iLow(m_symbol, m_timeframe, i);
         swing.time = iTime(m_symbol, m_timeframe, i);
         swing.barIndex = i;
         swing.strength = m_swingStrength;
         swing.isConfirmed = true;
         swing.isValid = true;

         AddSwing(swing);

         // Ajouter aux lows séparés
         int lSize = ArraySize(m_swingLows);
         ArrayResize(m_swingLows, lSize + 1);
         m_swingLows[lSize] = swing;
      }
   }

   m_analysis.swingCount = ArraySize(m_swings);
   return m_analysis.swingCount;
}

//+------------------------------------------------------------------+
//| Ajouter un swing à l'historique                                   |
//+------------------------------------------------------------------+
void CMarketStructure::AddSwing(SSwingPoint &swing)
{
   int size = ArraySize(m_swings);

   if(size >= m_maxSwings)
   {
      for(int i = 0; i < size - 1; i++)
         m_swings[i] = m_swings[i + 1];
      ArrayResize(m_swings, size);
      m_swings[size - 1] = swing;
   }
   else
   {
      ArrayResize(m_swings, size + 1);
      m_swings[size] = swing;
   }
}

//+------------------------------------------------------------------+
//| Labéliser les swings (HH/HL/LH/LL)                                |
//+------------------------------------------------------------------+
void CMarketStructure::LabelSwings()
{
   // Labéliser les highs
   for(int i = 0; i < ArraySize(m_swingHighs); i++)
   {
      if(i < ArraySize(m_swingHighs) - 1)
      {
         m_swingHighs[i].label = DetermineHighLabel(m_swingHighs[i].price, m_swingHighs[i + 1].price);
      }
   }

   // Labéliser les lows
   for(int i = 0; i < ArraySize(m_swingLows); i++)
   {
      if(i < ArraySize(m_swingLows) - 1)
      {
         m_swingLows[i].label = DetermineLowLabel(m_swingLows[i].price, m_swingLows[i + 1].price);
      }
   }
}

//+------------------------------------------------------------------+
//| Déterminer le label d'un swing high                               |
//+------------------------------------------------------------------+
ENUM_SWING_LABEL CMarketStructure::DetermineHighLabel(double currentPrice, double prevPrice)
{
   double diff = currentPrice - prevPrice;
   double avgPrice = (currentPrice + prevPrice) / 2.0;
   double diffPct = MathAbs(diff / avgPrice) * 100.0;

   if(diffPct <= m_equalTolerance)
      return LABEL_EQUAL_HIGH;

   if(diff > 0) return LABEL_HH;  // Current > Previous = Higher High
   else return LABEL_LH;          // Current < Previous = Lower High
}

//+------------------------------------------------------------------+
//| Déterminer le label d'un swing low                                |
//+------------------------------------------------------------------+
ENUM_SWING_LABEL CMarketStructure::DetermineLowLabel(double currentPrice, double prevPrice)
{
   double diff = currentPrice - prevPrice;
   double avgPrice = (currentPrice + prevPrice) / 2.0;
   double diffPct = MathAbs(diff / avgPrice) * 100.0;

   if(diffPct <= m_equalTolerance)
      return LABEL_EQUAL_LOW;

   if(diff > 0) return LABEL_HL;  // Current > Previous = Higher Low
   else return LABEL_LL;          // Current < Previous = Lower Low
}

//+------------------------------------------------------------------+
//| Analyser la structure                                             |
//+------------------------------------------------------------------+
void CMarketStructure::AnalyzeStructure()
{
   // Récupérer les swings clés
   if(ArraySize(m_swingHighs) > 0)
   {
      m_analysis.lastHigh = m_swingHighs[0];
      if(ArraySize(m_swingHighs) > 1)
         m_analysis.prevHigh = m_swingHighs[1];
   }

   if(ArraySize(m_swingLows) > 0)
   {
      m_analysis.lastLow = m_swingLows[0];
      if(ArraySize(m_swingLows) > 1)
         m_analysis.prevLow = m_swingLows[1];
   }

   // Vérifier BOS et CHoCH
   SStructureEvent bosEvent, chochEvent;
   bosEvent.Reset();
   chochEvent.Reset();

   bool hasBOS = CheckForBOS(bosEvent);
   bool hasCHoCH = CheckForCHoCH(chochEvent);

   // Prioriser CHoCH sur BOS
   if(hasCHoCH)
   {
      m_analysis.lastEvent = chochEvent;
      m_analysis.chochCount++;
      m_analysis.state = STRUCTURE_TRANSITION;
   }
   else if(hasBOS)
   {
      m_analysis.lastEvent = bosEvent;
      m_analysis.bosCount++;
   }

   // Déterminer l'état final
   m_analysis.state = DetermineState();

   // Calculer les barres depuis l'événement
   if(m_analysis.lastEvent.isValid)
   {
      m_analysis.barsSinceEvent = iBarShift(m_symbol, m_timeframe, m_analysis.lastEvent.time);
   }

   m_analysis.avgSwingSize = GetAverageSwingSize();
}

//+------------------------------------------------------------------+
//| Vérifier un BOS (Break of Structure)                              |
//| BOS = CONTINUATION de tendance                                    |
//| - Haussier: Clôture au-dessus du dernier HH                       |
//| - Baissier: Clôture en-dessous du dernier LL                      |
//+------------------------------------------------------------------+
bool CMarketStructure::CheckForBOS(SStructureEvent &event)
{
   event.Reset();

   double currentClose = iClose(m_symbol, m_timeframe, 1);
   datetime currentTime = iTime(m_symbol, m_timeframe, 1);

   // BOS HAUSSIER: Clôture au-dessus du dernier HH (continuation haussière)
   if(m_analysis.lastHigh.isValid && m_analysis.lastHigh.label == LABEL_HH)
   {
      if(currentClose > m_analysis.lastHigh.price)
      {
         if(IsValidBreak(currentClose, m_analysis.lastHigh.price, true))
         {
            event.eventType = EVENT_BOS_BULLISH;
            event.breakPrice = currentClose;
            event.swingPrice = m_analysis.lastHigh.price;
            event.time = currentTime;
            event.barIndex = 1;
            event.displacement = (currentClose - m_analysis.lastHigh.price) / GetPointValue();
            event.displacementPct = CalculateDisplacement(currentClose, m_analysis.lastHigh.price);
            event.quality = EvaluateEventQuality(event);
            event.isValid = true;
            return true;
         }
      }
   }

   // BOS BAISSIER: Clôture en-dessous du dernier LL (continuation baissière)
   if(m_analysis.lastLow.isValid && m_analysis.lastLow.label == LABEL_LL)
   {
      if(currentClose < m_analysis.lastLow.price)
      {
         if(IsValidBreak(currentClose, m_analysis.lastLow.price, false))
         {
            event.eventType = EVENT_BOS_BEARISH;
            event.breakPrice = currentClose;
            event.swingPrice = m_analysis.lastLow.price;
            event.time = currentTime;
            event.barIndex = 1;
            event.displacement = (m_analysis.lastLow.price - currentClose) / GetPointValue();
            event.displacementPct = CalculateDisplacement(currentClose, m_analysis.lastLow.price);
            event.quality = EvaluateEventQuality(event);
            event.isValid = true;
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier un CHoCH (Change of Character)                           |
//| CHoCH = RETOURNEMENT potentiel                                    |
//| - Haussier: Tendance baissière casse son dernier LH               |
//| - Baissier: Tendance haussière casse son dernier HL               |
//+------------------------------------------------------------------+
bool CMarketStructure::CheckForCHoCH(SStructureEvent &event)
{
   event.Reset();

   double currentClose = iClose(m_symbol, m_timeframe, 1);
   datetime currentTime = iTime(m_symbol, m_timeframe, 1);

   // CHoCH HAUSSIER: En tendance baissière, cassure du dernier LH
   if(m_analysis.state == STRUCTURE_BEARISH || m_analysis.previousState == STRUCTURE_BEARISH)
   {
      if(m_analysis.lastHigh.isValid && m_analysis.lastHigh.label == LABEL_LH)
      {
         if(currentClose > m_analysis.lastHigh.price)
         {
            if(IsValidBreak(currentClose, m_analysis.lastHigh.price, true))
            {
               event.eventType = EVENT_CHOCH_BULLISH;
               event.breakPrice = currentClose;
               event.swingPrice = m_analysis.lastHigh.price;
               event.time = currentTime;
               event.barIndex = 1;
               event.displacement = (currentClose - m_analysis.lastHigh.price) / GetPointValue();
               event.displacementPct = CalculateDisplacement(currentClose, m_analysis.lastHigh.price);
               event.quality = EvaluateEventQuality(event);
               event.isValid = true;
               return true;
            }
         }
      }
   }

   // CHoCH BAISSIER: En tendance haussière, cassure du dernier HL
   if(m_analysis.state == STRUCTURE_BULLISH || m_analysis.previousState == STRUCTURE_BULLISH)
   {
      if(m_analysis.lastLow.isValid && m_analysis.lastLow.label == LABEL_HL)
      {
         if(currentClose < m_analysis.lastLow.price)
         {
            if(IsValidBreak(currentClose, m_analysis.lastLow.price, false))
            {
               event.eventType = EVENT_CHOCH_BEARISH;
               event.breakPrice = currentClose;
               event.swingPrice = m_analysis.lastLow.price;
               event.time = currentTime;
               event.barIndex = 1;
               event.displacement = (m_analysis.lastLow.price - currentClose) / GetPointValue();
               event.displacementPct = CalculateDisplacement(currentClose, m_analysis.lastLow.price);
               event.quality = EvaluateEventQuality(event);
               event.isValid = true;
               return true;
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Valider une cassure (filtre anti-faux signaux)                    |
//+------------------------------------------------------------------+
bool CMarketStructure::IsValidBreak(double breakPrice, double swingPrice, bool isBullish)
{
   // 1. Déplacement minimum
   double displacement = CalculateDisplacement(breakPrice, swingPrice);
   if(displacement < m_minDisplacement)
      return false;

   // 2. Range serré = exiger plus de déplacement
   if(IsInTightRange())
   {
      if(displacement < m_minDisplacement * 2)
         return false;
   }

   // 3. Force de la bougie de cassure
   double open = iOpen(m_symbol, m_timeframe, 1);
   double close = iClose(m_symbol, m_timeframe, 1);
   double high = iHigh(m_symbol, m_timeframe, 1);
   double low = iLow(m_symbol, m_timeframe, 1);

   double body = MathAbs(close - open);
   double range = high - low;

   if(range == 0) return false;

   double bodyRatio = body / range;

   // Corps d'au moins 40%
   if(bodyRatio < 0.4)
      return false;

   // 4. Direction de la bougie
   if(isBullish && close < open)
      return false;

   if(!isBullish && close > open)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si on est dans un range serré                            |
//+------------------------------------------------------------------+
bool CMarketStructure::IsInTightRange()
{
   if(!m_analysis.lastHigh.isValid || !m_analysis.lastLow.isValid)
      return true;

   double range = m_analysis.lastHigh.price - m_analysis.lastLow.price;
   double avgPrice = (m_analysis.lastHigh.price + m_analysis.lastLow.price) / 2.0;
   double rangePct = (range / avgPrice) * 100.0;

   return (rangePct < 1.0);
}

//+------------------------------------------------------------------+
//| Calculer le déplacement en pourcentage                            |
//+------------------------------------------------------------------+
double CMarketStructure::CalculateDisplacement(double price1, double price2)
{
   double avgPrice = (price1 + price2) / 2.0;
   if(avgPrice == 0) return 0;

   return MathAbs(price1 - price2) / avgPrice * 100.0;
}

//+------------------------------------------------------------------+
//| Calculer la taille moyenne des swings                             |
//+------------------------------------------------------------------+
double CMarketStructure::GetAverageSwingSize()
{
   int count = 0;
   double total = 0;

   for(int i = 0; i < ArraySize(m_swings) - 1; i++)
   {
      double diff = MathAbs(m_swings[i].price - m_swings[i + 1].price);
      total += diff;
      count++;
   }

   return (count > 0) ? total / count : 0;
}

//+------------------------------------------------------------------+
//| Évaluer la qualité d'un événement                                 |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_QUALITY CMarketStructure::EvaluateEventQuality(SStructureEvent &event)
{
   int score = 0;

   // Déplacement (0-40 points)
   if(event.displacementPct >= 0.5) score += 40;
   else if(event.displacementPct >= 0.3) score += 30;
   else if(event.displacementPct >= 0.2) score += 20;
   else if(event.displacementPct >= 0.1) score += 10;

   // Corps de la bougie (0-30 points)
   double open = iOpen(m_symbol, m_timeframe, event.barIndex);
   double close = iClose(m_symbol, m_timeframe, event.barIndex);
   double high = iHigh(m_symbol, m_timeframe, event.barIndex);
   double low = iLow(m_symbol, m_timeframe, event.barIndex);

   double body = MathAbs(close - open);
   double range = high - low;
   double bodyRatio = (range > 0) ? body / range : 0;

   if(bodyRatio >= 0.7) score += 30;
   else if(bodyRatio >= 0.5) score += 20;
   else if(bodyRatio >= 0.4) score += 10;

   // Volume (0-30 points)
   long volume = iVolume(m_symbol, m_timeframe, event.barIndex);
   long avgVolume = 0;
   for(int i = 2; i <= 11; i++)
      avgVolume += iVolume(m_symbol, m_timeframe, i);
   avgVolume /= 10;

   if(avgVolume > 0)
   {
      double volRatio = (double)volume / avgVolume;
      if(volRatio >= 2.0) score += 30;
      else if(volRatio >= 1.5) score += 20;
      else if(volRatio >= 1.0) score += 10;
   }
   else
   {
      score += 15;
   }

   if(score >= 70) return QUALITY_HIGH;
   if(score >= 50) return QUALITY_MEDIUM;
   if(score >= 30) return QUALITY_LOW;
   return QUALITY_INVALID;
}

//+------------------------------------------------------------------+
//| Déterminer l'état de la structure                                 |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_STATE CMarketStructure::DetermineState()
{
   // CHoCH récent = transition
   if(m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH ||
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH)
   {
      if(m_analysis.barsSinceEvent < 10)
         return STRUCTURE_TRANSITION;
   }

   // Compter les labels
   int bullishCount = 0;
   int bearishCount = 0;
   int rangeCount = 0;

   int checkHighs = MathMin(ArraySize(m_swingHighs), 5);
   int checkLows = MathMin(ArraySize(m_swingLows), 5);

   for(int i = 0; i < checkHighs; i++)
   {
      if(m_swingHighs[i].label == LABEL_HH) bullishCount++;
      else if(m_swingHighs[i].label == LABEL_LH) bearishCount++;
      else if(m_swingHighs[i].label == LABEL_EQUAL_HIGH) rangeCount++;
   }

   for(int i = 0; i < checkLows; i++)
   {
      if(m_swingLows[i].label == LABEL_HL) bullishCount++;
      else if(m_swingLows[i].label == LABEL_LL) bearishCount++;
      else if(m_swingLows[i].label == LABEL_EQUAL_LOW) rangeCount++;
   }

   int total = bullishCount + bearishCount + rangeCount;
   if(total == 0) return STRUCTURE_RANGE;

   if(rangeCount >= total / 2)
      return STRUCTURE_RANGE;

   if(bullishCount > bearishCount * 1.5)
      return STRUCTURE_BULLISH;

   if(bearishCount > bullishCount * 1.5)
      return STRUCTURE_BEARISH;

   // Dernier événement décisif
   if(m_analysis.lastEvent.eventType == EVENT_BOS_BULLISH ||
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH)
      return STRUCTURE_BULLISH;

   if(m_analysis.lastEvent.eventType == EVENT_BOS_BEARISH ||
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH)
      return STRUCTURE_BEARISH;

   return STRUCTURE_RANGE;
}

//+------------------------------------------------------------------+
//| Mettre à jour les niveaux clés                                    |
//+------------------------------------------------------------------+
void CMarketStructure::UpdateKeyLevels()
{
   if(m_analysis.lastHigh.isValid)
      m_analysis.keyHighLevel = m_analysis.lastHigh.price;

   if(m_analysis.lastLow.isValid)
      m_analysis.keyLowLevel = m_analysis.lastLow.price;
}

//+------------------------------------------------------------------+
//| Générer les alertes                                               |
//+------------------------------------------------------------------+
void CMarketStructure::GenerateAlert()
{
   m_analysis.alertLevel = ALERT_NONE;
   m_analysis.alertMessage = "";

   // CHoCH = DANGER
   if(m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH ||
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH)
   {
      if(m_analysis.barsSinceEvent <= 3)
      {
         m_analysis.alertLevel = ALERT_DANGER;
         m_analysis.alertMessage = "CHoCH - Retournement potentiel!";
         return;
      }
   }

   // BOS = INFO
   if(m_analysis.lastEvent.eventType == EVENT_BOS_BULLISH ||
      m_analysis.lastEvent.eventType == EVENT_BOS_BEARISH)
   {
      if(m_analysis.barsSinceEvent <= 3)
      {
         m_analysis.alertLevel = ALERT_INFO;
         m_analysis.alertMessage = "BOS - Continuation de tendance";
         return;
      }
   }

   // Zone de pullback = SETUP
   if(m_analysis.state == STRUCTURE_BULLISH || m_analysis.state == STRUCTURE_BEARISH)
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);

      if(m_analysis.state == STRUCTURE_BULLISH && m_analysis.lastLow.isValid)
      {
         double distanceToLow = MathAbs(currentPrice - m_analysis.lastLow.price);
         double structureRange = m_analysis.lastHigh.price - m_analysis.lastLow.price;

         if(structureRange > 0 && distanceToLow / structureRange < 0.3)
         {
            m_analysis.alertLevel = ALERT_SETUP;
            m_analysis.alertMessage = "Pullback vers support structurel";
            return;
         }
      }

      if(m_analysis.state == STRUCTURE_BEARISH && m_analysis.lastHigh.isValid)
      {
         double distanceToHigh = MathAbs(m_analysis.lastHigh.price - currentPrice);
         double structureRange = m_analysis.lastHigh.price - m_analysis.lastLow.price;

         if(structureRange > 0 && distanceToHigh / structureRange < 0.3)
         {
            m_analysis.alertLevel = ALERT_SETUP;
            m_analysis.alertMessage = "Pullback vers resistance structurelle";
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ============ GETTERS ÉTAT ============                            |
//+------------------------------------------------------------------+

ENUM_STRUCTURE_STATE CMarketStructure::GetState()
{
   return m_analysis.state;
}

string CMarketStructure::GetStateString()
{
   return StateToString(m_analysis.state);
}

bool CMarketStructure::IsBullish()
{
   return (m_analysis.state == STRUCTURE_BULLISH);
}

bool CMarketStructure::IsBearish()
{
   return (m_analysis.state == STRUCTURE_BEARISH);
}

bool CMarketStructure::IsRange()
{
   return (m_analysis.state == STRUCTURE_RANGE);
}

bool CMarketStructure::IsInTransition()
{
   return (m_analysis.state == STRUCTURE_TRANSITION);
}

//+------------------------------------------------------------------+
//| ============ GETTERS ÉVÉNEMENTS ============                      |
//+------------------------------------------------------------------+

bool CMarketStructure::HasBOS()
{
   return (m_analysis.lastEvent.eventType == EVENT_BOS_BULLISH ||
           m_analysis.lastEvent.eventType == EVENT_BOS_BEARISH) &&
          m_analysis.barsSinceEvent <= 5;
}

bool CMarketStructure::HasBOSBullish()
{
   return m_analysis.lastEvent.eventType == EVENT_BOS_BULLISH &&
          m_analysis.barsSinceEvent <= 5;
}

bool CMarketStructure::HasBOSBearish()
{
   return m_analysis.lastEvent.eventType == EVENT_BOS_BEARISH &&
          m_analysis.barsSinceEvent <= 5;
}

bool CMarketStructure::HasCHoCH()
{
   return (m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH ||
           m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH) &&
          m_analysis.barsSinceEvent <= 10;
}

bool CMarketStructure::HasCHoCHBullish()
{
   return m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH &&
          m_analysis.barsSinceEvent <= 10;
}

bool CMarketStructure::HasCHoCHBearish()
{
   return m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH &&
          m_analysis.barsSinceEvent <= 10;
}

SStructureEvent CMarketStructure::GetLastEvent()
{
   return m_analysis.lastEvent;
}

int CMarketStructure::GetBarsSinceEvent()
{
   return m_analysis.barsSinceEvent;
}

//+------------------------------------------------------------------+
//| ============ GETTERS SWINGS ============                          |
//+------------------------------------------------------------------+

SSwingPoint CMarketStructure::GetLastHigh()
{
   return m_analysis.lastHigh;
}

SSwingPoint CMarketStructure::GetLastLow()
{
   return m_analysis.lastLow;
}

SSwingPoint CMarketStructure::GetPrevHigh()
{
   return m_analysis.prevHigh;
}

SSwingPoint CMarketStructure::GetPrevLow()
{
   return m_analysis.prevLow;
}

int CMarketStructure::GetSwingCount()
{
   return ArraySize(m_swings);
}

int CMarketStructure::GetSwingHighCount()
{
   return ArraySize(m_swingHighs);
}

int CMarketStructure::GetSwingLowCount()
{
   return ArraySize(m_swingLows);
}

SSwingPoint CMarketStructure::GetSwing(int index)
{
   SSwingPoint empty;
   empty.Reset();

   if(index < 0 || index >= ArraySize(m_swings))
      return empty;

   return m_swings[index];
}

SSwingPoint CMarketStructure::GetSwingHigh(int index)
{
   SSwingPoint empty;
   empty.Reset();

   if(index < 0 || index >= ArraySize(m_swingHighs))
      return empty;

   return m_swingHighs[index];
}

SSwingPoint CMarketStructure::GetSwingLow(int index)
{
   SSwingPoint empty;
   empty.Reset();

   if(index < 0 || index >= ArraySize(m_swingLows))
      return empty;

   return m_swingLows[index];
}

double CMarketStructure::GetLastSwingHighPrice()
{
   if(ArraySize(m_swingHighs) < 1) return 0;
   return m_swingHighs[0].price;
}

double CMarketStructure::GetLastSwingLowPrice()
{
   if(ArraySize(m_swingLows) < 1) return 0;
   return m_swingLows[0].price;
}

//+------------------------------------------------------------------+
//| ============ GETTERS NIVEAUX CLÉS ============                    |
//+------------------------------------------------------------------+

double CMarketStructure::GetKeyHighLevel()
{
   return m_analysis.keyHighLevel;
}

double CMarketStructure::GetKeyLowLevel()
{
   return m_analysis.keyLowLevel;
}

bool CMarketStructure::IsPriceNearKeyLevel(double price, double tolerancePct)
{
   double tolValue = price * tolerancePct / 100.0;

   if(MathAbs(price - m_analysis.keyHighLevel) <= tolValue)
      return true;

   if(MathAbs(price - m_analysis.keyLowLevel) <= tolValue)
      return true;

   return false;
}

bool CMarketStructure::IsPriceAboveStructure(double price)
{
   return (price > m_analysis.keyHighLevel);
}

bool CMarketStructure::IsPriceBelowStructure(double price)
{
   return (price < m_analysis.keyLowLevel);
}

//+------------------------------------------------------------------+
//| ============ FILTRAGE TRADES ============                         |
//+------------------------------------------------------------------+

bool CMarketStructure::AllowLong()
{
   if(m_analysis.state == STRUCTURE_BULLISH)
      return true;

   if(m_analysis.state == STRUCTURE_TRANSITION &&
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH)
      return true;

   if(m_analysis.state == STRUCTURE_RANGE)
      return true;

   return false;
}

bool CMarketStructure::AllowShort()
{
   if(m_analysis.state == STRUCTURE_BEARISH)
      return true;

   if(m_analysis.state == STRUCTURE_TRANSITION &&
      m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH)
      return true;

   if(m_analysis.state == STRUCTURE_RANGE)
      return true;

   return false;
}

bool CMarketStructure::IsCounterTrend(bool wantLong)
{
   if(wantLong)
      return (m_analysis.state == STRUCTURE_BEARISH);
   else
      return (m_analysis.state == STRUCTURE_BULLISH);
}

bool CMarketStructure::IsWithTrend(bool wantLong)
{
   if(wantLong)
      return (m_analysis.state == STRUCTURE_BULLISH);
   else
      return (m_analysis.state == STRUCTURE_BEARISH);
}

int CMarketStructure::GetTrendScore()
{
   int score = 0;

   switch(m_analysis.state)
   {
      case STRUCTURE_BULLISH: score += 50; break;
      case STRUCTURE_BEARISH: score -= 50; break;
      case STRUCTURE_TRANSITION:
         if(m_analysis.lastEvent.eventType == EVENT_CHOCH_BULLISH) score += 25;
         else if(m_analysis.lastEvent.eventType == EVENT_CHOCH_BEARISH) score -= 25;
         break;
   }

   if(m_analysis.lastEvent.isValid && m_analysis.barsSinceEvent <= 10)
   {
      switch(m_analysis.lastEvent.eventType)
      {
         case EVENT_BOS_BULLISH: score += 30; break;
         case EVENT_BOS_BEARISH: score -= 30; break;
         case EVENT_CHOCH_BULLISH: score += 20; break;
         case EVENT_CHOCH_BEARISH: score -= 20; break;
      }
   }

   int checkHighs = MathMin(ArraySize(m_swingHighs), 4);
   int checkLows = MathMin(ArraySize(m_swingLows), 4);

   for(int i = 0; i < checkHighs; i++)
   {
      if(m_swingHighs[i].label == LABEL_HH) score += 5;
      else if(m_swingHighs[i].label == LABEL_LH) score -= 5;
   }

   for(int i = 0; i < checkLows; i++)
   {
      if(m_swingLows[i].label == LABEL_HL) score += 5;
      else if(m_swingLows[i].label == LABEL_LL) score -= 5;
   }

   return MathMax(-100, MathMin(100, score));
}

//+------------------------------------------------------------------+
//| ============ MULTI-TIMEFRAME ============                         |
//+------------------------------------------------------------------+

bool CMarketStructure::UpdateMTF(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES mtf, ENUM_TIMEFRAMES ltf)
{
   CMarketStructure htfAnalyzer, mtfAnalyzer, ltfAnalyzer;

   if(htfAnalyzer.Init(m_symbol, htf))
   {
      m_htfStructure.timeframe = htf;
      m_htfStructure.analysis = htfAnalyzer.GetFullAnalysis();
      m_htfStructure.isValid = true;
      m_htfStructure.lastUpdate = TimeCurrent();
   }

   if(mtfAnalyzer.Init(m_symbol, mtf))
   {
      m_mtfStructure.timeframe = mtf;
      m_mtfStructure.analysis = mtfAnalyzer.GetFullAnalysis();
      m_mtfStructure.isValid = true;
      m_mtfStructure.lastUpdate = TimeCurrent();
   }

   if(ltfAnalyzer.Init(m_symbol, ltf))
   {
      m_ltfStructure.timeframe = ltf;
      m_ltfStructure.analysis = ltfAnalyzer.GetFullAnalysis();
      m_ltfStructure.isValid = true;
      m_ltfStructure.lastUpdate = TimeCurrent();
   }

   return (m_htfStructure.isValid && m_mtfStructure.isValid && m_ltfStructure.isValid);
}

SMTFAlignment CMarketStructure::GetMTFAlignment()
{
   SMTFAlignment alignment;
   alignment.Reset();

   if(!m_htfStructure.isValid || !m_mtfStructure.isValid || !m_ltfStructure.isValid)
   {
      alignment.reason = "Donnees MTF incompletes";
      return alignment;
   }

   alignment.htfState = m_htfStructure.analysis.state;
   alignment.mtfState = m_mtfStructure.analysis.state;
   alignment.ltfState = m_ltfStructure.analysis.state;

   int score = 0;

   if(alignment.htfState == STRUCTURE_BULLISH) score += 50;
   else if(alignment.htfState == STRUCTURE_BEARISH) score -= 50;

   if(alignment.mtfState == STRUCTURE_BULLISH) score += 30;
   else if(alignment.mtfState == STRUCTURE_BEARISH) score -= 30;

   if(alignment.ltfState == STRUCTURE_BULLISH) score += 20;
   else if(alignment.ltfState == STRUCTURE_BEARISH) score -= 20;

   alignment.alignmentScore = MathAbs(score);

   bool allBullish = (alignment.htfState == STRUCTURE_BULLISH &&
                      alignment.mtfState == STRUCTURE_BULLISH &&
                      alignment.ltfState == STRUCTURE_BULLISH);

   bool allBearish = (alignment.htfState == STRUCTURE_BEARISH &&
                      alignment.mtfState == STRUCTURE_BEARISH &&
                      alignment.ltfState == STRUCTURE_BEARISH);

   alignment.isAligned = allBullish || allBearish;

   alignment.allowLong = (alignment.htfState != STRUCTURE_BEARISH);
   alignment.allowShort = (alignment.htfState != STRUCTURE_BULLISH);

   if(alignment.isAligned)
   {
      if(allBullish)
         alignment.reason = "Toutes les UT alignees HAUSSIER";
      else
         alignment.reason = "Toutes les UT alignees BAISSIER";
   }
   else if(alignment.htfState == STRUCTURE_RANGE)
   {
      alignment.reason = "HTF en range - Prudence";
   }
   else if(alignment.htfState != alignment.ltfState)
   {
      alignment.reason = "Conflit HTF/LTF - Attendre alignement";
   }

   return alignment;
}

ENUM_STRUCTURE_STATE CMarketStructure::GetHTFState()
{
   return m_htfStructure.isValid ? m_htfStructure.analysis.state : STRUCTURE_RANGE;
}

ENUM_STRUCTURE_STATE CMarketStructure::GetMTFState()
{
   return m_mtfStructure.isValid ? m_mtfStructure.analysis.state : STRUCTURE_RANGE;
}

ENUM_STRUCTURE_STATE CMarketStructure::GetLTFState()
{
   return m_ltfStructure.isValid ? m_ltfStructure.analysis.state : STRUCTURE_RANGE;
}

bool CMarketStructure::IsMTFAligned()
{
   SMTFAlignment alignment = GetMTFAlignment();
   return alignment.isAligned;
}

bool CMarketStructure::IsHTFBullish()
{
   return (GetHTFState() == STRUCTURE_BULLISH);
}

bool CMarketStructure::IsHTFBearish()
{
   return (GetHTFState() == STRUCTURE_BEARISH);
}

//+------------------------------------------------------------------+
//| ============ ALERTES ============                                 |
//+------------------------------------------------------------------+

ENUM_STRUCTURE_ALERT CMarketStructure::GetAlertLevel()
{
   return m_analysis.alertLevel;
}

string CMarketStructure::GetAlertMessage()
{
   return m_analysis.alertMessage;
}

SStructureAnalysis CMarketStructure::GetFullAnalysis()
{
   return m_analysis;
}

//+------------------------------------------------------------------+
//| ============ COMPATIBILITÉ ANCIENNE API ============              |
//+------------------------------------------------------------------+

bool CMarketStructure::IsHigherHigh(int index)
{
   if(index >= ArraySize(m_swingHighs) - 1) return false;
   return (m_swingHighs[index].label == LABEL_HH);
}

bool CMarketStructure::IsHigherLow(int index)
{
   if(index >= ArraySize(m_swingLows) - 1) return false;
   return (m_swingLows[index].label == LABEL_HL);
}

bool CMarketStructure::IsLowerHigh(int index)
{
   if(index >= ArraySize(m_swingHighs) - 1) return false;
   return (m_swingHighs[index].label == LABEL_LH);
}

bool CMarketStructure::IsLowerLow(int index)
{
   if(index >= ArraySize(m_swingLows) - 1) return false;
   return (m_swingLows[index].label == LABEL_LL);
}

bool CMarketStructure::IsBullishBOS(int shift)
{
   double currentClose = iClose(m_symbol, m_timeframe, shift);
   if(ArraySize(m_swingHighs) < 1) return false;

   // BOS haussier = clôture au-dessus du dernier HH
   if(m_swingHighs[0].label == LABEL_HH && currentClose > m_swingHighs[0].price)
      return true;

   return false;
}

bool CMarketStructure::IsBearishBOS(int shift)
{
   double currentClose = iClose(m_symbol, m_timeframe, shift);
   if(ArraySize(m_swingLows) < 1) return false;

   // BOS baissier = clôture en-dessous du dernier LL
   if(m_swingLows[0].label == LABEL_LL && currentClose < m_swingLows[0].price)
      return true;

   return false;
}

bool CMarketStructure::IsBullishCHoCH(int shift)
{
   // CHoCH haussier = en tendance baissière, casser le dernier LH
   if(m_analysis.state != STRUCTURE_BEARISH) return false;

   double currentClose = iClose(m_symbol, m_timeframe, shift);
   if(ArraySize(m_swingHighs) < 1) return false;

   if(m_swingHighs[0].label == LABEL_LH && currentClose > m_swingHighs[0].price)
      return true;

   return false;
}

bool CMarketStructure::IsBearishCHoCH(int shift)
{
   // CHoCH baissier = en tendance haussière, casser le dernier HL
   if(m_analysis.state != STRUCTURE_BULLISH) return false;

   double currentClose = iClose(m_symbol, m_timeframe, shift);
   if(ArraySize(m_swingLows) < 1) return false;

   if(m_swingLows[0].label == LABEL_HL && currentClose < m_swingLows[0].price)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| ============ UTILITAIRES ============                             |
//+------------------------------------------------------------------+

string CMarketStructure::SwingToString(SSwingPoint &swing)
{
   if(!swing.isValid) return "Swing invalide";

   string typeStr = (swing.type == SWING_HIGH) ? "HIGH" : "LOW";
   string labelStr = "";

   switch(swing.label)
   {
      case LABEL_HH: labelStr = "HH"; break;
      case LABEL_HL: labelStr = "HL"; break;
      case LABEL_LH: labelStr = "LH"; break;
      case LABEL_LL: labelStr = "LL"; break;
      case LABEL_EQUAL_HIGH: labelStr = "EQ-H"; break;
      case LABEL_EQUAL_LOW: labelStr = "EQ-L"; break;
      default: labelStr = "?"; break;
   }

   return StringFormat("%s [%s] @ %.5f", typeStr, labelStr, swing.price);
}

string CMarketStructure::EventToString(SStructureEvent &event)
{
   if(!event.isValid) return "Aucun evenement";

   string typeStr = "";
   switch(event.eventType)
   {
      case EVENT_BOS_BULLISH: typeStr = "BOS Haussier"; break;
      case EVENT_BOS_BEARISH: typeStr = "BOS Baissier"; break;
      case EVENT_CHOCH_BULLISH: typeStr = "CHoCH Haussier"; break;
      case EVENT_CHOCH_BEARISH: typeStr = "CHoCH Baissier"; break;
      default: typeStr = "Inconnu"; break;
   }

   string qualityStr = "";
   switch(event.quality)
   {
      case QUALITY_HIGH: qualityStr = "Haute"; break;
      case QUALITY_MEDIUM: qualityStr = "Moyenne"; break;
      case QUALITY_LOW: qualityStr = "Faible"; break;
      default: qualityStr = "?"; break;
   }

   return StringFormat("%s (Qualite: %s) - Depl: %.2f%%", typeStr, qualityStr, event.displacementPct);
}

string CMarketStructure::StateToString(ENUM_STRUCTURE_STATE state)
{
   switch(state)
   {
      case STRUCTURE_BULLISH: return "HAUSSIER";
      case STRUCTURE_BEARISH: return "BAISSIER";
      case STRUCTURE_RANGE: return "RANGE";
      case STRUCTURE_TRANSITION: return "TRANSITION";
      default: return "INCONNU";
   }
}

string CMarketStructure::GetStructureSummary()
{
   string summary = "";

   summary += "=== MARKET STRUCTURE ===\n";
   summary += "Etat: " + GetStateString() + "\n";
   summary += "Score tendance: " + IntegerToString(GetTrendScore()) + "/100\n";
   summary += "\n";

   summary += "Dernier High: " + SwingToString(m_analysis.lastHigh) + "\n";
   summary += "Dernier Low: " + SwingToString(m_analysis.lastLow) + "\n";
   summary += "\n";

   summary += "Dernier evenement: " + EventToString(m_analysis.lastEvent) + "\n";
   summary += "Barres depuis: " + IntegerToString(m_analysis.barsSinceEvent) + "\n";
   summary += "\n";

   summary += "Niveau haut cle: " + DoubleToString(m_analysis.keyHighLevel, 5) + "\n";
   summary += "Niveau bas cle: " + DoubleToString(m_analysis.keyLowLevel, 5) + "\n";
   summary += "\n";

   summary += "Long autorise: " + (AllowLong() ? "OUI" : "NON") + "\n";
   summary += "Short autorise: " + (AllowShort() ? "OUI" : "NON") + "\n";

   if(m_analysis.alertLevel != ALERT_NONE)
   {
      summary += "\n";
      summary += "ALERTE: " + m_analysis.alertMessage + "\n";
   }

   return summary;
}

//+------------------------------------------------------------------+
