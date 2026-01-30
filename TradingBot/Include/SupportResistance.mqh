//+------------------------------------------------------------------+
//|                                          SupportResistance.mqh  |
//|                        CHAPITRE 2 - SUPPORT & RÉSISTANCE        |
//|                     Bot Multi-Marchés Forex & Crypto            |
//+------------------------------------------------------------------+
#property copyright "Trading Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Énumération des types de niveaux                                 |
//+------------------------------------------------------------------+
enum ENUM_LEVEL_TYPE
{
   LEVEL_SUPPORT = 0,       // Support
   LEVEL_RESISTANCE,        // Résistance
   LEVEL_BROKEN_SUPPORT,    // Support cassé (devient résistance)
   LEVEL_BROKEN_RESISTANCE  // Résistance cassée (devient support)
};

enum ENUM_LEVEL_STRENGTH
{
   STRENGTH_WEAK = 1,       // 2 touches
   STRENGTH_MODERATE = 2,   // 3 touches
   STRENGTH_STRONG = 3      // 4+ touches
};

//+------------------------------------------------------------------+
//| Structure d'un niveau S/R                                        |
//+------------------------------------------------------------------+
struct SLevel
{
   double            price;          // Prix du niveau
   ENUM_LEVEL_TYPE   type;           // Type de niveau
   ENUM_LEVEL_STRENGTH strength;     // Force du niveau
   int               touchCount;     // Nombre de touches
   datetime          firstTouch;     // Première touche
   datetime          lastTouch;      // Dernière touche
   bool              isBroken;       // Niveau cassé
   bool              isFakeout;      // Fausse cassure détectée
   double            brokenPrice;    // Prix de cassure
};

//+------------------------------------------------------------------+
//| Classe de gestion Support/Résistance                              |
//+------------------------------------------------------------------+
class CSupportResistance
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   SLevel            m_levels[];       // Tableau des niveaux détectés
   int               m_maxLevels;      // Nombre max de niveaux à stocker
   double            m_tolerance;      // Tolérance pour regrouper les niveaux (en pips)
   int               m_lookback;       // Période de recherche

   // Méthodes privées
   void              AddLevel(double price, ENUM_LEVEL_TYPE type, datetime time);
   void              MergeLevels();
   bool              IsPriceNearLevel(double price, double levelPrice);
   double            GetPipValue();

public:
   CSupportResistance();
   ~CSupportResistance();

   // Initialisation
   void              Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetParameters(int lookback, double tolerancePips, int maxLevels);

   // Détection des niveaux
   void              DetectLevels();
   void              DetectSwingHighsLows(int lookback);

   // RÈGLE: Le prix rebondit au moins 2 fois sur un même niveau
   bool              ValidateLevel(double price, int minTouches = 2);

   // RÈGLE: Polarité - Support cassé devient Résistance et vice versa
   void              CheckPolarityFlip();

   // RÈGLE: FAKEOUT - Seule la mèche casse sans clôture
   bool              IsFakeout(int shift, double levelPrice, bool isSupport);

   // Vérification de cassure valide
   bool              IsValidBreak(int shift, double levelPrice, bool isSupport);

   // Getters
   int               GetLevelCount();
   SLevel            GetLevel(int index);
   SLevel            GetNearestSupport(double currentPrice);
   SLevel            GetNearestResistance(double currentPrice);

   // Vérifications de position
   bool              IsPriceAtSupport(double price, double &levelPrice);
   bool              IsPriceAtResistance(double price, double &levelPrice);
   bool              IsPriceInZone(double price, double zoneHigh, double zoneLow);

   // Utilitaires
   string            LevelTypeToString(ENUM_LEVEL_TYPE type);
   string            StrengthToString(ENUM_LEVEL_STRENGTH strength);
   void              ClearLevels();
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CSupportResistance::CSupportResistance()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_maxLevels = 20;
   m_tolerance = 10.0;  // 10 pips par défaut
   m_lookback = 100;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CSupportResistance::~CSupportResistance()
{
   ArrayFree(m_levels);
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
void CSupportResistance::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Configuration des paramètres                                      |
//+------------------------------------------------------------------+
void CSupportResistance::SetParameters(int lookback, double tolerancePips, int maxLevels)
{
   m_lookback = lookback;
   m_tolerance = tolerancePips;
   m_maxLevels = maxLevels;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur d'un pip                                        |
//+------------------------------------------------------------------+
double CSupportResistance::GetPipValue()
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

   // Pour les paires Forex avec 5 décimales ou 3 décimales (JPY)
   if(digits == 5 || digits == 3)
      return point * 10;

   return point;
}

//+------------------------------------------------------------------+
//| Vérifier si un prix est proche d'un niveau                        |
//+------------------------------------------------------------------+
bool CSupportResistance::IsPriceNearLevel(double price, double levelPrice)
{
   double toleranceValue = m_tolerance * GetPipValue();
   return (MathAbs(price - levelPrice) <= toleranceValue);
}

//+------------------------------------------------------------------+
//| Détecter les swing highs et lows                                  |
//+------------------------------------------------------------------+
void CSupportResistance::DetectSwingHighsLows(int lookback)
{
   int barsToCheck = MathMin(lookback, iBars(m_symbol, m_timeframe) - 5);

   for(int i = 2; i < barsToCheck - 2; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      datetime time = iTime(m_symbol, m_timeframe, i);

      // Swing High (Résistance potentielle)
      if(high > iHigh(m_symbol, m_timeframe, i + 1) &&
         high > iHigh(m_symbol, m_timeframe, i + 2) &&
         high > iHigh(m_symbol, m_timeframe, i - 1) &&
         high > iHigh(m_symbol, m_timeframe, i - 2))
      {
         AddLevel(high, LEVEL_RESISTANCE, time);
      }

      // Swing Low (Support potentiel)
      if(low < iLow(m_symbol, m_timeframe, i + 1) &&
         low < iLow(m_symbol, m_timeframe, i + 2) &&
         low < iLow(m_symbol, m_timeframe, i - 1) &&
         low < iLow(m_symbol, m_timeframe, i - 2))
      {
         AddLevel(low, LEVEL_SUPPORT, time);
      }
   }
}

//+------------------------------------------------------------------+
//| Ajouter un niveau                                                 |
//+------------------------------------------------------------------+
void CSupportResistance::AddLevel(double price, ENUM_LEVEL_TYPE type, datetime time)
{
   // Vérifier si le niveau existe déjà (dans la tolérance)
   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if(IsPriceNearLevel(price, m_levels[i].price))
      {
         // Mettre à jour le niveau existant
         m_levels[i].touchCount++;
         m_levels[i].lastTouch = time;

         // Mettre à jour la force
         if(m_levels[i].touchCount >= 4)
            m_levels[i].strength = STRENGTH_STRONG;
         else if(m_levels[i].touchCount >= 3)
            m_levels[i].strength = STRENGTH_MODERATE;

         return;
      }
   }

   // Ajouter un nouveau niveau
   int size = ArraySize(m_levels);

   if(size >= m_maxLevels)
   {
      // Supprimer le niveau le plus ancien si max atteint
      for(int i = 0; i < size - 1; i++)
         m_levels[i] = m_levels[i + 1];
      ArrayResize(m_levels, size);
   }
   else
   {
      ArrayResize(m_levels, size + 1);
   }

   int idx = ArraySize(m_levels) - 1;
   m_levels[idx].price = price;
   m_levels[idx].type = type;
   m_levels[idx].strength = STRENGTH_WEAK;
   m_levels[idx].touchCount = 1;
   m_levels[idx].firstTouch = time;
   m_levels[idx].lastTouch = time;
   m_levels[idx].isBroken = false;
   m_levels[idx].isFakeout = false;
   m_levels[idx].brokenPrice = 0;
}

//+------------------------------------------------------------------+
//| Détection complète des niveaux                                    |
//+------------------------------------------------------------------+
void CSupportResistance::DetectLevels()
{
   ClearLevels();
   DetectSwingHighsLows(m_lookback);
   MergeLevels();
   CheckPolarityFlip();
}

//+------------------------------------------------------------------+
//| Fusionner les niveaux proches                                     |
//+------------------------------------------------------------------+
void CSupportResistance::MergeLevels()
{
   // Trier par prix et fusionner les niveaux proches
   for(int i = 0; i < ArraySize(m_levels) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(m_levels); j++)
      {
         if(IsPriceNearLevel(m_levels[i].price, m_levels[j].price))
         {
            // Fusionner vers le niveau avec le plus de touches
            if(m_levels[j].touchCount > m_levels[i].touchCount)
            {
               m_levels[i].price = m_levels[j].price;
            }
            m_levels[i].touchCount += m_levels[j].touchCount;

            // Supprimer le doublon
            for(int k = j; k < ArraySize(m_levels) - 1; k++)
               m_levels[k] = m_levels[k + 1];
            ArrayResize(m_levels, ArraySize(m_levels) - 1);
            j--;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| RÈGLE: Valider un niveau (minimum 2 touches)                      |
//+------------------------------------------------------------------+
bool CSupportResistance::ValidateLevel(double price, int minTouches = 2)
{
   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if(IsPriceNearLevel(price, m_levels[i].price))
      {
         return (m_levels[i].touchCount >= minTouches);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| RÈGLE: Polarité - Support cassé → Résistance et vice versa       |
//+------------------------------------------------------------------+
void CSupportResistance::CheckPolarityFlip()
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if(m_levels[i].isBroken)
      {
         // RÈGLE: Support cassé + clôture en dessous → devient Résistance
         if(m_levels[i].type == LEVEL_SUPPORT)
         {
            double lastClose = iClose(m_symbol, m_timeframe, 1);
            if(lastClose < m_levels[i].price)
            {
               m_levels[i].type = LEVEL_BROKEN_SUPPORT; // Devient résistance
            }
         }
         // RÈGLE: Résistance cassée + clôture au-dessus → devient Support
         else if(m_levels[i].type == LEVEL_RESISTANCE)
         {
            double lastClose = iClose(m_symbol, m_timeframe, 1);
            if(lastClose > m_levels[i].price)
            {
               m_levels[i].type = LEVEL_BROKEN_RESISTANCE; // Devient support
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| RÈGLE: FAKEOUT - Seule la mèche casse le niveau sans clôture     |
//+------------------------------------------------------------------+
bool CSupportResistance::IsFakeout(int shift, double levelPrice, bool isSupport)
{
   double high = iHigh(m_symbol, m_timeframe, shift);
   double low = iLow(m_symbol, m_timeframe, shift);
   double close = iClose(m_symbol, m_timeframe, shift);
   double open = iOpen(m_symbol, m_timeframe, shift);

   if(isSupport)
   {
      // FAKEOUT sur support: la mèche basse casse mais pas la clôture
      if(low < levelPrice && close > levelPrice && open > levelPrice)
      {
         // Marquer le niveau comme fakeout
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(IsPriceNearLevel(levelPrice, m_levels[i].price))
            {
               m_levels[i].isFakeout = true;
               break;
            }
         }
         return true;
      }
   }
   else
   {
      // FAKEOUT sur résistance: la mèche haute casse mais pas la clôture
      if(high > levelPrice && close < levelPrice && open < levelPrice)
      {
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(IsPriceNearLevel(levelPrice, m_levels[i].price))
            {
               m_levels[i].isFakeout = true;
               break;
            }
         }
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si une cassure est valide (avec clôture)                 |
//+------------------------------------------------------------------+
bool CSupportResistance::IsValidBreak(int shift, double levelPrice, bool isSupport)
{
   double close = iClose(m_symbol, m_timeframe, shift);

   // Vérifier d'abord si ce n'est pas un fakeout
   if(IsFakeout(shift, levelPrice, isSupport))
      return false;

   if(isSupport)
   {
      // Cassure valide: clôture en-dessous du support
      if(close < levelPrice)
      {
         // Marquer le niveau comme cassé
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(IsPriceNearLevel(levelPrice, m_levels[i].price))
            {
               m_levels[i].isBroken = true;
               m_levels[i].brokenPrice = close;
               break;
            }
         }
         return true;
      }
   }
   else
   {
      // Cassure valide: clôture au-dessus de la résistance
      if(close > levelPrice)
      {
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(IsPriceNearLevel(levelPrice, m_levels[i].price))
            {
               m_levels[i].isBroken = true;
               m_levels[i].brokenPrice = close;
               break;
            }
         }
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de niveaux                                      |
//+------------------------------------------------------------------+
int CSupportResistance::GetLevelCount()
{
   return ArraySize(m_levels);
}

//+------------------------------------------------------------------+
//| Obtenir un niveau par index                                       |
//+------------------------------------------------------------------+
SLevel CSupportResistance::GetLevel(int index)
{
   SLevel emptyLevel;
   if(index < 0 || index >= ArraySize(m_levels))
      return emptyLevel;

   return m_levels[index];
}

//+------------------------------------------------------------------+
//| Obtenir le support le plus proche                                 |
//+------------------------------------------------------------------+
SLevel CSupportResistance::GetNearestSupport(double currentPrice)
{
   SLevel nearest;
   nearest.price = 0;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if((m_levels[i].type == LEVEL_SUPPORT || m_levels[i].type == LEVEL_BROKEN_RESISTANCE) &&
         m_levels[i].price < currentPrice)
      {
         double distance = currentPrice - m_levels[i].price;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_levels[i];
         }
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Obtenir la résistance la plus proche                              |
//+------------------------------------------------------------------+
SLevel CSupportResistance::GetNearestResistance(double currentPrice)
{
   SLevel nearest;
   nearest.price = 0;
   double minDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if((m_levels[i].type == LEVEL_RESISTANCE || m_levels[i].type == LEVEL_BROKEN_SUPPORT) &&
         m_levels[i].price > currentPrice)
      {
         double distance = m_levels[i].price - currentPrice;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearest = m_levels[i];
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
   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if((m_levels[i].type == LEVEL_SUPPORT || m_levels[i].type == LEVEL_BROKEN_RESISTANCE) &&
         IsPriceNearLevel(price, m_levels[i].price))
      {
         levelPrice = m_levels[i].price;
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
   for(int i = 0; i < ArraySize(m_levels); i++)
   {
      if((m_levels[i].type == LEVEL_RESISTANCE || m_levels[i].type == LEVEL_BROKEN_SUPPORT) &&
         IsPriceNearLevel(price, m_levels[i].price))
      {
         levelPrice = m_levels[i].price;
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
   return (price <= zoneHigh && price >= zoneLow);
}

//+------------------------------------------------------------------+
//| Convertir le type en string                                       |
//+------------------------------------------------------------------+
string CSupportResistance::LevelTypeToString(ENUM_LEVEL_TYPE type)
{
   switch(type)
   {
      case LEVEL_SUPPORT:           return "Support";
      case LEVEL_RESISTANCE:        return "Résistance";
      case LEVEL_BROKEN_SUPPORT:    return "Support Cassé (→Résistance)";
      case LEVEL_BROKEN_RESISTANCE: return "Résistance Cassée (→Support)";
      default:                      return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Convertir la force en string                                      |
//+------------------------------------------------------------------+
string CSupportResistance::StrengthToString(ENUM_LEVEL_STRENGTH strength)
{
   switch(strength)
   {
      case STRENGTH_WEAK:     return "Faible (2 touches)";
      case STRENGTH_MODERATE: return "Modéré (3 touches)";
      case STRENGTH_STRONG:   return "Fort (4+ touches)";
      default:                return "Inconnu";
   }
}

//+------------------------------------------------------------------+
//| Effacer tous les niveaux                                          |
//+------------------------------------------------------------------+
void CSupportResistance::ClearLevels()
{
   ArrayFree(m_levels);
   ArrayResize(m_levels, 0);
}
//+------------------------------------------------------------------+
