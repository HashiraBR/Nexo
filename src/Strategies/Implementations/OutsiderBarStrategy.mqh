// Outsider Bar strategy with EMA + RSI filter and pending breakout orders.
#ifndef EA_OUTSIDERBARSTRATEGY_MQH
#define EA_OUTSIDERBARSTRATEGY_MQH

#include "../Base/StrategyBase.mqh"

class OutsiderBarStrategy : public StrategyBase
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int    m_ma_period;
   int    m_rsi_period;
   int    m_rsi_buy_low;
   int    m_rsi_buy_high;
   int    m_rsi_sell_low;
   int    m_rsi_sell_high;
   double m_body_ratio;
   double m_safe_range;

   int    m_ma_handle;
   int    m_rsi_handle;
   int    m_last_signal; // 0=none, 1=buy, -1=sell
   double m_entry_price;
   double m_stop_price;
   int    m_order_type;
   bool   m_debug;

   void ResetState()
   {
      m_last_signal = 0;
      m_entry_price = 0.0;
      m_stop_price = 0.0;
      m_order_type = -1;
   }

   void ReleaseIndicators()
   {
      if(m_ma_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_ma_handle);
         m_ma_handle = INVALID_HANDLE;
      }
      if(m_rsi_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsi_handle);
         m_rsi_handle = INVALID_HANDLE;
      }
   }

   bool EnsureIndicators()
   {
      if(m_ma_handle == INVALID_HANDLE)
      {
         if(m_ma_period <= 0)
            return false;
         m_ma_handle = iMA(m_symbol, m_timeframe, m_ma_period, 0, MODE_EMA, PRICE_CLOSE);
         if(m_ma_handle == INVALID_HANDLE)
            return false;
      }
      if(m_rsi_handle == INVALID_HANDLE)
      {
         if(m_rsi_period <= 0)
            return false;
         m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
         if(m_rsi_handle == INVALID_HANDLE)
            return false;
      }
      return true;
   }

   bool ReadIndicators(double &out_ma, double &out_rsi) const
   {
      double ma_buf[];
      double rsi_buf[];
      ArraySetAsSeries(ma_buf, true);
      ArraySetAsSeries(rsi_buf, true);
      if(CopyBuffer(m_ma_handle, 0, 1, 1, ma_buf) != 1)
         return false;
      if(CopyBuffer(m_rsi_handle, 0, 1, 1, rsi_buf) != 1)
         return false;
      out_ma = ma_buf[0];
      out_rsi = rsi_buf[0];
      return true;
   }

   bool IsOutsideBar(const MqlRates &latest, const MqlRates &previous) const
   {
      return (latest.high > previous.high && latest.low < previous.low);
   }

   bool IsFullBody(const MqlRates &candle) const
   {
      const double range = candle.high - candle.low;
      if(range <= 0.0)
         return false;
      const double body = MathAbs(candle.close - candle.open);
      return (body >= range * m_body_ratio);
   }

   void AdjustStopForMinimumDistance(const double entry, const double point)
   {
      const double min_distance = 10.0 * point;
      const double buffer = 15.0 * point;
      if(entry <= 0.0 || m_stop_price <= 0.0)
         return;
      const double distance = MathAbs(entry - m_stop_price);
      if(distance > min_distance)
         return;
      const double target = min_distance + buffer;
      if(m_order_type == ORDER_TYPE_BUY_STOP)
         m_stop_price = entry - target;
      else if(m_order_type == ORDER_TYPE_SELL_STOP)
         m_stop_price = entry + target;
   }

public:
   OutsiderBarStrategy()
   {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_ma_period = 0;
      m_rsi_period = 0;
      m_rsi_buy_low = 0;
      m_rsi_buy_high = 0;
      m_rsi_sell_low = 0;
      m_rsi_sell_high = 0;
      m_body_ratio = 0.0;
      m_safe_range = 0.0;
      m_ma_handle = INVALID_HANDLE;
      m_rsi_handle = INVALID_HANDLE;
      m_debug = false;
      ResetState();
   }

   ~OutsiderBarStrategy()
   {
      ReleaseIndicators();
   }

   void Configure(const StrategyContext &ctx)
   {
      StrategyBase::Configure(ctx);
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_ma_period = ctx.outsider_ma_period;
      m_rsi_period = ctx.outsider_rsi_period;
      m_rsi_buy_low = ctx.outsider_rsi_buy_low;
      m_rsi_buy_high = ctx.outsider_rsi_buy_high;
      m_rsi_sell_low = ctx.outsider_rsi_sell_low;
      m_rsi_sell_high = ctx.outsider_rsi_sell_high;
      m_body_ratio = ctx.outsider_body_ratio;
      m_safe_range = ctx.outsider_safe_range;
      ResetState();
      ReleaseIndicators();
      EnsureIndicators();
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      ResetState();
      if(!enabled)
         return;
      if(history.count < 2)
         return;
      if(m_symbol == "")
         m_symbol = market.symbol;
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;
      if(!EnsureIndicators())
         return;

      double ma_value = 0.0;
      double rsi_value = 0.0;
      if(!ReadIndicators(ma_value, rsi_value))
         return;

      const MqlRates latest_closed = history.rates[0];
      const MqlRates previous = history.rates[1];

      const bool outside = IsOutsideBar(latest_closed, previous);
      const bool full_body = IsFullBody(latest_closed);
      if(!outside || !full_body)
         return;

      const bool is_green = latest_closed.close > latest_closed.open;
      const bool is_red = latest_closed.close < latest_closed.open;
      const bool above_ma = (latest_closed.close > ma_value * (1.0 + m_safe_range / 100.0));
      const bool below_ma = (latest_closed.close < ma_value * (1.0 - m_safe_range / 100.0));
      const bool rsi_buy = (rsi_value >= m_rsi_buy_low && rsi_value <= m_rsi_buy_high);
      const bool rsi_sell = (rsi_value >= m_rsi_sell_low && rsi_value <= m_rsi_sell_high);

      if(above_ma && rsi_buy && is_green)
      {
         m_last_signal = 1;
         m_order_type = ORDER_TYPE_BUY_STOP;
         m_entry_price = latest_closed.high;
         m_stop_price = latest_closed.low;
      }
      else if(below_ma && rsi_sell && is_red)
      {
         m_last_signal = -1;
         m_order_type = ORDER_TYPE_SELL_STOP;
         m_entry_price = latest_closed.low;
         m_stop_price = latest_closed.high;
      }

      if(m_last_signal != 0)
         AdjustStopForMinimumDistance(m_entry_price, market.point);

      if(m_debug)
      {
         Print("OutsiderBar signal=" + (string)m_last_signal +
               " aboveMA=" + (string)above_ma +
               " belowMA=" + (string)below_ma +
               " rsi=" + DoubleToString(rsi_value, 2) +
               " outside=" + (string)outside +
               " fullBody=" + (string)full_body);
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

#endif // EA_OUTSIDERBARSTRATEGY_MQH
