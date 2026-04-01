// Holds per-strategy configuration and state.

#ifndef EA_STRATEGYCONTEXT_MQH
#define EA_STRATEGYCONTEXT_MQH

#include "../../Shared/CandlePatterns.mqh"

class StrategyContext
{
public:
   string   id;
   bool     enabled;
   int      max_orders;
   int      max_hold_minutes;
   int      pending_ttl_minutes;
   double   sl_atr_factor;
   double   tp_atr_factor;
   int      param1;
   int      param2;
   double   param3; // custom param (ADX extra)
   double   param4; // custom param (DI diff min)
   double   param5; // custom param (ATR min)
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   int      rsi_period;
   int      rsi_upper;
   int      rsi_lower;
   int      stoch_period;
   int      slowing_period;
   int      signal_period;
   double   dt_distance;
   double   accel_dist;
   int      ma_short_period;
   int      ma_long_period;
   double   ma_dist;
   int      lower_zone;
   int      upper_zone;
   int      volume_avg_period;
   int      trend_ma_period;
   double   candle_long_percent;
   double   candle_max_atr;
   CandlePatternConfig pattern_configs[CANDLE_PATTERN_COUNT];
   int      stop_type;
   double   trailing_atr_factor;
   double   breakeven_trigger_atr;
   double   progressive_trigger_atr;
   double   progressive_step_atr;
   int      tp_type;
   int      outsider_ma_period;
   int      outsider_rsi_period;
   int      outsider_rsi_buy_low;
   int      outsider_rsi_buy_high;
   int      outsider_rsi_sell_low;
   int      outsider_rsi_sell_high;
   double   outsider_body_ratio;
   double   outsider_safe_range;
};

#endif // EA_STRATEGYCONTEXT_MQH
