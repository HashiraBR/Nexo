// Centralized configuration assembled from EA inputs.
#ifndef EA_APPCONFIG_MQH
#define EA_APPCONFIG_MQH

#include "../Shared/CandlePatterns.mqh"

struct AppConfig
{
   int      session_start_hour;
   int      session_start_minute;
   int      session_end_hour;
   int      session_end_minute;
   int      close_grace_minutes;
   int      max_orders_global;
   bool     enable_time_window;
   bool     enable_order_limits;
   string   trade_symbol;
   int      max_trades_daily;
   int      max_loss_trades_daily;
   double   daily_loss_limit;
   double   daily_profit_limit;
   bool     enable_daily_risk;

   int      atr_period;
   int      atr_smooth_period;
   ENUM_TIMEFRAMES atr_timeframe;
   ENUM_TIMEFRAMES execution_timeframe;
   bool     trend_filter_enabled;
   int      trend_ma_short_period;
   int      trend_ma_medium_period;
   int      trend_ma_long_period;
   double   trend_dist_sm;
   double   trend_dist_ml;

   bool     strat1_enabled;
   int      strat1_max_orders;
   int      strat1_pending_ttl_minutes;
   int      strat1_max_hold_minutes;
   int      strat1_param1;
   int      strat1_param2;
   double   strat1_param3;
   double   strat1_param4;
   double   strat1_param5;
   double   strat1_sl_atr_factor;
   double   strat1_tp_atr_factor;
   int      strat1_stop_type;
   double   strat1_trailing_atr_factor;
   double   strat1_breakeven_trigger_atr;
   double   strat1_progressive_trigger_atr;
   double   strat1_progressive_step_atr;
   int      strat1_tp_type;

   bool     strat2_enabled;
   bool     strat2_debug;
   int      strat2_max_orders;
   int      strat2_pending_ttl_minutes;
   int      strat2_max_hold_minutes;
   int      strat2_param1;
   int      strat2_param2;
   int      strat2_rsi_period;
   int      strat2_stoch_period;
   int      strat2_slowing_period;
   int      strat2_signal_period;
   double   strat2_dt_distance;
   int      strat2_ma_short_period;
   int      strat2_ma_long_period;
   double   strat2_ma_dist;
   int      strat2_lower_zone;
   int      strat2_upper_zone;
   double   strat2_sl_atr_factor;
   double   strat2_tp_atr_factor;
   int      strat2_stop_type;
   double   strat2_trailing_atr_factor;
   double   strat2_breakeven_trigger_atr;
   double   strat2_progressive_trigger_atr;
   double   strat2_progressive_step_atr;
   int      strat2_tp_type;

   bool     strat3_enabled;
   int      strat3_max_orders;
   int      strat3_pending_ttl_minutes;
   int      strat3_max_hold_minutes;
   int      strat3_rsi_period;
   int      strat3_rsi_upper;
   int      strat3_rsi_lower;
   int      strat3_ma_short_period;
   int      strat3_ma_long_period;
   double   strat3_ma_dist;
   double   strat3_accel_dist;
   double   strat3_sl_atr_factor;
   double   strat3_tp_atr_factor;
   int      strat3_stop_type;
   double   strat3_trailing_atr_factor;
   double   strat3_breakeven_trigger_atr;
   double   strat3_progressive_trigger_atr;
   double   strat3_progressive_step_atr;
   int      strat3_tp_type;

   bool     strat4_enabled;
   int      strat4_max_orders;
   int      strat4_pending_ttl_minutes;
   int      strat4_max_hold_minutes;
   int      strat4_volume_avg_period;
   int      strat4_trend_ma_period;
   CandlePatternConfig strat4_pattern_configs[CANDLE_PATTERN_COUNT];
   double   strat4_sl_atr_factor;
   double   strat4_tp_atr_factor;
   int      strat4_stop_type;
   double   strat4_trailing_atr_factor;
   double   strat4_breakeven_trigger_atr;
   double   strat4_progressive_trigger_atr;
   double   strat4_progressive_step_atr;
   int      strat4_tp_type;

   bool     strat5_enabled;
   int      strat5_max_orders;
   int      strat5_pending_ttl_minutes;
   int      strat5_max_hold_minutes;
   int      strat5_volume_avg_period;
   int      strat5_trend_ma_period;
   double   strat5_candle_long_percent;
   double   strat5_candle_max_atr;
   double   strat5_sl_atr_factor;
   double   strat5_tp_atr_factor;
   int      strat5_stop_type;
   double   strat5_trailing_atr_factor;
   double   strat5_breakeven_trigger_atr;
   double   strat5_progressive_trigger_atr;
   double   strat5_progressive_step_atr;
   int      strat5_tp_type;

   bool     strat6_enabled;
   int      strat6_max_orders;
   int      strat6_pending_ttl_minutes;
   int      strat6_max_hold_minutes;
   int      strat6_ma_period;
   int      strat6_rsi_period;
   int      strat6_rsi_buy_low;
   int      strat6_rsi_buy_high;
   int      strat6_rsi_sell_low;
   int      strat6_rsi_sell_high;
   double   strat6_body_ratio;
   double   strat6_safe_range;
   double   strat6_sl_atr_factor;
   double   strat6_tp_atr_factor;
   int      strat6_stop_type;
   double   strat6_trailing_atr_factor;
   double   strat6_breakeven_trigger_atr;
   double   strat6_progressive_trigger_atr;
   double   strat6_progressive_step_atr;
   int      strat6_tp_type;

   bool     enable_logging;
   bool     enable_email;
   bool     enable_push;
   bool     enable_notifications;
   bool     enable_time_exit;

   double   lot_size;

   string   license_key;
   bool     enable_integrity;
};

#endif // EA_APPCONFIG_MQH
