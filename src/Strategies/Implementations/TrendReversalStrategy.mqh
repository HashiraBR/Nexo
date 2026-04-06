// Trend Reversal strategy using EMA trend filter, candle reversal and volume confirmation.
#ifndef EA_TRENDREVERSALSTRATEGY_MQH
#define EA_TRENDREVERSALSTRATEGY_MQH

#include "../Base/StrategyBase.mqh"

class TrendReversalStrategy : public StrategyBase
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int    m_volume_avg_period;
   int    m_trend_ma_period;
   double m_candle_long_percent;
   double m_candle_max_atr;

   int    m_trend_ma_handle;
   int    m_last_signal; // 0=none, 1=buy, -1=sell
   double m_last_atr;
   bool   m_debug;

   void ResetState()
   {
      m_last_signal = 0;
      m_last_atr = 0.0;
   }

   void ReleaseIndicators()
   {
      if(m_trend_ma_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_trend_ma_handle);
         m_trend_ma_handle = INVALID_HANDLE;
      }
   }

   bool EnsureIndicators()
   {
      if(m_trend_ma_handle != INVALID_HANDLE)
         return true;
      if(m_trend_ma_period <= 0)
         return false;
      m_trend_ma_handle = iMA(m_symbol, m_timeframe, m_trend_ma_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_trend_ma_handle == INVALID_HANDLE)
         return false;
      return true;
   }

   bool ReadTrendEma(double &out_ema)
   {
      double ema_buf[];
      ArraySetAsSeries(ema_buf, true);
      if(CopyBuffer(m_trend_ma_handle, 0, 0, 2, ema_buf) != 2)
         return false;
      out_ema = ema_buf[1];
      return true;
   }

   bool VolumeAboveAverage(const MqlRates &rates[], const int count) const
   {
      if(m_volume_avg_period <= 0)
         return true;
      if(count < m_volume_avg_period)
         return false;

      double sum = 0.0;
      for(int i = 0; i < m_volume_avg_period; ++i)
         sum += (double)rates[i].real_volume;
      const double avg = sum / m_volume_avg_period;
      return ((double)rates[0].real_volume > avg);
   }

   bool IsCandleLong(const MqlRates &last_closed, const MqlRates &prior_closed) const
   {
      const double last_body = MathAbs(last_closed.close - last_closed.open);
      const double previous_body = MathAbs(prior_closed.close - prior_closed.open);
      return (last_body > previous_body * (1.0 + m_candle_long_percent / 100.0));
   }

   bool IsReversal(const bool trend_up, const MqlRates &last_closed, const MqlRates &prior_closed) const
   {
      if(trend_up)
         return (prior_closed.close < prior_closed.open &&
                 last_closed.close > last_closed.open &&
                 last_closed.close > prior_closed.open);
      return (prior_closed.close > prior_closed.open &&
              last_closed.close < last_closed.open &&
              last_closed.close < prior_closed.open);
   }

   bool IsCandleSizeValid(const MqlRates &last_closed) const
   {
      const double range = last_closed.high - last_closed.low;
      return (range <= (m_candle_max_atr * m_last_atr));
   }

public:
   TrendReversalStrategy()
   {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_volume_avg_period = 0;
      m_trend_ma_period = 0;
      m_candle_long_percent = 0.0;
      m_candle_max_atr = 1.0;
      m_trend_ma_handle = INVALID_HANDLE;
      m_last_signal = 0;
      m_last_atr = 0.0;
      m_debug = false;
   }

   ~TrendReversalStrategy()
   {
      ReleaseIndicators();
   }

   void Configure(const StrategyContext &ctx)
   {
      Print("Oi 1");
      StrategyBase::Configure(ctx);
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_volume_avg_period = ctx.volume_avg_period;
      m_trend_ma_period = ctx.trend_ma_period;
      m_candle_long_percent = ctx.candle_long_percent;
      m_candle_max_atr = ctx.candle_max_atr;
      ResetState();
      //Print("Oi 2");
      ReleaseIndicators();
      //Print("Oi 3");
      EnsureIndicators();
      //Print("Oi 4");
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      //Print("Aqui 1");
      m_last_signal = 0;
      if(!enabled)
         return;
      
      //Print("Aqui 2");
      if(atr <= 0.0)
         return;

      //Print("Aqui 3");
      if(history.count < 2)
         return;
      
      //Print("Aqui 4");
      m_last_atr = atr;
      if(m_symbol == "")
         m_symbol = market.symbol;

      //Print("Aqui 5");
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;

      //Print("Aqui 6");
      if(!EnsureIndicators())
         return;

      //Print("Aqui 7");
      const int needed = MathMax(2, m_volume_avg_period);
      if(history.count < needed)
         return;
      
      //Print("Aqui 8");
      if(!VolumeAboveAverage(history.rates, history.count))
         return;

      //Print("Aqui 9");
      double ema_trend = 0.0;
      if(!ReadTrendEma(ema_trend))
         return;

      //Print("Aqui 10");

      const MqlRates latest_closed = history.rates[0];
      const MqlRates prior_closed = history.rates[1];

      const bool trend_up = latest_closed.close > ema_trend;
      const bool trend_down = latest_closed.close < ema_trend;

      Print("TrendReversal OnNewCandle: " +
            "trendUp=" + (string)trend_up +
            " trendDown=" + (string)trend_down +
            " ema=" + DoubleToString(ema_trend, 2) +
            " close=" + DoubleToString(latest_closed.close, 2)+
            " prevClose=" + DoubleToString(prior_closed.close, 2));

      if(!trend_up && !trend_down)
         return;

      if(!IsCandleLong(latest_closed, prior_closed))
         return;
      if(!IsReversal(trend_up, latest_closed, prior_closed))
         return;
      if(!IsCandleSizeValid(latest_closed))
         return;

      if(trend_up)
         m_last_signal = 1;
      else if(trend_down)
         m_last_signal = -1;

      if(m_debug)
      {
         Print("TrendReversal signal=" + (string)m_last_signal +
               " trendUp=" + (string)trend_up +
               " trendDown=" + (string)trend_down);
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

   bool ShouldClose(const ulong position_ticket,
                    const MarketSnapshot &market,
                    const MarketHistory &history)
   {
      return false;
   }
};

#endif // EA_TRENDREVERSALSTRATEGY_MQH
