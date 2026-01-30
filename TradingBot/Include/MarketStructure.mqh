//+------------------------------------------------------------------+
//|                                            MarketStructure.mqh  |
//|                        CHAPITRE 3 - STRUCTURE & TENDANCE        |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération de la structure de marché                            |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STRUCTURE
{
   STRUCTURE_BULLISH = 1,    // Haussier: HH + HL
   STRUCTURE_BEARISH = -1,   // Baissier: LH + LL
   STRUCTURE_RANGING = 0     // Range / Consolidation
};

enum ENUM_TREND_STRENGTH
{
   TREND_WEAK = 0,           // < 25° - Tendance faible
   TREND_HEALTHY = 1,        // ≈ 45° - Tendance saine
   TREND_OVEREXTENDED = 2    // > 60° - Risque de correction violente
};

//+------------------------------------------------------------------+
//| Structure d'un point pivot (swing)                               |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   double      price;
   datetime    time;
   int         barIndex;
   bool        isHigh;       // true = swing high, false = swing low
};

//+------------------------------------------------------------------+
//| Structure d'une ligne de tendance                                |
//+------------------------------------------------------------------+
struct STrendLine
{
   SSwingPoint    point1;
   SSwingPoint    point2;
   SSwingPoint    point3;        // Point de confirmation (optionnel)
   double         angle;          // Angle en degrés
   bool           isConfirmed;    // 3 points = confirmé
   bool           isUptrend;      // true = trendline haussière
   ENUM_TREND_STRENGTH strength;
};

//+------------------------------------------------------------------+
//| Classe d'analyse de la structure de marché                        |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   SSwingPoint       m_swingHighs[];
   SSwingPoint       m_swingLows[];
   int               m_lookback;
   int               m_swingStrength;  // Nombre de barres pour confirmer un swing

   ENUM_MARKET_STRUCTURE m_currentStructure;
   STrendLine        m_uptrendLine;
   STrendLine        m_downtrendLine;

   // Méthodes privées
   void              DetectSwingPoints();
   double            CalculateTrendAngle(SSwingPoint &p1, SSwingPoint &p2);
   double            PriceToPixelRatio();

public:
   CMarketStructure();
   ~CMarketStructure();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int lookback, int swingStrength);

   // Analyse de la structure
   void              Analyze();
   ENUM_MARKET_STRUCTURE GetStructure();

   // RÈGLE: Haussier = Higher High + Higher Low
   bool              IsHigherHigh(int index = 0);
   bool              IsHigherLow(int index = 0);

   // RÈGLE: Baissier = Lower High + Lower Low
   bool              IsLowerHigh(int index = 0);
   bool              IsLowerLow(int index = 0);

   // Break of Structure (BOS) - pour Smart Money
   bool              IsBullishBOS(int shift);
   bool              IsBearishBOS(int shift);

   // Change of Character (CHoCH)
   bool              IsBullishCHoCH(int shift);
   bool              IsBearishCHoCH(int shift);

   // Lignes de tendance
   bool              DetectTrendLine(bool isUptrend);
   STrendLine        GetUptrendLine();
   STrendLine        GetDowntrendLine();

   // RÈGLE: Angle de tendance
   // ≈ 45° = Tendance saine
   // > 60° = Alerte "Risque de correction violente"
   // < 25° = Tendance faible
   ENUM_TREND_STRENGTH GetTrendStrength(double angle);
   string            GetTrendAlert(double angle);

   // Swing points
   int               GetSwingHighCount();
   int               GetSwingLowCount();
   SSwingPoint       GetSwingHigh(int index);
   SSwingPoint       GetSwingLow(int index);
   double            GetLastSwingHigh();
   double            GetLastSwingLow();

   // Utilitaires
   string            StructureToString(ENUM_MARKET_STRUCTURE structure);
   string            TrendStrengthToString(ENUM_TREND_STRENGTH strength);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lookback = 100;
   m_swingStrength = 3;
   m_currentStructure = STRUCTURE_RANGING;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure()
{
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CMarketStructure::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CMarketStructure::SetParameters(int lookback, int swingStrength)
{
   m_lookback = lookback;
   m_swingStrength = swingStrength;
}

//+------------------------------------------------------------------+
//| Détecter les points pivots (swing highs/lows)                    |
//+------------------------------------------------------------------+
void CMarketStructure::DetectSwingPoints()
{
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);
   ArrayResize(m_swingHighs, 0);
   ArrayResize(m_swingLows, 0);

   int barsToCheck = MathMin(m_lookback, iBars(m_symbol, m_timeframe) - m_swingStrength);

   for(int i = m_swingStrength; i < barsToCheck - m_swingStrength; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      bool isSwingHigh = true;
      bool isSwingLow = true;

      // Vérifier si c'est un swing high
      for(int j = 1; j <= m_swingStrength; j++)
      {
         if(high <= iHigh(m_symbol, m_timeframe, i + j) ||
            high <= iHigh(m_symbol, m_timeframe, i - j))
         {
            isSwingHigh = false;
            break;
         }
      }

      // Vérifier si c'est un swing low
      for(int j = 1; j <= m_swingStrength; j++)
      {
         if(low >= iLow(m_symbol, m_timeframe, i + j) ||
            low >= iLow(m_symbol, m_timeframe, i - j))
         {
            isSwingLow = false;
            break;
         }
      }

      // Ajouter le swing high
      if(isSwingHigh)
      {
         int size = ArraySize(m_swingHighs);
         ArrayResize(m_swingHighs, size + 1);
         m_swingHighs[size].price = high;
         m_swingHighs[size].time = iTime(m_symbol, m_timeframe, i);
         m_swingHighs[size].barIndex = i;
         m_swingHighs[size].isHigh = true;
      }

      // Ajouter le swing low
      if(isSwingLow)
      {
         int size = ArraySize(m_swingLows);
         ArrayResize(m_swingLows, size + 1);
         m_swingLows[size].price = low;
         m_swingLows[size].time = iTime(m_symbol, m_timeframe, i);
         m_swingLows[size].barIndex = i;
         m_swingLows[size].isHigh = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyser la structure de marché                                   |
//+------------------------------------------------------------------+
void CMarketStructure::Analyze()
{
   DetectSwingPoints();

   // Besoin d'au moins 2 swing highs et 2 swing lows
   if(ArraySize(m_swingHighs) < 2 || ArraySize(m_swingLows) < 2)
   {
      m_currentStructure = STRUCTURE_RANGING;
      return;
   }

   bool hasHigherHigh = IsHigherHigh(0);
   bool hasHigherLow = IsHigherLow(0);
   bool hasLowerHigh = IsLowerHigh(0);
   bool hasLowerLow = IsLowerLow(0);

   // RÈGLE: Structure Haussière = HH + HL
   if(hasHigherHigh && hasHigherLow)
   {
      m_currentStructure = STRUCTURE_BULLISH;
   }
   // RÈGLE: Structure Baissière = LH + LL
   else if(hasLowerHigh && hasLowerLow)
   {
      m_currentStructure = STRUCTURE_BEARISH;
   }
   else
   {
      m_currentStructure = STRUCTURE_RANGING;
   }

   // Détecter les lignes de tendance
   DetectTrendLine(true);   // Uptrend
   DetectTrendLine(false);  // Downtrend
}

//+------------------------------------------------------------------+
//| Obtenir la structure actuelle                                     |
//+------------------------------------------------------------------+
ENUM_MARKET_STRUCTURE CMarketStructure::GetStructure()
{
   return m_currentStructure;
}

//+------------------------------------------------------------------+
//| RÈGLE: Higher High - nouveau plus haut plus haut que le précédent|
//+------------------------------------------------------------------+
bool CMarketStructure::IsHigherHigh(int index)
{
   if(ArraySize(m_swingHighs) < 2) return false;
   if(index + 1 >= ArraySize(m_swingHighs)) return false;

   return (m_swingHighs[index].price > m_swingHighs[index + 1].price);
}

//+------------------------------------------------------------------+
//| RÈGLE: Higher Low - nouveau plus bas plus haut que le précédent  |
//+------------------------------------------------------------------+
bool CMarketStructure::IsHigherLow(int index)
{
   if(ArraySize(m_swingLows) < 2) return false;
   if(index + 1 >= ArraySize(m_swingLows)) return false;

   return (m_swingLows[index].price > m_swingLows[index + 1].price);
}

//+------------------------------------------------------------------+
//| RÈGLE: Lower High - nouveau plus haut plus bas que le précédent  |
//+------------------------------------------------------------------+
bool CMarketStructure::IsLowerHigh(int index)
{
   if(ArraySize(m_swingHighs) < 2) return false;
   if(index + 1 >= ArraySize(m_swingHighs)) return false;

   return (m_swingHighs[index].price < m_swingHighs[index + 1].price);
}

//+------------------------------------------------------------------+
//| RÈGLE: Lower Low - nouveau plus bas plus bas que le précédent    |
//+------------------------------------------------------------------+
bool CMarketStructure::IsLowerLow(int index)
{
   if(ArraySize(m_swingLows) < 2) return false;
   if(index + 1 >= ArraySize(m_swingLows)) return false;

   return (m_swingLows[index].price < m_swingLows[index + 1].price);
}

//+------------------------------------------------------------------+
//| Break of Structure (BOS) Haussier                                 |
//| Le prix casse le dernier swing high                               |
//+------------------------------------------------------------------+
bool CMarketStructure::IsBullishBOS(int shift)
{
   if(ArraySize(m_swingHighs) < 1) return false;

   double currentClose = iClose(m_symbol, m_timeframe, shift);
   double lastSwingHigh = m_swingHighs[0].price;

   return (currentClose > lastSwingHigh);
}

//+------------------------------------------------------------------+
//| Break of Structure (BOS) Baissier                                 |
//| Le prix casse le dernier swing low                                |
//+------------------------------------------------------------------+
bool CMarketStructure::IsBearishBOS(int shift)
{
   if(ArraySize(m_swingLows) < 1) return false;

   double currentClose = iClose(m_symbol, m_timeframe, shift);
   double lastSwingLow = m_swingLows[0].price;

   return (currentClose < lastSwingLow);
}

//+------------------------------------------------------------------+
//| Change of Character (CHoCH) Haussier                              |
//| Passage de structure baissière à haussière                        |
//+------------------------------------------------------------------+
bool CMarketStructure::IsBullishCHoCH(int shift)
{
   // CHoCH haussier: dans une tendance baissière, le prix casse un swing high
   if(m_currentStructure != STRUCTURE_BEARISH) return false;

   return IsBullishBOS(shift);
}

//+------------------------------------------------------------------+
//| Change of Character (CHoCH) Baissier                              |
//| Passage de structure haussière à baissière                        |
//+------------------------------------------------------------------+
bool CMarketStructure::IsBearishCHoCH(int shift)
{
   // CHoCH baissier: dans une tendance haussière, le prix casse un swing low
   if(m_currentStructure != STRUCTURE_BULLISH) return false;

   return IsBearishBOS(shift);
}

//+------------------------------------------------------------------+
//| Calculer le ratio prix/pixel pour l'angle                         |
//+------------------------------------------------------------------+
double CMarketStructure::PriceToPixelRatio()
{
   // Approximation basée sur les bougies visibles
   return 0.001; // À ajuster selon le timeframe
}

//+------------------------------------------------------------------+
//| Calculer l'angle d'une ligne de tendance                          |
//+------------------------------------------------------------------+
double CMarketStructure::CalculateTrendAngle(SSwingPoint &p1, SSwingPoint &p2)
{
   if(p1.barIndex == p2.barIndex) return 0;

   // Différence de prix
   double priceDiff = p2.price - p1.price;

   // Différence de barres
   int barDiff = MathAbs(p1.barIndex - p2.barIndex);

   // Normaliser pour avoir un angle cohérent
   // On utilise l'ATR pour normaliser le mouvement de prix
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

   if(atr == 0) atr = SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 100;

   // Calculer l'angle en utilisant l'ATR comme référence
   double normalizedPriceDiff = priceDiff / atr;
   double angle = MathArctan(normalizedPriceDiff / barDiff) * 180.0 / M_PI;

   return MathAbs(angle);
}

//+------------------------------------------------------------------+
//| Détecter une ligne de tendance                                    |
//| RÈGLE: Minimum 2 points, confirmation avec 3 points               |
//+------------------------------------------------------------------+
bool CMarketStructure::DetectTrendLine(bool isUptrend)
{
   SSwingPoint points[];

   if(isUptrend)
   {
      ArrayCopy(points, m_swingLows);
   }
   else
   {
      ArrayCopy(points, m_swingHighs);
   }

   if(ArraySize(points) < 2) return false;

   STrendLine trendLine;
   trendLine.point1 = points[1];  // Point plus ancien
   trendLine.point2 = points[0];  // Point plus récent
   trendLine.isUptrend = isUptrend;
   trendLine.isConfirmed = false;

   // Calculer l'angle
   trendLine.angle = CalculateTrendAngle(trendLine.point1, trendLine.point2);
   trendLine.strength = GetTrendStrength(trendLine.angle);

   // Chercher un 3ème point de confirmation
   if(ArraySize(points) >= 3)
   {
      // Vérifier si le 3ème point est aligné (avec tolérance)
      double tolerance = SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 50;

      // Calculer la ligne entre point1 et point2
      double slope = (trendLine.point2.price - trendLine.point1.price) /
                     (trendLine.point1.barIndex - trendLine.point2.barIndex);

      double expectedPrice = trendLine.point2.price +
                             slope * (trendLine.point2.barIndex - points[2].barIndex);

      if(MathAbs(points[2].price - expectedPrice) <= tolerance)
      {
         trendLine.point3 = points[2];
         trendLine.isConfirmed = true;  // RÈGLE: 3 points = confirmation
      }
   }

   if(isUptrend)
   {
      m_uptrendLine = trendLine;
   }
   else
   {
      m_downtrendLine = trendLine;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Obtenir la ligne de tendance haussière                            |
//+------------------------------------------------------------------+
STrendLine CMarketStructure::GetUptrendLine()
{
   return m_uptrendLine;
}

//+------------------------------------------------------------------+
//| Obtenir la ligne de tendance baissière                            |
//+------------------------------------------------------------------+
STrendLine CMarketStructure::GetDowntrendLine()
{
   return m_downtrendLine;
}

//+------------------------------------------------------------------+
//| RÈGLE: Évaluer la force de la tendance selon l'angle              |
//| ≈ 45° = Tendance saine                                            |
//| > 60° = Risque de correction violente                             |
//| < 25° = Tendance faible                                           |
//+------------------------------------------------------------------+
ENUM_TREND_STRENGTH CMarketStructure::GetTrendStrength(double angle)
{
   if(angle > 60.0)
      return TREND_OVEREXTENDED;
   else if(angle >= 25.0 && angle <= 60.0)
      return TREND_HEALTHY;
   else
      return TREND_WEAK;
}

//+------------------------------------------------------------------+
//| RÈGLE: Générer une alerte selon l'angle                           |
//+------------------------------------------------------------------+
string CMarketStructure::GetTrendAlert(double angle)
{
   if(angle > 60.0)
      return "⚠️ ALERTE: Angle > 60° - Risque de correction violente";
   else if(angle < 25.0)
      return "Tendance faible (angle < 25°)";
   else
      return "Tendance saine (angle ≈ 45°)";
}

//+------------------------------------------------------------------+
//| Getters pour les swing points                                     |
//+------------------------------------------------------------------+
int CMarketStructure::GetSwingHighCount()
{
   return ArraySize(m_swingHighs);
}

int CMarketStructure::GetSwingLowCount()
{
   return ArraySize(m_swingLows);
}

SSwingPoint CMarketStructure::GetSwingHigh(int index)
{
   SSwingPoint empty;
   if(index < 0 || index >= ArraySize(m_swingHighs))
      return empty;
   return m_swingHighs[index];
}

SSwingPoint CMarketStructure::GetSwingLow(int index)
{
   SSwingPoint empty;
   if(index < 0 || index >= ArraySize(m_swingLows))
      return empty;
   return m_swingLows[index];
}

double CMarketStructure::GetLastSwingHigh()
{
   if(ArraySize(m_swingHighs) < 1) return 0;
   return m_swingHighs[0].price;
}

double CMarketStructure::GetLastSwingLow()
{
   if(ArraySize(m_swingLows) < 1) return 0;
   return m_swingLows[0].price;
}

//+------------------------------------------------------------------+
//| Convertir la structure en string                                  |
//+------------------------------------------------------------------+
string CMarketStructure::StructureToString(ENUM_MARKET_STRUCTURE structure)
{
   switch(structure)
   {
      case STRUCTURE_BULLISH: return "HAUSSIER (HH + HL)";
      case STRUCTURE_BEARISH: return "BAISSIER (LH + LL)";
      case STRUCTURE_RANGING: return "RANGE / CONSOLIDATION";
      default:                return "INCONNU";
   }
}

//+------------------------------------------------------------------+
//| Convertir la force de tendance en string                          |
//+------------------------------------------------------------------+
string CMarketStructure::TrendStrengthToString(ENUM_TREND_STRENGTH strength)
{
   switch(strength)
   {
      case TREND_WEAK:          return "Faible (< 25°)";
      case TREND_HEALTHY:       return "Saine (≈ 45°)";
      case TREND_OVEREXTENDED:  return "Surétendue (> 60°)";
      default:                  return "Inconnue";
   }
}
//+------------------------------------------------------------------+
