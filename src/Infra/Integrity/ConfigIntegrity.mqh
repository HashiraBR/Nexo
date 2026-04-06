// Configuration integrity hashing and validation.
#ifndef EA_CONFIGINTEGRITY_MQH
#define EA_CONFIGINTEGRITY_MQH

#include "../../App/AppConfig.mqh"

class ConfigIntegrity
{
public:
   bool Validate(const AppConfig &cfg, string &out_error)
   {
      out_error = "";

      if(cfg.session_start_hour < 0 || cfg.session_start_hour > 23 ||
         cfg.session_end_hour < 0 || cfg.session_end_hour > 23)
      {
         out_error = "Invalid session hour";
         return false;
      }
      if(cfg.session_start_minute < 0 || cfg.session_start_minute > 59 ||
         cfg.session_end_minute < 0 || cfg.session_end_minute > 59)
      {
         out_error = "Invalid session minute";
         return false;
      }
      if(cfg.close_grace_minutes < 0)
      {
         out_error = "Invalid close grace minutes";
         return false;
      }
      if(cfg.max_orders_global < 0)
      {
         out_error = "Invalid global max orders";
         return false;
      }
      if(cfg.trade_symbol == "")
      {
         out_error = "Trade symbol is required";
         return false;
      }
      if(cfg.atr_period <= 0 || cfg.atr_smooth_period <= 0)
      {
         out_error = "Invalid ATR periods";
         return false;
      }
      if(cfg.trend_filter_enabled)
      {
         if(cfg.trend_ma_short_period <= 0 || cfg.trend_ma_medium_period <= 0 ||
            cfg.trend_ma_long_period <= 0)
         {
            out_error = "Invalid trend filter MA period";
            return false;
         }
         if(cfg.trend_dist_sm < 0.0 || cfg.trend_dist_ml < 0.0)
         {
            out_error = "Invalid trend filter distance";
            return false;
         }
      }
      if(cfg.lot_size <= 0.0)
      {
         out_error = "Invalid lot size";
         return false;
      }

      if(cfg.adx_max_orders < 0 || cfg.dtosc_max_orders < 0 ||
         cfg.trend_accel_max_orders < 0 || cfg.candle_wave_max_orders < 0 ||
         cfg.trend_reversal_max_orders < 0 || cfg.outsider_bar_max_orders < 0)
      {
         out_error = "Invalid strategy max orders";
         return false;
      }
      if(cfg.dtosc_rsi_period <= 0 || cfg.dtosc_stoch_period <= 0)
      {
         out_error = "Invalid DT RSI/Stoch period";
         return false;
      }
      if(cfg.dtosc_slowing_period <= 0 || cfg.dtosc_signal_period <= 0)
      {
         out_error = "Invalid DT smoothing/signal period";
         return false;
      }
      if(cfg.dtosc_dt_distance < 0.0)
      {
         out_error = "Invalid DT distance";
         return false;
      }
      if(cfg.dtosc_ma_short_period <= 0 || cfg.dtosc_ma_long_period <= 0)
      {
         out_error = "Invalid DT EMA period";
         return false;
      }
      if(cfg.dtosc_ma_dist < 0.0)
      {
         out_error = "Invalid DT EMA distance";
         return false;
      }
      if(cfg.trend_accel_rsi_period <= 0)
      {
         out_error = "Invalid Trend Accelerator RSI period";
         return false;
      }
      if(cfg.trend_accel_rsi_lower < 0 || cfg.trend_accel_rsi_upper > 100 ||
         cfg.trend_accel_rsi_lower >= cfg.trend_accel_rsi_upper)
      {
         out_error = "Invalid Trend Accelerator RSI limits";
         return false;
      }
      if(cfg.trend_accel_ma_short_period <= 0 || cfg.trend_accel_ma_long_period <= 0)
      {
         out_error = "Invalid Trend Accelerator EMA period";
         return false;
      }
      if(cfg.trend_accel_ma_dist < 0.0)
      {
         out_error = "Invalid Trend Accelerator EMA distance";
         return false;
      }
      if(cfg.trend_accel_accel_dist < 0.0)
      {
         out_error = "Invalid Trend Accelerator acceleration distance";
         return false;
      }
      if(cfg.candle_wave_volume_avg_period < 0)
      {
         out_error = "Invalid Candle Wave volume period";
         return false;
      }
      if(cfg.candle_wave_trend_ma_period < 0)
      {
         out_error = "Invalid Candle Wave MA period";
         return false;
      }
      for(int i = 1; i < CANDLE_PATTERN_COUNT; ++i)
      {
         if(cfg.candle_wave_pattern_configs[i].min_atr < 0.0 ||
            cfg.candle_wave_pattern_configs[i].max_atr < 0.0)
         {
            out_error = "Invalid Candle Wave pattern ATR range";
            return false;
         }
         if(cfg.candle_wave_pattern_configs[i].max_atr > 0.0 &&
            cfg.candle_wave_pattern_configs[i].max_atr < cfg.candle_wave_pattern_configs[i].min_atr)
         {
            out_error = "Invalid Candle Wave pattern ATR bounds";
            return false;
         }
      }
      if(cfg.trend_reversal_volume_avg_period < 0)
      {
         out_error = "Invalid Trend Reversal volume period";
         return false;
      }
      if(cfg.trend_reversal_trend_ma_period <= 0)
      {
         out_error = "Invalid Trend Reversal EMA period";
         return false;
      }
      if(cfg.trend_reversal_candle_long_percent < 0.0)
      {
         out_error = "Invalid Trend Reversal candle long percent";
         return false;
      }
      if(cfg.trend_reversal_candle_max_atr <= 0.0)
      {
         out_error = "Invalid Trend Reversal candle max ATR";
         return false;
      }
      if(cfg.outsider_bar_ma_period <= 0)
      {
         out_error = "Invalid Outsider Bar EMA period";
         return false;
      }
      if(cfg.outsider_bar_rsi_period <= 0)
      {
         out_error = "Invalid Outsider Bar RSI period";
         return false;
      }
      if(cfg.outsider_bar_rsi_buy_low < 0 || cfg.outsider_bar_rsi_buy_high > 100 ||
         cfg.outsider_bar_rsi_sell_low < 0 || cfg.outsider_bar_rsi_sell_high > 100)
      {
         out_error = "Invalid Outsider Bar RSI limits";
         return false;
      }
      if(cfg.outsider_bar_rsi_buy_low >= cfg.outsider_bar_rsi_buy_high ||
         cfg.outsider_bar_rsi_sell_low >= cfg.outsider_bar_rsi_sell_high)
      {
         out_error = "Invalid Outsider Bar RSI limits";
         return false;
      }
      if(cfg.outsider_bar_body_ratio <= 0.0 || cfg.outsider_bar_body_ratio > 1.0)
      {
         out_error = "Invalid Outsider Bar body ratio";
         return false;
      }
      if(cfg.outsider_bar_safe_range < 0.0)
      {
         out_error = "Invalid Outsider Bar safe range";
         return false;
      }
      if(cfg.dtosc_lower_zone < 0 || cfg.dtosc_upper_zone < 0 ||
         cfg.dtosc_lower_zone >= cfg.dtosc_upper_zone)
      {
         out_error = "Invalid DT zones";
         return false;
      }
      if(cfg.adx_pending_ttl_minutes < 0 || cfg.dtosc_pending_ttl_minutes < 0 ||
         cfg.trend_accel_pending_ttl_minutes < 0 || cfg.candle_wave_pending_ttl_minutes < 0 ||
         cfg.trend_reversal_pending_ttl_minutes < 0 || cfg.outsider_bar_pending_ttl_minutes < 0)
      {
         out_error = "Invalid pending TTL";
         return false;
      }
      if(cfg.adx_max_hold_minutes < 0 || cfg.dtosc_max_hold_minutes < 0 ||
         cfg.trend_accel_max_hold_minutes < 0 || cfg.candle_wave_max_hold_minutes < 0 ||
         cfg.trend_reversal_max_hold_minutes < 0 || cfg.outsider_bar_max_hold_minutes < 0)
      {
         out_error = "Invalid max hold minutes";
         return false;
      }
      if(cfg.adx_sl_atr_factor <= 0.0 || cfg.dtosc_sl_atr_factor <= 0.0 ||
         cfg.trend_accel_sl_atr_factor <= 0.0 || cfg.candle_wave_sl_atr_factor <= 0.0 ||
         cfg.trend_reversal_sl_atr_factor <= 0.0 || cfg.outsider_bar_sl_atr_factor <= 0.0)
      {
         out_error = "Invalid SL ATR factor";
         return false;
      }
      if(cfg.adx_tp_atr_factor <= 0.0 || cfg.dtosc_tp_atr_factor <= 0.0 ||
         cfg.trend_accel_tp_atr_factor <= 0.0 || cfg.candle_wave_tp_atr_factor <= 0.0 ||
         cfg.trend_reversal_tp_atr_factor <= 0.0 || cfg.outsider_bar_tp_atr_factor <= 0.0)
      {
         out_error = "Invalid TP ATR factor";
         return false;
      }
      if(cfg.adx_trailing_atr_factor < 0.0 || cfg.dtosc_trailing_atr_factor < 0.0 ||
         cfg.trend_accel_trailing_atr_factor < 0.0 || cfg.candle_wave_trailing_atr_factor < 0.0 ||
         cfg.trend_reversal_trailing_atr_factor < 0.0 || cfg.outsider_bar_trailing_atr_factor < 0.0)
      {
         out_error = "Invalid trailing ATR factor";
         return false;
      }
      if(cfg.adx_breakeven_trigger_atr < 0.0 || cfg.dtosc_breakeven_trigger_atr < 0.0 ||
         cfg.trend_accel_breakeven_trigger_atr < 0.0 || cfg.candle_wave_breakeven_trigger_atr < 0.0 ||
         cfg.trend_reversal_breakeven_trigger_atr < 0.0 || cfg.outsider_bar_breakeven_trigger_atr < 0.0)
      {
         out_error = "Invalid break-even trigger";
         return false;
      }
      if(cfg.adx_progressive_trigger_atr < 0.0 || cfg.dtosc_progressive_trigger_atr < 0.0 ||
         cfg.trend_accel_progressive_trigger_atr < 0.0 || cfg.candle_wave_progressive_trigger_atr < 0.0 ||
         cfg.trend_reversal_progressive_trigger_atr < 0.0 || cfg.outsider_bar_progressive_trigger_atr < 0.0)
      {
         out_error = "Invalid progressive trigger";
         return false;
      }
      if(cfg.adx_progressive_step_atr < 0.0 || cfg.dtosc_progressive_step_atr < 0.0 ||
         cfg.trend_accel_progressive_step_atr < 0.0 || cfg.candle_wave_progressive_step_atr < 0.0 ||
         cfg.trend_reversal_progressive_step_atr < 0.0 || cfg.outsider_bar_progressive_step_atr < 0.0)
      {
         out_error = "Invalid progressive step";
         return false;
      }
      if(cfg.adx_progressive_step_atr > 0.0 && cfg.adx_progressive_trigger_atr > 0.0 &&
         cfg.adx_progressive_step_atr > cfg.adx_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (ADX)";
         return false;
      }
      if(cfg.dtosc_progressive_step_atr > 0.0 && cfg.dtosc_progressive_trigger_atr > 0.0 &&
         cfg.dtosc_progressive_step_atr > cfg.dtosc_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (DTOSC)";
         return false;
      }
      if(cfg.trend_accel_progressive_step_atr > 0.0 && cfg.trend_accel_progressive_trigger_atr > 0.0 &&
         cfg.trend_accel_progressive_step_atr > cfg.trend_accel_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (TACCEL)";
         return false;
      }
      if(cfg.candle_wave_progressive_step_atr > 0.0 && cfg.candle_wave_progressive_trigger_atr > 0.0 &&
         cfg.candle_wave_progressive_step_atr > cfg.candle_wave_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (CWAVE)";
         return false;
      }
      if(cfg.trend_reversal_progressive_step_atr > 0.0 && cfg.trend_reversal_progressive_trigger_atr > 0.0 &&
         cfg.trend_reversal_progressive_step_atr > cfg.trend_reversal_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (TRENDREV)";
         return false;
      }
      if(cfg.outsider_bar_progressive_step_atr > 0.0 && cfg.outsider_bar_progressive_trigger_atr > 0.0 &&
         cfg.outsider_bar_progressive_step_atr > cfg.outsider_bar_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (OUTBAR)";
         return false;
      }
      if(cfg.adx_stop_type < 0 || cfg.adx_stop_type > 3 ||
         cfg.dtosc_stop_type < 0 || cfg.dtosc_stop_type > 3 ||
         cfg.trend_accel_stop_type < 0 || cfg.trend_accel_stop_type > 3 ||
         cfg.candle_wave_stop_type < 0 || cfg.candle_wave_stop_type > 3 ||
         cfg.trend_reversal_stop_type < 0 || cfg.trend_reversal_stop_type > 3 ||
         cfg.outsider_bar_stop_type < 0 || cfg.outsider_bar_stop_type > 3)
      {
         out_error = "Invalid stop type";
         return false;
      }
      if(cfg.adx_tp_type < 0 || cfg.dtosc_tp_type < 0 ||
         cfg.trend_accel_tp_type < 0 || cfg.candle_wave_tp_type < 0 ||
         cfg.trend_reversal_tp_type < 0 || cfg.outsider_bar_tp_type < 0)
      {
         out_error = "Invalid TP type";
         return false;
      }
      return true;
   }

private:
};

#endif // EA_CONFIGINTEGRITY_MQH
