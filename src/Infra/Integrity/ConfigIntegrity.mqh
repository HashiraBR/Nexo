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

      if(cfg.strat1_max_orders < 0 || cfg.strat2_max_orders < 0 ||
         cfg.strat3_max_orders < 0 || cfg.strat4_max_orders < 0 ||
         cfg.strat5_max_orders < 0 || cfg.strat6_max_orders < 0)
      {
         out_error = "Invalid strategy max orders";
         return false;
      }
      if(cfg.strat2_rsi_period <= 0 || cfg.strat2_stoch_period <= 0)
      {
         out_error = "Invalid DT RSI/Stoch period";
         return false;
      }
      if(cfg.strat2_slowing_period <= 0 || cfg.strat2_signal_period <= 0)
      {
         out_error = "Invalid DT smoothing/signal period";
         return false;
      }
      if(cfg.strat2_dt_distance < 0.0)
      {
         out_error = "Invalid DT distance";
         return false;
      }
      if(cfg.strat2_ma_short_period <= 0 || cfg.strat2_ma_long_period <= 0)
      {
         out_error = "Invalid DT EMA period";
         return false;
      }
      if(cfg.strat2_ma_dist < 0.0)
      {
         out_error = "Invalid DT EMA distance";
         return false;
      }
      if(cfg.strat3_rsi_period <= 0)
      {
         out_error = "Invalid Trend Accelerator RSI period";
         return false;
      }
      if(cfg.strat3_rsi_lower < 0 || cfg.strat3_rsi_upper > 100 ||
         cfg.strat3_rsi_lower >= cfg.strat3_rsi_upper)
      {
         out_error = "Invalid Trend Accelerator RSI limits";
         return false;
      }
      if(cfg.strat3_ma_short_period <= 0 || cfg.strat3_ma_long_period <= 0)
      {
         out_error = "Invalid Trend Accelerator EMA period";
         return false;
      }
      if(cfg.strat3_ma_dist < 0.0)
      {
         out_error = "Invalid Trend Accelerator EMA distance";
         return false;
      }
      if(cfg.strat3_accel_dist < 0.0)
      {
         out_error = "Invalid Trend Accelerator acceleration distance";
         return false;
      }
      if(cfg.strat4_volume_avg_period < 0)
      {
         out_error = "Invalid Candle Wave volume period";
         return false;
      }
      if(cfg.strat4_trend_ma_period < 0)
      {
         out_error = "Invalid Candle Wave MA period";
         return false;
      }
      for(int i = 1; i < CANDLE_PATTERN_COUNT; ++i)
      {
         if(cfg.strat4_pattern_configs[i].min_atr < 0.0 ||
            cfg.strat4_pattern_configs[i].max_atr < 0.0)
         {
            out_error = "Invalid Candle Wave pattern ATR range";
            return false;
         }
         if(cfg.strat4_pattern_configs[i].max_atr > 0.0 &&
            cfg.strat4_pattern_configs[i].max_atr < cfg.strat4_pattern_configs[i].min_atr)
         {
            out_error = "Invalid Candle Wave pattern ATR bounds";
            return false;
         }
      }
      if(cfg.strat5_volume_avg_period < 0)
      {
         out_error = "Invalid Trend Reversal volume period";
         return false;
      }
      if(cfg.strat5_trend_ma_period <= 0)
      {
         out_error = "Invalid Trend Reversal EMA period";
         return false;
      }
      if(cfg.strat5_candle_long_percent < 0.0)
      {
         out_error = "Invalid Trend Reversal candle long percent";
         return false;
      }
      if(cfg.strat5_candle_max_atr <= 0.0)
      {
         out_error = "Invalid Trend Reversal candle max ATR";
         return false;
      }
      if(cfg.strat6_ma_period <= 0)
      {
         out_error = "Invalid Outsider Bar EMA period";
         return false;
      }
      if(cfg.strat6_rsi_period <= 0)
      {
         out_error = "Invalid Outsider Bar RSI period";
         return false;
      }
      if(cfg.strat6_rsi_buy_low < 0 || cfg.strat6_rsi_buy_high > 100 ||
         cfg.strat6_rsi_sell_low < 0 || cfg.strat6_rsi_sell_high > 100)
      {
         out_error = "Invalid Outsider Bar RSI limits";
         return false;
      }
      if(cfg.strat6_rsi_buy_low >= cfg.strat6_rsi_buy_high ||
         cfg.strat6_rsi_sell_low >= cfg.strat6_rsi_sell_high)
      {
         out_error = "Invalid Outsider Bar RSI limits";
         return false;
      }
      if(cfg.strat6_body_ratio <= 0.0 || cfg.strat6_body_ratio > 1.0)
      {
         out_error = "Invalid Outsider Bar body ratio";
         return false;
      }
      if(cfg.strat6_safe_range < 0.0)
      {
         out_error = "Invalid Outsider Bar safe range";
         return false;
      }
      if(cfg.strat2_lower_zone < 0 || cfg.strat2_upper_zone < 0 ||
         cfg.strat2_lower_zone >= cfg.strat2_upper_zone)
      {
         out_error = "Invalid DT zones";
         return false;
      }
      if(cfg.strat1_pending_ttl_minutes < 0 || cfg.strat2_pending_ttl_minutes < 0 ||
         cfg.strat3_pending_ttl_minutes < 0 || cfg.strat4_pending_ttl_minutes < 0 ||
         cfg.strat5_pending_ttl_minutes < 0 || cfg.strat6_pending_ttl_minutes < 0)
      {
         out_error = "Invalid pending TTL";
         return false;
      }
      if(cfg.strat1_max_hold_minutes < 0 || cfg.strat2_max_hold_minutes < 0 ||
         cfg.strat3_max_hold_minutes < 0 || cfg.strat4_max_hold_minutes < 0 ||
         cfg.strat5_max_hold_minutes < 0 || cfg.strat6_max_hold_minutes < 0)
      {
         out_error = "Invalid max hold minutes";
         return false;
      }
      if(cfg.strat1_sl_atr_factor <= 0.0 || cfg.strat2_sl_atr_factor <= 0.0 ||
         cfg.strat3_sl_atr_factor <= 0.0 || cfg.strat4_sl_atr_factor <= 0.0 ||
         cfg.strat5_sl_atr_factor <= 0.0 || cfg.strat6_sl_atr_factor <= 0.0)
      {
         out_error = "Invalid SL ATR factor";
         return false;
      }
      if(cfg.strat1_tp_atr_factor <= 0.0 || cfg.strat2_tp_atr_factor <= 0.0 ||
         cfg.strat3_tp_atr_factor <= 0.0 || cfg.strat4_tp_atr_factor <= 0.0 ||
         cfg.strat5_tp_atr_factor <= 0.0 || cfg.strat6_tp_atr_factor <= 0.0)
      {
         out_error = "Invalid TP ATR factor";
         return false;
      }
      if(cfg.strat1_trailing_atr_factor < 0.0 || cfg.strat2_trailing_atr_factor < 0.0 ||
         cfg.strat3_trailing_atr_factor < 0.0 || cfg.strat4_trailing_atr_factor < 0.0 ||
         cfg.strat5_trailing_atr_factor < 0.0 || cfg.strat6_trailing_atr_factor < 0.0)
      {
         out_error = "Invalid trailing ATR factor";
         return false;
      }
      if(cfg.strat1_breakeven_trigger_atr < 0.0 || cfg.strat2_breakeven_trigger_atr < 0.0 ||
         cfg.strat3_breakeven_trigger_atr < 0.0 || cfg.strat4_breakeven_trigger_atr < 0.0 ||
         cfg.strat5_breakeven_trigger_atr < 0.0 || cfg.strat6_breakeven_trigger_atr < 0.0)
      {
         out_error = "Invalid break-even trigger";
         return false;
      }
      if(cfg.strat1_progressive_trigger_atr < 0.0 || cfg.strat2_progressive_trigger_atr < 0.0 ||
         cfg.strat3_progressive_trigger_atr < 0.0 || cfg.strat4_progressive_trigger_atr < 0.0 ||
         cfg.strat5_progressive_trigger_atr < 0.0 || cfg.strat6_progressive_trigger_atr < 0.0)
      {
         out_error = "Invalid progressive trigger";
         return false;
      }
      if(cfg.strat1_progressive_step_atr < 0.0 || cfg.strat2_progressive_step_atr < 0.0 ||
         cfg.strat3_progressive_step_atr < 0.0 || cfg.strat4_progressive_step_atr < 0.0 ||
         cfg.strat5_progressive_step_atr < 0.0 || cfg.strat6_progressive_step_atr < 0.0)
      {
         out_error = "Invalid progressive step";
         return false;
      }
      if(cfg.strat1_progressive_step_atr > 0.0 && cfg.strat1_progressive_trigger_atr > 0.0 &&
         cfg.strat1_progressive_step_atr > cfg.strat1_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat1)";
         return false;
      }
      if(cfg.strat2_progressive_step_atr > 0.0 && cfg.strat2_progressive_trigger_atr > 0.0 &&
         cfg.strat2_progressive_step_atr > cfg.strat2_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat2)";
         return false;
      }
      if(cfg.strat3_progressive_step_atr > 0.0 && cfg.strat3_progressive_trigger_atr > 0.0 &&
         cfg.strat3_progressive_step_atr > cfg.strat3_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat3)";
         return false;
      }
      if(cfg.strat4_progressive_step_atr > 0.0 && cfg.strat4_progressive_trigger_atr > 0.0 &&
         cfg.strat4_progressive_step_atr > cfg.strat4_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat4)";
         return false;
      }
      if(cfg.strat5_progressive_step_atr > 0.0 && cfg.strat5_progressive_trigger_atr > 0.0 &&
         cfg.strat5_progressive_step_atr > cfg.strat5_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat5)";
         return false;
      }
      if(cfg.strat6_progressive_step_atr > 0.0 && cfg.strat6_progressive_trigger_atr > 0.0 &&
         cfg.strat6_progressive_step_atr > cfg.strat6_progressive_trigger_atr)
      {
         out_error = "Progressive step must be <= trigger (strat6)";
         return false;
      }
      if(cfg.strat1_stop_type < 0 || cfg.strat1_stop_type > 3 ||
         cfg.strat2_stop_type < 0 || cfg.strat2_stop_type > 3 ||
         cfg.strat3_stop_type < 0 || cfg.strat3_stop_type > 3 ||
         cfg.strat4_stop_type < 0 || cfg.strat4_stop_type > 3 ||
         cfg.strat5_stop_type < 0 || cfg.strat5_stop_type > 3 ||
         cfg.strat6_stop_type < 0 || cfg.strat6_stop_type > 3)
      {
         out_error = "Invalid stop type";
         return false;
      }
      if(cfg.strat1_tp_type < 0 || cfg.strat2_tp_type < 0 ||
         cfg.strat3_tp_type < 0 || cfg.strat4_tp_type < 0 ||
         cfg.strat5_tp_type < 0 || cfg.strat6_tp_type < 0)
      {
         out_error = "Invalid TP type";
         return false;
      }
      return true;
   }

private:
};

#endif // EA_CONFIGINTEGRITY_MQH
