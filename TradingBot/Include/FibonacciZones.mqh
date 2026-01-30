//+------------------------------------------------------------------+
//|                                             FibonacciZones.mqh  |
//|                            CHAPITRE 6 - FIBONACCI               |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Niveaux Fibonacci standard                                       |
//+------------------------------------------------------------------+
#define FIB_0      0.0
#define FIB_236    0.236
#define FIB_382    0.382
#define FIB_50     0.5
#define FIB_618    0.618     // Golden Ratio
#define FIB_786    0.786
#define FIB_100    1.0
#define FIB_1272   1.272     // Extension TP
#define FIB_1618   1.618     // Extension TP

//+------------------------------------------------------------------+
//| Structure d'une impulsion pour Fibonacci                         |
//+------------------------------------------------------------------+
struct SImpulse
{
   double      startPrice;     // Prix de départ
   double      endPrice;       // Prix de fin
   datetime    startTime;
   datetime    endTime;
   bool        isBullish;      // Impulsion haussière
   double      range;          // Amplitude de l'impulsion
};

//+------------------------------------------------------------------+
//| Structure des niveaux Fibonacci                                  |
//+------------------------------------------------------------------+
struct SFibLevels
{
   double      fib0;           // 0%
   double      fib236;         // 23.6%
   double      fib382;         // 38.2%
   double      fib50;          // 50%
   double      fib618;         // 61.8%
   double      fib786;         // 78.6%
   double      fib100;         // 100%
   double      ext1272;        // 127.2% Extension
   double      ext1618;        // 161.8% Extension
   double      goldenZoneHigh; // Haut de la Golden Zone (61.8%)
   double      goldenZoneLow;  // Bas de la Golden Zone (50%)
};

//+------------------------------------------------------------------+
//| Classe d'analyse Fibonacci                                        |
//+------------------------------------------------------------------+
class CFibonacciZones
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   SImpulse          m_lastImpulse;
   SFibLevels        m_levels;

   // Méthodes privées
   bool              FindLastImpulse();
   void              CalculateLevels();

public:
   CFibonacciZones();
   ~CFibonacciZones();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetLookback(int lookback);

   // Analyse
   bool              Analyze();

   // RÈGLE: Tracer Fibonacci sur la dernière impulsion valide
   SImpulse          GetLastImpulse();
   SFibLevels        GetFibLevels();

   // RÈGLE: Zone clé = 50% – 61.8% (Golden Zone)
   bool              IsPriceInGoldenZone(double price);
   double            GetGoldenZoneHigh();
   double            GetGoldenZoneLow();

   // RÈGLE: CONFLUENCE OBLIGATOIRE
   // Fibonacci + Support/Résistance OU Fibonacci + EMA 50/200
   bool              HasConfluenceWithSR(double srLevel);
   bool              HasConfluenceWithEMA(double emaValue);
   bool              HasValidConfluence(double srLevel, double ema50, double ema200);

   // RÈGLE: Extensions TP
   // TP1: 127.2%, TP2: 161.8%
   double            GetTP1();  // 127.2%
   double            GetTP2();  // 161.8%

   // Vérifications de niveau
   bool              IsPriceAtFibLevel(double price, double &fibLevel, string &fibName);
   double            GetNearestFibLevel(double price);

   // Utilitaires
   string            FibLevelToString(double fibRatio);
   string            GetFibAlert(double currentPrice);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CFibonacciZones::CFibonacciZones()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookback = 100;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CFibonacciZones::~CFibonacciZones()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CFibonacciZones::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration du lookback                                         |
//+------------------------------------------------------------------+
void CFibonacciZones::SetLookback(int lookback)
{
   m_lookback = lookback;
}

//+------------------------------------------------------------------+
//| RÈGLE: Trouver la dernière impulsion valide                      |
//+------------------------------------------------------------------+
bool CFibonacciZones::FindLastImpulse()
{
   // Trouver le swing high et swing low les plus récents
   int highestBar = iHighest(m_symbol, m_timeframe, MODE_HIGH, m_lookback, 1);
   int lowestBar = iLowest(m_symbol, m_timeframe, MODE_LOW, m_lookback, 1);

   double highestHigh = iHigh(m_symbol, m_timeframe, highestBar);
   double lowestLow = iLow(m_symbol, m_timeframe, lowestBar);

   // Déterminer la direction de l'impulsion
   // Si le high est plus récent que le low = impulsion haussière
   // Si le low est plus récent que le high = impulsion baissière

   if(highestBar < lowestBar)
   {
      // Impulsion haussière (le high est plus récent)
      m_lastImpulse.startPrice = lowestLow;
      m_lastImpulse.endPrice = highestHigh;
      m_lastImpulse.startTime = iTime(m_symbol, m_timeframe, lowestBar);
      m_lastImpulse.endTime = iTime(m_symbol, m_timeframe, highestBar);
      m_lastImpulse.isBullish = true;
   }
   else
   {
      // Impulsion baissière (le low est plus récent)
      m_lastImpulse.startPrice = highestHigh;
      m_lastImpulse.endPrice = lowestLow;
      m_lastImpulse.startTime = iTime(m_symbol, m_timeframe, highestBar);
      m_lastImpulse.endTime = iTime(m_symbol, m_timeframe, lowestBar);
      m_lastImpulse.isBullish = false;
   }

   m_lastImpulse.range = MathAbs(m_lastImpulse.endPrice - m_lastImpulse.startPrice);

   // Valider l'impulsion (doit être significative)
   double atr = 0;
   int atrHandle = iATR(m_symbol, m_timeframe, 14);
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
      atr = atrBuffer[0];
      IndicatorRelease(atrHandle);
   }

   // L'impulsion doit être d'au moins 2x l'ATR pour être valide
   if(m_lastImpulse.range < atr * 2)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculer les niveaux Fibonacci                                    |
//+------------------------------------------------------------------+
void CFibonacciZones::CalculateLevels()
{
   double start = m_lastImpulse.startPrice;
   double end = m_lastImpulse.endPrice;
   double range = m_lastImpulse.range;

   if(m_lastImpulse.isBullish)
   {
      // Retracement sur impulsion haussière (niveaux en dessous)
      m_levels.fib0 = end;                        // 0% = sommet
      m_levels.fib236 = end - range * FIB_236;
      m_levels.fib382 = end - range * FIB_382;
      m_levels.fib50 = end - range * FIB_50;
      m_levels.fib618 = end - range * FIB_618;
      m_levels.fib786 = end - range * FIB_786;
      m_levels.fib100 = start;                    // 100% = base

      // Extensions au-dessus
      m_levels.ext1272 = end + range * (FIB_1272 - 1.0);
      m_levels.ext1618 = end + range * (FIB_1618 - 1.0);

      // Golden Zone
      m_levels.goldenZoneHigh = m_levels.fib50;
      m_levels.goldenZoneLow = m_levels.fib618;
   }
   else
   {
      // Retracement sur impulsion baissière (niveaux au-dessus)
      m_levels.fib0 = end;                        // 0% = creux
      m_levels.fib236 = end + range * FIB_236;
      m_levels.fib382 = end + range * FIB_382;
      m_levels.fib50 = end + range * FIB_50;
      m_levels.fib618 = end + range * FIB_618;
      m_levels.fib786 = end + range * FIB_786;
      m_levels.fib100 = start;                    // 100% = sommet

      // Extensions en dessous
      m_levels.ext1272 = end - range * (FIB_1272 - 1.0);
      m_levels.ext1618 = end - range * (FIB_1618 - 1.0);

      // Golden Zone
      m_levels.goldenZoneLow = m_levels.fib50;
      m_levels.goldenZoneHigh = m_levels.fib618;
   }
}

//+------------------------------------------------------------------+
//| Analyser et calculer les niveaux                                  |
//+------------------------------------------------------------------+
bool CFibonacciZones::Analyze()
{
   if(!FindLastImpulse())
      return false;

   CalculateLevels();
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir la dernière impulsion                                     |
//+------------------------------------------------------------------+
SImpulse CFibonacciZones::GetLastImpulse()
{
   return m_lastImpulse;
}

//+------------------------------------------------------------------+
//| Obtenir les niveaux Fibonacci                                     |
//+------------------------------------------------------------------+
SFibLevels CFibonacciZones::GetFibLevels()
{
   return m_levels;
}

//+------------------------------------------------------------------+
//| RÈGLE: Vérifier si le prix est dans la Golden Zone (50%-61.8%)   |
//+------------------------------------------------------------------+
bool CFibonacciZones::IsPriceInGoldenZone(double price)
{
   if(m_lastImpulse.isBullish)
   {
      return (price <= m_levels.goldenZoneHigh && price >= m_levels.goldenZoneLow);
   }
   else
   {
      return (price >= m_levels.goldenZoneLow && price <= m_levels.goldenZoneHigh);
   }
}

//+------------------------------------------------------------------+
//| Obtenir le haut de la Golden Zone                                 |
//+------------------------------------------------------------------+
double CFibonacciZones::GetGoldenZoneHigh()
{
   return m_levels.goldenZoneHigh;
}

//+------------------------------------------------------------------+
//| Obtenir le bas de la Golden Zone                                  |
//+------------------------------------------------------------------+
double CFibonacciZones::GetGoldenZoneLow()
{
   return m_levels.goldenZoneLow;
}

//+------------------------------------------------------------------+
//| RÈGLE: Confluence avec Support/Résistance                         |
//+------------------------------------------------------------------+
bool CFibonacciZones::HasConfluenceWithSR(double srLevel)
{
   double tolerance = m_lastImpulse.range * 0.02; // 2% de tolérance

   // Vérifier la confluence avec chaque niveau Fibonacci
   if(MathAbs(srLevel - m_levels.fib382) <= tolerance) return true;
   if(MathAbs(srLevel - m_levels.fib50) <= tolerance) return true;
   if(MathAbs(srLevel - m_levels.fib618) <= tolerance) return true;
   if(MathAbs(srLevel - m_levels.fib786) <= tolerance) return true;

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Confluence avec EMA 50 ou EMA 200                          |
//+------------------------------------------------------------------+
bool CFibonacciZones::HasConfluenceWithEMA(double emaValue)
{
   double tolerance = m_lastImpulse.range * 0.02; // 2% de tolérance

   // Vérifier la confluence avec chaque niveau Fibonacci
   if(MathAbs(emaValue - m_levels.fib382) <= tolerance) return true;
   if(MathAbs(emaValue - m_levels.fib50) <= tolerance) return true;
   if(MathAbs(emaValue - m_levels.fib618) <= tolerance) return true;
   if(MathAbs(emaValue - m_levels.fib786) <= tolerance) return true;

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Vérifier la confluence obligatoire                         |
//| Fibonacci + S/R OU Fibonacci + EMA 50/200                         |
//+------------------------------------------------------------------+
bool CFibonacciZones::HasValidConfluence(double srLevel, double ema50, double ema200)
{
   // Confluence avec S/R
   if(HasConfluenceWithSR(srLevel))
      return true;

   // Confluence avec EMA 50
   if(HasConfluenceWithEMA(ema50))
      return true;

   // Confluence avec EMA 200
   if(HasConfluenceWithEMA(ema200))
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Extension TP1 = 127.2%                                     |
//+------------------------------------------------------------------+
double CFibonacciZones::GetTP1()
{
   return m_levels.ext1272;
}

//+------------------------------------------------------------------+
//| RÈGLE: Extension TP2 = 161.8%                                     |
//+------------------------------------------------------------------+
double CFibonacciZones::GetTP2()
{
   return m_levels.ext1618;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est sur un niveau Fibonacci                   |
//+------------------------------------------------------------------+
bool CFibonacciZones::IsPriceAtFibLevel(double price, double &fibLevel, string &fibName)
{
   double tolerance = m_lastImpulse.range * 0.01; // 1% de tolérance

   if(MathAbs(price - m_levels.fib236) <= tolerance)
   {
      fibLevel = FIB_236;
      fibName = "23.6%";
      return true;
   }
   if(MathAbs(price - m_levels.fib382) <= tolerance)
   {
      fibLevel = FIB_382;
      fibName = "38.2%";
      return true;
   }
   if(MathAbs(price - m_levels.fib50) <= tolerance)
   {
      fibLevel = FIB_50;
      fibName = "50%";
      return true;
   }
   if(MathAbs(price - m_levels.fib618) <= tolerance)
   {
      fibLevel = FIB_618;
      fibName = "61.8%";
      return true;
   }
   if(MathAbs(price - m_levels.fib786) <= tolerance)
   {
      fibLevel = FIB_786;
      fibName = "78.6%";
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le niveau Fibonacci le plus proche                        |
//+------------------------------------------------------------------+
double CFibonacciZones::GetNearestFibLevel(double price)
{
   double levels[] = {m_levels.fib236, m_levels.fib382, m_levels.fib50,
                      m_levels.fib618, m_levels.fib786};

   double nearest = levels[0];
   double minDistance = MathAbs(price - levels[0]);

   for(int i = 1; i < ArraySize(levels); i++)
   {
      double distance = MathAbs(price - levels[i]);
      if(distance < minDistance)
      {
         minDistance = distance;
         nearest = levels[i];
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Convertir le ratio Fib en string                                  |
//+------------------------------------------------------------------+
string CFibonacciZones::FibLevelToString(double fibRatio)
{
   if(fibRatio == FIB_0)    return "0%";
   if(fibRatio == FIB_236)  return "23.6%";
   if(fibRatio == FIB_382)  return "38.2%";
   if(fibRatio == FIB_50)   return "50%";
   if(fibRatio == FIB_618)  return "61.8%";
   if(fibRatio == FIB_786)  return "78.6%";
   if(fibRatio == FIB_100)  return "100%";
   if(fibRatio == FIB_1272) return "127.2%";
   if(fibRatio == FIB_1618) return "161.8%";
   return DoubleToString(fibRatio * 100, 1) + "%";
}

//+------------------------------------------------------------------+
//| Générer une alerte Fibonacci                                      |
//+------------------------------------------------------------------+
string CFibonacciZones::GetFibAlert(double currentPrice)
{
   string alert = "";

   // Vérifier si dans la Golden Zone
   if(IsPriceInGoldenZone(currentPrice))
   {
      alert = "📐 ALERTE: Prix dans la GOLDEN ZONE (50%-61.8%)" +
              " | Zone: " + DoubleToString(m_levels.goldenZoneLow, 5) +
              " - " + DoubleToString(m_levels.goldenZoneHigh, 5);
      return alert;
   }

   // Vérifier si sur un niveau Fib
   double fibLevel;
   string fibName;
   if(IsPriceAtFibLevel(currentPrice, fibLevel, fibName))
   {
      alert = "📐 Prix au niveau Fibonacci " + fibName +
              " | TP1 (127.2%): " + DoubleToString(GetTP1(), 5) +
              " | TP2 (161.8%): " + DoubleToString(GetTP2(), 5);
   }

   return alert;
}
//+------------------------------------------------------------------+
