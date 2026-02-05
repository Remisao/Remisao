//+------------------------------------------------------------------+
//|                                                  SmartMoney.mqh |
//|                     MODULE ORDER BLOCKS & FAIR VALUE GAPS        |
//|                        Smart Money Concepts Professionnel        |
//+------------------------------------------------------------------+
#property copyright "Trading Bot - SMC Professional"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE SMC:                                                  |
//| Les institutions laissent des empreintes                          |
//| Ces empreintes sont des ZONES, pas des lignes                     |
//|                                                                   |
//| RÈGLES FONDAMENTALES:                                             |
//| - Order Block = dernière bougie opposée AVANT impulsion + BOS    |
//| - PAS DE BOS = PAS D'ORDER BLOCK (règle critique)                |
//| - FVG = déséquilibre de prix (structure 3 bougies)               |
//| - On n'anticipe pas une zone, on attend le retour du prix        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ÉNUMÉRATIONS                                                      |
//+------------------------------------------------------------------+

// Type d'Order Block
enum ENUM_OB_TYPE
{
   OB_NONE = 0,
   OB_BULLISH,              // Order Block haussier (zone de demande)
   OB_BEARISH               // Order Block baissier (zone d'offre)
};

// Statut d'une zone
enum ENUM_SMC_ZONE_STATUS
{
   ZONE_ACTIVE,             // Zone active, non testée
   ZONE_TESTED,             // Zone testée mais pas invalidée
   ZONE_PARTIALLY_FILLED,   // Partiellement comblée (FVG)
   ZONE_INVALIDATED,        // Zone invalidée/cassée
   ZONE_MITIGATED           // Zone mitiguée (OB touché)
};

// Qualité d'une zone
enum ENUM_SMC_ZONE_QUALITY
{
   SMC_QUALITY_PREMIUM,         // Qualité premium (confluence forte)
   SMC_QUALITY_HIGH,            // Haute qualité
   SMC_QUALITY_MEDIUM,          // Qualité moyenne
   SMC_QUALITY_LOW,             // Faible qualité
   SMC_QUALITY_INVALID          // Invalide
};

// Type d'événement de zone
enum ENUM_ZONE_EVENT
{
   ZONE_EVENT_NONE,
   ZONE_EVENT_CREATED,      // Zone créée
   ZONE_EVENT_PRICE_ENTER,  // Prix entre dans la zone
   ZONE_EVENT_PRICE_EXIT,   // Prix sort de la zone
   ZONE_EVENT_TESTED,       // Zone testée
   ZONE_EVENT_INVALIDATED,  // Zone invalidée
   ZONE_EVENT_FILLED        // Zone comblée (FVG)
};

// Niveau d'alerte
enum ENUM_SMC_ALERT
{
   SMC_ALERT_NONE,
   SMC_ALERT_INFO,          // Information (zone détectée)
   SMC_ALERT_SETUP,         // Setup (prix entre dans zone)
   SMC_ALERT_INVALIDATION   // Invalidation (zone cassée)
};

// Mode de marquage OB
enum ENUM_OB_MODE
{
   OB_MODE_BODY,            // Utiliser Open/Close
   OB_MODE_WICK             // Utiliser High/Low
};

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES                                             |
//+------------------------------------------------------------------+

// Structure Order Block complète
struct SOrderBlock
{
   // Identification
   int                  id;              // ID unique
   ENUM_OB_TYPE         type;            // Haussier ou Baissier
   ENUM_SMC_ZONE_STATUS     status;          // Statut actuel
   ENUM_SMC_ZONE_QUALITY    quality;         // Qualité de la zone
   ENUM_TIMEFRAMES      timeframe;       // UT d'origine

   // Zone
   double               high;            // Haut de la zone
   double               low;             // Bas de la zone
   double               open;            // Open de la bougie OB
   double               close;           // Close de la bougie OB
   double               midPoint;        // Point médian
   double               zoneSize;        // Taille de la zone
   double               zoneSizePct;     // Taille en %

   // Contexte
   datetime             time;            // Horodatage création
   int                  barIndex;        // Index de la barre OB
   int                  bosBarIndex;     // Index du BOS associé
   double               impulseSize;     // Taille de l'impulsion
   double               impulseSizePct;  // Impulsion en %
   bool                 hasBOS;          // Lié à un BOS valide

   // Suivi
   int                  testCount;       // Nombre de tests
   datetime             lastTest;        // Dernier test
   double               fillLevel;       // Niveau de remplissage (0-100%)
   bool                 priceInZone;     // Prix actuellement dans la zone

   // Validité
   bool                 isValid;
   int                  score;           // Score qualité (0-100)

   void Reset()
   {
      id = 0;
      type = OB_NONE;
      status = ZONE_ACTIVE;
      quality = SMC_QUALITY_INVALID;
      timeframe = PERIOD_CURRENT;
      high = 0;
      low = 0;
      open = 0;
      close = 0;
      midPoint = 0;
      zoneSize = 0;
      zoneSizePct = 0;
      time = 0;
      barIndex = -1;
      bosBarIndex = -1;
      impulseSize = 0;
      impulseSizePct = 0;
      hasBOS = false;
      testCount = 0;
      lastTest = 0;
      fillLevel = 0;
      priceInZone = false;
      isValid = false;
      score = 0;
   }
};

// Structure Fair Value Gap complète
struct SFairValueGap
{
   // Identification
   int                  id;              // ID unique
   bool                 isBullish;       // Direction
   ENUM_SMC_ZONE_STATUS     status;          // Statut actuel
   ENUM_SMC_ZONE_QUALITY    quality;         // Qualité
   ENUM_TIMEFRAMES      timeframe;       // UT d'origine

   // Zone
   double               high;            // Haut du gap
   double               low;             // Bas du gap
   double               midPoint;        // Point médian
   double               gapSize;         // Taille du gap
   double               gapSizePct;      // Taille en %

   // Bougies (structure 3 bougies)
   double               candle1High;     // Bougie 1 (récente)
   double               candle1Low;
   double               candle2High;     // Bougie 2 (milieu - impulsion)
   double               candle2Low;
   double               candle3High;     // Bougie 3 (ancienne)
   double               candle3Low;

   // Contexte
   datetime             time;            // Horodatage création
   int                  barIndex;        // Index barre du milieu
   double               impulseSize;     // Taille de l'impulsion

   // Suivi du remplissage
   double               fillLevel;       // Niveau de remplissage (0-100%)
   double               currentFillHigh; // Niveau haut actuel du gap
   double               currentFillLow;  // Niveau bas actuel du gap
   bool                 priceInZone;     // Prix dans le gap

   // Validité
   bool                 isValid;
   int                  score;           // Score qualité (0-100)

   void Reset()
   {
      id = 0;
      isBullish = false;
      status = ZONE_ACTIVE;
      quality = SMC_QUALITY_INVALID;
      timeframe = PERIOD_CURRENT;
      high = 0;
      low = 0;
      midPoint = 0;
      gapSize = 0;
      gapSizePct = 0;
      candle1High = 0;
      candle1Low = 0;
      candle2High = 0;
      candle2Low = 0;
      candle3High = 0;
      candle3Low = 0;
      time = 0;
      barIndex = -1;
      impulseSize = 0;
      fillLevel = 0;
      currentFillHigh = 0;
      currentFillLow = 0;
      priceInZone = false;
      isValid = false;
      score = 0;
   }
};

// Structure de liquidité
struct SLiquidity
{
   int                  id;
   double               level;           // Niveau de liquidité
   bool                 isHighLiquidity; // Equal highs (true) ou equal lows (false)
   int                  touchCount;      // Nombre de touches
   datetime             firstTouch;      // Premier contact
   datetime             lastTouch;       // Dernier contact
   bool                 isSwept;         // Liquidité prise
   datetime             sweepTime;       // Quand la liquidité a été prise
   ENUM_TIMEFRAMES      timeframe;
   bool                 isValid;

   void Reset()
   {
      id = 0;
      level = 0;
      isHighLiquidity = false;
      touchCount = 0;
      firstTouch = 0;
      lastTouch = 0;
      isSwept = false;
      sweepTime = 0;
      timeframe = PERIOD_CURRENT;
      isValid = false;
   }
};

// Événement de zone
struct SZoneEvent
{
   ENUM_ZONE_EVENT      eventType;
   int                  zoneId;
   bool                 isOrderBlock;    // true = OB, false = FVG
   double               price;
   datetime             time;
   string               message;
   bool                 isValid;

   void Reset()
   {
      eventType = ZONE_EVENT_NONE;
      zoneId = 0;
      isOrderBlock = true;
      price = 0;
      time = 0;
      message = "";
      isValid = false;
   }
};

// Analyse SMC complète
struct SSMCAnalysis
{
   // Compteurs
   int                  activeOBCount;
   int                  activeFVGCount;
   int                  activeLiquidityCount;

   // Zones proches
   SOrderBlock          nearestBullishOB;
   SOrderBlock          nearestBearishOB;
   SFairValueGap        nearestBullishFVG;
   SFairValueGap        nearestBearishFVG;

   // Confluence
   bool                 hasBullishConfluence;
   bool                 hasBearishConfluence;
   int                  bullishScore;
   int                  bearishScore;

   // Événement récent
   SZoneEvent           lastEvent;

   // Alerte
   ENUM_SMC_ALERT       alertLevel;
   string               alertMessage;

   void Reset()
   {
      activeOBCount = 0;
      activeFVGCount = 0;
      activeLiquidityCount = 0;
      nearestBullishOB.Reset();
      nearestBearishOB.Reset();
      nearestBullishFVG.Reset();
      nearestBearishFVG.Reset();
      hasBullishConfluence = false;
      hasBearishConfluence = false;
      bullishScore = 0;
      bearishScore = 0;
      lastEvent.Reset();
      alertLevel = SMC_ALERT_NONE;
      alertMessage = "";
   }
};

// Structure MTF SMC
struct SMTFSmartMoney
{
   ENUM_TIMEFRAMES      timeframe;
   SSMCAnalysis         analysis;
   bool                 isValid;
   datetime             lastUpdate;

   void Reset()
   {
      timeframe = PERIOD_CURRENT;
      analysis.Reset();
      isValid = false;
      lastUpdate = 0;
   }
};

//+------------------------------------------------------------------+
//| CLASSE PRINCIPALE - Smart Money Concepts                          |
//+------------------------------------------------------------------+
class CSmartMoney
{
private:
   //--- Paramètres
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_lookbackBars;
   ENUM_OB_MODE         m_obMode;        // Mode de marquage OB
   double               m_minImpulsePct; // Impulsion min pour OB (%)
   double               m_minGapPct;     // Gap min pour FVG (%)
   double               m_maxDistancePct;// Distance max du prix (%)
   double               m_equalTolerance;// Tolérance equal H/L (%)

   //--- Données internes
   SOrderBlock          m_orderBlocks[];
   SFairValueGap        m_fvgs[];
   SLiquidity           m_liquidityLevels[];
   SSMCAnalysis         m_analysis;
   int                  m_nextOBId;
   int                  m_nextFVGId;
   int                  m_nextLiqId;
   int                  m_maxZones;

   //--- Cache
   datetime             m_lastBarTime;
   bool                 m_initialized;

   //--- MTF
   SMTFSmartMoney       m_htfSMC;
   SMTFSmartMoney       m_ltfSMC;

   //--- Méthodes privées - Order Blocks
   bool                 DetectBullishOB(int bosBarIndex, SOrderBlock &ob);
   bool                 DetectBearishOB(int bosBarIndex, SOrderBlock &ob);
   int                  FindLastBearishCandle(int startBar, int maxLookback);
   int                  FindLastBullishCandle(int startBar, int maxLookback);
   bool                 ValidateOBImpulse(int obBar, int bosBar, bool isBullish);
   int                  CalculateOBScore(SOrderBlock &ob);
   ENUM_SMC_ZONE_QUALITY    ScoreToQuality(int score);

   //--- Méthodes privées - FVG
   bool                 DetectBullishFVG(int shift, SFairValueGap &fvg);
   bool                 DetectBearishFVG(int shift, SFairValueGap &fvg);
   void                 UpdateFVGFillLevel(SFairValueGap &fvg);
   int                  CalculateFVGScore(SFairValueGap &fvg);

   //--- Méthodes privées - Liquidité
   void                 DetectEqualHighs();
   void                 DetectEqualLows();
   bool                 ArePricesEqual(double price1, double price2);

   //--- Méthodes privées - Gestion zones
   void                 UpdateZoneStatuses();
   void                 UpdateOBStatus(SOrderBlock &ob);
   void                 UpdateFVGStatus(SFairValueGap &fvg);
   void                 CleanupInvalidZones();
   bool                 IsPriceInZone(double price, double high, double low);

   //--- Méthodes privées - Utilitaires
   double               GetPointValue();
   double               CalculatePercentage(double value, double reference);
   void                 AddOrderBlock(SOrderBlock &ob);
   void                 AddFVG(SFairValueGap &fvg);
   void                 GenerateEvent(ENUM_ZONE_EVENT eventType, int zoneId, bool isOB, double price, string msg);
   void                 UpdateAnalysis();
   void                 GenerateAlert();

public:
   //--- Constructeur/Destructeur
                        CSmartMoney();
                       ~CSmartMoney();

   //--- Initialisation
   bool                 Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void                 SetParameters(int lookback, ENUM_OB_MODE obMode, double minImpulsePct, double minGapPct, double maxDistancePct);
   void                 Deinit();

   //--- Mise à jour
   bool                 Update();
   bool                 ForceUpdate();

   //--- ============ ORDER BLOCKS ============
   void                 DetectOrderBlocks();
   void                 DetectOrderBlocksFromBOS(int bosBarIndex, bool isBullish);
   int                  GetOrderBlockCount();
   int                  GetActiveOBCount();
   SOrderBlock          GetOrderBlock(int index);
   SOrderBlock          GetNearestBullishOB(double price);
   SOrderBlock          GetNearestBearishOB(double price);
   bool                 IsPriceInOB(double price, SOrderBlock &ob);
   bool                 IsPriceInAnyBullishOB(double price);
   bool                 IsPriceInAnyBearishOB(double price);

   //--- ============ FAIR VALUE GAPS ============
   void                 DetectFVGs();
   int                  GetFVGCount();
   int                  GetActiveFVGCount();
   SFairValueGap        GetFVG(int index);
   SFairValueGap        GetNearestBullishFVG(double price);
   SFairValueGap        GetNearestBearishFVG(double price);
   bool                 IsPriceInFVG(double price, SFairValueGap &fvg);
   bool                 IsPriceInAnyBullishFVG(double price);
   bool                 IsPriceInAnyBearishFVG(double price);

   //--- ============ LIQUIDITÉ ============
   void                 DetectLiquidity();
   int                  GetLiquidityCount();
   SLiquidity           GetLiquidity(int index);
   SLiquidity           GetNearestHighLiquidity(double price);
   SLiquidity           GetNearestLowLiquidity(double price);
   bool                 IsLiquiditySwept(int index);

   //--- ============ CONFLUENCE ============
   bool                 HasBullishConfluence(double price);
   bool                 HasBearishConfluence(double price);
   int                  GetBullishScore(double price);
   int                  GetBearishScore(double price);
   bool                 HasOBFVGConfluence(double price, bool lookingForBuy);

   //--- ============ ZONES PROCHES ============
   bool                 GetNearestBullishZone(double price, double &zoneHigh, double &zoneLow);
   bool                 GetNearestBearishZone(double price, double &zoneHigh, double &zoneLow);
   double               GetDistanceToNearestBullishZone(double price);
   double               GetDistanceToNearestBearishZone(double price);

   //--- ============ MULTI-TIMEFRAME ============
   bool                 UpdateMTF(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf);
   bool                 HasHTFBullishOB();
   bool                 HasHTFBearishOB();
   bool                 HasLTFBullishFVG();
   bool                 HasLTFBearishFVG();
   bool                 IsMTFConfluent(bool lookingForBuy);

   //--- ============ ÉVÉNEMENTS & ALERTES ============
   SZoneEvent           GetLastEvent();
   ENUM_SMC_ALERT       GetAlertLevel();
   string               GetAlertMessage();
   SSMCAnalysis         GetFullAnalysis();

   //--- ============ UTILITAIRES ============
   string               OrderBlockToString(SOrderBlock &ob);
   string               FVGToString(SFairValueGap &fvg);
   string               LiquidityToString(SLiquidity &liq);
   string               ZoneStatusToString(ENUM_SMC_ZONE_STATUS status);
   string               ZoneQualityToString(ENUM_SMC_ZONE_QUALITY quality);
   string               GetSMCSummary();

   //--- ============ COMPATIBILITÉ ANCIENNE API ============
   void                 AnalyzeAll() { ForceUpdate(); }
   bool                 HasSMCConfluence(double price, bool lookingForBuy);
   string               GetSMCAlert();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CSmartMoney::CSmartMoney()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookbackBars = 200;
   m_obMode = OB_MODE_WICK;
   m_minImpulsePct = 0.3;     // 0.3% impulsion min
   m_minGapPct = 0.05;        // 0.05% gap min
   m_maxDistancePct = 5.0;    // 5% distance max du prix
   m_equalTolerance = 0.1;    // 0.1% tolérance
   m_nextOBId = 1;
   m_nextFVGId = 1;
   m_nextLiqId = 1;
   m_maxZones = 50;
   m_lastBarTime = 0;
   m_initialized = false;

   ArrayResize(m_orderBlocks, 0);
   ArrayResize(m_fvgs, 0);
   ArrayResize(m_liquidityLevels, 0);
   m_analysis.Reset();
   m_htfSMC.Reset();
   m_ltfSMC.Reset();
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CSmartMoney::~CSmartMoney()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CSmartMoney::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   if(!SymbolSelect(m_symbol, true))
   {
      Print("SmartMoney: Symbole invalide - ", m_symbol);
      return false;
   }

   ArrayResize(m_orderBlocks, 0);
   ArrayResize(m_fvgs, 0);
   ArrayResize(m_liquidityLevels, 0);
   m_analysis.Reset();
   m_initialized = true;

   ForceUpdate();
   return true;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CSmartMoney::SetParameters(int lookback, ENUM_OB_MODE obMode, double minImpulsePct, double minGapPct, double maxDistancePct)
{
   m_lookbackBars = MathMax(50, lookback);
   m_obMode = obMode;
   m_minImpulsePct = MathMax(0.1, minImpulsePct);
   m_minGapPct = MathMax(0.01, minGapPct);
   m_maxDistancePct = MathMax(1.0, maxDistancePct);
}

//+------------------------------------------------------------------+
//| Libération des ressources                                         |
//+------------------------------------------------------------------+
void CSmartMoney::Deinit()
{
   ArrayFree(m_orderBlocks);
   ArrayFree(m_fvgs);
   ArrayFree(m_liquidityLevels);
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un point                                      |
//+------------------------------------------------------------------+
double CSmartMoney::GetPointValue()
{
   return SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Calculer un pourcentage                                           |
//+------------------------------------------------------------------+
double CSmartMoney::CalculatePercentage(double value, double reference)
{
   if(reference == 0) return 0;
   return MathAbs(value / reference) * 100.0;
}

//+------------------------------------------------------------------+
//| Mise à jour (optimisée)                                           |
//+------------------------------------------------------------------+
bool CSmartMoney::Update()
{
   if(!m_initialized) return false;

   datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
   if(currentBarTime == m_lastBarTime) return true;

   m_lastBarTime = currentBarTime;
   return ForceUpdate();
}

//+------------------------------------------------------------------+
//| Mise à jour forcée                                                |
//+------------------------------------------------------------------+
bool CSmartMoney::ForceUpdate()
{
   if(!m_initialized) return false;

   // 1. Mettre à jour les statuts des zones existantes
   UpdateZoneStatuses();

   // 2. Détecter nouvelles zones (OB liés au BOS)
   DetectOrderBlocks();

   // 3. Détecter FVG
   DetectFVGs();

   // 4. Détecter liquidité
   DetectLiquidity();

   // 5. Nettoyer les zones invalides
   CleanupInvalidZones();

   // 6. Mettre à jour l'analyse
   UpdateAnalysis();

   // 7. Générer alertes
   GenerateAlert();

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone                             |
//+------------------------------------------------------------------+
bool CSmartMoney::IsPriceInZone(double price, double high, double low)
{
   return (price >= low && price <= high);
}

//+------------------------------------------------------------------+
//| Vérifier si deux prix sont égaux (avec tolérance)                 |
//+------------------------------------------------------------------+
bool CSmartMoney::ArePricesEqual(double price1, double price2)
{
   double avgPrice = (price1 + price2) / 2.0;
   double tolerance = avgPrice * (m_equalTolerance / 100.0);
   return (MathAbs(price1 - price2) <= tolerance);
}

//+------------------------------------------------------------------+
//| ============ DÉTECTION ORDER BLOCKS ============                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détecter les Order Blocks (liés au BOS)                           |
//| RÈGLE CRITIQUE: Pas de BOS = Pas d'Order Block                    |
//+------------------------------------------------------------------+
void CSmartMoney::DetectOrderBlocks()
{
   int bars = MathMin(iBars(m_symbol, m_timeframe), m_lookbackBars);

   // Scanner les barres récentes pour trouver des BOS
   for(int i = 3; i < bars - 5; i++)
   {
      double close = iClose(m_symbol, m_timeframe, i);
      double prevClose = iClose(m_symbol, m_timeframe, i + 1);

      // Trouver les swing highs/lows récents
      double swingHigh = 0;
      double swingLow = DBL_MAX;

      for(int j = i + 1; j < MathMin(i + 20, bars); j++)
      {
         double h = iHigh(m_symbol, m_timeframe, j);
         double l = iLow(m_symbol, m_timeframe, j);

         // Swing High simple
         if(j > i + 1 && j < bars - 1)
         {
            if(h > iHigh(m_symbol, m_timeframe, j - 1) &&
               h > iHigh(m_symbol, m_timeframe, j + 1))
            {
               if(swingHigh == 0) swingHigh = h;
            }
         }

         // Swing Low simple
         if(j > i + 1 && j < bars - 1)
         {
            if(l < iLow(m_symbol, m_timeframe, j - 1) &&
               l < iLow(m_symbol, m_timeframe, j + 1))
            {
               if(swingLow == DBL_MAX) swingLow = l;
            }
         }
      }

      // BOS Haussier: clôture au-dessus du swing high
      if(swingHigh > 0 && close > swingHigh && prevClose <= swingHigh)
      {
         DetectOrderBlocksFromBOS(i, true);
      }

      // BOS Baissier: clôture en-dessous du swing low
      if(swingLow < DBL_MAX && close < swingLow && prevClose >= swingLow)
      {
         DetectOrderBlocksFromBOS(i, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter OB à partir d'un BOS validé                              |
//+------------------------------------------------------------------+
void CSmartMoney::DetectOrderBlocksFromBOS(int bosBarIndex, bool isBullish)
{
   SOrderBlock ob;
   ob.Reset();

   if(isBullish)
   {
      if(DetectBullishOB(bosBarIndex, ob))
      {
         // Vérifier que cet OB n'existe pas déjà
         bool exists = false;
         for(int i = 0; i < ArraySize(m_orderBlocks); i++)
         {
            if(m_orderBlocks[i].time == ob.time && m_orderBlocks[i].type == ob.type)
            {
               exists = true;
               break;
            }
         }

         if(!exists)
         {
            ob.hasBOS = true;
            ob.bosBarIndex = bosBarIndex;
            AddOrderBlock(ob);
         }
      }
   }
   else
   {
      if(DetectBearishOB(bosBarIndex, ob))
      {
         bool exists = false;
         for(int i = 0; i < ArraySize(m_orderBlocks); i++)
         {
            if(m_orderBlocks[i].time == ob.time && m_orderBlocks[i].type == ob.type)
            {
               exists = true;
               break;
            }
         }

         if(!exists)
         {
            ob.hasBOS = true;
            ob.bosBarIndex = bosBarIndex;
            AddOrderBlock(ob);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trouver la dernière bougie baissière avant le BOS                 |
//+------------------------------------------------------------------+
int CSmartMoney::FindLastBearishCandle(int startBar, int maxLookback)
{
   for(int i = startBar + 1; i < startBar + maxLookback; i++)
   {
      double open = iOpen(m_symbol, m_timeframe, i);
      double close = iClose(m_symbol, m_timeframe, i);

      if(close < open)  // Bougie baissière
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Trouver la dernière bougie haussière avant le BOS                 |
//+------------------------------------------------------------------+
int CSmartMoney::FindLastBullishCandle(int startBar, int maxLookback)
{
   for(int i = startBar + 1; i < startBar + maxLookback; i++)
   {
      double open = iOpen(m_symbol, m_timeframe, i);
      double close = iClose(m_symbol, m_timeframe, i);

      if(close > open)  // Bougie haussière
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Détecter un Order Block haussier                                  |
//| = Dernière bougie BAISSIÈRE avant impulsion haussière + BOS       |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBullishOB(int bosBarIndex, SOrderBlock &ob)
{
   // Trouver la dernière bougie baissière avant l'impulsion
   int obBar = FindLastBearishCandle(bosBarIndex, 10);
   if(obBar < 0) return false;

   // Valider l'impulsion
   if(!ValidateOBImpulse(obBar, bosBarIndex, true))
      return false;

   // Récupérer les données de la bougie OB
   double obOpen = iOpen(m_symbol, m_timeframe, obBar);
   double obClose = iClose(m_symbol, m_timeframe, obBar);
   double obHigh = iHigh(m_symbol, m_timeframe, obBar);
   double obLow = iLow(m_symbol, m_timeframe, obBar);

   // Créer l'OB
   ob.id = m_nextOBId++;
   ob.type = OB_BULLISH;
   ob.status = ZONE_ACTIVE;
   ob.timeframe = m_timeframe;

   // Zone selon le mode
   if(m_obMode == OB_MODE_BODY)
   {
      ob.high = MathMax(obOpen, obClose);
      ob.low = MathMin(obOpen, obClose);
   }
   else  // OB_MODE_WICK
   {
      ob.high = obHigh;
      ob.low = obLow;
   }

   ob.open = obOpen;
   ob.close = obClose;
   ob.midPoint = (ob.high + ob.low) / 2.0;
   ob.zoneSize = ob.high - ob.low;
   ob.zoneSizePct = CalculatePercentage(ob.zoneSize, ob.midPoint);

   ob.time = iTime(m_symbol, m_timeframe, obBar);
   ob.barIndex = obBar;

   // Calculer la taille de l'impulsion
   double bosHigh = iHigh(m_symbol, m_timeframe, bosBarIndex);
   ob.impulseSize = bosHigh - ob.low;
   ob.impulseSizePct = CalculatePercentage(ob.impulseSize, ob.midPoint);

   ob.testCount = 0;
   ob.lastTest = 0;
   ob.fillLevel = 0;
   ob.priceInZone = false;

   // Calculer le score et la qualité
   ob.score = CalculateOBScore(ob);
   ob.quality = ScoreToQuality(ob.score);
   ob.isValid = (ob.quality != SMC_QUALITY_INVALID);

   return ob.isValid;
}

//+------------------------------------------------------------------+
//| Détecter un Order Block baissier                                  |
//| = Dernière bougie HAUSSIÈRE avant impulsion baissière + BOS       |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBearishOB(int bosBarIndex, SOrderBlock &ob)
{
   int obBar = FindLastBullishCandle(bosBarIndex, 10);
   if(obBar < 0) return false;

   if(!ValidateOBImpulse(obBar, bosBarIndex, false))
      return false;

   double obOpen = iOpen(m_symbol, m_timeframe, obBar);
   double obClose = iClose(m_symbol, m_timeframe, obBar);
   double obHigh = iHigh(m_symbol, m_timeframe, obBar);
   double obLow = iLow(m_symbol, m_timeframe, obBar);

   ob.id = m_nextOBId++;
   ob.type = OB_BEARISH;
   ob.status = ZONE_ACTIVE;
   ob.timeframe = m_timeframe;

   if(m_obMode == OB_MODE_BODY)
   {
      ob.high = MathMax(obOpen, obClose);
      ob.low = MathMin(obOpen, obClose);
   }
   else
   {
      ob.high = obHigh;
      ob.low = obLow;
   }

   ob.open = obOpen;
   ob.close = obClose;
   ob.midPoint = (ob.high + ob.low) / 2.0;
   ob.zoneSize = ob.high - ob.low;
   ob.zoneSizePct = CalculatePercentage(ob.zoneSize, ob.midPoint);

   ob.time = iTime(m_symbol, m_timeframe, obBar);
   ob.barIndex = obBar;

   double bosLow = iLow(m_symbol, m_timeframe, bosBarIndex);
   ob.impulseSize = ob.high - bosLow;
   ob.impulseSizePct = CalculatePercentage(ob.impulseSize, ob.midPoint);

   ob.testCount = 0;
   ob.lastTest = 0;
   ob.fillLevel = 0;
   ob.priceInZone = false;

   ob.score = CalculateOBScore(ob);
   ob.quality = ScoreToQuality(ob.score);
   ob.isValid = (ob.quality != SMC_QUALITY_INVALID);

   return ob.isValid;
}

//+------------------------------------------------------------------+
//| Valider l'impulsion d'un OB                                       |
//+------------------------------------------------------------------+
bool CSmartMoney::ValidateOBImpulse(int obBar, int bosBar, bool isBullish)
{
   // Calculer la taille de l'impulsion
   double impulseStart, impulseEnd;

   if(isBullish)
   {
      impulseStart = iLow(m_symbol, m_timeframe, obBar);
      impulseEnd = iHigh(m_symbol, m_timeframe, bosBar);
   }
   else
   {
      impulseStart = iHigh(m_symbol, m_timeframe, obBar);
      impulseEnd = iLow(m_symbol, m_timeframe, bosBar);
   }

   double impulseSize = MathAbs(impulseEnd - impulseStart);
   double avgPrice = (impulseStart + impulseEnd) / 2.0;
   double impulsePct = CalculatePercentage(impulseSize, avgPrice);

   // Vérifier le déplacement minimum
   return (impulsePct >= m_minImpulsePct);
}

//+------------------------------------------------------------------+
//| Calculer le score d'un Order Block (0-100)                        |
//+------------------------------------------------------------------+
int CSmartMoney::CalculateOBScore(SOrderBlock &ob)
{
   int score = 0;

   // 1. Impulsion (0-40 points)
   if(ob.impulseSizePct >= 1.0) score += 40;
   else if(ob.impulseSizePct >= 0.7) score += 30;
   else if(ob.impulseSizePct >= 0.5) score += 20;
   else if(ob.impulseSizePct >= 0.3) score += 10;

   // 2. Lié à un BOS (0-30 points)
   if(ob.hasBOS) score += 30;

   // 3. Taille de la zone (0-15 points) - pas trop grande
   if(ob.zoneSizePct <= 0.3) score += 15;
   else if(ob.zoneSizePct <= 0.5) score += 10;
   else if(ob.zoneSizePct <= 1.0) score += 5;

   // 4. Distance du prix actuel (0-15 points)
   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   double distance = MathAbs(currentPrice - ob.midPoint);
   double distancePct = CalculatePercentage(distance, currentPrice);

   if(distancePct <= 1.0) score += 15;
   else if(distancePct <= 2.0) score += 10;
   else if(distancePct <= 3.0) score += 5;

   return score;
}

//+------------------------------------------------------------------+
//| Convertir un score en qualité                                     |
//+------------------------------------------------------------------+
ENUM_SMC_ZONE_QUALITY CSmartMoney::ScoreToQuality(int score)
{
   if(score >= 85) return SMC_QUALITY_PREMIUM;
   if(score >= 70) return SMC_QUALITY_HIGH;
   if(score >= 50) return SMC_QUALITY_MEDIUM;
   if(score >= 30) return SMC_QUALITY_LOW;
   return SMC_QUALITY_INVALID;
}

//+------------------------------------------------------------------+
//| Ajouter un Order Block                                            |
//+------------------------------------------------------------------+
void CSmartMoney::AddOrderBlock(SOrderBlock &ob)
{
   int size = ArraySize(m_orderBlocks);

   if(size >= m_maxZones)
   {
      // Supprimer le plus ancien
      for(int i = 0; i < size - 1; i++)
         m_orderBlocks[i] = m_orderBlocks[i + 1];
      ArrayResize(m_orderBlocks, size);
      m_orderBlocks[size - 1] = ob;
   }
   else
   {
      ArrayResize(m_orderBlocks, size + 1);
      m_orderBlocks[size] = ob;
   }

   // Générer événement
   GenerateEvent(ZONE_EVENT_CREATED, ob.id, true, ob.midPoint,
                 (ob.type == OB_BULLISH ? "OB Haussier" : "OB Baissier") + " detecte");
}

//+------------------------------------------------------------------+
//| ============ DÉTECTION FVG ============                           |
//+------------------------------------------------------------------+

void CSmartMoney::DetectFVGs()
{
   int bars = MathMin(iBars(m_symbol, m_timeframe), m_lookbackBars);

   for(int i = 2; i < bars - 1; i++)
   {
      SFairValueGap fvg;

      // FVG Haussier
      if(DetectBullishFVG(i, fvg))
      {
         bool exists = false;
         for(int j = 0; j < ArraySize(m_fvgs); j++)
         {
            if(m_fvgs[j].time == fvg.time && m_fvgs[j].isBullish == fvg.isBullish)
            {
               exists = true;
               break;
            }
         }

         if(!exists)
            AddFVG(fvg);
      }

      // FVG Baissier
      fvg.Reset();
      if(DetectBearishFVG(i, fvg))
      {
         bool exists = false;
         for(int j = 0; j < ArraySize(m_fvgs); j++)
         {
            if(m_fvgs[j].time == fvg.time && m_fvgs[j].isBullish == fvg.isBullish)
            {
               exists = true;
               break;
            }
         }

         if(!exists)
            AddFVG(fvg);
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter un FVG haussier (structure 3 bougies)                    |
//| Low bougie 1 > High bougie 3 = gap                                |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBullishFVG(int shift, SFairValueGap &fvg)
{
   // Bougie 1 (la plus récente)
   double c1High = iHigh(m_symbol, m_timeframe, shift - 1);
   double c1Low = iLow(m_symbol, m_timeframe, shift - 1);

   // Bougie 2 (du milieu - impulsion)
   double c2Open = iOpen(m_symbol, m_timeframe, shift);
   double c2Close = iClose(m_symbol, m_timeframe, shift);
   double c2High = iHigh(m_symbol, m_timeframe, shift);
   double c2Low = iLow(m_symbol, m_timeframe, shift);

   // Bougie 3 (la plus ancienne)
   double c3High = iHigh(m_symbol, m_timeframe, shift + 1);
   double c3Low = iLow(m_symbol, m_timeframe, shift + 1);

   // Vérifier le gap: Low de bougie 1 > High de bougie 3
   if(c1Low <= c3High) return false;

   // La bougie du milieu doit être haussière
   if(c2Close <= c2Open) return false;

   // Calculer la taille du gap
   double gapSize = c1Low - c3High;
   double avgPrice = (c1Low + c3High) / 2.0;
   double gapPct = CalculatePercentage(gapSize, avgPrice);

   // Vérifier la taille minimum
   if(gapPct < m_minGapPct) return false;

   // Créer le FVG
   fvg.id = m_nextFVGId++;
   fvg.isBullish = true;
   fvg.status = ZONE_ACTIVE;
   fvg.timeframe = m_timeframe;

   fvg.high = c1Low;      // Haut du gap = low de bougie 1
   fvg.low = c3High;      // Bas du gap = high de bougie 3
   fvg.midPoint = (fvg.high + fvg.low) / 2.0;
   fvg.gapSize = gapSize;
   fvg.gapSizePct = gapPct;

   fvg.candle1High = c1High;
   fvg.candle1Low = c1Low;
   fvg.candle2High = c2High;
   fvg.candle2Low = c2Low;
   fvg.candle3High = c3High;
   fvg.candle3Low = c3Low;

   fvg.time = iTime(m_symbol, m_timeframe, shift);
   fvg.barIndex = shift;
   fvg.impulseSize = c2High - c2Low;

   fvg.fillLevel = 0;
   fvg.currentFillHigh = fvg.high;
   fvg.currentFillLow = fvg.low;
   fvg.priceInZone = false;

   fvg.score = CalculateFVGScore(fvg);
   fvg.quality = ScoreToQuality(fvg.score);
   fvg.isValid = (fvg.quality != SMC_QUALITY_INVALID);

   return fvg.isValid;
}

//+------------------------------------------------------------------+
//| Détecter un FVG baissier (structure 3 bougies)                    |
//| High bougie 1 < Low bougie 3 = gap                                |
//+------------------------------------------------------------------+
bool CSmartMoney::DetectBearishFVG(int shift, SFairValueGap &fvg)
{
   double c1High = iHigh(m_symbol, m_timeframe, shift - 1);
   double c1Low = iLow(m_symbol, m_timeframe, shift - 1);

   double c2Open = iOpen(m_symbol, m_timeframe, shift);
   double c2Close = iClose(m_symbol, m_timeframe, shift);
   double c2High = iHigh(m_symbol, m_timeframe, shift);
   double c2Low = iLow(m_symbol, m_timeframe, shift);

   double c3High = iHigh(m_symbol, m_timeframe, shift + 1);
   double c3Low = iLow(m_symbol, m_timeframe, shift + 1);

   // High de bougie 1 < Low de bougie 3
   if(c1High >= c3Low) return false;

   // Bougie du milieu baissière
   if(c2Close >= c2Open) return false;

   double gapSize = c3Low - c1High;
   double avgPrice = (c3Low + c1High) / 2.0;
   double gapPct = CalculatePercentage(gapSize, avgPrice);

   if(gapPct < m_minGapPct) return false;

   fvg.id = m_nextFVGId++;
   fvg.isBullish = false;
   fvg.status = ZONE_ACTIVE;
   fvg.timeframe = m_timeframe;

   fvg.high = c3Low;      // Haut du gap = low de bougie 3
   fvg.low = c1High;      // Bas du gap = high de bougie 1
   fvg.midPoint = (fvg.high + fvg.low) / 2.0;
   fvg.gapSize = gapSize;
   fvg.gapSizePct = gapPct;

   fvg.candle1High = c1High;
   fvg.candle1Low = c1Low;
   fvg.candle2High = c2High;
   fvg.candle2Low = c2Low;
   fvg.candle3High = c3High;
   fvg.candle3Low = c3Low;

   fvg.time = iTime(m_symbol, m_timeframe, shift);
   fvg.barIndex = shift;
   fvg.impulseSize = c2High - c2Low;

   fvg.fillLevel = 0;
   fvg.currentFillHigh = fvg.high;
   fvg.currentFillLow = fvg.low;
   fvg.priceInZone = false;

   fvg.score = CalculateFVGScore(fvg);
   fvg.quality = ScoreToQuality(fvg.score);
   fvg.isValid = (fvg.quality != SMC_QUALITY_INVALID);

   return fvg.isValid;
}

//+------------------------------------------------------------------+
//| Calculer le score d'un FVG (0-100)                                |
//+------------------------------------------------------------------+
int CSmartMoney::CalculateFVGScore(SFairValueGap &fvg)
{
   int score = 0;

   // 1. Taille du gap (0-35 points)
   if(fvg.gapSizePct >= 0.3) score += 35;
   else if(fvg.gapSizePct >= 0.2) score += 25;
   else if(fvg.gapSizePct >= 0.1) score += 15;
   else if(fvg.gapSizePct >= 0.05) score += 5;

   // 2. Impulsion de la bougie du milieu (0-30 points)
   double avgPrice = fvg.midPoint;
   double impulsePct = CalculatePercentage(fvg.impulseSize, avgPrice);

   if(impulsePct >= 0.5) score += 30;
   else if(impulsePct >= 0.3) score += 20;
   else if(impulsePct >= 0.2) score += 10;

   // 3. Statut du gap (0-20 points)
   if(fvg.status == ZONE_ACTIVE) score += 20;
   else if(fvg.status == ZONE_PARTIALLY_FILLED) score += 10;

   // 4. Distance du prix actuel (0-15 points)
   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   double distance = MathAbs(currentPrice - fvg.midPoint);
   double distancePct = CalculatePercentage(distance, currentPrice);

   if(distancePct <= 0.5) score += 15;
   else if(distancePct <= 1.0) score += 10;
   else if(distancePct <= 2.0) score += 5;

   return score;
}

//+------------------------------------------------------------------+
//| Mettre à jour le niveau de remplissage d'un FVG                   |
//+------------------------------------------------------------------+
void CSmartMoney::UpdateFVGFillLevel(SFairValueGap &fvg)
{
   if(!fvg.isValid || fvg.status == ZONE_INVALIDATED) return;

   // Vérifier les barres récentes pour le remplissage
   for(int i = 0; i < 20; i++)
   {
      double barHigh = iHigh(m_symbol, m_timeframe, i);
      double barLow = iLow(m_symbol, m_timeframe, i);

      if(fvg.isBullish)
      {
         // FVG haussier: le prix doit descendre dans le gap
         if(barLow < fvg.currentFillHigh)
         {
            fvg.currentFillHigh = barLow;
         }
      }
      else
      {
         // FVG baissier: le prix doit monter dans le gap
         if(barHigh > fvg.currentFillLow)
         {
            fvg.currentFillLow = barHigh;
         }
      }
   }

   // Calculer le niveau de remplissage
   if(fvg.isBullish)
   {
      double filled = fvg.high - fvg.currentFillHigh;
      fvg.fillLevel = (filled / fvg.gapSize) * 100.0;
   }
   else
   {
      double filled = fvg.currentFillLow - fvg.low;
      fvg.fillLevel = (filled / fvg.gapSize) * 100.0;
   }

   fvg.fillLevel = MathMin(100.0, MathMax(0.0, fvg.fillLevel));

   // Mettre à jour le statut
   if(fvg.fillLevel >= 100.0)
   {
      fvg.status = ZONE_INVALIDATED;
      GenerateEvent(ZONE_EVENT_FILLED, fvg.id, false, fvg.midPoint, "FVG entierement comble");
   }
   else if(fvg.fillLevel > 0)
   {
      fvg.status = ZONE_PARTIALLY_FILLED;
   }
}

//+------------------------------------------------------------------+
//| Ajouter un FVG                                                    |
//+------------------------------------------------------------------+
void CSmartMoney::AddFVG(SFairValueGap &fvg)
{
   int size = ArraySize(m_fvgs);

   if(size >= m_maxZones)
   {
      for(int i = 0; i < size - 1; i++)
         m_fvgs[i] = m_fvgs[i + 1];
      ArrayResize(m_fvgs, size);
      m_fvgs[size - 1] = fvg;
   }
   else
   {
      ArrayResize(m_fvgs, size + 1);
      m_fvgs[size] = fvg;
   }

   GenerateEvent(ZONE_EVENT_CREATED, fvg.id, false, fvg.midPoint,
                 (fvg.isBullish ? "FVG Haussier" : "FVG Baissier") + " detecte");
}

//+------------------------------------------------------------------+
//| ============ DÉTECTION LIQUIDITÉ ============                     |
//+------------------------------------------------------------------+

void CSmartMoney::DetectLiquidity()
{
   DetectEqualHighs();
   DetectEqualLows();
}

void CSmartMoney::DetectEqualHighs()
{
   double highs[];
   int bars[];
   ArrayResize(highs, 0);
   ArrayResize(bars, 0);

   int maxBars = MathMin(iBars(m_symbol, m_timeframe), m_lookbackBars);

   // Collecter les swing highs
   for(int i = 2; i < maxBars - 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);

      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 1) &&
         high > iHigh(m_symbol, m_timeframe, i - 2) &&
         high > iHigh(m_symbol, m_timeframe, i + 2))
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
            // Vérifier que ce niveau n'existe pas déjà
            bool exists = false;
            double avgLevel = (highs[i] + highs[j]) / 2.0;

            for(int k = 0; k < ArraySize(m_liquidityLevels); k++)
            {
               if(m_liquidityLevels[k].isHighLiquidity &&
                  ArePricesEqual(m_liquidityLevels[k].level, avgLevel))
               {
                  exists = true;
                  m_liquidityLevels[k].touchCount++;
                  m_liquidityLevels[k].lastTouch = iTime(m_symbol, m_timeframe, bars[j]);
                  break;
               }
            }

            if(!exists)
            {
               SLiquidity liq;
               liq.Reset();
               liq.id = m_nextLiqId++;
               liq.level = avgLevel;
               liq.isHighLiquidity = true;
               liq.touchCount = 2;
               liq.firstTouch = iTime(m_symbol, m_timeframe, bars[i]);
               liq.lastTouch = iTime(m_symbol, m_timeframe, bars[j]);
               liq.isSwept = false;
               liq.timeframe = m_timeframe;
               liq.isValid = true;

               int size = ArraySize(m_liquidityLevels);
               ArrayResize(m_liquidityLevels, size + 1);
               m_liquidityLevels[size] = liq;
            }
         }
      }
   }
}

void CSmartMoney::DetectEqualLows()
{
   double lows[];
   int bars[];
   ArrayResize(lows, 0);
   ArrayResize(bars, 0);

   int maxBars = MathMin(iBars(m_symbol, m_timeframe), m_lookbackBars);

   for(int i = 2; i < maxBars - 2; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);

      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i + 1) &&
         low < iLow(m_symbol, m_timeframe, i - 2) &&
         low < iLow(m_symbol, m_timeframe, i + 2))
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
            bool exists = false;
            double avgLevel = (lows[i] + lows[j]) / 2.0;

            for(int k = 0; k < ArraySize(m_liquidityLevels); k++)
            {
               if(!m_liquidityLevels[k].isHighLiquidity &&
                  ArePricesEqual(m_liquidityLevels[k].level, avgLevel))
               {
                  exists = true;
                  m_liquidityLevels[k].touchCount++;
                  m_liquidityLevels[k].lastTouch = iTime(m_symbol, m_timeframe, bars[j]);
                  break;
               }
            }

            if(!exists)
            {
               SLiquidity liq;
               liq.Reset();
               liq.id = m_nextLiqId++;
               liq.level = avgLevel;
               liq.isHighLiquidity = false;
               liq.touchCount = 2;
               liq.firstTouch = iTime(m_symbol, m_timeframe, bars[i]);
               liq.lastTouch = iTime(m_symbol, m_timeframe, bars[j]);
               liq.isSwept = false;
               liq.timeframe = m_timeframe;
               liq.isValid = true;

               int size = ArraySize(m_liquidityLevels);
               ArrayResize(m_liquidityLevels, size + 1);
               m_liquidityLevels[size] = liq;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ============ GESTION DES ZONES ============                       |
//+------------------------------------------------------------------+

void CSmartMoney::UpdateZoneStatuses()
{
   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   double currentHigh = iHigh(m_symbol, m_timeframe, 0);
   double currentLow = iLow(m_symbol, m_timeframe, 0);

   // Mettre à jour les OB
   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      UpdateOBStatus(m_orderBlocks[i]);
   }

   // Mettre à jour les FVG
   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      UpdateFVGStatus(m_fvgs[i]);
   }

   // Vérifier la liquidité sweepée
   for(int i = 0; i < ArraySize(m_liquidityLevels); i++)
   {
      if(m_liquidityLevels[i].isValid && !m_liquidityLevels[i].isSwept)
      {
         if(m_liquidityLevels[i].isHighLiquidity)
         {
            if(currentHigh > m_liquidityLevels[i].level)
            {
               m_liquidityLevels[i].isSwept = true;
               m_liquidityLevels[i].sweepTime = TimeCurrent();
            }
         }
         else
         {
            if(currentLow < m_liquidityLevels[i].level)
            {
               m_liquidityLevels[i].isSwept = true;
               m_liquidityLevels[i].sweepTime = TimeCurrent();
            }
         }
      }
   }
}

void CSmartMoney::UpdateOBStatus(SOrderBlock &ob)
{
   if(!ob.isValid || ob.status == ZONE_INVALIDATED) return;

   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   double currentHigh = iHigh(m_symbol, m_timeframe, 0);
   double currentLow = iLow(m_symbol, m_timeframe, 0);

   bool wasInZone = ob.priceInZone;
   ob.priceInZone = IsPriceInZone(currentPrice, ob.high, ob.low);

   // Prix entre dans la zone
   if(ob.priceInZone && !wasInZone)
   {
      ob.testCount++;
      ob.lastTest = TimeCurrent();

      if(ob.status == ZONE_ACTIVE)
      {
         ob.status = ZONE_TESTED;
         GenerateEvent(ZONE_EVENT_PRICE_ENTER, ob.id, true, currentPrice,
                       "Prix entre dans " + (ob.type == OB_BULLISH ? "OB Haussier" : "OB Baissier"));
      }
   }

   // Vérifier invalidation (cassure violente)
   if(ob.type == OB_BULLISH)
   {
      // OB haussier invalidé si le prix clôture bien en-dessous
      if(currentLow < ob.low)
      {
         double breakPct = CalculatePercentage(ob.low - currentLow, ob.midPoint);
         if(breakPct > 0.2)  // Cassure significative
         {
            ob.status = ZONE_INVALIDATED;
            GenerateEvent(ZONE_EVENT_INVALIDATED, ob.id, true, currentPrice, "OB Haussier invalide");
         }
      }
   }
   else
   {
      // OB baissier invalidé si le prix clôture bien au-dessus
      if(currentHigh > ob.high)
      {
         double breakPct = CalculatePercentage(currentHigh - ob.high, ob.midPoint);
         if(breakPct > 0.2)
         {
            ob.status = ZONE_INVALIDATED;
            GenerateEvent(ZONE_EVENT_INVALIDATED, ob.id, true, currentPrice, "OB Baissier invalide");
         }
      }
   }

   // Vérifier distance maximale
   double distance = MathAbs(currentPrice - ob.midPoint);
   double distancePct = CalculatePercentage(distance, currentPrice);
   if(distancePct > m_maxDistancePct)
   {
      ob.status = ZONE_INVALIDATED;
   }
}

void CSmartMoney::UpdateFVGStatus(SFairValueGap &fvg)
{
   if(!fvg.isValid || fvg.status == ZONE_INVALIDATED) return;

   double currentPrice = iClose(m_symbol, m_timeframe, 0);

   bool wasInZone = fvg.priceInZone;
   fvg.priceInZone = IsPriceInZone(currentPrice, fvg.high, fvg.low);

   if(fvg.priceInZone && !wasInZone)
   {
      GenerateEvent(ZONE_EVENT_PRICE_ENTER, fvg.id, false, currentPrice,
                    "Prix entre dans " + (fvg.isBullish ? "FVG Haussier" : "FVG Baissier"));
   }

   // Mettre à jour le remplissage
   UpdateFVGFillLevel(fvg);

   // Vérifier distance maximale
   double distance = MathAbs(currentPrice - fvg.midPoint);
   double distancePct = CalculatePercentage(distance, currentPrice);
   if(distancePct > m_maxDistancePct)
   {
      fvg.status = ZONE_INVALIDATED;
   }
}

void CSmartMoney::CleanupInvalidZones()
{
   // Nettoyer les OB invalides
   int i = 0;
   while(i < ArraySize(m_orderBlocks))
   {
      if(!m_orderBlocks[i].isValid || m_orderBlocks[i].status == ZONE_INVALIDATED)
      {
         for(int j = i; j < ArraySize(m_orderBlocks) - 1; j++)
            m_orderBlocks[j] = m_orderBlocks[j + 1];
         ArrayResize(m_orderBlocks, ArraySize(m_orderBlocks) - 1);
      }
      else
      {
         i++;
      }
   }

   // Nettoyer les FVG invalides
   i = 0;
   while(i < ArraySize(m_fvgs))
   {
      if(!m_fvgs[i].isValid || m_fvgs[i].status == ZONE_INVALIDATED)
      {
         for(int j = i; j < ArraySize(m_fvgs) - 1; j++)
            m_fvgs[j] = m_fvgs[j + 1];
         ArrayResize(m_fvgs, ArraySize(m_fvgs) - 1);
      }
      else
      {
         i++;
      }
   }
}

//+------------------------------------------------------------------+
//| Générer un événement                                              |
//+------------------------------------------------------------------+
void CSmartMoney::GenerateEvent(ENUM_ZONE_EVENT eventType, int zoneId, bool isOB, double price, string msg)
{
   m_analysis.lastEvent.eventType = eventType;
   m_analysis.lastEvent.zoneId = zoneId;
   m_analysis.lastEvent.isOrderBlock = isOB;
   m_analysis.lastEvent.price = price;
   m_analysis.lastEvent.time = TimeCurrent();
   m_analysis.lastEvent.message = msg;
   m_analysis.lastEvent.isValid = true;
}

//+------------------------------------------------------------------+
//| Mettre à jour l'analyse                                           |
//+------------------------------------------------------------------+
void CSmartMoney::UpdateAnalysis()
{
   double currentPrice = iClose(m_symbol, m_timeframe, 0);

   // Compter les zones actives
   m_analysis.activeOBCount = 0;
   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].isValid && m_orderBlocks[i].status != ZONE_INVALIDATED)
         m_analysis.activeOBCount++;
   }

   m_analysis.activeFVGCount = 0;
   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(m_fvgs[i].isValid && m_fvgs[i].status != ZONE_INVALIDATED)
         m_analysis.activeFVGCount++;
   }

   m_analysis.activeLiquidityCount = 0;
   for(int i = 0; i < ArraySize(m_liquidityLevels); i++)
   {
      if(m_liquidityLevels[i].isValid && !m_liquidityLevels[i].isSwept)
         m_analysis.activeLiquidityCount++;
   }

   // Trouver les zones les plus proches
   m_analysis.nearestBullishOB = GetNearestBullishOB(currentPrice);
   m_analysis.nearestBearishOB = GetNearestBearishOB(currentPrice);
   m_analysis.nearestBullishFVG = GetNearestBullishFVG(currentPrice);
   m_analysis.nearestBearishFVG = GetNearestBearishFVG(currentPrice);

   // Calculer les scores de confluence
   m_analysis.bullishScore = GetBullishScore(currentPrice);
   m_analysis.bearishScore = GetBearishScore(currentPrice);

   m_analysis.hasBullishConfluence = (m_analysis.bullishScore >= 50);
   m_analysis.hasBearishConfluence = (m_analysis.bearishScore >= 50);
}

//+------------------------------------------------------------------+
//| Générer les alertes                                               |
//+------------------------------------------------------------------+
void CSmartMoney::GenerateAlert()
{
   m_analysis.alertLevel = SMC_ALERT_NONE;
   m_analysis.alertMessage = "";

   double currentPrice = iClose(m_symbol, m_timeframe, 0);

   // Vérifier si le prix est dans une zone
   if(IsPriceInAnyBullishOB(currentPrice))
   {
      m_analysis.alertLevel = SMC_ALERT_SETUP;
      m_analysis.alertMessage = "Prix dans OB Haussier - Zone de demande";
      return;
   }

   if(IsPriceInAnyBearishOB(currentPrice))
   {
      m_analysis.alertLevel = SMC_ALERT_SETUP;
      m_analysis.alertMessage = "Prix dans OB Baissier - Zone d'offre";
      return;
   }

   if(IsPriceInAnyBullishFVG(currentPrice))
   {
      m_analysis.alertLevel = SMC_ALERT_SETUP;
      m_analysis.alertMessage = "Prix dans FVG Haussier";
      return;
   }

   if(IsPriceInAnyBearishFVG(currentPrice))
   {
      m_analysis.alertLevel = SMC_ALERT_SETUP;
      m_analysis.alertMessage = "Prix dans FVG Baissier";
      return;
   }

   // Vérifier les invalidations récentes
   if(m_analysis.lastEvent.isValid &&
      m_analysis.lastEvent.eventType == ZONE_EVENT_INVALIDATED &&
      TimeCurrent() - m_analysis.lastEvent.time < 300)  // 5 minutes
   {
      m_analysis.alertLevel = SMC_ALERT_INVALIDATION;
      m_analysis.alertMessage = m_analysis.lastEvent.message;
      return;
   }

   // Info sur zones proches
   if(m_analysis.nearestBullishOB.isValid || m_analysis.nearestBearishOB.isValid)
   {
      m_analysis.alertLevel = SMC_ALERT_INFO;
      m_analysis.alertMessage = "Zones SMC actives disponibles";
   }
}

//+------------------------------------------------------------------+
//| ============ GETTERS ORDER BLOCKS ============                    |
//+------------------------------------------------------------------+

int CSmartMoney::GetOrderBlockCount()
{
   return ArraySize(m_orderBlocks);
}

int CSmartMoney::GetActiveOBCount()
{
   return m_analysis.activeOBCount;
}

SOrderBlock CSmartMoney::GetOrderBlock(int index)
{
   SOrderBlock empty;
   empty.Reset();
   if(index < 0 || index >= ArraySize(m_orderBlocks)) return empty;
   return m_orderBlocks[index];
}

SOrderBlock CSmartMoney::GetNearestBullishOB(double price)
{
   SOrderBlock nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BULLISH &&
         m_orderBlocks[i].isValid &&
         m_orderBlocks[i].status != ZONE_INVALIDATED &&
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
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BEARISH &&
         m_orderBlocks[i].isValid &&
         m_orderBlocks[i].status != ZONE_INVALIDATED &&
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
   return IsPriceInZone(price, ob.high, ob.low);
}

bool CSmartMoney::IsPriceInAnyBullishOB(double price)
{
   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BULLISH &&
         m_orderBlocks[i].isValid &&
         m_orderBlocks[i].status != ZONE_INVALIDATED &&
         IsPriceInZone(price, m_orderBlocks[i].high, m_orderBlocks[i].low))
         return true;
   }
   return false;
}

bool CSmartMoney::IsPriceInAnyBearishOB(double price)
{
   for(int i = 0; i < ArraySize(m_orderBlocks); i++)
   {
      if(m_orderBlocks[i].type == OB_BEARISH &&
         m_orderBlocks[i].isValid &&
         m_orderBlocks[i].status != ZONE_INVALIDATED &&
         IsPriceInZone(price, m_orderBlocks[i].high, m_orderBlocks[i].low))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ============ GETTERS FVG ============                             |
//+------------------------------------------------------------------+

int CSmartMoney::GetFVGCount()
{
   return ArraySize(m_fvgs);
}

int CSmartMoney::GetActiveFVGCount()
{
   return m_analysis.activeFVGCount;
}

SFairValueGap CSmartMoney::GetFVG(int index)
{
   SFairValueGap empty;
   empty.Reset();
   if(index < 0 || index >= ArraySize(m_fvgs)) return empty;
   return m_fvgs[index];
}

SFairValueGap CSmartMoney::GetNearestBullishFVG(double price)
{
   SFairValueGap nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(m_fvgs[i].isBullish &&
         m_fvgs[i].isValid &&
         m_fvgs[i].status != ZONE_INVALIDATED &&
         m_fvgs[i].high < price)
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
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(!m_fvgs[i].isBullish &&
         m_fvgs[i].isValid &&
         m_fvgs[i].status != ZONE_INVALIDATED &&
         m_fvgs[i].low > price)
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
   return IsPriceInZone(price, fvg.high, fvg.low);
}

bool CSmartMoney::IsPriceInAnyBullishFVG(double price)
{
   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(m_fvgs[i].isBullish &&
         m_fvgs[i].isValid &&
         m_fvgs[i].status != ZONE_INVALIDATED &&
         IsPriceInZone(price, m_fvgs[i].high, m_fvgs[i].low))
         return true;
   }
   return false;
}

bool CSmartMoney::IsPriceInAnyBearishFVG(double price)
{
   for(int i = 0; i < ArraySize(m_fvgs); i++)
   {
      if(!m_fvgs[i].isBullish &&
         m_fvgs[i].isValid &&
         m_fvgs[i].status != ZONE_INVALIDATED &&
         IsPriceInZone(price, m_fvgs[i].high, m_fvgs[i].low))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ============ GETTERS LIQUIDITÉ ============                       |
//+------------------------------------------------------------------+

int CSmartMoney::GetLiquidityCount()
{
   return ArraySize(m_liquidityLevels);
}

SLiquidity CSmartMoney::GetLiquidity(int index)
{
   SLiquidity empty;
   empty.Reset();
   if(index < 0 || index >= ArraySize(m_liquidityLevels)) return empty;
   return m_liquidityLevels[index];
}

SLiquidity CSmartMoney::GetNearestHighLiquidity(double price)
{
   SLiquidity nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_liquidityLevels); i++)
   {
      if(m_liquidityLevels[i].isHighLiquidity &&
         m_liquidityLevels[i].isValid &&
         !m_liquidityLevels[i].isSwept &&
         m_liquidityLevels[i].level > price)
      {
         double distance = m_liquidityLevels[i].level - price;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_liquidityLevels[i];
         }
      }
   }

   return nearest;
}

SLiquidity CSmartMoney::GetNearestLowLiquidity(double price)
{
   SLiquidity nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_liquidityLevels); i++)
   {
      if(!m_liquidityLevels[i].isHighLiquidity &&
         m_liquidityLevels[i].isValid &&
         !m_liquidityLevels[i].isSwept &&
         m_liquidityLevels[i].level < price)
      {
         double distance = price - m_liquidityLevels[i].level;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_liquidityLevels[i];
         }
      }
   }

   return nearest;
}

bool CSmartMoney::IsLiquiditySwept(int index)
{
   if(index < 0 || index >= ArraySize(m_liquidityLevels)) return false;
   return m_liquidityLevels[index].isSwept;
}

//+------------------------------------------------------------------+
//| ============ CONFLUENCE ============                              |
//+------------------------------------------------------------------+

bool CSmartMoney::HasBullishConfluence(double price)
{
   return (GetBullishScore(price) >= 50);
}

bool CSmartMoney::HasBearishConfluence(double price)
{
   return (GetBearishScore(price) >= 50);
}

int CSmartMoney::GetBullishScore(double price)
{
   int score = 0;

   // OB haussier proche ou actif
   SOrderBlock ob = GetNearestBullishOB(price);
   if(ob.isValid)
   {
      double distance = price - ob.high;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 0.5) score += 40;
      else if(distancePct <= 1.0) score += 30;
      else if(distancePct <= 2.0) score += 20;

      if(ob.quality == SMC_QUALITY_PREMIUM) score += 20;
      else if(ob.quality == SMC_QUALITY_HIGH) score += 15;
      else if(ob.quality == SMC_QUALITY_MEDIUM) score += 10;
   }

   // FVG haussier proche
   SFairValueGap fvg = GetNearestBullishFVG(price);
   if(fvg.isValid)
   {
      double distance = price - fvg.high;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 0.5) score += 25;
      else if(distancePct <= 1.0) score += 15;
      else if(distancePct <= 2.0) score += 10;
   }

   // Liquidité basse proche (cible)
   SLiquidity liq = GetNearestLowLiquidity(price);
   if(liq.isValid && !liq.isSwept)
   {
      double distance = price - liq.level;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 1.0) score += 15;
   }

   return MathMin(100, score);
}

int CSmartMoney::GetBearishScore(double price)
{
   int score = 0;

   SOrderBlock ob = GetNearestBearishOB(price);
   if(ob.isValid)
   {
      double distance = ob.low - price;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 0.5) score += 40;
      else if(distancePct <= 1.0) score += 30;
      else if(distancePct <= 2.0) score += 20;

      if(ob.quality == SMC_QUALITY_PREMIUM) score += 20;
      else if(ob.quality == SMC_QUALITY_HIGH) score += 15;
      else if(ob.quality == SMC_QUALITY_MEDIUM) score += 10;
   }

   SFairValueGap fvg = GetNearestBearishFVG(price);
   if(fvg.isValid)
   {
      double distance = fvg.low - price;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 0.5) score += 25;
      else if(distancePct <= 1.0) score += 15;
      else if(distancePct <= 2.0) score += 10;
   }

   SLiquidity liq = GetNearestHighLiquidity(price);
   if(liq.isValid && !liq.isSwept)
   {
      double distance = liq.level - price;
      double distancePct = CalculatePercentage(distance, price);

      if(distancePct <= 1.0) score += 15;
   }

   return MathMin(100, score);
}

bool CSmartMoney::HasOBFVGConfluence(double price, bool lookingForBuy)
{
   if(lookingForBuy)
   {
      // OB haussier + FVG haussier dans la même zone
      SOrderBlock ob = GetNearestBullishOB(price);
      SFairValueGap fvg = GetNearestBullishFVG(price);

      if(ob.isValid && fvg.isValid)
      {
         // Vérifier si les zones se chevauchent
         double obMid = ob.midPoint;
         double fvgMid = fvg.midPoint;
         double diff = MathAbs(obMid - fvgMid);
         double avgSize = (ob.zoneSize + fvg.gapSize) / 2.0;

         return (diff <= avgSize);
      }
   }
   else
   {
      SOrderBlock ob = GetNearestBearishOB(price);
      SFairValueGap fvg = GetNearestBearishFVG(price);

      if(ob.isValid && fvg.isValid)
      {
         double obMid = ob.midPoint;
         double fvgMid = fvg.midPoint;
         double diff = MathAbs(obMid - fvgMid);
         double avgSize = (ob.zoneSize + fvg.gapSize) / 2.0;

         return (diff <= avgSize);
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| ============ ZONES PROCHES ============                           |
//+------------------------------------------------------------------+

bool CSmartMoney::GetNearestBullishZone(double price, double &zoneHigh, double &zoneLow)
{
   SOrderBlock ob = GetNearestBullishOB(price);
   SFairValueGap fvg = GetNearestBullishFVG(price);

   bool hasOB = ob.isValid;
   bool hasFVG = fvg.isValid;

   if(!hasOB && !hasFVG) return false;

   double obDist = hasOB ? (price - ob.high) : DBL_MAX;
   double fvgDist = hasFVG ? (price - fvg.high) : DBL_MAX;

   if(obDist <= fvgDist && hasOB)
   {
      zoneHigh = ob.high;
      zoneLow = ob.low;
   }
   else if(hasFVG)
   {
      zoneHigh = fvg.high;
      zoneLow = fvg.low;
   }

   return true;
}

bool CSmartMoney::GetNearestBearishZone(double price, double &zoneHigh, double &zoneLow)
{
   SOrderBlock ob = GetNearestBearishOB(price);
   SFairValueGap fvg = GetNearestBearishFVG(price);

   bool hasOB = ob.isValid;
   bool hasFVG = fvg.isValid;

   if(!hasOB && !hasFVG) return false;

   double obDist = hasOB ? (ob.low - price) : DBL_MAX;
   double fvgDist = hasFVG ? (fvg.low - price) : DBL_MAX;

   if(obDist <= fvgDist && hasOB)
   {
      zoneHigh = ob.high;
      zoneLow = ob.low;
   }
   else if(hasFVG)
   {
      zoneHigh = fvg.high;
      zoneLow = fvg.low;
   }

   return true;
}

double CSmartMoney::GetDistanceToNearestBullishZone(double price)
{
   double zoneHigh, zoneLow;
   if(GetNearestBullishZone(price, zoneHigh, zoneLow))
      return price - zoneHigh;
   return DBL_MAX;
}

double CSmartMoney::GetDistanceToNearestBearishZone(double price)
{
   double zoneHigh, zoneLow;
   if(GetNearestBearishZone(price, zoneHigh, zoneLow))
      return zoneLow - price;
   return DBL_MAX;
}

//+------------------------------------------------------------------+
//| ============ MULTI-TIMEFRAME ============                         |
//+------------------------------------------------------------------+

bool CSmartMoney::UpdateMTF(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf)
{
   CSmartMoney htfAnalyzer, ltfAnalyzer;

   if(htfAnalyzer.Init(m_symbol, htf))
   {
      m_htfSMC.timeframe = htf;
      m_htfSMC.analysis = htfAnalyzer.GetFullAnalysis();
      m_htfSMC.isValid = true;
      m_htfSMC.lastUpdate = TimeCurrent();
   }

   if(ltfAnalyzer.Init(m_symbol, ltf))
   {
      m_ltfSMC.timeframe = ltf;
      m_ltfSMC.analysis = ltfAnalyzer.GetFullAnalysis();
      m_ltfSMC.isValid = true;
      m_ltfSMC.lastUpdate = TimeCurrent();
   }

   return (m_htfSMC.isValid && m_ltfSMC.isValid);
}

bool CSmartMoney::HasHTFBullishOB()
{
   return (m_htfSMC.isValid && m_htfSMC.analysis.nearestBullishOB.isValid);
}

bool CSmartMoney::HasHTFBearishOB()
{
   return (m_htfSMC.isValid && m_htfSMC.analysis.nearestBearishOB.isValid);
}

bool CSmartMoney::HasLTFBullishFVG()
{
   return (m_ltfSMC.isValid && m_ltfSMC.analysis.nearestBullishFVG.isValid);
}

bool CSmartMoney::HasLTFBearishFVG()
{
   return (m_ltfSMC.isValid && m_ltfSMC.analysis.nearestBearishFVG.isValid);
}

bool CSmartMoney::IsMTFConfluent(bool lookingForBuy)
{
   if(!m_htfSMC.isValid || !m_ltfSMC.isValid) return false;

   if(lookingForBuy)
   {
      // OB H4 + FVG M15 = confluence forte
      return (HasHTFBullishOB() && HasLTFBullishFVG());
   }
   else
   {
      return (HasHTFBearishOB() && HasLTFBearishFVG());
   }
}

//+------------------------------------------------------------------+
//| ============ ÉVÉNEMENTS & ALERTES ============                    |
//+------------------------------------------------------------------+

SZoneEvent CSmartMoney::GetLastEvent()
{
   return m_analysis.lastEvent;
}

ENUM_SMC_ALERT CSmartMoney::GetAlertLevel()
{
   return m_analysis.alertLevel;
}

string CSmartMoney::GetAlertMessage()
{
   return m_analysis.alertMessage;
}

SSMCAnalysis CSmartMoney::GetFullAnalysis()
{
   return m_analysis;
}

//+------------------------------------------------------------------+
//| ============ COMPATIBILITÉ ============                           |
//+------------------------------------------------------------------+

bool CSmartMoney::HasSMCConfluence(double price, bool lookingForBuy)
{
   if(lookingForBuy)
      return HasBullishConfluence(price);
   else
      return HasBearishConfluence(price);
}

string CSmartMoney::GetSMCAlert()
{
   string alert = "";
   double price = iClose(m_symbol, m_timeframe, 0);

   if(m_analysis.alertLevel != SMC_ALERT_NONE)
   {
      alert = m_analysis.alertMessage + "\n";
   }

   SOrderBlock obBull = GetNearestBullishOB(price);
   SOrderBlock obBear = GetNearestBearishOB(price);

   if(obBull.isValid)
      alert += "Zone de demande (OB): " + DoubleToString(obBull.low, 5) + " - " + DoubleToString(obBull.high, 5) + "\n";

   if(obBear.isValid)
      alert += "Zone d'offre (OB): " + DoubleToString(obBear.low, 5) + " - " + DoubleToString(obBear.high, 5) + "\n";

   SFairValueGap fvgBull = GetNearestBullishFVG(price);
   SFairValueGap fvgBear = GetNearestBearishFVG(price);

   if(fvgBull.isValid)
      alert += "FVG Haussier: " + DoubleToString(fvgBull.low, 5) + " - " + DoubleToString(fvgBull.high, 5) + "\n";

   if(fvgBear.isValid)
      alert += "FVG Baissier: " + DoubleToString(fvgBear.low, 5) + " - " + DoubleToString(fvgBear.high, 5) + "\n";

   return alert;
}

//+------------------------------------------------------------------+
//| ============ UTILITAIRES ============                             |
//+------------------------------------------------------------------+

string CSmartMoney::OrderBlockToString(SOrderBlock &ob)
{
   if(!ob.isValid) return "OB invalide";

   string type = (ob.type == OB_BULLISH) ? "HAUSSIER" : "BAISSIER";
   string status = ZoneStatusToString(ob.status);
   string quality = ZoneQualityToString(ob.quality);

   return StringFormat("OB %s [%s] [%s]: %.5f - %.5f (Score: %d)",
                       type, status, quality, ob.low, ob.high, ob.score);
}

string CSmartMoney::FVGToString(SFairValueGap &fvg)
{
   if(!fvg.isValid) return "FVG invalide";

   string type = fvg.isBullish ? "HAUSSIER" : "BAISSIER";
   string status = ZoneStatusToString(fvg.status);

   return StringFormat("FVG %s [%s]: %.5f - %.5f (Fill: %.0f%%)",
                       type, status, fvg.low, fvg.high, fvg.fillLevel);
}

string CSmartMoney::LiquidityToString(SLiquidity &liq)
{
   if(!liq.isValid) return "Liquidite invalide";

   string type = liq.isHighLiquidity ? "Equal Highs" : "Equal Lows";
   string status = liq.isSwept ? "SWEPT" : "ACTIVE";

   return StringFormat("%s [%s]: %.5f (Touches: %d)",
                       type, status, liq.level, liq.touchCount);
}

string CSmartMoney::ZoneStatusToString(ENUM_SMC_ZONE_STATUS status)
{
   switch(status)
   {
      case ZONE_ACTIVE: return "ACTIVE";
      case ZONE_TESTED: return "TESTEE";
      case ZONE_PARTIALLY_FILLED: return "PARTIEL";
      case ZONE_INVALIDATED: return "INVALIDE";
      case ZONE_MITIGATED: return "MITIGUEE";
      default: return "?";
   }
}

string CSmartMoney::ZoneQualityToString(ENUM_SMC_ZONE_QUALITY quality)
{
   switch(quality)
   {
      case SMC_QUALITY_PREMIUM: return "PREMIUM";
      case SMC_QUALITY_HIGH: return "HAUTE";
      case SMC_QUALITY_MEDIUM: return "MOYENNE";
      case SMC_QUALITY_LOW: return "FAIBLE";
      case SMC_QUALITY_INVALID: return "INVALIDE";
      default: return "?";
   }
}

string CSmartMoney::GetSMCSummary()
{
   string summary = "";

   summary += "=== SMART MONEY CONCEPTS ===\n";
   summary += "OB Actifs: " + IntegerToString(m_analysis.activeOBCount) + "\n";
   summary += "FVG Actifs: " + IntegerToString(m_analysis.activeFVGCount) + "\n";
   summary += "Liquidite Active: " + IntegerToString(m_analysis.activeLiquidityCount) + "\n";
   summary += "\n";

   double price = iClose(m_symbol, m_timeframe, 0);
   summary += "Score Haussier: " + IntegerToString(m_analysis.bullishScore) + "/100\n";
   summary += "Score Baissier: " + IntegerToString(m_analysis.bearishScore) + "/100\n";
   summary += "\n";

   if(m_analysis.nearestBullishOB.isValid)
      summary += "OB Bull proche: " + OrderBlockToString(m_analysis.nearestBullishOB) + "\n";

   if(m_analysis.nearestBearishOB.isValid)
      summary += "OB Bear proche: " + OrderBlockToString(m_analysis.nearestBearishOB) + "\n";

   if(m_analysis.nearestBullishFVG.isValid)
      summary += "FVG Bull proche: " + FVGToString(m_analysis.nearestBullishFVG) + "\n";

   if(m_analysis.nearestBearishFVG.isValid)
      summary += "FVG Bear proche: " + FVGToString(m_analysis.nearestBearishFVG) + "\n";

   if(m_analysis.alertLevel != SMC_ALERT_NONE)
   {
      summary += "\n";
      summary += "ALERTE: " + m_analysis.alertMessage + "\n";
   }

   return summary;
}

//+------------------------------------------------------------------+
