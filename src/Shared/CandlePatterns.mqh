// Candle pattern utilities for signal filters.
#ifndef EA_CANDLEPATTERNS_MQH
#define EA_CANDLEPATTERNS_MQH

#define CANDLE_PATTERN_COUNT 9

enum CandlePattern
{
   PATTERN_NONE = 0,
   PATTERN_DOJI,
   PATTERN_MARUBOZU_GREEN,
   PATTERN_MARUBOZU_RED,
   PATTERN_SHOOTING_STAR_RED,
   PATTERN_SHOOTING_STAR_GREEN,
   PATTERN_SPINNING_TOP,
   PATTERN_HAMMER_GREEN,
   PATTERN_HAMMER_RED
};

struct CandlePatternConfig
{
   bool   enabled;
   double min_atr;
   double max_atr;
};

string CandlePatternNames[] =
{
   "NONE",
   "DOJI",
   "MARUBOZU_GREEN",
   "MARUBOZU_RED",
   "SHOOTING_STAR_RED",
   "SHOOTING_STAR_GREEN",
   "SPINNING_TOP",
   "HAMMER_GREEN",
   "HAMMER_RED"
};

string GetCandlePatternName(const CandlePattern pattern)
{
   const int index = (int)pattern;
   if(index >= 0 && index < ArraySize(CandlePatternNames))
      return CandlePatternNames[index];
   return "PATTERN_UNKNOWN";
}

CandlePattern IdentifyPattern(const double open,
                              const double high,
                              const double low,
                              const double close,
                              const double min_range,
                              const double max_range,
                              const string symbol)
{
   double point = _Point;
   if(symbol != "")
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double multiplier = 1.0;
   const bool is_wdo = (StringFind(symbol, "WDO", 0) != -1) || (StringFind(symbol, "DOL", 0) != -1);
   if(is_wdo)
      multiplier = 2.0;

   const double body_size = MathAbs(close - open);
   const double total_range = high - low;

   bool is_range_valid = (total_range >= min_range * point);
   if(max_range > 0)
      is_range_valid = is_range_valid && (total_range <= max_range * point);
   if(!is_range_valid)
      return PATTERN_NONE;

   const double shadow_percent = 0.15 * multiplier;
   const double small_body_percent = 0.05 * multiplier;
   const double marubozu_body_percent = 0.85;
   const double marubozu_shadow_percent = 0.1 * multiplier;

   if(body_size <= small_body_percent * total_range && body_size <= 10 * point)
      return PATTERN_DOJI;

   if(total_range >= 3 * body_size)
   {
      const double upper_shadow = (close > open) ? (high - close) : (high - open);
      if(upper_shadow <= shadow_percent * total_range)
         return (close > open) ? PATTERN_HAMMER_GREEN : PATTERN_HAMMER_RED;
   }

   if(total_range >= 3 * body_size)
   {
      const double lower_shadow = (close > open) ? (open - low) : (close - low);
      if(lower_shadow <= shadow_percent * total_range)
         return (close > open) ? PATTERN_SHOOTING_STAR_GREEN : PATTERN_SHOOTING_STAR_RED;
   }

   if(body_size >= marubozu_body_percent * total_range)
   {
      const double upper_shadow = high - MathMax(open, close);
      const double lower_shadow = MathMin(open, close) - low;
      if(upper_shadow <= marubozu_shadow_percent * total_range &&
         lower_shadow <= marubozu_shadow_percent * total_range)
         return (close > open) ? PATTERN_MARUBOZU_GREEN : PATTERN_MARUBOZU_RED;
   }

   if(body_size <= 0.3 * total_range)
   {
      const double upper_shadow = (close > open) ? (high - close) : (high - open);
      const double lower_shadow = (close > open) ? (open - low) : (close - low);
      if(upper_shadow > body_size && lower_shadow > body_size)
         return PATTERN_SPINNING_TOP;
   }

   return PATTERN_NONE;
}

CandlePattern IdentifyPatternByAtr(const double open,
                                   const double high,
                                   const double low,
                                   const double close,
                                   const double min_atr,
                                   const double max_atr,
                                   const double atr_value,
                                   const double tick_size,
                                   const string symbol)
{
   if(atr_value <= 0.0)
      return PATTERN_NONE;
   const double min_range = (min_atr > 0.0) ? (min_atr * atr_value) : 0.0;
   const double max_range = (max_atr > 0.0) ? (max_atr * atr_value) : 0.0;

   double multiplier = 1.0;
   const bool is_wdo = (StringFind(symbol, "WDO", 0) != -1) || (StringFind(symbol, "DOL", 0) != -1);
   if(is_wdo)
      multiplier = 2.0;

   const double body_size = MathAbs(close - open);
   const double total_range = high - low;

   bool is_range_valid = (total_range >= min_range);
   if(max_range > 0.0)
      is_range_valid = is_range_valid && (total_range <= max_range);
   if(!is_range_valid)
      return PATTERN_NONE;

   const double shadow_percent = 0.15 * multiplier;
   const double small_body_percent = 0.05 * multiplier;
   const double marubozu_body_percent = 0.85;
   const double marubozu_shadow_percent = 0.1 * multiplier;

   if(body_size <= small_body_percent * total_range && body_size <= 10 * tick_size)
      return PATTERN_DOJI;

   if(total_range >= 3 * body_size)
   {
      const double upper_shadow = (close > open) ? (high - close) : (high - open);
      if(upper_shadow <= shadow_percent * total_range)
         return (close > open) ? PATTERN_HAMMER_GREEN : PATTERN_HAMMER_RED;
   }

   if(total_range >= 3 * body_size)
   {
      const double lower_shadow = (close > open) ? (open - low) : (close - low);
      if(lower_shadow <= shadow_percent * total_range)
         return (close > open) ? PATTERN_SHOOTING_STAR_GREEN : PATTERN_SHOOTING_STAR_RED;
   }

   if(body_size >= marubozu_body_percent * total_range)
   {
      const double upper_shadow = high - MathMax(open, close);
      const double lower_shadow = MathMin(open, close) - low;
      if(upper_shadow <= marubozu_shadow_percent * total_range &&
         lower_shadow <= marubozu_shadow_percent * total_range)
         return (close > open) ? PATTERN_MARUBOZU_GREEN : PATTERN_MARUBOZU_RED;
   }

   if(body_size <= 0.3 * total_range)
   {
      const double upper_shadow = (close > open) ? (high - close) : (high - open);
      const double lower_shadow = (close > open) ? (open - low) : (close - low);
      if(upper_shadow > body_size && lower_shadow > body_size)
         return PATTERN_SPINNING_TOP;
   }

   return PATTERN_NONE;
}

bool IsBuyPatternSignal(const CandlePattern pattern)
{
   return (pattern == PATTERN_MARUBOZU_GREEN ||
           pattern == PATTERN_HAMMER_GREEN ||
           pattern == PATTERN_HAMMER_RED);
}

bool IsSellPatternSignal(const CandlePattern pattern)
{
   return (pattern == PATTERN_MARUBOZU_RED ||
           pattern == PATTERN_SHOOTING_STAR_RED ||
           pattern == PATTERN_SHOOTING_STAR_GREEN);
}

bool IsBuyPatternSignal(const string symbol, const ENUM_TIMEFRAMES timeframe, const int shift = 1)
{
   const double open = iOpen(symbol, timeframe, shift);
   const double close = iClose(symbol, timeframe, shift);
   const double low = iLow(symbol, timeframe, shift);
   const double high = iHigh(symbol, timeframe, shift);
   const CandlePattern pattern = IdentifyPattern(open, high, low, close, 0, 0, symbol);
   return IsBuyPatternSignal(pattern);
}

bool IsSellPatternSignal(const string symbol, const ENUM_TIMEFRAMES timeframe, const int shift = 1)
{
   const double open = iOpen(symbol, timeframe, shift);
   const double close = iClose(symbol, timeframe, shift);
   const double low = iLow(symbol, timeframe, shift);
   const double high = iHigh(symbol, timeframe, shift);
   const CandlePattern pattern = IdentifyPattern(open, high, low, close, 0, 0, symbol);
   return IsSellPatternSignal(pattern);
}

#endif // EA_CANDLEPATTERNS_MQH
