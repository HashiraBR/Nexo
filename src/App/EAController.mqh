// Application layer orchestrator for the EA lifecycle.
#ifndef EA_EACONTROLLER_MQH
#define EA_EACONTROLLER_MQH

#include <Trade/Trade.mqh>

#include "../App/AppConfig.mqh"
#include "../Domain/Entities/DailyState.mqh"
#include "../Domain/ValueObjects/TimeWindow.mqh"
#include "../Shared/Clock.mqh"
#include "../Infra/Market/AtrSmoother.mqh"
#include "../Infra/Market/MarketAdapter.mqh"
#include "../Infra/Logging/Logger.mqh"
#include "../Infra/Notifications/Notifier.mqh"
#include "../Infra/Licensing/LicenseService.mqh"
#include "../Infra/Integrity/ConfigIntegrity.mqh"
#include "../Shared/OrderTag.mqh"
#include "../Shared/EaInfo.mqh"
#include "../Shared/StopTypes.mqh"
#include "../Shared/TakeProfitTypes.mqh"
#include "../Strategies/Implementations/AdxStrategy.mqh"
#include "../Strategies/Implementations/DtStrategy.mqh"
#include "../Strategies/Implementations/TrendAcceleratorStrategy.mqh"
#include "../Strategies/Implementations/CandleWaveStrategy.mqh"
#include "../Strategies/Implementations/TrendReversalStrategy.mqh"
#include "../Strategies/Implementations/OutsiderBarStrategy.mqh"

class EAController
{
public:
   bool Initialize(const AppConfig &config)
   {
      m_config = config;
      m_force_close_done = false;
      m_last_bar_time = 0;
      m_last_trend_dir = TREND_NONE;
      m_daily_day_key = 0;
      m_daily_blocked = false;
      m_daily_state.trades_count = 0;
      m_daily_state.loss_trades_count = 0;
      m_daily_state.pnl = 0.0;
      m_license_ok = false;
      m_license_expiry_warned = false;
      LogInfo((string)EA_ID + " INIT start");
      if(!ValidateWindowConfig())
      {
         LogWarning("Invalid time window: end must be after start");
         return false;
      }
      if(!ValidateLotConfig())
      {
         LogWarning("Invalid lot size: must be positive integer");
         return false;
      }
      if(!ValidateAccountMode())
         return false;
      if(!ValidateAtrConfig())
      {
         LogWarning("Invalid ATR configuration");
         return false;
      }
      if(!m_atr.Initialize(m_config.trade_symbol, m_config.atr_timeframe, m_config.atr_period, m_config.atr_smooth_period))
      {
         LogWarning("ATR initialization failed");
         return false;
      }
      if(!InitializeTrendFilter())
         return false;

      if(m_config.enable_notifications && m_config.enable_logging)
         m_logger.Initialize((string)EA_ID + ".log");
      if(m_config.enable_notifications)
         m_notifier.Configure(m_config.enable_email, m_config.enable_push);
      else
         m_notifier.Configure(false, false);

      ValidatePermissions();

      if(!ValidateLicense())
         return false;

      LogInfo("[DEBUG] BuildStrategies: After ValidateLicense - m_license_state.strategies_csv=" + m_license_state.strategies_csv);

      if(!ValidateIntegrityOnInit())
         return false;

      BuildStrategies();
      LogStartupSummary();
      return true;
   }

   void OnTick()
   {
      const datetime now = m_clock.ServerNow();
      EnsureDailyState(now);

      // Update global ATR (only changes on new ATR candle).
      m_atr.Update();

      // Update stop loss policies on each tick (independent of other guards).
      UpdateStops();

      // Global guardrails: cancel pendings if limits are hit, and expire old pending orders.
      if(m_config.enable_order_limits)
      {
         HandleGlobalOrderLimit();
         ExpirePendingOrders();
      }

      if(m_config.enable_daily_risk)
      {
         if(HandleDailyRisk(now))
            return;
      }

      if(!ValidateIntegrityRuntime())
         return;

      // License expiration check (runtime).
      if(!HandleLicenseRuntime(now))
         return;

      // Time-based exits (per strategy) should be checked on every tick.
      if(m_config.enable_time_exit)
         HandleTimeBasedExits(now);

      // Enforce trading window rules (RF01/RF02).
      if(m_config.enable_time_window)
      {
         const TimeWindow window = BuildTodayWindow(now);

         // If OUTSIDE the trading window, block operations
         if(!TimeWindowContains(window, now))
         {
            // Before session start: only block new operations.
            if(now < window.start)
               return;

            // After session end: wait grace period, then close all positions.
            const datetime grace_end = window.end + (m_config.close_grace_minutes * 60);
            if(now >= grace_end)
            {
               if(!m_force_close_done)
               {
                  CloseAllPositions();
                  if(PositionsTotal() == 0)
                     m_force_close_done = true;
               }
            }
            return;
         }
         
         // Inside trading window - allow operations
         m_force_close_done = false;
      }

      // RF03: only run strategy logic on new candle.
      if(IsNewCandle())
      {
         OnNewCandle();
      }
   }

   void OnNewCandle()
   {
      if(!m_atr.IsReady())
         return;

      const double atr_value = m_atr.Value();
      //LogInfo("[DEBUG] OnNewCandle: ATR value = " + DoubleToString(atr_value, 4));
      EvaluateStrategyExits();
      TrendDirection trend = TREND_NONE;
      if(m_config.trend_filter_enabled)
      {
         trend = DetermineMarketTrend();
         if(trend != m_last_trend_dir)
         {
            LogInfo("Trend filter: " + TrendDirectionToString(trend));
            m_last_trend_dir = trend;
         }
      }
      ExecuteStrategy(m_strategy1, atr_value);
      ExecuteStrategy(m_strategy2, atr_value);
      ExecuteStrategy(m_strategy3, atr_value);
      if(!m_config.trend_filter_enabled || trend != TREND_NONE)
      {
         ExecuteStrategy(m_strategy4, atr_value);
         ExecuteStrategy(m_strategy5, atr_value);
      }
      ExecuteStrategy(m_strategy6, atr_value);
   }

   void Shutdown()
   {
      m_atr.Shutdown();
      ShutdownTrendFilter();
   }

   void OnTradeTransaction(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
      HandleTradeTransaction(trans, request, result);
   }

private:
   enum TrendDirection
   {
      TREND_NONE = 0,
      TREND_UP = 1,
      TREND_DOWN = 2
   };

   AppConfig m_config;
   Clock     m_clock;
   bool      m_force_close_done;
   datetime  m_last_bar_time;
   TrendDirection m_last_trend_dir;
   DailyState m_daily_state;
   int        m_daily_day_key;
   bool       m_daily_blocked;
   AtrSmoother m_atr;
   MarketAdapter m_market;
   Logger m_logger;
   Notifier m_notifier;
   LicenseService m_license;
   LicenseState m_license_state;
   bool m_license_ok;
   bool m_license_expiry_warned;
   ConfigIntegrity m_integrity;
   AdxStrategy m_strategy1;
   DtStrategy m_strategy2;
   TrendAcceleratorStrategy m_strategy3;
   CandleWaveStrategy m_strategy4;
   TrendReversalStrategy m_strategy5;
   OutsiderBarStrategy m_strategy6;
   int m_trend_ma_short_handle;
   int m_trend_ma_medium_handle;
   int m_trend_ma_long_handle;

   TimeWindow BuildTodayWindow(const datetime now)
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);

      MqlDateTime start_dt = dt;
      start_dt.hour = m_config.session_start_hour;
      start_dt.min  = m_config.session_start_minute;
      start_dt.sec  = 0;

      MqlDateTime end_dt = dt;
      end_dt.hour = m_config.session_end_hour;
      end_dt.min  = m_config.session_end_minute;
      end_dt.sec  = 0;

      TimeWindow window;
      window.start = StructToTime(start_dt);
      window.end   = StructToTime(end_dt);
      return window;
   }

   void CloseAllPositions()
   {
      CTrade trade;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         trade.PositionClose((long)ticket);
      }
   }

   bool IsNewCandle()
   {
      const datetime bar_time = iTime(m_config.trade_symbol, m_config.execution_timeframe, 0);
      if(bar_time == 0)
         return false;
      if(bar_time == m_last_bar_time)
         return false;
      m_last_bar_time = bar_time;
      return true;
   }

   bool ValidateAtrConfig()
   {
      return (m_config.atr_period > 0 && m_config.atr_smooth_period > 0);
   }

   bool InitializeTrendFilter()
   {
      m_trend_ma_short_handle = INVALID_HANDLE;
      m_trend_ma_medium_handle = INVALID_HANDLE;
      m_trend_ma_long_handle = INVALID_HANDLE;
      if(!m_config.trend_filter_enabled)
         return true;
      m_trend_ma_short_handle = iMA(m_config.trade_symbol, m_config.execution_timeframe,
                                    m_config.trend_ma_short_period, 0, MODE_EMA, PRICE_CLOSE);
      m_trend_ma_medium_handle = iMA(m_config.trade_symbol, m_config.execution_timeframe,
                                     m_config.trend_ma_medium_period, 0, MODE_EMA, PRICE_CLOSE);
      m_trend_ma_long_handle = iMA(m_config.trade_symbol, m_config.execution_timeframe,
                                   m_config.trend_ma_long_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_trend_ma_short_handle == INVALID_HANDLE ||
         m_trend_ma_medium_handle == INVALID_HANDLE ||
         m_trend_ma_long_handle == INVALID_HANDLE)
      {
         LogWarning("Trend filter MA initialization failed");
         ShutdownTrendFilter();
         return false;
      }
      return true;
   }

   void ShutdownTrendFilter()
   {
      if(m_trend_ma_short_handle != INVALID_HANDLE)
         IndicatorRelease(m_trend_ma_short_handle);
      if(m_trend_ma_medium_handle != INVALID_HANDLE)
         IndicatorRelease(m_trend_ma_medium_handle);
      if(m_trend_ma_long_handle != INVALID_HANDLE)
         IndicatorRelease(m_trend_ma_long_handle);
      m_trend_ma_short_handle = INVALID_HANDLE;
      m_trend_ma_medium_handle = INVALID_HANDLE;
      m_trend_ma_long_handle = INVALID_HANDLE;
   }

   double ReadMaValue(const int handle) const
   {
      if(handle == INVALID_HANDLE)
         return 0.0;
      double buffer[1];
      if(CopyBuffer(handle, 0, 0, 1, buffer) != 1)
         return 0.0;
      return buffer[0];
   }

   TrendDirection DetermineMarketTrend() const
   {
      const double ma_short = ReadMaValue(m_trend_ma_short_handle);
      const double ma_medium = ReadMaValue(m_trend_ma_medium_handle);
      const double ma_long = ReadMaValue(m_trend_ma_long_handle);
      if(ma_short <= 0.0 || ma_medium <= 0.0 || ma_long <= 0.0)
         return TREND_NONE;
      const double dist_sm = m_config.trend_dist_sm / 100.0;
      const double dist_ml = m_config.trend_dist_ml / 100.0;
      if(ma_short > ma_medium * (1.0 + dist_sm) &&
         ma_medium > ma_long * (1.0 + dist_ml))
         return TREND_UP;
      if(ma_short < ma_medium * (1.0 - dist_sm) &&
         ma_medium < ma_long * (1.0 - dist_ml))
         return TREND_DOWN;
      return TREND_NONE;
   }

   string TrendDirectionToString(const TrendDirection trend) const
   {
      if(trend == TREND_UP)
         return "UP";
      if(trend == TREND_DOWN)
         return "DOWN";
      return "NONE";
   }

   bool ValidateLotConfig()
   {
      if(m_config.lot_size <= 0.0)
         return false;
      // B3 requires integer lots. Enforce by requiring lot_size to be whole.
      return (MathFloor(m_config.lot_size) == m_config.lot_size);
   }

   bool ValidateAccountMode()
   {
      const long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      if(mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         LogWarning("Account is not hedge mode");
         return false;
      }
      return true;
   }

   void BuildStrategies()
   {
      StrategyContext ctx1;
      ctx1.id = "ADX";
      ctx1.enabled = m_config.adx_enabled;
      ctx1.max_orders = m_config.adx_max_orders;
      ctx1.pending_ttl_minutes = m_config.adx_pending_ttl_minutes;
      ctx1.param1 = m_config.adx_param1;
      ctx1.param2 = m_config.adx_param2;
      ctx1.param3 = m_config.adx_param3;
      ctx1.param4 = m_config.adx_param4;
      ctx1.param5 = m_config.adx_param5;
      ctx1.symbol = m_config.trade_symbol;
      ctx1.timeframe = m_config.execution_timeframe;
      ctx1.sl_atr_factor = m_config.adx_sl_atr_factor;
      ctx1.tp_atr_factor = m_config.adx_tp_atr_factor;
      ctx1.stop_type = m_config.adx_stop_type;
      ctx1.tp_type = m_config.adx_tp_type;
      ctx1.trailing_atr_factor = m_config.adx_trailing_atr_factor;
      ctx1.breakeven_trigger_atr = m_config.adx_breakeven_trigger_atr;
      ctx1.progressive_trigger_atr = m_config.adx_progressive_trigger_atr;
      ctx1.progressive_step_atr = m_config.adx_progressive_step_atr;
      ctx1.max_hold_minutes = m_config.adx_max_hold_minutes;
      ctx1.debug = m_config.enable_debug;
      
      LogInfo("[DEBUG] Strategy ADX: config.enabled=" + (string)ctx1.enabled + ", strategies_csv=" + m_license_state.strategies_csv);
      if(!m_license.IsStrategyAllowed(m_license_state, ctx1.id))
      {
         LogInfo("[DEBUG] Strategy ADX: BLOCKED by license check");
         ctx1.enabled = false;
      }
      else
      {
         LogInfo("[DEBUG] Strategy ADX: ALLOWED by license check");
      }
      m_strategy1.Configure(ctx1);

      StrategyContext ctx2;
      ctx2.id = "DTOSC";
      ctx2.enabled = m_config.dtosc_enabled;
      ctx2.max_orders = m_config.dtosc_max_orders;
      ctx2.pending_ttl_minutes = m_config.dtosc_pending_ttl_minutes;
      ctx2.param1 = m_config.dtosc_param1;
      ctx2.param2 = m_config.dtosc_param2;
      ctx2.symbol = m_config.trade_symbol;
      ctx2.timeframe = m_config.execution_timeframe;
      ctx2.rsi_period = m_config.dtosc_rsi_period;
      ctx2.stoch_period = m_config.dtosc_stoch_period;
      ctx2.slowing_period = m_config.dtosc_slowing_period;
      ctx2.signal_period = m_config.dtosc_signal_period;
      ctx2.dt_distance = m_config.dtosc_dt_distance;
      ctx2.ma_short_period = m_config.dtosc_ma_short_period;
      ctx2.ma_long_period = m_config.dtosc_ma_long_period;
      ctx2.ma_dist = m_config.dtosc_ma_dist;
      ctx2.lower_zone = m_config.dtosc_lower_zone;
      ctx2.upper_zone = m_config.dtosc_upper_zone;
      ctx2.sl_atr_factor = m_config.dtosc_sl_atr_factor;
      ctx2.tp_atr_factor = m_config.dtosc_tp_atr_factor;
      ctx2.stop_type = m_config.dtosc_stop_type;
      ctx2.tp_type = m_config.dtosc_tp_type;
      ctx2.trailing_atr_factor = m_config.dtosc_trailing_atr_factor;
      ctx2.breakeven_trigger_atr = m_config.dtosc_breakeven_trigger_atr;
      ctx2.progressive_trigger_atr = m_config.dtosc_progressive_trigger_atr;
      ctx2.progressive_step_atr = m_config.dtosc_progressive_step_atr;
      ctx2.max_hold_minutes = m_config.dtosc_max_hold_minutes;
      ctx2.debug = m_config.enable_debug;
      if(!m_license.IsStrategyAllowed(m_license_state, ctx2.id))
         ctx2.enabled = false;
      m_strategy2.Configure(ctx2);

      StrategyContext ctx3;
      ctx3.id = "TACCEL";
      ctx3.enabled = m_config.trend_accel_enabled;
      ctx3.max_orders = m_config.trend_accel_max_orders;
      ctx3.pending_ttl_minutes = m_config.trend_accel_pending_ttl_minutes;
      ctx3.symbol = m_config.trade_symbol;
      ctx3.timeframe = m_config.execution_timeframe;
      ctx3.rsi_period = m_config.trend_accel_rsi_period;
      ctx3.rsi_upper = m_config.trend_accel_rsi_upper;
      ctx3.rsi_lower = m_config.trend_accel_rsi_lower;
      ctx3.ma_short_period = m_config.trend_accel_ma_short_period;
      ctx3.ma_long_period = m_config.trend_accel_ma_long_period;
      ctx3.ma_dist = m_config.trend_accel_ma_dist;
      ctx3.accel_dist = m_config.trend_accel_accel_dist;
      ctx3.sl_atr_factor = m_config.trend_accel_sl_atr_factor;
      ctx3.tp_atr_factor = m_config.trend_accel_tp_atr_factor;
      ctx3.stop_type = m_config.trend_accel_stop_type;
      ctx3.tp_type = m_config.trend_accel_tp_type;
      ctx3.trailing_atr_factor = m_config.trend_accel_trailing_atr_factor;
      ctx3.breakeven_trigger_atr = m_config.trend_accel_breakeven_trigger_atr;
      ctx3.progressive_trigger_atr = m_config.trend_accel_progressive_trigger_atr;
      ctx3.progressive_step_atr = m_config.trend_accel_progressive_step_atr;
      ctx3.max_hold_minutes = m_config.trend_accel_max_hold_minutes;
      ctx3.debug = m_config.enable_debug;
      
      LogInfo("[DEBUG] Strategy TACCEL: config.enabled=" + (string)ctx3.enabled + ", strategies_csv=" + m_license_state.strategies_csv);
      if(!m_license.IsStrategyAllowed(m_license_state, ctx3.id))
      {
         LogInfo("[DEBUG] Strategy TACCEL: BLOCKED by license check");
         ctx3.enabled = false;
      }
      else
      {
         LogInfo("[DEBUG] Strategy TACCEL: ALLOWED by license check");
      }
      m_strategy3.Configure(ctx3);

      StrategyContext ctx4;
      ctx4.id = "CWAVE";
      ctx4.enabled = m_config.candle_wave_enabled;
      ctx4.max_orders = m_config.candle_wave_max_orders;
      ctx4.pending_ttl_minutes = m_config.candle_wave_pending_ttl_minutes;
      ctx4.symbol = m_config.trade_symbol;
      ctx4.timeframe = m_config.execution_timeframe;
      ctx4.volume_avg_period = m_config.candle_wave_volume_avg_period;
      ctx4.trend_ma_period = m_config.candle_wave_trend_ma_period;
      for(int i = 0; i < CANDLE_PATTERN_COUNT; ++i)
         ctx4.pattern_configs[i] = m_config.candle_wave_pattern_configs[i];
      ctx4.sl_atr_factor = m_config.candle_wave_sl_atr_factor;
      ctx4.tp_atr_factor = m_config.candle_wave_tp_atr_factor;
      ctx4.stop_type = m_config.candle_wave_stop_type;
      ctx4.tp_type = m_config.candle_wave_tp_type;
      ctx4.trailing_atr_factor = m_config.candle_wave_trailing_atr_factor;
      ctx4.breakeven_trigger_atr = m_config.candle_wave_breakeven_trigger_atr;
      ctx4.progressive_trigger_atr = m_config.candle_wave_progressive_trigger_atr;
      ctx4.progressive_step_atr = m_config.candle_wave_progressive_step_atr;
      ctx4.max_hold_minutes = m_config.candle_wave_max_hold_minutes;
      ctx4.debug = m_config.enable_debug;
      if(!m_license.IsStrategyAllowed(m_license_state, ctx4.id))
         ctx4.enabled = false;
      m_strategy4.Configure(ctx4);

      StrategyContext ctx5;
      ctx5.id = "TRENDREV";
      ctx5.enabled = m_config.trend_reversal_enabled;
      ctx5.max_orders = m_config.trend_reversal_max_orders;
      ctx5.pending_ttl_minutes = m_config.trend_reversal_pending_ttl_minutes;
      ctx5.symbol = m_config.trade_symbol;
      ctx5.timeframe = m_config.execution_timeframe;
      ctx5.volume_avg_period = m_config.trend_reversal_volume_avg_period;
      ctx5.trend_ma_period = m_config.trend_reversal_trend_ma_period;
      ctx5.candle_long_percent = m_config.trend_reversal_candle_long_percent;
      ctx5.candle_max_atr = m_config.trend_reversal_candle_max_atr;
      ctx5.sl_atr_factor = m_config.trend_reversal_sl_atr_factor;
      ctx5.tp_atr_factor = m_config.trend_reversal_tp_atr_factor;
      ctx5.stop_type = m_config.trend_reversal_stop_type;
      ctx5.tp_type = m_config.trend_reversal_tp_type;
      ctx5.trailing_atr_factor = m_config.trend_reversal_trailing_atr_factor;
      ctx5.breakeven_trigger_atr = m_config.trend_reversal_breakeven_trigger_atr;
      ctx5.progressive_trigger_atr = m_config.trend_reversal_progressive_trigger_atr;
      ctx5.progressive_step_atr = m_config.trend_reversal_progressive_step_atr;
      ctx5.max_hold_minutes = m_config.trend_reversal_max_hold_minutes;
      ctx5.debug = m_config.enable_debug;
      if(!m_license.IsStrategyAllowed(m_license_state, ctx5.id))
         ctx5.enabled = false;
      m_strategy5.Configure(ctx5);

      StrategyContext ctx6;
      ctx6.id = "OUTBAR";
      ctx6.enabled = m_config.outsider_bar_enabled;
      ctx6.max_orders = m_config.outsider_bar_max_orders;
      ctx6.pending_ttl_minutes = m_config.outsider_bar_pending_ttl_minutes;
      ctx6.symbol = m_config.trade_symbol;
      ctx6.timeframe = m_config.execution_timeframe;
      ctx6.outsider_ma_period = m_config.outsider_bar_ma_period;
      ctx6.outsider_rsi_period = m_config.outsider_bar_rsi_period;
      ctx6.outsider_rsi_buy_low = m_config.outsider_bar_rsi_buy_low;
      ctx6.outsider_rsi_buy_high = m_config.outsider_bar_rsi_buy_high;
      ctx6.outsider_rsi_sell_low = m_config.outsider_bar_rsi_sell_low;
      ctx6.outsider_rsi_sell_high = m_config.outsider_bar_rsi_sell_high;
      ctx6.outsider_body_ratio = m_config.outsider_bar_body_ratio;
      ctx6.outsider_safe_range = m_config.outsider_bar_safe_range;
      ctx6.sl_atr_factor = m_config.outsider_bar_sl_atr_factor;
      ctx6.tp_atr_factor = m_config.outsider_bar_tp_atr_factor;
      ctx6.stop_type = m_config.outsider_bar_stop_type;
      ctx6.tp_type = m_config.outsider_bar_tp_type;
      ctx6.trailing_atr_factor = m_config.outsider_bar_trailing_atr_factor;
      ctx6.breakeven_trigger_atr = m_config.outsider_bar_breakeven_trigger_atr;
      ctx6.progressive_trigger_atr = m_config.outsider_bar_progressive_trigger_atr;
      ctx6.progressive_step_atr = m_config.outsider_bar_progressive_step_atr;
      ctx6.max_hold_minutes = m_config.outsider_bar_max_hold_minutes;
      ctx6.debug = m_config.enable_debug;
      if(!m_license.IsStrategyAllowed(m_license_state, ctx6.id))
         ctx6.enabled = false;
      m_strategy6.Configure(ctx6);
   }

   void ExecuteStrategy(Strategy &strategy, const double atr_value)
   {
      if(!strategy.IsEnabled())
         return;
      if(IsStrategyOrderLimitReached(strategy.Id()))
         return;
      const MarketSnapshot snapshot = m_market.Snapshot(m_config.trade_symbol);
      const MarketHistory history = m_market.History(m_config.trade_symbol, m_config.execution_timeframe, 100);
      strategy.OnNewCandle(atr_value, snapshot, history);
      if(strategy.UsesPendingOrders())
      {
         const bool wants_buy = strategy.ShouldOpenBuy();
         const bool wants_sell = (!wants_buy) && strategy.ShouldOpenSell();
         if(wants_buy || wants_sell)
            OpenPendingOrder(strategy, atr_value, snapshot);
         return;
      }
      if(strategy.ShouldOpenBuy())
         OpenMarketPosition(POSITION_TYPE_BUY, strategy.GetContext(), atr_value, snapshot);
      else if(strategy.ShouldOpenSell())
         OpenMarketPosition(POSITION_TYPE_SELL, strategy.GetContext(), atr_value, snapshot);
   }

   bool OpenMarketPosition(const int type, const StrategyContext &ctx, const double atr, const MarketSnapshot &snapshot)
   {
      if(atr <= 0.0)
      {
         LogInfo("[DEBUG] OpenMarketPosition: ATR invalid (atr=" + DoubleToString(atr, 4) + ")");
         return false;
      }
      
      const double entry = (type == POSITION_TYPE_BUY) ? snapshot.ask : snapshot.bid;
      double sl = ComputeFixedStop(type, entry, atr, ctx.sl_atr_factor);
      double tp = ComputeTakeProfit(type, entry, atr, ctx);
      sl = NormalizeDouble(NormalizePriceToTick(sl), snapshot.digits);
      tp = NormalizeDouble(NormalizePriceToTick(tp), snapshot.digits);

      if(RiskExceeded(ctx.id, entry, sl, snapshot.symbol))
         return false;
      LogInfo("[DEBUG] OpenMarketPosition: " + ctx.id + " " + ((type == POSITION_TYPE_BUY) ? "BUY" : "SELL") + 
              " entry=" + DoubleToString(entry, (int)snapshot.digits) + 
              " atr=" + DoubleToString(atr, 4) + 
              " sl_factor=" + DoubleToString(ctx.sl_atr_factor, 2) + 
              " tp_factor=" + DoubleToString(ctx.tp_atr_factor, 2) + 
              " sl=" + DoubleToString(sl, (int)snapshot.digits) + 
              " tp=" + DoubleToString(tp, (int)snapshot.digits) + 
              " lot=" + DoubleToString(m_config.lot_size, 2));

      const string comment = BuildStrategyCommentWithAtr(ctx.id, atr, TickSize());
      CTrade trade;
      bool ok = false;
      if(type == POSITION_TYPE_BUY)
         ok = trade.Buy(m_config.lot_size, m_config.trade_symbol, entry, sl, tp, comment);
      else
         ok = trade.Sell(m_config.lot_size, m_config.trade_symbol, entry, sl, tp, comment);

      if(!ok)
      {
         LogWarning("[DEBUG] Order send failed: " + (string)trade.ResultRetcode() + " " +
                    trade.ResultRetcodeDescription());
         return false;
      }
      LogInfo("Order opened: " + ctx.id + " " + ((type == POSITION_TYPE_BUY) ? "BUY" : "SELL"));
      return true;
   }

   bool OpenPendingOrder(Strategy &strategy, const double atr, const MarketSnapshot &snapshot)
   {
      const StrategyContext ctx = strategy.GetContext();
      if(atr <= 0.0)
         return false;
      if(IsStrategyOrderLimitReached(ctx.id))
         return false;
      if(HasPendingOrderForStrategy(ctx.id))
         return false;

      const int order_type = strategy.PendingOrderType();
      const double entry_raw = strategy.PendingEntryPrice();
      double sl_raw = strategy.PendingStopLoss();
      double tp_raw = strategy.PendingTakeProfit();
      if(entry_raw <= 0.0)
         return false;

      double entry = NormalizeDouble(NormalizePriceToTick(entry_raw), snapshot.digits);
      double sl = sl_raw;
      if(sl > 0.0)
         sl = NormalizeDouble(NormalizePriceToTick(sl), snapshot.digits);
      if(tp_raw <= 0.0)
      {
         const bool is_buy = (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT);
         tp_raw = ComputeTakeProfit(is_buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, entry, atr, ctx);
      }
      entry = EnsurePendingOrderEntryDistance(order_type, entry, snapshot);
      double tp = tp_raw;
      if(tp > 0.0)
         tp = NormalizeDouble(NormalizePriceToTick(tp), snapshot.digits);

      if(!ValidatePendingOrderPrices(order_type, entry, sl, tp, snapshot))
         return false;
      if(RiskExceeded(ctx.id, entry, sl, snapshot.symbol))
         return false;

      const string comment = BuildStrategyCommentWithAtr(ctx.id, atr, TickSize());
      CTrade trade;
      bool ok = false;
      if(order_type == ORDER_TYPE_BUY_STOP)
         ok = trade.BuyStop(m_config.lot_size, entry, m_config.trade_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_SELL_STOP)
         ok = trade.SellStop(m_config.lot_size, entry, m_config.trade_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_BUY_LIMIT)
         ok = trade.BuyLimit(m_config.lot_size, entry, m_config.trade_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_SELL_LIMIT)
         ok = trade.SellLimit(m_config.lot_size, entry, m_config.trade_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      else
         return false;

      if(!ok)
      {
         LogWarning("Pending order failed: " + (string)trade.ResultRetcode() + " " +
                    trade.ResultRetcodeDescription());
         return false;
      }
      string type_label = "PENDING";
      if(order_type == ORDER_TYPE_BUY_STOP)
         type_label = "BUY_STOP";
      else if(order_type == ORDER_TYPE_SELL_STOP)
         type_label = "SELL_STOP";
      else if(order_type == ORDER_TYPE_BUY_LIMIT)
         type_label = "BUY_LIMIT";
      else if(order_type == ORDER_TYPE_SELL_LIMIT)
         type_label = "SELL_LIMIT";
      LogInfo("Pending order placed: " + ctx.id + " " + type_label);
      return true;
   }

   bool ValidatePendingOrderPrices(const int order_type,
                                   const double entry,
                                   const double sl,
                                   const double tp,
                                   const MarketSnapshot &snapshot)
   {
      if(entry <= 0.0)
         return false;
      const double bid = snapshot.bid;
      const double ask = snapshot.ask;

      const int stop_level_points = (int)SymbolInfoInteger(snapshot.symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double stop_level = stop_level_points * snapshot.point;
      const bool is_buy = (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT);

      if(order_type == ORDER_TYPE_BUY_STOP && entry <= ask + stop_level)
      {
         LogWarning("Pending order rejected: BUY_STOP entry too close to ask");
         return false;
      }
      if(order_type == ORDER_TYPE_SELL_STOP && entry >= bid - stop_level)
      {
         LogWarning("Pending order rejected: SELL_STOP entry too close to bid");
         return false;
      }
      if(order_type == ORDER_TYPE_BUY_LIMIT && entry >= bid - stop_level)
      {
         LogWarning("Pending order rejected: BUY_LIMIT entry too close to bid");
         return false;
      }
      if(order_type == ORDER_TYPE_SELL_LIMIT && entry <= ask + stop_level)
      {
         LogWarning("Pending order rejected: SELL_LIMIT entry too close to ask");
         return false;
      }

      if(sl > 0.0)
      {
         if(is_buy && sl >= entry - stop_level)
         {
            LogWarning("Pending order rejected: SL too close for buy");
            return false;
         }
         if(!is_buy && sl <= entry + stop_level)
         {
            LogWarning("Pending order rejected: SL too close for sell");
            return false;
         }
      }

      if(tp > 0.0)
      {
         if(is_buy && tp <= entry + stop_level)
         {
            LogWarning("Pending order rejected: TP too close for buy");
            return false;
         }
         if(!is_buy && tp >= entry - stop_level)
         {
            LogWarning("Pending order rejected: TP too close for sell");
            return false;
         }
      }

      return true;
   }

   double EnsurePendingOrderEntryDistance(const int order_type,
                                          const double entry,
                                          const MarketSnapshot &snapshot) const
   {
      const int stop_level_points = (int)SymbolInfoInteger(snapshot.symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(stop_level_points <= 0)
         return entry;

      const double stop_level = stop_level_points * snapshot.point;
      const double buffer = MathMax(snapshot.point, stop_level * 0.25);
      double adjusted_entry = entry;

      if(order_type == ORDER_TYPE_BUY_LIMIT)
      {
         const double max_allowed = snapshot.bid - stop_level;
         if(adjusted_entry >= max_allowed)
            adjusted_entry = max_allowed - buffer;
      }
      else if(order_type == ORDER_TYPE_SELL_LIMIT)
      {
         const double min_allowed = snapshot.ask + stop_level;
         if(adjusted_entry <= min_allowed)
            adjusted_entry = min_allowed + buffer;
      }
      if(adjusted_entry <= 0.0)
         return entry;
      return NormalizeDouble(NormalizePriceToTick(adjusted_entry), snapshot.digits);
   }

   void EvaluateStrategyExits()
   {
      // Build shared market data for exit evaluation.
      const MarketSnapshot snapshot = m_market.Snapshot(m_config.trade_symbol);
      const MarketHistory history = m_market.History(m_config.trade_symbol, m_config.execution_timeframe, 100);

      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         // Identify which strategy opened this position.
         const string comment = PositionGetString(POSITION_COMMENT);
         const string strategy_id = ExtractStrategyId(comment);
         if(strategy_id == "")
            continue;

         // RF12: strategy exit signal.
         if(ShouldCloseByStrategyId(strategy_id, ticket, snapshot, history))
         {
            CTrade trade;
            trade.PositionClose((long)ticket);
         }
      }
   }

   void HandleTimeBasedExits(const datetime now)
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         const string comment = PositionGetString(POSITION_COMMENT);
         const string strategy_id = ExtractStrategyId(comment);
         if(strategy_id == "")
            continue;

         StrategyContext ctx;
         if(!GetStrategyContext(strategy_id, ctx))
            continue;
         if(ctx.max_hold_minutes <= 0)
            continue;

         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if((now - open_time) >= (ctx.max_hold_minutes * 60))
         {
            CTrade trade;
            trade.PositionClose((long)ticket);
            NotifyTimeExit(strategy_id, ticket);
         }
      }
   }

   void NotifyTimeExit(const string strategy_id, const ulong ticket)
   {
      string msg = (string)EA_ID + " TIME_EXIT strategy=" + strategy_id +
                   " ticket=" + (string)ticket;
      if(m_config.enable_logging)
         m_logger.Warn(msg);
      m_notifier.Send(msg);
      Print(msg);
   }

   bool IsStrategyOrderLimitReached(const string strategy_id)
   {
      StrategyContext ctx;
      if(!GetStrategyContext(strategy_id, ctx))
         return false;
      if(ctx.max_orders <= 0)
         return false;
      const int open_positions = CountOpenPositionsByStrategy(strategy_id);
      const int pending_orders = CountPendingOrdersByStrategy(strategy_id);
      return ((open_positions + pending_orders) >= ctx.max_orders);
   }

   int CountOpenPositionsByStrategy(const string strategy_id)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         const string comment = PositionGetString(POSITION_COMMENT);
         if(CommentMatchesStrategy(comment, strategy_id))
            count++;
      }
      return count;
   }

   int CountPendingOrdersByStrategy(const string strategy_id)
   {
      int count = 0;
      for(int i = OrdersTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket))
            continue;
         const int type = (int)OrderGetInteger(ORDER_TYPE);
         if(!IsPendingOrderType(type))
            continue;
         const string comment = OrderGetString(ORDER_COMMENT);
         if(CommentMatchesStrategy(comment, strategy_id))
            count++;
      }
      return count;
   }

   bool HasPendingOrderForStrategy(const string strategy_id)
   {
      return (CountPendingOrdersByStrategy(strategy_id) > 0);
   }

   bool GetStrategyContext(const string strategy_id, StrategyContext &out_ctx)
   {
      if(strategy_id == "ADX")
      {
         out_ctx = m_strategy1.GetContext();
         return true;
      }
      if(strategy_id == "DTOSC")
      {
         out_ctx = m_strategy2.GetContext();
         return true;
      }
      if(strategy_id == "TACCEL")
      {
         out_ctx = m_strategy3.GetContext();
         return true;
      }
      if(strategy_id == "CWAVE")
      {
         out_ctx = m_strategy4.GetContext();
         return true;
      }
      if(strategy_id == "TRENDREV")
      {
         out_ctx = m_strategy5.GetContext();
         return true;
      }
      if(strategy_id == "OUTBAR")
      {
         out_ctx = m_strategy6.GetContext();
         return true;
      }
      return false;
   }

   bool ShouldCloseByStrategyId(const string strategy_id,
                                const ulong ticket,
                                const MarketSnapshot &snapshot,
                                const MarketHistory &history)
   {
      if(strategy_id == "ADX")
         return m_strategy1.ShouldClose(ticket, snapshot, history);
      if(strategy_id == "DTOSC")
         return m_strategy2.ShouldClose(ticket, snapshot, history);
      if(strategy_id == "TACCEL")
         return m_strategy3.ShouldClose(ticket, snapshot, history);
      if(strategy_id == "CWAVE")
         return m_strategy4.ShouldClose(ticket, snapshot, history);
      if(strategy_id == "TRENDREV")
         return m_strategy5.ShouldClose(ticket, snapshot, history);
      if(strategy_id == "OUTBAR")
         return m_strategy6.ShouldClose(ticket, snapshot, history);
      return false;
   }

   void UpdateStops()
   {
      if(!m_atr.IsReady())
         return;
      const double atr = m_atr.Value();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         const string comment = PositionGetString(POSITION_COMMENT);
         const string strategy_id = ExtractStrategyId(comment);
         if(strategy_id == "")
            continue;

         StrategyContext ctx;
         if(!GetStrategyContext(strategy_id, ctx))
            continue;

         double atr_entry = ExtractAtrFromComment(comment);
         if(atr_entry <= 0.0)
            atr_entry = atr;
         ApplyStopPolicy(ticket, ctx, atr_entry);
      }
   }

   void ApplyStopPolicy(const ulong ticket, const StrategyContext &ctx, const double atr)
   {
      const int type = (int)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);

      double desired_sl = sl;
      double desired_tp = tp;

      if(ctx.id == "OUTBAR" && ctx.stop_type == STOP_FIXED)
      {
         desired_sl = sl;
      }
      else if(ctx.stop_type == STOP_FIXED)
      {
         desired_sl = ComputeFixedStop(type, entry, atr, ctx.sl_atr_factor);
      }
      else if(ctx.stop_type == STOP_TRAILING)
      {
         desired_sl = ComputeTrailingStop(type, atr, ctx.trailing_atr_factor);
      }
      else if(ctx.stop_type == STOP_BREAK_EVEN)
      {
         desired_sl = ComputeBreakEvenStop(type, entry, atr, ctx.breakeven_trigger_atr, sl);
      }
      else if(ctx.stop_type == STOP_PROGRESSIVE)
      {
         desired_sl = ComputeProgressiveStop(type, entry, atr, ctx.sl_atr_factor,
                                             ctx.progressive_trigger_atr, ctx.progressive_step_atr, sl);
      }

      desired_sl = NormalizePriceToTick(desired_sl);
      desired_tp = NormalizePriceToTick(ComputeTakeProfit(type, entry, atr, ctx));

      bool modify = false;
      if(IsBetterStop(type, sl, desired_sl))
         modify = true;
      if(IsBetterTakeProfit(type, tp, desired_tp))
         modify = true;

      if(modify)
      {
         CTrade trade;
         trade.PositionModify((long)ticket, desired_sl, desired_tp);
      }
   }

   double ComputeFixedStop(const int type, const double entry, const double atr, const double factor)
   {
      if(type == POSITION_TYPE_BUY)
         return entry - (factor * atr);
      return entry + (factor * atr);
   }

   double ComputeTrailingStop(const int type, const double atr, const double factor)
   {
      if(factor <= 0.0)
         return 0.0;
      if(type == POSITION_TYPE_BUY)
         return SymbolInfoDouble(m_config.trade_symbol, SYMBOL_BID) - (factor * atr);
      return SymbolInfoDouble(m_config.trade_symbol, SYMBOL_ASK) + (factor * atr);
   }

   double ComputeBreakEvenStop(const int type, const double entry, const double atr,
                               const double trigger, const double current_sl)
   {
      if(trigger <= 0.0)
         return current_sl;
      const double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(m_config.trade_symbol, SYMBOL_BID)
                                                       : SymbolInfoDouble(m_config.trade_symbol, SYMBOL_ASK);
      const double move = (type == POSITION_TYPE_BUY) ? (price - entry) : (entry - price);
      if(move >= (trigger * atr))
         return entry + ((type == POSITION_TYPE_BUY) ? TickSize() : -TickSize());
      return current_sl;
   }

   double ComputeProgressiveStop(const int type, const double entry, const double atr,
                                 const double sl_factor, const double trigger, const double step,
                                 const double current_sl)
   {
      if(trigger <= 0.0 || step <= 0.0)
         return current_sl;
      const double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(m_config.trade_symbol, SYMBOL_BID)
                                                       : SymbolInfoDouble(m_config.trade_symbol, SYMBOL_ASK);
      const double move = (type == POSITION_TYPE_BUY) ? (price - entry) : (entry - price);
      if(move <= 0.0)
         return current_sl;
      const int steps = (int)MathFloor(move / (trigger * atr));
      if(steps <= 0)
         return current_sl;
      const double initial_sl = (type == POSITION_TYPE_BUY) ? (entry - (sl_factor * atr))
                                                            : (entry + (sl_factor * atr));
      const double shift = step * atr * steps;
      if(type == POSITION_TYPE_BUY)
         return initial_sl + shift;
      return initial_sl - shift;
   }

   double ComputeTakeProfit(const int type, const double entry, const double atr, const StrategyContext &ctx)
   {
      if(ctx.tp_type != TP_FIXED)
         return 0.0;
      if(type == POSITION_TYPE_BUY)
         return entry + (ctx.tp_atr_factor * atr);
      return entry - (ctx.tp_atr_factor * atr);
   }

   double NormalizePriceToTick(const double price) const
   {
      if(price <= 0.0)
         return price;
      const double tick = TickSize();
      if(tick <= 0.0)
         return price;
      const double ticks = MathRound(price / tick);
      return ticks * tick;
   }

   double TickSize() const
   {
      double tick = SymbolInfoDouble(m_config.trade_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0)
         tick = SymbolInfoDouble(m_config.trade_symbol, SYMBOL_POINT);
      return tick;
   }

   double CalculateRiskAmount(const double entry, const double sl, const string &symbol) const
   {
      if(entry <= 0.0 || sl <= 0.0)
         return 0.0;
      const double distance = MathAbs(entry - sl);
      if(distance <= 0.0)
         return 0.0;
      double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0)
         tick = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tick <= 0.0)
         return 0.0;
      const double ticks = distance / tick;
      const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_value <= 0.0)
         return 0.0;
      return ticks * tick_value * m_config.lot_size;
   }

   bool RiskExceeded(const string strategy_id, const double entry, const double sl, const string &symbol)
   {
      if(m_config.max_trade_risk <= 0.0)
         return false;
      const double risk = CalculateRiskAmount(entry, sl, symbol);
      if(risk <= 0.0)
         return false;
      if(risk > m_config.max_trade_risk)
      {
         LogWarning("Risk limit exceeded: strategy=" + strategy_id +
                    " risk=" + DoubleToString(risk, 2) +
                    " limit=" + DoubleToString(m_config.max_trade_risk, 2));
         return true;
      }
      return false;
   }

   bool IsBetterStop(const int type, const double current_sl, const double desired_sl)
   {
      if(desired_sl == 0.0)
         return false;
      if(current_sl == 0.0)
         return true;
      if(type == POSITION_TYPE_BUY)
         return (desired_sl > current_sl);
      return (desired_sl < current_sl);
   }

   bool IsBetterTakeProfit(const int type, const double current_tp, const double desired_tp)
   {
      if(desired_tp == 0.0)
         return false;
      if(current_tp == 0.0)
         return true;
      if(type == POSITION_TYPE_BUY)
         return (desired_tp > current_tp);
      return (desired_tp < current_tp);
   }

   bool IsPendingOrderType(const int type)
   {
      return (type == ORDER_TYPE_BUY_LIMIT ||
              type == ORDER_TYPE_SELL_LIMIT ||
              type == ORDER_TYPE_BUY_STOP ||
              type == ORDER_TYPE_SELL_STOP ||
              type == ORDER_TYPE_BUY_STOP_LIMIT ||
              type == ORDER_TYPE_SELL_STOP_LIMIT);
   }

   void EnsureDailyState(const datetime now)
   {
      const int key = DayKey(now);
      if(key == m_daily_day_key)
         return;

      m_daily_day_key = key;
      m_daily_blocked = false;
      m_daily_state.day = now;
      m_daily_state.trades_count = 0;
      m_daily_state.loss_trades_count = 0;
      m_daily_state.pnl = 0.0;
   }

   int DayKey(const datetime now)
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);
      return (dt.year * 10000) + (dt.mon * 100) + dt.day;
   }

   bool HandleDailyRisk(const datetime now)
   {
      if(m_daily_blocked)
      {
         CloseAllPositions();
         CancelAllPendingOrders();
         return true;
      }

      bool limit_hit = false;
      if(m_config.daily_loss_limit > 0.0 && m_daily_state.pnl <= -m_config.daily_loss_limit)
         limit_hit = true;
      if(m_config.daily_profit_limit > 0.0 && m_daily_state.pnl >= m_config.daily_profit_limit)
         limit_hit = true;
      if(m_config.max_trades_daily > 0 && m_daily_state.trades_count >= m_config.max_trades_daily)
         limit_hit = true;
      if(m_config.max_loss_trades_daily > 0 && m_daily_state.loss_trades_count >= m_config.max_loss_trades_daily)
         limit_hit = true;

      if(limit_hit)
      {
         m_daily_blocked = true;
         NotifyDailyBlock();
         CloseAllPositions();
         CancelAllPendingOrders();
         return true;
      }

      return false;
   }

   void NotifyDailyBlock()
   {
      string reason = "Daily risk limit reached";
      if(m_config.daily_loss_limit > 0.0 && m_daily_state.pnl <= -m_config.daily_loss_limit)
         reason = "Daily loss limit reached";
      else if(m_config.daily_profit_limit > 0.0 && m_daily_state.pnl >= m_config.daily_profit_limit)
         reason = "Daily profit limit reached";
      else if(m_config.max_trades_daily > 0 && m_daily_state.trades_count >= m_config.max_trades_daily)
         reason = "Daily trades limit reached";
      else if(m_config.max_loss_trades_daily > 0 && m_daily_state.loss_trades_count >= m_config.max_loss_trades_daily)
         reason = "Daily loss trades limit reached";

      if(m_config.enable_logging)
         m_logger.Warn(reason);
      m_notifier.Send(reason);
      Print(reason);
   }

   void HandleGlobalOrderLimit()
   {
      // <= 0 means "no global limit"
      if(m_config.max_orders_global <= 0)
         return;
      const int open_positions = PositionsTotal();
      if(open_positions >= m_config.max_orders_global)
      {
         CloseAllPositions();
         CancelAllPendingOrders();
         return;
      }
   }

   void HandleTradeTransaction(const MqlTradeTransaction &trans,
                               const MqlTradeRequest &request,
                               const MqlTradeResult &result)
   {
      if(!m_config.enable_notifications)
         return;
      const int type = (int)trans.type;
      if(type != TRADE_TRANSACTION_DEAL_ADD && type != TRADE_TRANSACTION_ORDER_ADD)
         return;

      string message = BuildTradeMessage(trans);
      if(message == "")
         return;

      if(m_config.enable_logging)
         m_logger.Info(message);
      m_notifier.Send(message);

      UpdateDailyStateFromDeal(trans);
   }

   string BuildTradeMessage(const MqlTradeTransaction &trans)
   {
      const int type = (int)trans.type;
      const ulong deal = trans.deal;
      const ulong order = trans.order;
      const double price = trans.price;
      const double volume = trans.volume;
      const string symbol = trans.symbol;
      string comment = "";
      datetime event_time = TimeCurrent();
      int entry = -1;
      int reason = -1;
      ulong position_id = 0;

      string action = "";
      if(type == TRADE_TRANSACTION_ORDER_ADD)
         action = "ORDER_ADD";
      else if(type == TRADE_TRANSACTION_DEAL_ADD)
         action = "DEAL_ADD";

      if(action == "")
         return "";

      string msg = (string)EA_ID + " " + action +
                   " symbol=" + symbol +
                   " price=" + DoubleToString(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) +
                   " volume=" + DoubleToString(volume, 2) +
                   " order=" + (string)order +
                   " deal=" + (string)deal;

      string open_time_str = "";
      string close_time_str = "";
      string duration_str = "";
      if(type == TRADE_TRANSACTION_DEAL_ADD)
      {
         double profit = 0.0;
         if(FetchDealInfo(deal, event_time, entry, reason, comment, position_id, profit))
         {
            if(entry == DEAL_ENTRY_IN)
            {
               open_time_str = TimeToString(event_time, TIME_DATE | TIME_SECONDS);
            }
            else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
            {
               close_time_str = TimeToString(event_time, TIME_DATE | TIME_SECONDS);
               datetime open_time = FindPositionOpenTime(position_id, event_time);
               if(open_time > 0)
               {
                  open_time_str = TimeToString(open_time, TIME_DATE | TIME_SECONDS);
                  duration_str = FormatDuration(event_time - open_time);
               }
            }
         }
      }

      if(open_time_str != "")
         msg += " open=" + open_time_str;
      if(close_time_str != "")
         msg += " close=" + close_time_str;
      if(duration_str != "")
         msg += " duration=" + duration_str;

      const string reason_str = DealReasonToString(reason);
      if(reason_str != "")
         msg += " reason=" + reason_str;
      if(comment != "")
         msg += " comment=" + comment;
      return msg;
   }

   bool FetchDealInfo(const ulong deal_ticket,
                      datetime &out_time,
                      int &out_entry,
                      int &out_reason,
                      string &out_comment,
                      ulong &out_position_id,
                      double &out_profit)
   {
      if(deal_ticket == 0)
         return false;
      if(!HistorySelect(0, TimeCurrent()))
         return false;
      out_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      out_entry = (int)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      out_reason = (int)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      out_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
      out_position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      out_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      return true;
   }

   void UpdateDailyStateFromDeal(const MqlTradeTransaction &trans)
   {
      if((int)trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return;

      datetime deal_time = 0;
      int entry = -1;
      int reason = -1;
      string comment = "";
      ulong position_id = 0;
      double profit = 0.0;

      if(!FetchDealInfo(trans.deal, deal_time, entry, reason, comment, position_id, profit))
         return;

      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         return;

      EnsureDailyState(deal_time);
      m_daily_state.trades_count++;
      if(profit < 0.0)
         m_daily_state.loss_trades_count++;
      m_daily_state.pnl += profit;
   }

   datetime FindPositionOpenTime(const ulong position_id, const datetime now)
   {
      if(position_id == 0)
         return 0;
      if(!HistorySelect(0, now))
         return 0;
      const int total = HistoryDealsTotal();
      datetime best_time = 0;
      for(int i = 0; i < total; ++i)
      {
         const ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if((ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID) != position_id)
            continue;
         const int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_IN)
            continue;
         const datetime t = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(best_time == 0 || t < best_time)
            best_time = t;
      }
      return best_time;
   }

   string FormatDuration(const long seconds)
   {
      if(seconds <= 0)
         return "";
      const long h = seconds / 3600;
      const long m = (seconds % 3600) / 60;
      const long s = seconds % 60;
      return (string)h + "h" + (string)m + "m" + (string)s + "s";
   }

   string DealReasonToString(const int reason)
   {
      switch(reason)
      {
         case DEAL_REASON_SL: return "SL";
         case DEAL_REASON_TP: return "TP";
         case DEAL_REASON_SO: return "SO";
         case DEAL_REASON_EXPERT: return "EXPERT";
         case DEAL_REASON_CLIENT: return "MANUAL";
         case DEAL_REASON_MOBILE: return "MOBILE";
         case DEAL_REASON_WEB: return "WEB";
         case DEAL_REASON_ROLLOVER: return "ROLLOVER";
         case DEAL_REASON_VMARGIN: return "VMARGIN";
         case DEAL_REASON_SPLIT: return "SPLIT";
         default: return "";
      }
   }

   void ValidatePermissions()
   {
      if(!m_config.enable_notifications)
         return;
      if(m_config.enable_email)
      {
         if(!TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
            LogWarning("Email enabled in EA but terminal email is disabled.");
      }
      if(m_config.enable_push)
      {
         if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
            LogWarning("Push enabled in EA but terminal notifications are disabled.");
      }
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      {
         LogWarning("Trading is not allowed in terminal. EA will not trade.");
      }
   }

   bool ValidateLicense()
   {
      m_license_ok = false;

      if(MQLInfoInteger(MQL_TESTER))
      {
         LogInfo("[DEBUG] ValidateLicense: TESTER mode detected");
         m_license_state.strategies_csv = "*";
         m_license_state.symbols_csv = "*";
         m_license_state.timeframes_csv = "*";
         m_license_state.max_lot = 0.0;
         LogInfo("[DEBUG] ValidateLicense: Set strategies_csv to '*'");
         m_license_ok = true;
         return true;
      }
      
      LogInfo("[DEBUG] ValidateLicense: Not in TESTER mode");
      if(LICENSE_BYPASS)
      {
         LogInfo("[DEBUG] ValidateLicense: LICENSE_BYPASS mode detected");
         m_license_state.strategies_csv = "*";
         m_license_state.symbols_csv = "*";
         m_license_state.timeframes_csv = "*";
         m_license_state.max_lot = 0.0;
         m_license_ok = true;
         return true;
      }

      if(m_config.license_key == "")
      {
         LogWarning("License key is empty");
         return false;
      }

      string error = "";
      if(!m_license.Decode(m_config.license_key, m_license_state, error))
      {
         LogWarning("License invalid: " + error);
         return false;
      }

      if(m_license_state.demo_only)
      {
         if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
         {
            LogWarning("Demo license requires a demo account");
            return false;
         }
         m_license_ok = true;
         LogLicenseDetails("DEMO");
         return true;
      }

      const long account = AccountInfoInteger(ACCOUNT_LOGIN);
      if(account != m_license_state.account)
      {
         LogWarning("License account mismatch. Expected=" + (string)m_license_state.account +
                    " Current=" + (string)account);
         return false;
      }

      m_license_ok = true;
      LogLicenseDetails("OK");
      return true;
   }

   bool HandleLicenseRuntime(const datetime now)
   {
      if(MQLInfoInteger(MQL_TESTER))
         return true;
      if(!m_license_ok)
         return false;
      if(LICENSE_BYPASS)
         return true;
      if(m_license.IsExpired(m_license_state, now))
      {
         LogWarning("License expired");
         return false;
      }
      WarnIfLicenseExpiringSoon(now);
      if(!m_license.IsSymbolAllowed(m_license_state, m_config.trade_symbol))
      {
         LogWarning("Symbol not allowed by license: " + m_config.trade_symbol);
         return false;
      }
      if(!m_license.IsTimeframeAllowed(m_license_state, m_config.execution_timeframe))
      {
         LogWarning("Timeframe not allowed by license");
         return false;
      }
      if(!m_license.IsLotAllowed(m_license_state, m_config.lot_size))
      {
         LogWarning("Lot size not allowed by license");
         return false;
      }
      return true;
   }

   bool ValidateIntegrityOnInit()
   {
      if(!m_config.enable_integrity)
         return true;
      string error = "";
      if(!m_integrity.Validate(m_config, error))
      {
         LogWarning("Config invalid: " + error);
         return false;
      }
      return true;
   }

   bool ValidateIntegrityRuntime()
   {
      if(!m_config.enable_integrity)
         return true;
      string error = "";
      if(!m_integrity.Validate(m_config, error))
      {
         LogWarning("Config invalid: " + error);
         return false;
      }
      return true;
   }

   void LogWarning(const string message)
   {
      if(m_config.enable_logging)
         m_logger.Warn(message);
      Print(message);
   }

   void LogInfo(const string message)
   {
      if(m_config.enable_logging)
         m_logger.Info(message);
      Print(message);
   }

   string BoolText(const bool value) const
   {
      return value ? "ON" : "OFF";
   }

   string FormatTime(const int hour, const int minute) const
   {
      return StringFormat("%02d:%02d", hour, minute);
   }

   string LicenseSummary() const
   {
      if(MQLInfoInteger(MQL_TESTER))
         return "TESTER";
      if(LICENSE_BYPASS)
         return "BYPASS";
      if(!m_license_ok)
         return "INVALID";
      if(m_license_state.demo_only)
         return "DEMO";
      return "OK";
   }

   void LogStartupSummary()
   {
      const string time_window = FormatTime(m_config.session_start_hour, m_config.session_start_minute) +
                                 "-" + FormatTime(m_config.session_end_hour, m_config.session_end_minute);

      LogInfo((string)EA_ID + " INIT OK");
      LogInfo("Symbol=" + m_config.trade_symbol + " | TF=" + EnumToString(m_config.execution_timeframe) +
              " | ATR=" + (string)m_config.atr_period + "/" + (string)m_config.atr_smooth_period +
              " " + EnumToString(m_config.atr_timeframe));
      LogInfo("TimeWindow=" + time_window + " | Grace=" + (string)m_config.close_grace_minutes +
              " | TimeExit=" + BoolText(m_config.enable_time_exit));
      LogInfo("TrendFilter=" + BoolText(m_config.trend_filter_enabled) +
              " | MA=" + (string)m_config.trend_ma_short_period + "/" +
              (string)m_config.trend_ma_medium_period + "/" +
              (string)m_config.trend_ma_long_period +
              " | Dist=" + DoubleToString(m_config.trend_dist_sm, 2) + "/" +
              DoubleToString(m_config.trend_dist_ml, 2));
      LogInfo("Orders: global=" + (string)m_config.max_orders_global +
              " | ADX=" + (string)m_config.adx_max_orders +
              " | DTOSC=" + (string)m_config.dtosc_max_orders +
              " | TACCEL=" + (string)m_config.trend_accel_max_orders +
              " | CWAVE=" + (string)m_config.candle_wave_max_orders +
              " | TRENDREV=" + (string)m_config.trend_reversal_max_orders +
              " | OUTBAR=" + (string)m_config.outsider_bar_max_orders);
      LogInfo("DailyRisk=" + BoolText(m_config.enable_daily_risk) +
              " | loss=" + DoubleToString(m_config.daily_loss_limit, 2) +
              " | profit=" + DoubleToString(m_config.daily_profit_limit, 2) +
              " | maxTrades=" + (string)m_config.max_trades_daily +
              " | maxLossTrades=" + (string)m_config.max_loss_trades_daily);
      LogInfo("Notifications=" + BoolText(m_config.enable_notifications) +
              " | LogFile=" + BoolText(m_config.enable_logging) +
              " | Email=" + BoolText(m_config.enable_email) +
              " | Push=" + BoolText(m_config.enable_push));
      LogInfo("Integrity=" + BoolText(m_config.enable_integrity) +
              " | License=" + LicenseSummary());
      LogInfo("Strategies: ADX=" + BoolText(m_strategy1.IsEnabled()) +
              " | DTOSC=" + BoolText(m_strategy2.IsEnabled()) +
              " | TACCEL=" + BoolText(m_strategy3.IsEnabled()) +
              " | CWAVE=" + BoolText(m_strategy4.IsEnabled()) +
              " | TRENDREV=" + BoolText(m_strategy5.IsEnabled()) +
              " | OUTBAR=" + BoolText(m_strategy6.IsEnabled()));
   }

   void LogLicenseDetails(const string status)
   {
      const string expires = (m_license_state.expires_at > 0)
         ? TimeToString(m_license_state.expires_at, TIME_DATE)
         : "N/A";
      LogInfo("LicenseStatus=" + status +
              " | Account=" + (string)m_license_state.account +
              " | Expires=" + expires +
              " | Symbols=" + m_license_state.symbols_csv +
              " | TFs=" + m_license_state.timeframes_csv +
              " | MaxLot=" + DoubleToString(m_license_state.max_lot, 2) +
              " | Strategies=" + m_license_state.strategies_csv);
   }

   void WarnIfLicenseExpiringSoon(const datetime now)
   {
      if(m_license_expiry_warned)
         return;
      if(m_license_state.expires_at <= 0)
         return;
      const int seconds_left = (int)(m_license_state.expires_at - now);
      if(seconds_left <= 0)
         return;
      const int days_left = seconds_left / 86400;
      if(days_left <= 7)
      {
         LogWarning("License expiring soon: " + (string)days_left + " day(s) left");
         m_license_expiry_warned = true;
      }
   }

   void CancelAllPendingOrders()
   {
      CTrade trade;
      for(int i = OrdersTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket))
            continue;
         trade.OrderDelete((long)ticket);
      }
   }

   void ExpirePendingOrders()
   {
      // Remove pending orders that exceeded their strategy TTL.
      const datetime now = TimeCurrent();
      CTrade trade;
      for(int i = OrdersTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket))
            continue;

         const int type = (int)OrderGetInteger(ORDER_TYPE);
         // Only pending order types are handled here.
         if(!IsPendingOrderType(type))
            continue;

         const string comment = OrderGetString(ORDER_COMMENT);
         // Strategy id is stored in the order comment.
         const string strategy_id = ExtractStrategyId(comment);
         if(strategy_id == "")
            continue;

         StrategyContext ctx;
         // Each strategy defines how long its pending orders may live.
         if(!GetStrategyContext(strategy_id, ctx))
            continue;
         if(ctx.pending_ttl_minutes <= 0)
            continue;

         const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         // Expire when now >= setup_time + TTL.
         if(now >= (setup_time + (ctx.pending_ttl_minutes * 60)))
         {
            trade.OrderDelete((long)ticket);
         }
      }
   }

   bool ValidateWindowConfig()
   {
      const int start_minutes = (m_config.session_start_hour * 60) + m_config.session_start_minute;
      const int end_minutes   = (m_config.session_end_hour * 60) + m_config.session_end_minute;
      return (end_minutes > start_minutes);
   }
};

#endif // EA_EACONTROLLER_MQH
