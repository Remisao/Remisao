//+------------------------------------------------------------------+
//|                                          SupportResistance.mqh   |
//|                    MODULE SUPPORT & RÉSISTANCE PROFESSIONNEL      |
//|                      Zones Institutionnelles Multi-Timeframe      |
//+------------------------------------------------------------------+
#property copyright "Trading Bot - SR Professional"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PHILOSOPHIE DU MODULE:                                            |
//|                                                                   |
//| Les S/R sont des ZONES, pas des lignes                            |
//| Un niveau valide = minimum 2 touches ESPACÉES dans le temps       |
//| Cassure valide = CLÔTURE au-delà (pas juste mèche)               |
//| Support cassé → Résistance (Polarité)                            |
//| Fakeout = mèche casse mais clôture ne confirme pas               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ÉNUMÉRATIONS - ANCIENNE API (Compatibilité)                       |
//+------------------------------------------------------------------+

// Type de niveau (ancienne API)
enum ENUM_LEVEL_TYPE
{
   LEVEL_SUPPORT,             // Support
   LEVEL_RESISTANCE,          // Résistance
   LEVEL_BROKEN_SUPPORT,      // Support cassé
   LEVEL_BROKEN_RESISTANCE    // Résistance cassée
};

// Force du niveau (ancienne API)
enum ENUM_LEVEL_STRENGTH
{
   LEVEL_STRENGTH_WEAK,       // Faible
   LEVEL_STRENGTH_MODERATE,   // Modéré
   LEVEL_STRENGTH_STRONG      // Fort
};

//+------------------------------------------------------------------+
//| ÉNUMÉRATIONS - NOUVELLE API (Professionnelle)                     |
//+------------------------------------------------------------------+

// Type de zone S/R
enum ENUM_ZONE_TYPE
{
   ZONE_SUPPORT,              // Support actif
   ZONE_RESISTANCE,           // Résistance active
   ZONE_FLIPPED_TO_RESISTANCE,// Support cassé → devient Résistance
   ZONE_FLIPPED_TO_SUPPORT    // Résistance cassée → devient Support
};

// Force de la zone
enum ENUM_ZONE_STRENGTH
{
   SR_STRENGTH_WEAK,          // 2 touches
   SR_STRENGTH_MODERATE,      // 3 touches
   SR_STRENGTH_STRONG,        // 4-5 touches
   SR_STRENGTH_MAJOR          // 6+ touches (institutionnel)
};

// Qualité de la zone
enum ENUM_ZONE_QUALITY
{
   SR_QUALITY_LOW,            // Faible qualité
   SR_QUALITY_MEDIUM,         // Qualité moyenne
   SR_QUALITY_HIGH,           // Haute qualité
   SR_QUALITY_PREMIUM         // Qualité premium (confluence)
};

// Statut de la zone
enum ENUM_ZONE_STATUS
{
   SR_STATUS_ACTIVE,          // Zone active
   SR_STATUS_TESTED,          // Zone testée mais pas cassée
   SR_STATUS_BROKEN,          // Zone cassée
   SR_STATUS_FLIPPED,         // Polarité inversée
   SR_STATUS_INVALID          // Zone invalidée
};

// Type de réaction sur la zone
enum ENUM_REACTION_TYPE
{
   REACTION_NONE,             // Pas de réaction
   REACTION_WICK_REJECTION,   // Rejet par mèche (≥50%)
   REACTION_BODY_REVERSAL,    // Retournement avec corps fort
   REACTION_STRONG_REJECTION, // Rejet fort (mèche + volume)
   REACTION_WEAK_TEST         // Test faible
};

// Hiérarchie timeframe
enum ENUM_SR_TIMEFRAME_RANK
{
   SR_RANK_MAJOR,             // Daily/H4 - Zones majeures
   SR_RANK_INTERMEDIATE,      // H1 - Zones intermédiaires
   SR_RANK_MINOR              // M15 - Zones de précision
};

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES - ANCIENNE API (Compatibilité)              |
//+------------------------------------------------------------------+

// Structure de niveau (ancienne API - pour compatibilité)
struct SLevel
{
   double               price;          // Prix du niveau
   ENUM_LEVEL_TYPE      type;           // Type de niveau
   ENUM_LEVEL_STRENGTH  strength;       // Force du niveau
   int                  touchCount;     // Nombre de touches
   datetime             firstTouch;     // Première touche
   datetime             lastTouch;      // Dernière touche
   bool                 isBroken;       // Niveau cassé
   bool                 isFakeout;      // Fausse cassure
   double               brokenPrice;    // Prix de cassure

   void Reset()
   {
      price = 0;
      type = LEVEL_SUPPORT;
      strength = LEVEL_STRENGTH_WEAK;
      touchCount = 0;
      firstTouch = 0;
      lastTouch = 0;
      isBroken = false;
      isFakeout = false;
      brokenPrice = 0;
   }
};

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES - NOUVELLE API (Professionnelle)            |
//+------------------------------------------------------------------+

// Structure d'une touche sur une zone
struct SZoneTouch
{
   datetime             time;           // Horodatage de la touche
   int                  barIndex;       // Index de la barre
   double               price;          // Prix exact de la touche
   ENUM_REACTION_TYPE   reactionType;   // Type de réaction
   double               wickSize;       // Taille de la mèche (%)
   double               bodySize;       // Taille du corps (%)
   double               volumeRatio;    // Ratio volume vs moyenne
   bool                 isValid;        // Touche valide

   void Reset()
   {
      time = 0;
      barIndex = -1;
      price = 0;
      reactionType = REACTION_NONE;
      wickSize = 0;
      bodySize = 0;
      volumeRatio = 0;
      isValid = false;
   }
};

// Structure d'une zone S/R complète
struct SSRZone
{
   // Identification
   int                  id;             // ID unique
   ENUM_ZONE_TYPE       type;           // Type de zone
   ENUM_ZONE_STRENGTH   strength;       // Force
   ENUM_ZONE_QUALITY    quality;        // Qualité
   ENUM_ZONE_STATUS     status;         // Statut actuel
   ENUM_TIMEFRAMES      timeframe;      // Timeframe d'origine
   ENUM_SR_TIMEFRAME_RANK rank;         // Rang hiérarchique

   // Zone (pas une ligne!)
   double               zoneHigh;       // Haut de la zone
   double               zoneLow;        // Bas de la zone
   double               midPoint;       // Point médian
   double               zoneSize;       // Taille de la zone
   double               zoneSizePct;    // Taille en %

   // Touches
   int                  touchCount;     // Nombre de touches valides
   SZoneTouch           touches[10];    // Historique des touches (max 10)
   datetime             firstTouch;     // Première touche
   datetime             lastTouch;      // Dernière touche
   int                  barsSinceLastTouch; // Barres depuis dernière touche

   // Cassure / Polarité
   bool                 isBroken;       // Zone cassée
   bool                 isFlipped;      // Polarité inversée
   datetime             breakTime;      // Quand cassée
   double               breakPrice;     // Prix de cassure
   bool                 isFakeout;      // Fausse cassure détectée

   // Scoring
   int                  score;          // Score global (0-100)
   bool                 hasVolumeConfirmation; // Volume confirme

   // Validité
   bool                 isValid;

   void Reset()
   {
      id = 0;
      type = ZONE_SUPPORT;
      strength = SR_STRENGTH_WEAK;
      quality = SR_QUALITY_LOW;
      status = SR_STATUS_ACTIVE;
      timeframe = PERIOD_CURRENT;
      rank = SR_RANK_MINOR;
      zoneHigh = 0;
      zoneLow = 0;
      midPoint = 0;
      zoneSize = 0;
      zoneSizePct = 0;
      touchCount = 0;
      for(int i = 0; i < 10; i++) touches[i].Reset();
      firstTouch = 0;
      lastTouch = 0;
      barsSinceLastTouch = 0;
      isBroken = false;
      isFlipped = false;
      breakTime = 0;
      breakPrice = 0;
      isFakeout = false;
      score = 0;
      hasVolumeConfirmation = false;
      isValid = false;
   }
};

// Structure swing point pour détection
struct SSRSwing
{
   double               price;
   datetime             time;
   int                  barIndex;
   bool                 isHigh;         // true = swing high, false = swing low
   double               bodyHigh;       // Pour les zones: haut du corps
   double               bodyLow;        // Pour les zones: bas du corps
   double               wickHigh;       // Haut de mèche
   double               wickLow;        // Bas de mèche
   bool                 isValid;

   void Reset()
   {
      price = 0;
      time = 0;
      barIndex = -1;
      isHigh = false;
      bodyHigh = 0;
      bodyLow = 0;
      wickHigh = 0;
      wickLow = 0;
      isValid = false;
   }
};

// Analyse S/R complète
struct SSRAnalysis
{
   int                  totalZones;
   int                  activeSupports;
   int                  activeResistances;
   SSRZone              nearestSupport;
   SSRZone              nearestResistance;
   double               distanceToSupport;
   double               distanceToResistance;
   bool                 priceInSupportZone;
   bool                 priceInResistanceZone;
   bool                 isValid;

   void Reset()
   {
      totalZones = 0;
      activeSupports = 0;
      activeResistances = 0;
      nearestSupport.Reset();
      nearestResistance.Reset();
      distanceToSupport = 0;
      distanceToResistance = 0;
      priceInSupportZone = false;
      priceInResistanceZone = false;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| CLASSE PRINCIPALE - Support & Résistance Professionnel            |
//+------------------------------------------------------------------+
class CSupportResistance
{
private:
   //--- Paramètres
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_lookbackBars;
   int                  m_swingStrength;     // N barres gauche/droite pour swing
   double               m_tolerancePips;     // Tolérance fixe en pips
   bool                 m_useATR;            // Utiliser ATR pour tolérance
   double               m_atrMultiplier;     // Multiplicateur ATR
   int                  m_minTouchSpacing;   // Espacement min entre touches (barres)
   int                  m_maxZones;          // Nombre max de zones

   //--- Données internes
   SSRZone              m_zones[];
   SSRAnalysis          m_analysis;
   int                  m_nextZoneId;

   //--- Cache
   datetime             m_lastBarTime;
   double               m_currentATR;
   bool                 m_initialized;

   //--- Méthodes privées - Détection
   void                 DetectSwingPoints(SSRSwing &swings[], int maxSwings);
   bool                 IsSwingHigh(int barIndex, int strength);
   bool                 IsSwingLow(int barIndex, int strength);
   void                 CreateZoneFromSwing(SSRSwing &swing, bool isResistance);

   //--- Méthodes privées - Validation
   bool                 ValidateTouchSpacing(SSRZone &zone, datetime newTouchTime);
   ENUM_REACTION_TYPE   AnalyzeReaction(int barIndex, double zoneHigh, double zoneLow, bool isSupport);
   bool                 IsValidRejection(int barIndex, bool isSupport);
   double               CalculateWickPercent(int barIndex, bool upperWick);
   double               CalculateBodyPercent(int barIndex);

   //--- Méthodes privées - Cassure & Polarité
   bool                 CheckZoneBreak(SSRZone &zone);
   bool                 IsValidBreakout(int barIndex, double level, bool breakDown);
   void                 FlipZonePolarity(SSRZone &zone);

   //--- Méthodes privées - Scoring
   int                  CalculateZoneScore(SSRZone &zone);
   ENUM_ZONE_QUALITY    ScoreToQuality(int score);
   ENUM_ZONE_STRENGTH   TouchCountToStrength(int touchCount);
   ENUM_SR_TIMEFRAME_RANK GetTimeframeRank(ENUM_TIMEFRAMES tf);

   //--- Méthodes privées - Zone management
   void                 AddZone(SSRZone &zone);
   void                 MergeOverlappingZones();
   void                 UpdateZoneStatus(SSRZone &zone);
   void                 CleanupInvalidZones();
   bool                 ZonesOverlap(SSRZone &zone1, SSRZone &zone2);

   //--- Méthodes privées - Utilitaires
   double               GetPipValue();
   double               GetToleranceValue();
   double               CalculateATR(int period = 14);
   double               GetVolumeRatio(int barIndex);
   void                 UpdateAnalysis();

public:
   //--- Constructeur/Destructeur
                        CSupportResistance();
                       ~CSupportResistance();

   //--- Initialisation
   bool                 Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void                 SetParameters(int lookback, double tolerancePips, int maxZones);
   void                 SetSwingStrength(int strength) { m_swingStrength = MathMax(2, strength); }
   void                 SetMinTouchSpacing(int bars)   { m_minTouchSpacing = MathMax(3, bars); }
   void                 UseATRTolerance(bool use, double multiplier = 0.5);
   void                 Deinit();

   //--- Mise à jour
   bool                 Update();
   bool                 ForceUpdate();

   //--- ============ DÉTECTION DES ZONES ============
   void                 DetectLevels();
   void                 DetectSwingHighsLows(int lookback);

   //--- ============ VALIDATION ============
   //--- RÈGLE: Minimum 2 touches espacées dans le temps
   bool                 ValidateLevel(double price, int minTouches = 2);
   bool                 ValidateZone(SSRZone &zone);

   //--- ============ CASSURE & POLARITÉ ============
   //--- RÈGLE: Cassure valide = CLÔTURE au-delà (pas mèche seule)
   void                 CheckPolarityFlip();
   bool                 IsValidBreak(int shift, double levelPrice, bool isSupport);

   //--- RÈGLE: FAKEOUT = mèche casse sans clôture
   bool                 IsFakeout(int shift, double levelPrice, bool isSupport);
   bool                 DetectFakeout(int barIndex, SSRZone &zone);

   //--- ============ GETTERS ============
   int                  GetLevelCount();
   int                  GetZoneCount();
   SLevel               GetLevel(int index);  // Compatibilité ancienne API
   SSRZone              GetZone(int index);
   SSRZone              GetNearestSupport(double currentPrice);
   SSRZone              GetNearestResistance(double currentPrice);
   SSRAnalysis          GetAnalysis();

   //--- ============ VÉRIFICATIONS POSITION ============
   bool                 IsPriceAtSupport(double price, double &levelPrice);
   bool                 IsPriceAtResistance(double price, double &levelPrice);
   bool                 IsPriceInZone(double price, double zoneHigh, double zoneLow);
   bool                 IsPriceInSupportZone(double price);
   bool                 IsPriceInResistanceZone(double price);

   //--- ============ MULTI-TIMEFRAME ============
   //--- RÈGLE: Zone HTF domine zone LTF si chevauchement
   bool                 IsHTFZoneDominant(SSRZone &htfZone, SSRZone &ltfZone);
   int                  GetZoneRank(SSRZone &zone);

   //--- ============ CONFLUENCE ============
   bool                 HasConfluenceWithFibo(double fiboLevel, double &zonePrice);
   bool                 HasConfluenceWithEMA(double emaValue, double &zonePrice);
   bool                 HasConfluenceWithOB(double obHigh, double obLow, double &zonePrice);

   //--- ============ UTILITAIRES ============
   string               LevelTypeToString(ENUM_LEVEL_TYPE type);  // Compatibilité
   string               ZoneTypeToString(ENUM_ZONE_TYPE type);
   string               StrengthToString(ENUM_LEVEL_STRENGTH strength);  // Compatibilité
   string               ZoneStrengthToString(ENUM_ZONE_STRENGTH strength);
   string               ZoneQualityToString(ENUM_ZONE_QUALITY quality);
   string               GetZoneSummary(SSRZone &zone);
   void                 ClearLevels();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CSupportResistance::CSupportResistance()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookbackBars = 200;
   m_swingStrength = 3;           // 3 barres gauche/droite
   m_tolerancePips = 10.0;
   m_useATR = true;               // ATR par défaut
   m_atrMultiplier = 0.5;         // 50% de l'ATR
   m_minTouchSpacing = 5;         // Min 5 barres entre touches
   m_maxZones = 30;
   m_nextZoneId = 1;
   m_lastBarTime = 0;
   m_currentATR = 0;
   m_initialized = false;

   ArrayResize(m_zones, 0);
   m_analysis.Reset();
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CSupportResistance::~CSupportResistance()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CSupportResistance::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;

   if(!SymbolSelect(m_symbol, true))
   {
      Print("SupportResistance: Symbole invalide - ", m_symbol);
      return false;
   }

   ArrayResize(m_zones, 0);
   m_analysis.Reset();
   m_currentATR = CalculateATR(14);
   m_initialized = true;

   ForceUpdate();
   return true;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CSupportResistance::SetParameters(int lookback, double tolerancePips, int maxZones)
{
   m_lookbackBars = MathMax(50, lookback);
   m_tolerancePips = MathMax(1.0, tolerancePips);
   m_maxZones = MathMax(10, maxZones);
}

//+------------------------------------------------------------------+
//| Utiliser ATR pour la tolérance                                    |
//+------------------------------------------------------------------+
void CSupportResistance::UseATRTolerance(bool use, double multiplier = 0.5)
{
   m_useATR = use;
   m_atrMultiplier = MathMax(0.1, multiplier);
}

//+------------------------------------------------------------------+
//| Libération des ressources                                         |
//+------------------------------------------------------------------+
void CSupportResistance::Deinit()
{
   ArrayFree(m_zones);
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un pip                                        |
//+------------------------------------------------------------------+
double CSupportResistance::GetPipValue()
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

   if(digits == 5 || digits == 3)
      return point * 10;

   return point;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur de tolérance (ATR ou pips fixes)               |
//+------------------------------------------------------------------+
double CSupportResistance::GetToleranceValue()
{
   if(m_useATR && m_currentATR > 0)
   {
      return m_currentATR * m_atrMultiplier;
   }
   return m_tolerancePips * GetPipValue();
}

//+------------------------------------------------------------------+
//| Calculer l'ATR                                                    |
//+------------------------------------------------------------------+
double CSupportResistance::CalculateATR(int period = 14)
{
   double atr = 0;
   int bars = MathMin(period, iBars(m_symbol, m_timeframe) - 1);

   for(int i = 1; i <= bars; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double prevClose = iClose(m_symbol, m_timeframe, i + 1);

      double tr = MathMax(high - low,
                  MathMax(MathAbs(high - prevClose),
                          MathAbs(low - prevClose)));
      atr += tr;
   }

   return (bars > 0) ? atr / bars : 0;
}

//+------------------------------------------------------------------+
//| Obtenir le ratio de volume                                        |
//+------------------------------------------------------------------+
double CSupportResistance::GetVolumeRatio(int barIndex)
{
   long currentVol = iVolume(m_symbol, m_timeframe, barIndex);

   // Moyenne sur 20 barres
   double avgVol = 0;
   for(int i = barIndex + 1; i <= barIndex + 20; i++)
   {
      avgVol += (double)iVolume(m_symbol, m_timeframe, i);
   }
   avgVol /= 20;

   if(avgVol == 0) return 1.0;
   return (double)currentVol / avgVol;
}

//+------------------------------------------------------------------+
//| Mise à jour (optimisée - sur nouvelle bougie)                     |
//+------------------------------------------------------------------+
bool CSupportResistance::Update()
{
   if(!m_initialized) return false;

   datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);

   if(currentBarTime == m_lastBarTime)
      return true;  // Pas de nouvelle bougie

   m_lastBarTime = currentBarTime;
   return ForceUpdate();
}

//+------------------------------------------------------------------+
//| Mise à jour forcée                                                |
//+------------------------------------------------------------------+
bool CSupportResistance::ForceUpdate()
{
   if(!m_initialized) return false;

   // Mettre à jour ATR
   m_currentATR = CalculateATR(14);

   // Mettre à jour le statut des zones existantes
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      UpdateZoneStatus(m_zones[i]);
   }

   // Vérifier les cassures et polarité
   CheckPolarityFlip();

   // Nettoyer les zones invalides
   CleanupInvalidZones();

   // Détecter de nouvelles zones si nécessaire
   if(ArraySize(m_zones) < m_maxZones / 2)
   {
      DetectLevels();
   }

   // Mettre à jour l'analyse
   UpdateAnalysis();

   return true;
}

//+------------------------------------------------------------------+
//| Détection complète des niveaux                                    |
//+------------------------------------------------------------------+
void CSupportResistance::DetectLevels()
{
   DetectSwingHighsLows(m_lookbackBars);
   MergeOverlappingZones();
}

//+------------------------------------------------------------------+
//| Détecter les swing highs et lows                                  |
//+------------------------------------------------------------------+
void CSupportResistance::DetectSwingHighsLows(int lookback)
{
   int barsToCheck = MathMin(lookback, iBars(m_symbol, m_timeframe) - m_swingStrength - 1);

   for(int i = m_swingStrength; i < barsToCheck - m_swingStrength; i++)
   {
      // Swing High → Résistance potentielle
      if(IsSwingHigh(i, m_swingStrength))
      {
         SSRSwing swing;
         swing.Reset();
         swing.price = iHigh(m_symbol, m_timeframe, i);
         swing.time = iTime(m_symbol, m_timeframe, i);
         swing.barIndex = i;
         swing.isHigh = true;
         swing.wickHigh = iHigh(m_symbol, m_timeframe, i);
         swing.bodyHigh = MathMax(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         swing.bodyLow = MathMin(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         swing.wickLow = iLow(m_symbol, m_timeframe, i);
         swing.isValid = true;

         CreateZoneFromSwing(swing, true);
      }

      // Swing Low → Support potentiel
      if(IsSwingLow(i, m_swingStrength))
      {
         SSRSwing swing;
         swing.Reset();
         swing.price = iLow(m_symbol, m_timeframe, i);
         swing.time = iTime(m_symbol, m_timeframe, i);
         swing.barIndex = i;
         swing.isHigh = false;
         swing.wickHigh = iHigh(m_symbol, m_timeframe, i);
         swing.bodyHigh = MathMax(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         swing.bodyLow = MathMin(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         swing.wickLow = iLow(m_symbol, m_timeframe, i);
         swing.isValid = true;

         CreateZoneFromSwing(swing, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un swing high                                   |
//+------------------------------------------------------------------+
bool CSupportResistance::IsSwingHigh(int barIndex, int strength)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);

   // Vérifier les barres à gauche
   for(int i = 1; i <= strength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, barIndex + i) >= high)
         return false;
   }

   // Vérifier les barres à droite
   for(int i = 1; i <= strength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, barIndex - i) >= high)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un swing low                                    |
//+------------------------------------------------------------------+
bool CSupportResistance::IsSwingLow(int barIndex, int strength)
{
   double low = iLow(m_symbol, m_timeframe, barIndex);

   // Vérifier les barres à gauche
   for(int i = 1; i <= strength; i++)
   {
      if(iLow(m_symbol, m_timeframe, barIndex + i) <= low)
         return false;
   }

   // Vérifier les barres à droite
   for(int i = 1; i <= strength; i++)
   {
      if(iLow(m_symbol, m_timeframe, barIndex - i) <= low)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Créer une zone à partir d'un swing                                |
//+------------------------------------------------------------------+
void CSupportResistance::CreateZoneFromSwing(SSRSwing &swing, bool isResistance)
{
   double tolerance = GetToleranceValue();

   // Vérifier si une zone existe déjà dans cette région
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      // Zone existante dans la tolérance
      if(MathAbs(swing.price - m_zones[i].midPoint) <= tolerance * 2)
      {
         // Ajouter une touche si espacement suffisant
         if(ValidateTouchSpacing(m_zones[i], swing.time))
         {
            // Ajouter la touche
            int touchIdx = MathMin(m_zones[i].touchCount, 9);

            m_zones[i].touches[touchIdx].time = swing.time;
            m_zones[i].touches[touchIdx].barIndex = swing.barIndex;
            m_zones[i].touches[touchIdx].price = swing.price;
            m_zones[i].touches[touchIdx].reactionType = AnalyzeReaction(
               swing.barIndex,
               m_zones[i].zoneHigh,
               m_zones[i].zoneLow,
               !isResistance
            );
            m_zones[i].touches[touchIdx].wickSize = CalculateWickPercent(swing.barIndex, isResistance);
            m_zones[i].touches[touchIdx].bodySize = CalculateBodyPercent(swing.barIndex);
            m_zones[i].touches[touchIdx].volumeRatio = GetVolumeRatio(swing.barIndex);
            m_zones[i].touches[touchIdx].isValid = true;

            m_zones[i].touchCount++;
            m_zones[i].lastTouch = swing.time;

            // Élargir la zone si nécessaire
            if(isResistance)
            {
               m_zones[i].zoneHigh = MathMax(m_zones[i].zoneHigh, swing.wickHigh);
               m_zones[i].zoneLow = MathMin(m_zones[i].zoneLow, swing.bodyLow);
            }
            else
            {
               m_zones[i].zoneHigh = MathMax(m_zones[i].zoneHigh, swing.bodyHigh);
               m_zones[i].zoneLow = MathMin(m_zones[i].zoneLow, swing.wickLow);
            }

            // Mettre à jour
            m_zones[i].midPoint = (m_zones[i].zoneHigh + m_zones[i].zoneLow) / 2;
            m_zones[i].zoneSize = m_zones[i].zoneHigh - m_zones[i].zoneLow;
            m_zones[i].strength = TouchCountToStrength(m_zones[i].touchCount);
            m_zones[i].score = CalculateZoneScore(m_zones[i]);
            m_zones[i].quality = ScoreToQuality(m_zones[i].score);

            return;
         }
         return;  // Zone existe mais espacement insuffisant
      }
   }

   // Créer nouvelle zone
   SSRZone newZone;
   newZone.Reset();
   newZone.id = m_nextZoneId++;
   newZone.type = isResistance ? ZONE_RESISTANCE : ZONE_SUPPORT;
   newZone.status = SR_STATUS_ACTIVE;
   newZone.timeframe = m_timeframe;
   newZone.rank = GetTimeframeRank(m_timeframe);

   // Définir la zone (pas une ligne!)
   if(isResistance)
   {
      newZone.zoneHigh = swing.wickHigh + tolerance * 0.2;
      newZone.zoneLow = swing.bodyLow - tolerance * 0.2;
   }
   else
   {
      newZone.zoneHigh = swing.bodyHigh + tolerance * 0.2;
      newZone.zoneLow = swing.wickLow - tolerance * 0.2;
   }

   newZone.midPoint = (newZone.zoneHigh + newZone.zoneLow) / 2;
   newZone.zoneSize = newZone.zoneHigh - newZone.zoneLow;

   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(price > 0)
      newZone.zoneSizePct = (newZone.zoneSize / price) * 100;

   // Première touche
   newZone.touchCount = 1;
   newZone.touches[0].time = swing.time;
   newZone.touches[0].barIndex = swing.barIndex;
   newZone.touches[0].price = swing.price;
   newZone.touches[0].reactionType = REACTION_WICK_REJECTION;
   newZone.touches[0].wickSize = CalculateWickPercent(swing.barIndex, isResistance);
   newZone.touches[0].bodySize = CalculateBodyPercent(swing.barIndex);
   newZone.touches[0].volumeRatio = GetVolumeRatio(swing.barIndex);
   newZone.touches[0].isValid = true;

   newZone.firstTouch = swing.time;
   newZone.lastTouch = swing.time;
   newZone.strength = SR_STRENGTH_WEAK;
   newZone.score = CalculateZoneScore(newZone);
   newZone.quality = ScoreToQuality(newZone.score);
   newZone.isValid = true;

   AddZone(newZone);
}

//+------------------------------------------------------------------+
//| Valider l'espacement entre les touches                            |
//| RÈGLE: Les touches doivent être espacées dans le temps            |
//+------------------------------------------------------------------+
bool CSupportResistance::ValidateTouchSpacing(SSRZone &zone, datetime newTouchTime)
{
   if(zone.touchCount == 0) return true;

   // Calculer l'espacement en barres
   int currentBar = iBarShift(m_symbol, m_timeframe, newTouchTime);
   int lastTouchBar = iBarShift(m_symbol, m_timeframe, zone.lastTouch);

   int spacing = MathAbs(currentBar - lastTouchBar);

   // RÈGLE: Minimum m_minTouchSpacing barres entre les touches
   return (spacing >= m_minTouchSpacing);
}

//+------------------------------------------------------------------+
//| Analyser le type de réaction sur une zone                         |
//+------------------------------------------------------------------+
ENUM_REACTION_TYPE CSupportResistance::AnalyzeReaction(int barIndex, double zoneHigh, double zoneLow, bool isSupport)
{
   double wickPct = CalculateWickPercent(barIndex, !isSupport);
   double bodyPct = CalculateBodyPercent(barIndex);
   double volRatio = GetVolumeRatio(barIndex);

   // RÈGLE: Rejet fort = mèche ≥50% + corps <40% + volume élevé
   if(wickPct >= 50.0 && bodyPct < 40.0 && volRatio >= 1.5)
   {
      return REACTION_STRONG_REJECTION;
   }

   // RÈGLE: Rejet par mèche = mèche ≥50%
   if(wickPct >= 50.0)
   {
      return REACTION_WICK_REJECTION;
   }

   // Retournement avec corps fort
   if(bodyPct >= 60.0)
   {
      double close = iClose(m_symbol, m_timeframe, barIndex);
      double open = iOpen(m_symbol, m_timeframe, barIndex);
      bool isBullish = close > open;

      if((isSupport && isBullish) || (!isSupport && !isBullish))
      {
         return REACTION_BODY_REVERSAL;
      }
   }

   // Test faible
   if(wickPct >= 30.0 || bodyPct >= 40.0)
   {
      return REACTION_WEAK_TEST;
   }

   return REACTION_NONE;
}

//+------------------------------------------------------------------+
//| Calculer le pourcentage de mèche                                  |
//+------------------------------------------------------------------+
double CSupportResistance::CalculateWickPercent(int barIndex, bool upperWick)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   double low = iLow(m_symbol, m_timeframe, barIndex);
   double open = iOpen(m_symbol, m_timeframe, barIndex);
   double close = iClose(m_symbol, m_timeframe, barIndex);

   double range = high - low;
   if(range == 0) return 0;

   double bodyHigh = MathMax(open, close);
   double bodyLow = MathMin(open, close);

   if(upperWick)
   {
      return ((high - bodyHigh) / range) * 100;
   }
   else
   {
      return ((bodyLow - low) / range) * 100;
   }
}

//+------------------------------------------------------------------+
//| Calculer le pourcentage du corps                                  |
//+------------------------------------------------------------------+
double CSupportResistance::CalculateBodyPercent(int barIndex)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   double low = iLow(m_symbol, m_timeframe, barIndex);
   double open = iOpen(m_symbol, m_timeframe, barIndex);
   double close = iClose(m_symbol, m_timeframe, barIndex);

   double range = high - low;
   if(range == 0) return 0;

   double body = MathAbs(close - open);
   return (body / range) * 100;
}

//+------------------------------------------------------------------+
//| Vérifier la cassure d'une zone                                    |
//+------------------------------------------------------------------+
bool CSupportResistance::CheckZoneBreak(SSRZone &zone)
{
   double close = iClose(m_symbol, m_timeframe, 1);

   if(zone.type == ZONE_SUPPORT || zone.type == ZONE_FLIPPED_TO_SUPPORT)
   {
      // Support cassé si clôture SOUS la zone
      if(close < zone.zoneLow)
      {
         // Vérifier que ce n'est pas un fakeout
         if(!DetectFakeout(1, zone))
         {
            zone.isBroken = true;
            zone.breakTime = iTime(m_symbol, m_timeframe, 1);
            zone.breakPrice = close;
            return true;
         }
      }
   }
   else if(zone.type == ZONE_RESISTANCE || zone.type == ZONE_FLIPPED_TO_RESISTANCE)
   {
      // Résistance cassée si clôture AU-DESSUS de la zone
      if(close > zone.zoneHigh)
      {
         if(!DetectFakeout(1, zone))
         {
            zone.isBroken = true;
            zone.breakTime = iTime(m_symbol, m_timeframe, 1);
            zone.breakPrice = close;
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Détecter un fakeout sur une zone                                  |
//| RÈGLE: Fakeout = mèche casse mais clôture ne confirme pas        |
//+------------------------------------------------------------------+
bool CSupportResistance::DetectFakeout(int barIndex, SSRZone &zone)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   double low = iLow(m_symbol, m_timeframe, barIndex);
   double close = iClose(m_symbol, m_timeframe, barIndex);
   double open = iOpen(m_symbol, m_timeframe, barIndex);

   if(zone.type == ZONE_SUPPORT || zone.type == ZONE_FLIPPED_TO_SUPPORT)
   {
      // Fakeout support: mèche casse mais clôture au-dessus
      if(low < zone.zoneLow && close > zone.zoneLow && open > zone.zoneLow)
      {
         zone.isFakeout = true;
         // Renforcer la zone après fakeout
         zone.touchCount++;
         zone.score = MathMin(100, zone.score + 10);
         return true;
      }
   }
   else
   {
      // Fakeout résistance: mèche casse mais clôture en-dessous
      if(high > zone.zoneHigh && close < zone.zoneHigh && open < zone.zoneHigh)
      {
         zone.isFakeout = true;
         zone.touchCount++;
         zone.score = MathMin(100, zone.score + 10);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Inverser la polarité d'une zone                                   |
//| RÈGLE: Support cassé → Résistance, Résistance cassée → Support   |
//+------------------------------------------------------------------+
void CSupportResistance::FlipZonePolarity(SSRZone &zone)
{
   if(!zone.isBroken) return;

   if(zone.type == ZONE_SUPPORT)
   {
      zone.type = ZONE_FLIPPED_TO_RESISTANCE;
      zone.status = SR_STATUS_FLIPPED;
      zone.isFlipped = true;
   }
   else if(zone.type == ZONE_RESISTANCE)
   {
      zone.type = ZONE_FLIPPED_TO_SUPPORT;
      zone.status = SR_STATUS_FLIPPED;
      zone.isFlipped = true;
   }

   // Reset des touches pour la nouvelle polarité
   zone.touchCount = 0;
   zone.isBroken = false;
}

//+------------------------------------------------------------------+
//| Vérifier et appliquer les changements de polarité                 |
//+------------------------------------------------------------------+
void CSupportResistance::CheckPolarityFlip()
{
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(m_zones[i].status == SR_STATUS_ACTIVE)
      {
         if(CheckZoneBreak(m_zones[i]))
         {
            FlipZonePolarity(m_zones[i]);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculer le score d'une zone (0-100)                              |
//+------------------------------------------------------------------+
int CSupportResistance::CalculateZoneScore(SSRZone &zone)
{
   int score = 0;

   // Touches (max 40 points)
   score += MathMin(40, zone.touchCount * 10);

   // Qualité des réactions (max 30 points)
   int strongReactions = 0;
   for(int i = 0; i < zone.touchCount && i < 10; i++)
   {
      if(zone.touches[i].reactionType == REACTION_STRONG_REJECTION)
         strongReactions += 3;
      else if(zone.touches[i].reactionType == REACTION_WICK_REJECTION)
         strongReactions += 2;
      else if(zone.touches[i].reactionType == REACTION_BODY_REVERSAL)
         strongReactions += 2;
   }
   score += MathMin(30, strongReactions * 5);

   // Volume confirmation (max 15 points)
   double avgVolRatio = 0;
   for(int i = 0; i < zone.touchCount && i < 10; i++)
   {
      avgVolRatio += zone.touches[i].volumeRatio;
   }
   if(zone.touchCount > 0) avgVolRatio /= zone.touchCount;

   if(avgVolRatio >= 2.0)
   {
      score += 15;
      zone.hasVolumeConfirmation = true;
   }
   else if(avgVolRatio >= 1.5)
   {
      score += 10;
      zone.hasVolumeConfirmation = true;
   }
   else if(avgVolRatio >= 1.2)
   {
      score += 5;
   }

   // Fakeout détecté = zone plus forte (max 10 points)
   if(zone.isFakeout) score += 10;

   // Timeframe rank (max 5 points)
   if(zone.rank == SR_RANK_MAJOR) score += 5;
   else if(zone.rank == SR_RANK_INTERMEDIATE) score += 3;

   return MathMin(100, score);
}

//+------------------------------------------------------------------+
//| Convertir score en qualité                                        |
//+------------------------------------------------------------------+
ENUM_ZONE_QUALITY CSupportResistance::ScoreToQuality(int score)
{
   if(score >= 80) return SR_QUALITY_PREMIUM;
   if(score >= 60) return SR_QUALITY_HIGH;
   if(score >= 40) return SR_QUALITY_MEDIUM;
   return SR_QUALITY_LOW;
}

//+------------------------------------------------------------------+
//| Convertir nombre de touches en force                              |
//+------------------------------------------------------------------+
ENUM_ZONE_STRENGTH CSupportResistance::TouchCountToStrength(int touchCount)
{
   if(touchCount >= 6) return SR_STRENGTH_MAJOR;
   if(touchCount >= 4) return SR_STRENGTH_STRONG;
   if(touchCount >= 3) return SR_STRENGTH_MODERATE;
   return SR_STRENGTH_WEAK;
}

//+------------------------------------------------------------------+
//| Obtenir le rang du timeframe                                      |
//+------------------------------------------------------------------+
ENUM_SR_TIMEFRAME_RANK CSupportResistance::GetTimeframeRank(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_D1:
      case PERIOD_H4:
         return SR_RANK_MAJOR;
      case PERIOD_H1:
         return SR_RANK_INTERMEDIATE;
      default:
         return SR_RANK_MINOR;
   }
}

//+------------------------------------------------------------------+
//| Ajouter une zone                                                  |
//+------------------------------------------------------------------+
void CSupportResistance::AddZone(SSRZone &zone)
{
   int size = ArraySize(m_zones);

   if(size >= m_maxZones)
   {
      // Supprimer la zone avec le plus faible score
      int minScoreIdx = 0;
      int minScore = m_zones[0].score;

      for(int i = 1; i < size; i++)
      {
         if(m_zones[i].score < minScore)
         {
            minScore = m_zones[i].score;
            minScoreIdx = i;
         }
      }

      // Remplacer
      m_zones[minScoreIdx] = zone;
   }
   else
   {
      ArrayResize(m_zones, size + 1);
      m_zones[size] = zone;
   }
}

//+------------------------------------------------------------------+
//| Fusionner les zones qui se chevauchent                            |
//+------------------------------------------------------------------+
void CSupportResistance::MergeOverlappingZones()
{
   for(int i = 0; i < ArraySize(m_zones) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(m_zones); j++)
      {
         if(ZonesOverlap(m_zones[i], m_zones[j]))
         {
            // Fusionner vers la zone avec le plus de touches
            if(m_zones[j].touchCount > m_zones[i].touchCount)
            {
               m_zones[i].zoneHigh = MathMax(m_zones[i].zoneHigh, m_zones[j].zoneHigh);
               m_zones[i].zoneLow = MathMin(m_zones[i].zoneLow, m_zones[j].zoneLow);
               m_zones[i].touchCount += m_zones[j].touchCount;
               m_zones[i].midPoint = (m_zones[i].zoneHigh + m_zones[i].zoneLow) / 2;
            }
            else
            {
               m_zones[i].zoneHigh = MathMax(m_zones[i].zoneHigh, m_zones[j].zoneHigh);
               m_zones[i].zoneLow = MathMin(m_zones[i].zoneLow, m_zones[j].zoneLow);
               m_zones[i].touchCount += m_zones[j].touchCount;
            }

            m_zones[i].strength = TouchCountToStrength(m_zones[i].touchCount);
            m_zones[i].score = CalculateZoneScore(m_zones[i]);

            // Supprimer zone j
            for(int k = j; k < ArraySize(m_zones) - 1; k++)
               m_zones[k] = m_zones[k + 1];
            ArrayResize(m_zones, ArraySize(m_zones) - 1);
            j--;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si deux zones se chevauchent                             |
//+------------------------------------------------------------------+
bool CSupportResistance::ZonesOverlap(SSRZone &zone1, SSRZone &zone2)
{
   // Même type requis pour fusion
   bool sameType = (zone1.type == zone2.type) ||
                   (zone1.type == ZONE_SUPPORT && zone2.type == ZONE_FLIPPED_TO_SUPPORT) ||
                   (zone1.type == ZONE_RESISTANCE && zone2.type == ZONE_FLIPPED_TO_RESISTANCE);

   if(!sameType) return false;

   // Vérifier chevauchement
   return !(zone1.zoneLow > zone2.zoneHigh || zone2.zoneLow > zone1.zoneHigh);
}

//+------------------------------------------------------------------+
//| Mettre à jour le statut d'une zone                                |
//+------------------------------------------------------------------+
void CSupportResistance::UpdateZoneStatus(SSRZone &zone)
{
   // Calculer barres depuis dernière touche
   zone.barsSinceLastTouch = iBarShift(m_symbol, m_timeframe, zone.lastTouch);

   // Invalider les zones trop anciennes sans nouvelles touches
   if(zone.barsSinceLastTouch > m_lookbackBars * 2 && zone.touchCount < 3)
   {
      zone.status = SR_STATUS_INVALID;
      zone.isValid = false;
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les zones invalides                                      |
//+------------------------------------------------------------------+
void CSupportResistance::CleanupInvalidZones()
{
   for(int i = ArraySize(m_zones) - 1; i >= 0; i--)
   {
      if(!m_zones[i].isValid || m_zones[i].status == SR_STATUS_INVALID)
      {
         for(int j = i; j < ArraySize(m_zones) - 1; j++)
            m_zones[j] = m_zones[j + 1];
         ArrayResize(m_zones, ArraySize(m_zones) - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour l'analyse globale                                   |
//+------------------------------------------------------------------+
void CSupportResistance::UpdateAnalysis()
{
   m_analysis.Reset();
   m_analysis.totalZones = ArraySize(m_zones);

   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double minDistSupport = DBL_MAX;
   double minDistResistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(m_zones[i].type == ZONE_SUPPORT || m_zones[i].type == ZONE_FLIPPED_TO_SUPPORT)
      {
         m_analysis.activeSupports++;

         if(m_zones[i].zoneHigh < currentPrice)
         {
            double dist = currentPrice - m_zones[i].zoneHigh;
            if(dist < minDistSupport)
            {
               minDistSupport = dist;
               m_analysis.nearestSupport = m_zones[i];
            }
         }

         // Vérifier si prix dans zone
         if(currentPrice >= m_zones[i].zoneLow && currentPrice <= m_zones[i].zoneHigh)
         {
            m_analysis.priceInSupportZone = true;
         }
      }
      else
      {
         m_analysis.activeResistances++;

         if(m_zones[i].zoneLow > currentPrice)
         {
            double dist = m_zones[i].zoneLow - currentPrice;
            if(dist < minDistResistance)
            {
               minDistResistance = dist;
               m_analysis.nearestResistance = m_zones[i];
            }
         }

         if(currentPrice >= m_zones[i].zoneLow && currentPrice <= m_zones[i].zoneHigh)
         {
            m_analysis.priceInResistanceZone = true;
         }
      }
   }

   m_analysis.distanceToSupport = minDistSupport;
   m_analysis.distanceToResistance = minDistResistance;
   m_analysis.isValid = true;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de zones                                        |
//+------------------------------------------------------------------+
int CSupportResistance::GetZoneCount()
{
   return ArraySize(m_zones);
}

//+------------------------------------------------------------------+
//| Obtenir une zone par index                                        |
//+------------------------------------------------------------------+
SSRZone CSupportResistance::GetZone(int index)
{
   SSRZone empty;
   empty.Reset();

   if(index < 0 || index >= ArraySize(m_zones))
      return empty;

   return m_zones[index];
}

//+------------------------------------------------------------------+
//| Obtenir l'analyse complète                                        |
//+------------------------------------------------------------------+
SSRAnalysis CSupportResistance::GetAnalysis()
{
   return m_analysis;
}

//+------------------------------------------------------------------+
//| Obtenir le support le plus proche                                 |
//+------------------------------------------------------------------+
SSRZone CSupportResistance::GetNearestSupport(double currentPrice)
{
   SSRZone nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if((m_zones[i].type == ZONE_SUPPORT || m_zones[i].type == ZONE_FLIPPED_TO_SUPPORT) &&
         m_zones[i].zoneHigh < currentPrice)
      {
         double distance = currentPrice - m_zones[i].zoneHigh;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_zones[i];
         }
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Obtenir la résistance la plus proche                              |
//+------------------------------------------------------------------+
SSRZone CSupportResistance::GetNearestResistance(double currentPrice)
{
   SSRZone nearest;
   nearest.Reset();
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if((m_zones[i].type == ZONE_RESISTANCE || m_zones[i].type == ZONE_FLIPPED_TO_RESISTANCE) &&
         m_zones[i].zoneLow > currentPrice)
      {
         double distance = m_zones[i].zoneLow - currentPrice;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_zones[i];
         }
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est sur un support                            |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceAtSupport(double price, double &levelPrice)
{
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if((m_zones[i].type == ZONE_SUPPORT || m_zones[i].type == ZONE_FLIPPED_TO_SUPPORT) &&
         price >= m_zones[i].zoneLow && price <= m_zones[i].zoneHigh)
      {
         levelPrice = m_zones[i].midPoint;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est sur une résistance                        |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceAtResistance(double price, double &levelPrice)
{
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if((m_zones[i].type == ZONE_RESISTANCE || m_zones[i].type == ZONE_FLIPPED_TO_RESISTANCE) &&
         price >= m_zones[i].zoneLow && price <= m_zones[i].zoneHigh)
      {
         levelPrice = m_zones[i].midPoint;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone                             |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceInZone(double price, double zoneHigh, double zoneLow)
{
   return (price >= zoneLow && price <= zoneHigh);
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone de support                  |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceInSupportZone(double price)
{
   double dummy;
   return IsPriceAtSupport(price, dummy);
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone de résistance               |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceInResistanceZone(double price)
{
   double dummy;
   return IsPriceAtResistance(price, dummy);
}

//+------------------------------------------------------------------+
//| Vérifier si zone HTF domine zone LTF                              |
//| RÈGLE: Zone HTF prend la priorité si chevauchement                |
//+------------------------------------------------------------------+
bool CSupportResistance::IsHTFZoneDominant(SSRZone &htfZone, SSRZone &ltfZone)
{
   // Vérifier le rang
   if(htfZone.rank > ltfZone.rank) return false;  // HTF a un rang plus petit = priorité

   // Vérifier chevauchement
   if(ZonesOverlap(htfZone, ltfZone))
   {
      return (htfZone.rank <= ltfZone.rank);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le rang d'une zone                                        |
//+------------------------------------------------------------------+
int CSupportResistance::GetZoneRank(SSRZone &zone)
{
   return (int)zone.rank;
}

//+------------------------------------------------------------------+
//| Confluence avec Fibonacci                                         |
//+------------------------------------------------------------------+
bool CSupportResistance::HasConfluenceWithFibo(double fiboLevel, double &zonePrice)
{
   double tolerance = GetToleranceValue();

   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(MathAbs(m_zones[i].midPoint - fiboLevel) <= tolerance)
      {
         zonePrice = m_zones[i].midPoint;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Confluence avec EMA                                               |
//+------------------------------------------------------------------+
bool CSupportResistance::HasConfluenceWithEMA(double emaValue, double &zonePrice)
{
   double tolerance = GetToleranceValue();

   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(emaValue >= m_zones[i].zoneLow - tolerance &&
         emaValue <= m_zones[i].zoneHigh + tolerance)
      {
         zonePrice = m_zones[i].midPoint;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Confluence avec Order Block                                       |
//+------------------------------------------------------------------+
bool CSupportResistance::HasConfluenceWithOB(double obHigh, double obLow, double &zonePrice)
{
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      // Vérifier chevauchement avec OB
      if(!(m_zones[i].zoneLow > obHigh || obLow > m_zones[i].zoneHigh))
      {
         zonePrice = m_zones[i].midPoint;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Convertir type de zone en string                                  |
//+------------------------------------------------------------------+
string CSupportResistance::ZoneTypeToString(ENUM_ZONE_TYPE type)
{
   switch(type)
   {
      case ZONE_SUPPORT:              return "Support";
      case ZONE_RESISTANCE:           return "Résistance";
      case ZONE_FLIPPED_TO_RESISTANCE:return "Support → Résistance";
      case ZONE_FLIPPED_TO_SUPPORT:   return "Résistance → Support";
      default:                        return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir force de zone en string                                 |
//+------------------------------------------------------------------+
string CSupportResistance::ZoneStrengthToString(ENUM_ZONE_STRENGTH strength)
{
   switch(strength)
   {
      case SR_STRENGTH_WEAK:     return "Faible (2 touches)";
      case SR_STRENGTH_MODERATE: return "Modéré (3 touches)";
      case SR_STRENGTH_STRONG:   return "Fort (4-5 touches)";
      case SR_STRENGTH_MAJOR:    return "Majeur (6+ touches)";
      default:                   return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir qualité de zone en string                               |
//+------------------------------------------------------------------+
string CSupportResistance::ZoneQualityToString(ENUM_ZONE_QUALITY quality)
{
   switch(quality)
   {
      case SR_QUALITY_LOW:     return "Faible";
      case SR_QUALITY_MEDIUM:  return "Moyenne";
      case SR_QUALITY_HIGH:    return "Haute";
      case SR_QUALITY_PREMIUM: return "Premium";
      default:                 return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Obtenir un résumé de zone                                         |
//+------------------------------------------------------------------+
string CSupportResistance::GetZoneSummary(SSRZone &zone)
{
   string summary = "";
   summary += ZoneTypeToString(zone.type) + " | ";
   summary += "Zone: " + DoubleToString(zone.zoneLow, 5) + " - " + DoubleToString(zone.zoneHigh, 5) + " | ";
   summary += "Touches: " + IntegerToString(zone.touchCount) + " | ";
   summary += "Score: " + IntegerToString(zone.score) + "/100 | ";
   summary += ZoneQualityToString(zone.quality);

   return summary;
}

//+------------------------------------------------------------------+
//| Effacer toutes les zones                                          |
//+------------------------------------------------------------------+
void CSupportResistance::ClearLevels()
{
   ArrayFree(m_zones);
   ArrayResize(m_zones, 0);
   m_analysis.Reset();
}

//+------------------------------------------------------------------+
//| ============ COMPATIBILITÉ ANCIENNE API ============              |
//+------------------------------------------------------------------+

int CSupportResistance::GetLevelCount()
{
   return GetZoneCount();
}

SLevel CSupportResistance::GetLevel(int index)
{
   SLevel level;
   level.price = 0;
   level.type = LEVEL_SUPPORT;
   level.strength = LEVEL_STRENGTH_WEAK;
   level.touchCount = 0;
   level.firstTouch = 0;
   level.lastTouch = 0;
   level.isBroken = false;
   level.isFakeout = false;
   level.brokenPrice = 0;

   if(index < 0 || index >= ArraySize(m_zones))
      return level;

   SSRZone zone = m_zones[index];

   level.price = zone.midPoint;

   switch(zone.type)
   {
      case ZONE_SUPPORT:              level.type = LEVEL_SUPPORT; break;
      case ZONE_RESISTANCE:           level.type = LEVEL_RESISTANCE; break;
      case ZONE_FLIPPED_TO_RESISTANCE:level.type = LEVEL_BROKEN_SUPPORT; break;
      case ZONE_FLIPPED_TO_SUPPORT:   level.type = LEVEL_BROKEN_RESISTANCE; break;
   }

   switch(zone.strength)
   {
      case SR_STRENGTH_WEAK:
      case SR_STRENGTH_MODERATE: level.strength = LEVEL_STRENGTH_WEAK; break;
      case SR_STRENGTH_STRONG:   level.strength = LEVEL_STRENGTH_MODERATE; break;
      case SR_STRENGTH_MAJOR:    level.strength = LEVEL_STRENGTH_STRONG; break;
   }

   level.touchCount = zone.touchCount;
   level.firstTouch = zone.firstTouch;
   level.lastTouch = zone.lastTouch;
   level.isBroken = zone.isBroken;
   level.isFakeout = zone.isFakeout;
   level.brokenPrice = zone.breakPrice;

   return level;
}

bool CSupportResistance::IsValidBreak(int shift, double levelPrice, bool isSupport)
{
   double close = iClose(m_symbol, m_timeframe, shift);

   // Trouver la zone correspondante
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(MathAbs(m_zones[i].midPoint - levelPrice) < GetToleranceValue())
      {
         // Vérifier fakeout d'abord
         if(DetectFakeout(shift, m_zones[i]))
            return false;

         if(isSupport)
            return (close < m_zones[i].zoneLow);
         else
            return (close > m_zones[i].zoneHigh);
      }
   }

   return false;
}

bool CSupportResistance::IsFakeout(int shift, double levelPrice, bool isSupport)
{
   for(int i = 0; i < ArraySize(m_zones); i++)
   {
      if(MathAbs(m_zones[i].midPoint - levelPrice) < GetToleranceValue())
      {
         return DetectFakeout(shift, m_zones[i]);
      }
   }
   return false;
}

string CSupportResistance::LevelTypeToString(ENUM_LEVEL_TYPE type)
{
   switch(type)
   {
      case LEVEL_SUPPORT:           return "Support";
      case LEVEL_RESISTANCE:        return "Résistance";
      case LEVEL_BROKEN_SUPPORT:    return "Support Cassé";
      case LEVEL_BROKEN_RESISTANCE: return "Résistance Cassée";
      default:                      return "Inconnu";
   }
}

string CSupportResistance::StrengthToString(ENUM_LEVEL_STRENGTH strength)
{
   switch(strength)
   {
      case LEVEL_STRENGTH_WEAK:     return "Faible";
      case LEVEL_STRENGTH_MODERATE: return "Modéré";
      case LEVEL_STRENGTH_STRONG:   return "Fort";
      default:                      return "Inconnu";
   }
}

//+------------------------------------------------------------------+
