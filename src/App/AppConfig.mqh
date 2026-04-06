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

   bool     adx_enabled;
   int      adx_max_orders;
   int      adx_pending_ttl_minutes;
   int      adx_max_hold_minutes;
   int      adx_param1;
   int      adx_param2;
   double   adx_param3;
   double   adx_param4;
   double   adx_param5;
   double   adx_sl_atr_factor;
   double   adx_tp_atr_factor;
   int      adx_stop_type;
   double   adx_trailing_atr_factor;
   double   adx_breakeven_trigger_atr;
   double   adx_progressive_trigger_atr;
   double   adx_progressive_step_atr;
   int      adx_tp_type;

   bool     dtosc_enabled;
   int      dtosc_max_orders;
   int      dtosc_pending_ttl_minutes;
   int      dtosc_max_hold_minutes;
   int      dtosc_param1;
   int      dtosc_param2;
   int      dtosc_rsi_period;
   int      dtosc_stoch_period;
   int      dtosc_slowing_period;
   int      dtosc_signal_period;
   double   dtosc_dt_distance;
   int      dtosc_ma_short_period;
   int      dtosc_ma_long_period;
   double   dtosc_ma_dist;
   int      dtosc_lower_zone;
   int      dtosc_upper_zone;
   double   dtosc_sl_atr_factor;
   double   dtosc_tp_atr_factor;
   int      dtosc_stop_type;
   double   dtosc_trailing_atr_factor;
   double   dtosc_breakeven_trigger_atr;
   double   dtosc_progressive_trigger_atr;
   double   dtosc_progressive_step_atr;
   int      dtosc_tp_type;

   bool     trend_accel_enabled;
   int      trend_accel_max_orders;
   int      trend_accel_pending_ttl_minutes;
   int      trend_accel_max_hold_minutes;
   int      trend_accel_rsi_period;
   int      trend_accel_rsi_upper;
   int      trend_accel_rsi_lower;
   int      trend_accel_ma_short_period;
   int      trend_accel_ma_long_period;
   double   trend_accel_ma_dist;
   double   trend_accel_accel_dist;
   double   trend_accel_sl_atr_factor;
   double   trend_accel_tp_atr_factor;
   int      trend_accel_stop_type;
   double   trend_accel_trailing_atr_factor;
   double   trend_accel_breakeven_trigger_atr;
   double   trend_accel_progressive_trigger_atr;
   double   trend_accel_progressive_step_atr;
   int      trend_accel_tp_type;

   bool     candle_wave_enabled;
   int      candle_wave_max_orders;
   int      candle_wave_pending_ttl_minutes;
   int      candle_wave_max_hold_minutes;
   int      candle_wave_volume_avg_period;
   int      candle_wave_trend_ma_period;
   CandlePatternConfig candle_wave_pattern_configs[CANDLE_PATTERN_COUNT];
   double   candle_wave_sl_atr_factor;
   double   candle_wave_tp_atr_factor;
   int      candle_wave_stop_type;
   double   candle_wave_trailing_atr_factor;
   double   candle_wave_breakeven_trigger_atr;
   double   candle_wave_progressive_trigger_atr;
   double   candle_wave_progressive_step_atr;
   int      candle_wave_tp_type;

   bool     trend_reversal_enabled;
   int      trend_reversal_max_orders;
   int      trend_reversal_pending_ttl_minutes;
   int      trend_reversal_max_hold_minutes;
   int      trend_reversal_volume_avg_period;
   int      trend_reversal_trend_ma_period;
   double   trend_reversal_candle_long_percent;
   double   trend_reversal_candle_max_atr;
   double   trend_reversal_sl_atr_factor;
   double   trend_reversal_tp_atr_factor;
   int      trend_reversal_stop_type;
   double   trend_reversal_trailing_atr_factor;
   double   trend_reversal_breakeven_trigger_atr;
   double   trend_reversal_progressive_trigger_atr;
   double   trend_reversal_progressive_step_atr;
   int      trend_reversal_tp_type;

   bool     outsider_bar_enabled;
   int      outsider_bar_max_orders;
   int      outsider_bar_pending_ttl_minutes;
   int      outsider_bar_max_hold_minutes;
   int      outsider_bar_ma_period;
   int      outsider_bar_rsi_period;
   int      outsider_bar_rsi_buy_low;
   int      outsider_bar_rsi_buy_high;
   int      outsider_bar_rsi_sell_low;
   int      outsider_bar_rsi_sell_high;
   double   outsider_bar_body_ratio;
   double   outsider_bar_safe_range;
   double   outsider_bar_sl_atr_factor;
   double   outsider_bar_tp_atr_factor;
   int      outsider_bar_stop_type;
   double   outsider_bar_trailing_atr_factor;
   double   outsider_bar_breakeven_trigger_atr;
   double   outsider_bar_progressive_trigger_atr;
   double   outsider_bar_progressive_step_atr;
   int      outsider_bar_tp_type;

   bool     enable_logging;
   bool     enable_email;
   bool     enable_push;
   bool     enable_notifications;
   bool     enable_debug;
   bool     enable_time_exit;

   double   lot_size;
   double   max_trade_risk;

   string   license_key;
   bool     enable_integrity;
};

#endif // EA_APPCONFIG_MQH
