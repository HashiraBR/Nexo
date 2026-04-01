// Trend Accelerator strategy using EMA trend/acceleration and RSI filter.
#ifndef EA_TRENDACCELERATORSTRATEGY_MQH
#define EA_TRENDACCELERATORSTRATEGY_MQH

#include "../Base/StrategyBase.mqh"

class TrendAcceleratorStrategy : public StrategyBase
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   int    m_ma_short_period;
   int    m_ma_long_period;
   double m_ma_dist;
   double m_accel_dist;

   int    m_rsi_period;
   int    m_rsi_upper;
   int    m_rsi_lower;

   int    m_ma_short_handle;
   int    m_ma_long_handle;
   int    m_rsi_handle;

   double m_ma_short;
   double m_ma_short_prev;
   double m_ma_long;
   double m_rsi_value;
   double m_last_atr;
   double m_last_low;
   double m_last_high;
   double m_prev_low;
   double m_prev_high;
   double m_entry_price;
   double m_stop_price;
   int    m_order_type;

   int    m_last_signal; // 0=none, 1=buy, -1=sell
   bool   m_debug;

   void ResetState()
   {
      m_last_signal = 0;
      m_ma_short = 0.0;
      m_ma_short_prev = 0.0;
      m_ma_long = 0.0;
      m_rsi_value = 0.0;
      m_last_atr = 0.0;
      m_last_low = 0.0;
      m_last_high = 0.0;
      m_prev_low = 0.0;
      m_prev_high = 0.0;
      m_entry_price = 0.0;
      m_stop_price = 0.0;
      m_order_type = -1;
   }

   void ReleaseIndicators()
   {
      if(m_ma_short_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_ma_short_handle);
         m_ma_short_handle = INVALID_HANDLE;
      }
      if(m_ma_long_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_ma_long_handle);
         m_ma_long_handle = INVALID_HANDLE;
      }
      if(m_rsi_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi_handle);
         m_rsi_handle = INVALID_HANDLE;
      }
   }

   bool EnsureIndicators()
   {
      if(m_ma_short_handle != INVALID_HANDLE &&
         m_ma_long_handle != INVALID_HANDLE &&
         m_rsi_handle != INVALID_HANDLE)
         return true;

      if(m_ma_short_period <= 0 || m_ma_long_period <= 0 || m_rsi_period <= 0)
         return false;

      m_ma_short_handle = iMA(m_symbol, m_timeframe, m_ma_short_period, 0, MODE_EMA, PRICE_CLOSE);
      m_ma_long_handle = iMA(m_symbol, m_timeframe, m_ma_long_period, 0, MODE_EMA, PRICE_CLOSE);
      m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);

      if(m_ma_short_handle == INVALID_HANDLE ||
         m_ma_long_handle == INVALID_HANDLE ||
         m_rsi_handle == INVALID_HANDLE)
      {
         ReleaseIndicators();
         return false;
      }
      return true;
   }

   bool UpdateData()
   {
      if(!EnsureIndicators())
         return false;

      double ma_short_buf[];
      double ma_long_buf[];
      double rsi_buf[];
      ArraySetAsSeries(ma_short_buf, true);
      ArraySetAsSeries(ma_long_buf, true);
      ArraySetAsSeries(rsi_buf, true);

      if(CopyBuffer(m_ma_short_handle, 0, 0, 3, ma_short_buf) != 3 ||
         CopyBuffer(m_ma_long_handle, 0, 0, 2, ma_long_buf) != 2 ||
         CopyBuffer(m_rsi_handle, 0, 0, 2, rsi_buf) != 2)
         return false;

      m_ma_short = ma_short_buf[1];
      m_ma_short_prev = ma_short_buf[2];
      m_ma_long = ma_long_buf[1];
      m_rsi_value = rsi_buf[1];
      return true;
   }

   bool IsBuySignalInternal()
   {
      bool trend_up = (m_ma_short > m_ma_long);
      if(m_ma_dist > 0.0)
         trend_up = (m_ma_short > m_ma_long * (1.0 + m_ma_dist / 100.0));

      const bool accel_up = (m_ma_short > m_ma_short_prev * (1.0 + m_accel_dist / 100.0));
      const bool rsi_ok = (m_rsi_value < m_rsi_upper);
      const bool price_ok = (m_last_low > m_ma_short);

      const bool signal = (trend_up && accel_up && rsi_ok && price_ok);
      if(m_debug)
      {
         Print("TrendAccel BUY signal=", signal,
               " trendUp=", trend_up,
               " accelUp=", accel_up,
               " rsiOk=", rsi_ok,
               " priceOk=", price_ok,
               " atr=", DoubleToString(m_last_atr, 2));
      }
      return signal;
   }

   bool IsSellSignalInternal()
   {
      bool trend_down = (m_ma_short < m_ma_long);
      if(m_ma_dist > 0.0)
         trend_down = (m_ma_short < m_ma_long * (1.0 - m_ma_dist / 100.0));

      const bool accel_down = (m_ma_short < m_ma_short_prev * (1.0 - m_accel_dist / 100.0));
      const bool rsi_ok = (m_rsi_value > m_rsi_lower);
      const bool price_ok = (m_last_high < m_ma_short);

      const bool signal = (trend_down && accel_down && rsi_ok && price_ok);
      if(m_debug)
      {
         Print("TrendAccel SELL signal=", signal,
               " trendDown=", trend_down,
               " accelDown=", accel_down,
               " rsiOk=", rsi_ok,
               " priceOk=", price_ok,
               " atr=", DoubleToString(m_last_atr, 2));
      }
      return signal;
   }

public:
   TrendAcceleratorStrategy()
   {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_ma_short_period = 0;
      m_ma_long_period = 0;
      m_ma_dist = 0.0;
      m_accel_dist = 0.0;
      m_rsi_period = 0;
      m_rsi_upper = 70;
      m_rsi_lower = 30;
      m_ma_short_handle = INVALID_HANDLE;
      m_ma_long_handle = INVALID_HANDLE;
      m_rsi_handle = INVALID_HANDLE;
      m_debug = false;
      ResetState();
   }

   ~TrendAcceleratorStrategy()
   {
      ReleaseIndicators();
   }

   void Configure(const StrategyContext &ctx)
   {
      StrategyBase::Configure(ctx);
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_ma_short_period = ctx.ma_short_period;
      m_ma_long_period = ctx.ma_long_period;
      m_ma_dist = ctx.ma_dist;
      m_accel_dist = ctx.accel_dist;
      m_rsi_period = ctx.rsi_period;
      m_rsi_upper = ctx.rsi_upper;
      m_rsi_lower = ctx.rsi_lower;
      ResetState();
      ReleaseIndicators();
      EnsureIndicators();
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      m_last_signal = 0;
      m_entry_price = 0.0;
      m_stop_price = 0.0;
      m_order_type = -1;
      if(!enabled)
         return;
      if(atr <= 0.0)
         return;
      if(history.count < 2)
         return;
      m_last_atr = atr;
      if(m_symbol == "")
         m_symbol = market.symbol;
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;
      m_last_low = history.rates[0].low;
      m_last_high = history.rates[0].high;
      m_prev_low = history.rates[1].low;
      m_prev_high = history.rates[1].high;
      if(!UpdateData())
         return;
      if(IsBuySignalInternal())
      {
         m_last_signal = 1;
         m_order_type = ORDER_TYPE_BUY_LIMIT;
         m_entry_price = MathMin(m_last_low, m_prev_low);
         m_stop_price = m_entry_price - (context.sl_atr_factor * m_last_atr);
      }
      else if(IsSellSignalInternal())
      {
         m_last_signal = -1;
         m_order_type = ORDER_TYPE_SELL_LIMIT;
         m_entry_price = MathMax(m_last_high, m_prev_high);
         m_stop_price = m_entry_price + (context.sl_atr_factor * m_last_atr);
      }
   }

   void OnTick()
   {
   }

   bool ShouldOpen()
   {
      return (m_last_signal != 0);
   }

   bool ShouldOpenBuy()
   {
      if(m_last_signal == 1)
      {
         m_last_signal = 0;
         return true;
      }
      return false;
   }

   bool ShouldOpenSell()
   {
      if(m_last_signal == -1)
      {
         m_last_signal = 0;
         return true;
      }
      return false;
   }

   bool UsesPendingOrders()
   {
      return true;
   }

   int PendingOrderType()
   {
      return m_order_type;
   }

   double PendingEntryPrice()
   {
      return m_entry_price;
   }

   double PendingStopLoss()
   {
      return m_stop_price;
   }

   double PendingTakeProfit()
   {
      return 0.0;
   }

   bool ShouldClose(const ulong position_ticket,
                    const MarketSnapshot &market,
                    const MarketHistory &history)
   {
      return false;
   }
};

#endif // EA_TRENDACCELERATORSTRATEGY_MQH
