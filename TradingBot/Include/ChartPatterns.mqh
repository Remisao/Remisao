//+------------------------------------------------------------------+
//|                                              ChartPatterns.mqh  |
//|                        CHAPITRE 5 - PATTERNS GRAPHIQUES         |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des types de patterns                                |
//+------------------------------------------------------------------+
enum ENUM_CHART_PATTERN
{
   PATTERN_NONE = 0,
   PATTERN_DOUBLE_TOP,           // Double Top
   PATTERN_DOUBLE_BOTTOM,        // Double Bottom
   PATTERN_TRIANGLE_ASCENDING,   // Triangle Ascendant
   PATTERN_TRIANGLE_DESCENDING,  // Triangle Descendant
   PATTERN_TRIANGLE_SYMMETRIC,   // Triangle Symétrique
   PATTERN_FLAG_BULLISH,         // Drapeau Haussier
   PATTERN_FLAG_BEARISH,         // Drapeau Baissier
   PATTERN_HEAD_SHOULDERS,       // Épaule-Tête-Épaule
   PATTERN_INV_HEAD_SHOULDERS,   // Épaule-Tête-Épaule Inversé
   PATTERN_WEDGE_RISING,         // Wedge Montant
   PATTERN_WEDGE_FALLING         // Wedge Descendant
};

enum ENUM_PATTERN_STATUS
{
   STATUS_FORMING = 0,           // En formation
   STATUS_COMPLETE,              // Pattern complet
   STATUS_NECKLINE_BREAK,        // Cassure de la neckline
   STATUS_CONFIRMED              // Confirmé
};

//+------------------------------------------------------------------+
//| Structure d'un pattern détecté                                   |
//+------------------------------------------------------------------+
struct SChartPattern
{
   ENUM_CHART_PATTERN   type;
   ENUM_PATTERN_STATUS  status;
   double               necklinePrice;    // Prix de la neckline
   double               targetPrice;      // Objectif
   double               peak1;            // Premier sommet
   double               peak2;            // Deuxième sommet
   double               trough1;          // Premier creux
   double               trough2;          // Deuxième creux
   datetime             startTime;
   datetime             endTime;
   bool                 isBullish;        // Direction du signal
   double               reliability;      // Fiabilité (0-100%)
};

//+------------------------------------------------------------------+
//| Classe de détection des patterns graphiques                       |
//+------------------------------------------------------------------+
class CChartPatterns
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   double            m_tolerance;      // Tolérance pour correspondance des niveaux (%)
   SChartPattern     m_detectedPatterns[];

   // Méthodes privées
   double            GetTolerance();
   bool              ArePricesEqual(double price1, double price2);
   double            FindPeaks(double &peaks[], int count);
   double            FindTroughs(double &troughs[], int count);

public:
   CChartPatterns();
   ~CChartPatterns();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int lookback, double tolerancePct);

   // Détection des patterns
   void              DetectAllPatterns();

   // RÈGLE: Double Top / Double Bottom
   // → Alerte UNIQUEMENT à la cassure de la Neckline
   bool              DetectDoubleTop(SChartPattern &pattern);
   bool              DetectDoubleBottom(SChartPattern &pattern);
   bool              IsNecklineBreak(SChartPattern &pattern);

   // RÈGLE: Patterns de continuation
   // → Alerte "Compression – Mouvement imminent"
   bool              DetectTriangle(SChartPattern &pattern);
   bool              DetectFlag(SChartPattern &pattern);

   // Head & Shoulders
   bool              DetectHeadShoulders(SChartPattern &pattern);
   bool              DetectInvHeadShoulders(SChartPattern &pattern);

   // Wedge patterns
   bool              DetectWedge(SChartPattern &pattern);

   // Vérification de cassure
   bool              CheckBreakout(SChartPattern &pattern, int shift = 1);

   // Calcul de l'objectif
   double            CalculateTarget(SChartPattern &pattern);

   // Getters
   int               GetPatternCount();
   SChartPattern     GetPattern(int index);
   SChartPattern     GetLastPattern();
   bool              HasActivePattern();

   // Utilitaires
   string            PatternTypeToString(ENUM_CHART_PATTERN type);
   string            PatternStatusToString(ENUM_PATTERN_STATUS status);
   string            GetPatternAlert(SChartPattern &pattern);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CChartPatterns::CChartPatterns()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookback = 50;
   m_tolerance = 1.0; // 1% de tolérance
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CChartPatterns::~CChartPatterns()
{
   ArrayFree(m_detectedPatterns);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CChartPatterns::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CChartPatterns::SetParameters(int lookback, double tolerancePct)
{
   m_lookback = lookback;
   m_tolerance = tolerancePct;
}

//+------------------------------------------------------------------+
//| Obtenir la tolérance en valeur de prix                           |
//+------------------------------------------------------------------+
double CChartPatterns::GetTolerance()
{
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return price * (m_tolerance / 100.0);
}

//+------------------------------------------------------------------+
//| Vérifier si deux prix sont "égaux" (dans la tolérance)           |
//+------------------------------------------------------------------+
bool CChartPatterns::ArePricesEqual(double price1, double price2)
{
   return (MathAbs(price1 - price2) <= GetTolerance());
}

//+------------------------------------------------------------------+
//| Détecter tous les patterns                                        |
//+------------------------------------------------------------------+
void CChartPatterns::DetectAllPatterns()
{
   ArrayFree(m_detectedPatterns);
   ArrayResize(m_detectedPatterns, 0);

   SChartPattern pattern;

   // Détecter Double Top
   if(DetectDoubleTop(pattern))
   {
      int size = ArraySize(m_detectedPatterns);
      ArrayResize(m_detectedPatterns, size + 1);
      m_detectedPatterns[size] = pattern;
   }

   // Détecter Double Bottom
   if(DetectDoubleBottom(pattern))
   {
      int size = ArraySize(m_detectedPatterns);
      ArrayResize(m_detectedPatterns, size + 1);
      m_detectedPatterns[size] = pattern;
   }

   // Détecter Triangles
   if(DetectTriangle(pattern))
   {
      int size = ArraySize(m_detectedPatterns);
      ArrayResize(m_detectedPatterns, size + 1);
      m_detectedPatterns[size] = pattern;
   }

   // Détecter Flags
   if(DetectFlag(pattern))
   {
      int size = ArraySize(m_detectedPatterns);
      ArrayResize(m_detectedPatterns, size + 1);
      m_detectedPatterns[size] = pattern;
   }
}

//+------------------------------------------------------------------+
//| RÈGLE: Double Top                                                 |
//| → Alerte UNIQUEMENT à la cassure de la Neckline                  |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectDoubleTop(SChartPattern &pattern)
{
   // Trouver les 2 sommets les plus récents
   double highs[];
   int highBars[];
   ArrayResize(highs, 0);
   ArrayResize(highBars, 0);

   // Scanner les swing highs
   for(int i = 3; i < m_lookback - 3; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);

      // Vérifier si c'est un swing high local
      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i - 2) &&
         high > iHigh(m_symbol, m_timeframe, i + 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(highs);
         ArrayResize(highs, size + 1);
         ArrayResize(highBars, size + 1);
         highs[size] = high;
         highBars[size] = i;

         if(ArraySize(highs) >= 2) break; // On a assez de sommets
      }
   }

   if(ArraySize(highs) < 2) return false;

   // Vérifier si les deux sommets sont au même niveau (Double Top)
   if(!ArePricesEqual(highs[0], highs[1])) return false;

   // Trouver la neckline (creux entre les deux sommets)
   int startBar = MathMin(highBars[0], highBars[1]);
   int endBar = MathMax(highBars[0], highBars[1]);

   double neckline = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, endBar - startBar, startBar));

   // Créer le pattern
   pattern.type = PATTERN_DOUBLE_TOP;
   pattern.peak1 = highs[0];
   pattern.peak2 = highs[1];
   pattern.necklinePrice = neckline;
   pattern.targetPrice = neckline - (highs[0] - neckline); // Projection
   pattern.isBullish = false; // Signal baissier
   pattern.startTime = iTime(m_symbol, m_timeframe, endBar);
   pattern.endTime = iTime(m_symbol, m_timeframe, startBar);
   pattern.reliability = 75.0;

   // Vérifier le status
   double currentClose = iClose(m_symbol, m_timeframe, 1);
   if(currentClose < neckline)
   {
      pattern.status = STATUS_NECKLINE_BREAK;
   }
   else
   {
      pattern.status = STATUS_COMPLETE;
   }

   return true;
}

//+------------------------------------------------------------------+
//| RÈGLE: Double Bottom                                              |
//| → Alerte UNIQUEMENT à la cassure de la Neckline                  |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectDoubleBottom(SChartPattern &pattern)
{
   // Trouver les 2 creux les plus récents
   double lows[];
   int lowBars[];
   ArrayResize(lows, 0);
   ArrayResize(lowBars, 0);

   // Scanner les swing lows
   for(int i = 3; i < m_lookback - 3; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);

      // Vérifier si c'est un swing low local
      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i - 2) &&
         low < iLow(m_symbol, m_timeframe, i + 1) &&
         low < iLow(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(lows);
         ArrayResize(lows, size + 1);
         ArrayResize(lowBars, size + 1);
         lows[size] = low;
         lowBars[size] = i;

         if(ArraySize(lows) >= 2) break;
      }
   }

   if(ArraySize(lows) < 2) return false;

   // Vérifier si les deux creux sont au même niveau (Double Bottom)
   if(!ArePricesEqual(lows[0], lows[1])) return false;

   // Trouver la neckline (sommet entre les deux creux)
   int startBar = MathMin(lowBars[0], lowBars[1]);
   int endBar = MathMax(lowBars[0], lowBars[1]);

   double neckline = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, endBar - startBar, startBar));

   // Créer le pattern
   pattern.type = PATTERN_DOUBLE_BOTTOM;
   pattern.trough1 = lows[0];
   pattern.trough2 = lows[1];
   pattern.necklinePrice = neckline;
   pattern.targetPrice = neckline + (neckline - lows[0]); // Projection
   pattern.isBullish = true; // Signal haussier
   pattern.startTime = iTime(m_symbol, m_timeframe, endBar);
   pattern.endTime = iTime(m_symbol, m_timeframe, startBar);
   pattern.reliability = 75.0;

   // Vérifier le status
   double currentClose = iClose(m_symbol, m_timeframe, 1);
   if(currentClose > neckline)
   {
      pattern.status = STATUS_NECKLINE_BREAK;
   }
   else
   {
      pattern.status = STATUS_COMPLETE;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier la cassure de la neckline                                |
//+------------------------------------------------------------------+
bool CChartPatterns::IsNecklineBreak(SChartPattern &pattern)
{
   double currentClose = iClose(m_symbol, m_timeframe, 1);

   if(pattern.type == PATTERN_DOUBLE_TOP)
   {
      return (currentClose < pattern.necklinePrice);
   }
   else if(pattern.type == PATTERN_DOUBLE_BOTTOM)
   {
      return (currentClose > pattern.necklinePrice);
   }

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Patterns de continuation - Triangle                        |
//| → Alerte "Compression – Mouvement imminent"                      |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectTriangle(SChartPattern &pattern)
{
   // Collecter les highs et lows récents
   double highs[], lows[];
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   int minPoints = 4; // Minimum 2 highs et 2 lows

   // Scanner les points pivots
   for(int i = 2; i < m_lookback - 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);

      // Swing High
      if(high >= iHigh(m_symbol, m_timeframe, i - 1) &&
         high >= iHigh(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(highs);
         ArrayResize(highs, size + 1);
         highs[size] = high;
      }

      // Swing Low
      if(low <= iLow(m_symbol, m_timeframe, i - 1) &&
         low <= iLow(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(lows);
         ArrayResize(lows, size + 1);
         lows[size] = low;
      }

      if(ArraySize(highs) >= minPoints && ArraySize(lows) >= minPoints)
         break;
   }

   if(ArraySize(highs) < 2 || ArraySize(lows) < 2) return false;

   // Analyser les tendances
   bool highsDescending = (highs[0] < highs[ArraySize(highs) - 1]); // LH
   bool highsAscending = (highs[0] > highs[ArraySize(highs) - 1]);  // HH
   bool lowsAscending = (lows[0] > lows[ArraySize(lows) - 1]);      // HL
   bool lowsDescending = (lows[0] < lows[ArraySize(lows) - 1]);     // LL

   // Triangle Ascendant: highs plats, lows ascendants
   if(ArePricesEqual(highs[0], highs[ArraySize(highs) - 1]) && lowsAscending)
   {
      pattern.type = PATTERN_TRIANGLE_ASCENDING;
      pattern.isBullish = true;
      pattern.reliability = 70.0;
   }
   // Triangle Descendant: lows plats, highs descendants
   else if(ArePricesEqual(lows[0], lows[ArraySize(lows) - 1]) && highsDescending)
   {
      pattern.type = PATTERN_TRIANGLE_DESCENDING;
      pattern.isBullish = false;
      pattern.reliability = 70.0;
   }
   // Triangle Symétrique: highs descendants ET lows ascendants
   else if(highsDescending && lowsAscending)
   {
      pattern.type = PATTERN_TRIANGLE_SYMMETRIC;
      pattern.isBullish = true; // Généralement continuation
      pattern.reliability = 65.0;
   }
   else
   {
      return false;
   }

   pattern.status = STATUS_FORMING;
   pattern.peak1 = highs[ArraySize(highs) - 1];
   pattern.peak2 = highs[0];
   pattern.trough1 = lows[ArraySize(lows) - 1];
   pattern.trough2 = lows[0];
   pattern.necklinePrice = (pattern.peak2 + pattern.trough2) / 2.0;
   pattern.targetPrice = pattern.isBullish ?
                         pattern.peak1 + (pattern.peak1 - pattern.trough1) :
                         pattern.trough1 - (pattern.peak1 - pattern.trough1);

   return true;
}

//+------------------------------------------------------------------+
//| RÈGLE: Patterns de continuation - Drapeau                         |
//| → Alerte "Compression – Mouvement imminent"                      |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectFlag(SChartPattern &pattern)
{
   // Chercher une impulsion forte suivie d'une consolidation

   // 1. Trouver l'impulsion (mouvement fort)
   int impulseStart = 0;
   int impulseEnd = 0;
   double impulseMove = 0;
   bool isBullishImpulse = false;

   // Scanner pour une impulsion récente
   for(int i = 5; i < m_lookback - 10; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double highPrev = iHigh(m_symbol, m_timeframe, i + 5);
      double lowPrev = iLow(m_symbol, m_timeframe, i + 5);

      double upMove = high - lowPrev;
      double downMove = highPrev - low;

      double avgRange = 0;
      for(int j = i; j < i + 10; j++)
      {
         avgRange += (iHigh(m_symbol, m_timeframe, j) - iLow(m_symbol, m_timeframe, j));
      }
      avgRange /= 10;

      // Impulsion haussière: mouvement de plus de 3x le range moyen
      if(upMove > avgRange * 3)
      {
         impulseStart = i + 5;
         impulseEnd = i;
         impulseMove = upMove;
         isBullishImpulse = true;
         break;
      }
      // Impulsion baissière
      else if(downMove > avgRange * 3)
      {
         impulseStart = i + 5;
         impulseEnd = i;
         impulseMove = downMove;
         isBullishImpulse = false;
         break;
      }
   }

   if(impulseMove == 0) return false;

   // 2. Vérifier la consolidation après l'impulsion (le drapeau)
   double consolidationHigh = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, impulseEnd, 1));
   double consolidationLow = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, impulseEnd, 1));
   double consolidationRange = consolidationHigh - consolidationLow;

   // Le drapeau doit être plus petit que l'impulsion (moins de 50%)
   if(consolidationRange > impulseMove * 0.5) return false;

   // Créer le pattern
   if(isBullishImpulse)
   {
      pattern.type = PATTERN_FLAG_BULLISH;
      pattern.isBullish = true;
   }
   else
   {
      pattern.type = PATTERN_FLAG_BEARISH;
      pattern.isBullish = false;
   }

   pattern.status = STATUS_FORMING;
   pattern.peak1 = consolidationHigh;
   pattern.trough1 = consolidationLow;
   pattern.necklinePrice = isBullishImpulse ? consolidationHigh : consolidationLow;
   pattern.targetPrice = isBullishImpulse ?
                         consolidationHigh + impulseMove :
                         consolidationLow - impulseMove;
   pattern.reliability = 72.0;
   pattern.startTime = iTime(m_symbol, m_timeframe, impulseStart);
   pattern.endTime = iTime(m_symbol, m_timeframe, 1);

   return true;
}

//+------------------------------------------------------------------+
//| Détecter Épaule-Tête-Épaule                                       |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectHeadShoulders(SChartPattern &pattern)
{
   // Trouver 3 sommets
   double peaks[];
   int peakBars[];
   ArrayResize(peaks, 0);
   ArrayResize(peakBars, 0);

   for(int i = 3; i < m_lookback - 3; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);

      if(high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i - 2) &&
         high > iHigh(m_symbol, m_timeframe, i + 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(peaks);
         ArrayResize(peaks, size + 1);
         ArrayResize(peakBars, size + 1);
         peaks[size] = high;
         peakBars[size] = i;

         if(ArraySize(peaks) >= 3) break;
      }
   }

   if(ArraySize(peaks) < 3) return false;

   // Vérifier la structure: épaule gauche, tête (plus haute), épaule droite
   // peaks[0] = épaule droite (plus récent)
   // peaks[1] = tête
   // peaks[2] = épaule gauche

   // La tête doit être plus haute que les deux épaules
   if(peaks[1] <= peaks[0] || peaks[1] <= peaks[2]) return false;

   // Les épaules doivent être approximativement au même niveau
   if(!ArePricesEqual(peaks[0], peaks[2])) return false;

   // Trouver la neckline (ligne reliant les creux)
   int bar1 = (peakBars[0] + peakBars[1]) / 2;
   int bar2 = (peakBars[1] + peakBars[2]) / 2;

   double neckline1 = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, peakBars[1] - peakBars[0], peakBars[0]));
   double neckline2 = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, peakBars[2] - peakBars[1], peakBars[1]));
   double neckline = (neckline1 + neckline2) / 2.0;

   pattern.type = PATTERN_HEAD_SHOULDERS;
   pattern.peak1 = peaks[2];  // Épaule gauche
   pattern.peak2 = peaks[0];  // Épaule droite
   pattern.trough1 = peaks[1]; // Tête
   pattern.necklinePrice = neckline;
   pattern.targetPrice = neckline - (peaks[1] - neckline);
   pattern.isBullish = false;
   pattern.reliability = 80.0;

   double currentClose = iClose(m_symbol, m_timeframe, 1);
   pattern.status = (currentClose < neckline) ? STATUS_NECKLINE_BREAK : STATUS_COMPLETE;

   return true;
}

//+------------------------------------------------------------------+
//| Détecter Épaule-Tête-Épaule Inversé                               |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectInvHeadShoulders(SChartPattern &pattern)
{
   // Trouver 3 creux
   double troughs[];
   int troughBars[];
   ArrayResize(troughs, 0);
   ArrayResize(troughBars, 0);

   for(int i = 3; i < m_lookback - 3; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);

      if(low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i - 2) &&
         low < iLow(m_symbol, m_timeframe, i + 1) &&
         low < iLow(m_symbol, m_timeframe, i + 2))
      {
         int size = ArraySize(troughs);
         ArrayResize(troughs, size + 1);
         ArrayResize(troughBars, size + 1);
         troughs[size] = low;
         troughBars[size] = i;

         if(ArraySize(troughs) >= 3) break;
      }
   }

   if(ArraySize(troughs) < 3) return false;

   // La tête doit être plus basse que les deux épaules
   if(troughs[1] >= troughs[0] || troughs[1] >= troughs[2]) return false;

   // Les épaules doivent être approximativement au même niveau
   if(!ArePricesEqual(troughs[0], troughs[2])) return false;

   // Trouver la neckline
   double neckline1 = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, troughBars[1] - troughBars[0], troughBars[0]));
   double neckline2 = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, troughBars[2] - troughBars[1], troughBars[1]));
   double neckline = (neckline1 + neckline2) / 2.0;

   pattern.type = PATTERN_INV_HEAD_SHOULDERS;
   pattern.trough1 = troughs[2];  // Épaule gauche
   pattern.trough2 = troughs[0];  // Épaule droite
   pattern.peak1 = troughs[1];    // Tête
   pattern.necklinePrice = neckline;
   pattern.targetPrice = neckline + (neckline - troughs[1]);
   pattern.isBullish = true;
   pattern.reliability = 80.0;

   double currentClose = iClose(m_symbol, m_timeframe, 1);
   pattern.status = (currentClose > neckline) ? STATUS_NECKLINE_BREAK : STATUS_COMPLETE;

   return true;
}

//+------------------------------------------------------------------+
//| Détecter Wedge (Rising/Falling)                                   |
//+------------------------------------------------------------------+
bool CChartPatterns::DetectWedge(SChartPattern &pattern)
{
   // Collecter les highs et lows
   double highs[], lows[];
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   for(int i = 2; i < m_lookback / 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);

      // Swing High
      if(high >= iHigh(m_symbol, m_timeframe, i - 1) &&
         high >= iHigh(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(highs);
         ArrayResize(highs, size + 1);
         highs[size] = high;
      }

      // Swing Low
      if(low <= iLow(m_symbol, m_timeframe, i - 1) &&
         low <= iLow(m_symbol, m_timeframe, i + 1))
      {
         int size = ArraySize(lows);
         ArrayResize(lows, size + 1);
         lows[size] = low;
      }
   }

   if(ArraySize(highs) < 2 || ArraySize(lows) < 2) return false;

   // Analyser les pentes
   bool highsRising = (highs[0] > highs[ArraySize(highs) - 1]);
   bool lowsRising = (lows[0] > lows[ArraySize(lows) - 1]);
   bool highsFalling = (highs[0] < highs[ArraySize(highs) - 1]);
   bool lowsFalling = (lows[0] < lows[ArraySize(lows) - 1]);

   // Rising Wedge: les deux lignes montent mais convergent (baissier)
   if(highsRising && lowsRising)
   {
      // Vérifier la convergence
      double highSlope = highs[0] - highs[ArraySize(highs) - 1];
      double lowSlope = lows[0] - lows[ArraySize(lows) - 1];

      if(lowSlope > highSlope) // Les lows montent plus vite = convergence
      {
         pattern.type = PATTERN_WEDGE_RISING;
         pattern.isBullish = false; // Signal baissier
         pattern.reliability = 68.0;
         pattern.status = STATUS_FORMING;
         return true;
      }
   }
   // Falling Wedge: les deux lignes descendent mais convergent (haussier)
   else if(highsFalling && lowsFalling)
   {
      double highSlope = MathAbs(highs[0] - highs[ArraySize(highs) - 1]);
      double lowSlope = MathAbs(lows[0] - lows[ArraySize(lows) - 1]);

      if(highSlope > lowSlope) // Les highs descendent plus vite = convergence
      {
         pattern.type = PATTERN_WEDGE_FALLING;
         pattern.isBullish = true; // Signal haussier
         pattern.reliability = 68.0;
         pattern.status = STATUS_FORMING;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la cassure d'un pattern                                  |
//+------------------------------------------------------------------+
bool CChartPatterns::CheckBreakout(SChartPattern &pattern, int shift = 1)
{
   double close = iClose(m_symbol, m_timeframe, shift);

   switch(pattern.type)
   {
      case PATTERN_DOUBLE_TOP:
      case PATTERN_HEAD_SHOULDERS:
      case PATTERN_WEDGE_RISING:
         return (close < pattern.necklinePrice);

      case PATTERN_DOUBLE_BOTTOM:
      case PATTERN_INV_HEAD_SHOULDERS:
      case PATTERN_WEDGE_FALLING:
         return (close > pattern.necklinePrice);

      case PATTERN_TRIANGLE_ASCENDING:
      case PATTERN_FLAG_BULLISH:
         return (close > pattern.peak2);

      case PATTERN_TRIANGLE_DESCENDING:
      case PATTERN_FLAG_BEARISH:
         return (close < pattern.trough2);

      case PATTERN_TRIANGLE_SYMMETRIC:
         return (close > pattern.peak2 || close < pattern.trough2);

      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Calculer l'objectif du pattern                                    |
//+------------------------------------------------------------------+
double CChartPatterns::CalculateTarget(SChartPattern &pattern)
{
   return pattern.targetPrice;
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
int CChartPatterns::GetPatternCount()
{
   return ArraySize(m_detectedPatterns);
}

SChartPattern CChartPatterns::GetPattern(int index)
{
   SChartPattern empty;
   empty.type = PATTERN_NONE;
   empty.status = STATUS_FORMING;
   empty.necklinePrice = 0;
   empty.targetPrice = 0;
   empty.peak1 = 0;
   empty.peak2 = 0;
   empty.trough1 = 0;
   empty.trough2 = 0;
   empty.startTime = 0;
   empty.endTime = 0;
   empty.isBullish = false;
   empty.reliability = 0;
   if(index < 0 || index >= ArraySize(m_detectedPatterns))
      return empty;
   return m_detectedPatterns[index];
}

SChartPattern CChartPatterns::GetLastPattern()
{
   if(ArraySize(m_detectedPatterns) == 0)
   {
      SChartPattern empty;
      empty.type = PATTERN_NONE;
      empty.status = STATUS_FORMING;
      empty.necklinePrice = 0;
      empty.targetPrice = 0;
      empty.peak1 = 0;
      empty.peak2 = 0;
      empty.trough1 = 0;
      empty.trough2 = 0;
      empty.startTime = 0;
      empty.endTime = 0;
      empty.isBullish = false;
      empty.reliability = 0;
      return empty;
   }
   return m_detectedPatterns[ArraySize(m_detectedPatterns) - 1];
}

bool CChartPatterns::HasActivePattern()
{
   return (ArraySize(m_detectedPatterns) > 0);
}

//+------------------------------------------------------------------+
//| Convertir le type en string                                       |
//+------------------------------------------------------------------+
string CChartPatterns::PatternTypeToString(ENUM_CHART_PATTERN type)
{
   switch(type)
   {
      case PATTERN_NONE:               return "Aucun";
      case PATTERN_DOUBLE_TOP:         return "Double Top";
      case PATTERN_DOUBLE_BOTTOM:      return "Double Bottom";
      case PATTERN_TRIANGLE_ASCENDING: return "Triangle Ascendant";
      case PATTERN_TRIANGLE_DESCENDING:return "Triangle Descendant";
      case PATTERN_TRIANGLE_SYMMETRIC: return "Triangle Symétrique";
      case PATTERN_FLAG_BULLISH:       return "Drapeau Haussier";
      case PATTERN_FLAG_BEARISH:       return "Drapeau Baissier";
      case PATTERN_HEAD_SHOULDERS:     return "Épaule-Tête-Épaule";
      case PATTERN_INV_HEAD_SHOULDERS: return "ETE Inversé";
      case PATTERN_WEDGE_RISING:       return "Wedge Montant";
      case PATTERN_WEDGE_FALLING:      return "Wedge Descendant";
      default:                         return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir le status en string                                     |
//+------------------------------------------------------------------+
string CChartPatterns::PatternStatusToString(ENUM_PATTERN_STATUS status)
{
   switch(status)
   {
      case STATUS_FORMING:       return "En formation";
      case STATUS_COMPLETE:      return "Complet";
      case STATUS_NECKLINE_BREAK:return "Cassure Neckline";
      case STATUS_CONFIRMED:     return "Confirmé";
      default:                   return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Générer une alerte pour le pattern                                |
//+------------------------------------------------------------------+
string CChartPatterns::GetPatternAlert(SChartPattern &pattern)
{
   string alert = "";

   switch(pattern.type)
   {
      case PATTERN_DOUBLE_TOP:
      case PATTERN_DOUBLE_BOTTOM:
         // RÈGLE: Alerte UNIQUEMENT à la cassure de la Neckline
         if(pattern.status == STATUS_NECKLINE_BREAK)
         {
            alert = "📊 ALERTE: " + PatternTypeToString(pattern.type) +
                    " - CASSURE NECKLINE @ " + DoubleToString(pattern.necklinePrice, 5) +
                    " | Objectif: " + DoubleToString(pattern.targetPrice, 5);
         }
         break;

      case PATTERN_TRIANGLE_ASCENDING:
      case PATTERN_TRIANGLE_DESCENDING:
      case PATTERN_TRIANGLE_SYMMETRIC:
      case PATTERN_FLAG_BULLISH:
      case PATTERN_FLAG_BEARISH:
         // RÈGLE: Alerte "Compression – Mouvement imminent"
         alert = "📊 ALERTE: " + PatternTypeToString(pattern.type) +
                 " - Compression – Mouvement imminent" +
                 " | Direction: " + (pattern.isBullish ? "HAUSSIER" : "BAISSIER");
         break;

      case PATTERN_HEAD_SHOULDERS:
      case PATTERN_INV_HEAD_SHOULDERS:
         if(pattern.status == STATUS_NECKLINE_BREAK)
         {
            alert = "📊 ALERTE: " + PatternTypeToString(pattern.type) +
                    " - CASSURE NECKLINE @ " + DoubleToString(pattern.necklinePrice, 5) +
                    " | Objectif: " + DoubleToString(pattern.targetPrice, 5);
         }
         break;

      default:
         break;
   }

   return alert;
}
//+------------------------------------------------------------------+
