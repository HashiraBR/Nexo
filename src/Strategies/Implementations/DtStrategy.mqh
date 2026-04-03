// DT Oscillator strategy with EMA trend and candle pattern filters.
#ifndef EA_DTSTRATEGY_MQH
#define EA_DTSTRATEGY_MQH

#include "../Base/StrategyBase.mqh"
#include "../../Shared/CandlePatterns.mqh"

class DtStrategy : public StrategyBase
{
private:
   struct DtData
   {
      double dtosc;
      double dtoss;
   };

   struct RsiData
   {
      double chg_avg;
      double tot_chg;
      double last_price;
   };

   ENUM_TIMEFRAMES m_timeframe;
   int    m_rsi_period;
   int    m_stoch_period;
   int    m_slowing_period;
   int    m_signal_period;
   double m_dt_distance;
   string m_symbol;

   int    m_ma_short_period;
   int    m_ma_long_period;
   int    m_ma_short_handle;
   int    m_ma_long_handle;
   int    m_lower_zone;
   int    m_upper_zone;
   double m_ma_dist;

   DtData m_current_dt;
   DtData m_previous_dt;
   RsiData m_rsi_data;
   double m_stoch_buffer[];
   double m_dtosc_buffer[];
   double m_dtoss_buffer[];
   double m_last_close;
   double m_ema_short;
   double m_ema_long;

   int    m_last_signal; // 0=none, 1=buy, -1=sell
   double m_last_atr;
   CandlePattern m_last_pattern;
   bool   m_debug;

   void ResetBuffers()
   {
      ArrayResize(m_stoch_buffer, m_stoch_period);
      ArrayResize(m_dtosc_buffer, m_slowing_period);
      ArrayResize(m_dtoss_buffer, m_signal_period);
      ArrayInitialize(m_stoch_buffer, 0);
      ArrayInitialize(m_dtosc_buffer, 0);
      ArrayInitialize(m_dtoss_buffer, 0);
      m_rsi_data.chg_avg = 0.0;
      m_rsi_data.tot_chg = 0.0;
      m_rsi_data.last_price = 0.0;
      m_current_dt.dtosc = 0.0;
      m_current_dt.dtoss = 0.0;
      m_previous_dt = m_current_dt;
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
   }

   bool EnsureIndicators()
   {
      if(m_ma_short_handle != INVALID_HANDLE && m_ma_long_handle != INVALID_HANDLE)
         return true;
      if(m_ma_short_period <= 0 || m_ma_long_period <= 0)
         return false;
      m_ma_short_handle = iMA(m_symbol, m_timeframe, m_ma_short_period, 0, MODE_EMA, PRICE_CLOSE);
      m_ma_long_handle = iMA(m_symbol, m_timeframe, m_ma_long_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ma_short_handle == INVALID_HANDLE || m_ma_long_handle == INVALID_HANDLE)
      {
         ReleaseIndicators();
         return false;
      }
      return true;
   }

   double CalculateRsi(const double price)
   {
      if(m_rsi_data.last_price == 0.0)
      {
         m_rsi_data.last_price = price;
         return 50.0;
      }

      const double sf = 1.0 / m_rsi_period;
      const double change = price - m_rsi_data.last_price;
      m_rsi_data.chg_avg = m_rsi_data.chg_avg + sf * (change - m_rsi_data.chg_avg);
      m_rsi_data.tot_chg = m_rsi_data.tot_chg + sf * (MathAbs(change) - m_rsi_data.tot_chg);
      m_rsi_data.last_price = price;
      const double ratio = (m_rsi_data.tot_chg != 0.0) ? (m_rsi_data.chg_avg / m_rsi_data.tot_chg) : 0.0;
      return 50.0 * (ratio + 1.0);
   }

   double CalculateStochRsi(const double rsi_value)
   {
      for(int i = m_stoch_period - 1; i > 0; --i)
         m_stoch_buffer[i] = m_stoch_buffer[i - 1];
      m_stoch_buffer[0] = rsi_value;

      double min_v = rsi_value;
      double max_v = rsi_value;
      for(int i = 0; i < m_stoch_period; ++i)
      {
         min_v = MathMin(m_stoch_buffer[i], min_v);
         max_v = MathMax(m_stoch_buffer[i], max_v);
      }
      return (max_v != min_v) ? 100.0 * (rsi_value - min_v) / (max_v - min_v) : 0.0;
   }

   void CalculateDto(const double stoch_value)
   {
      for(int i = m_slowing_period - 1; i > 0; --i)
         m_dtosc_buffer[i] = m_dtosc_buffer[i - 1];
      m_dtosc_buffer[0] = stoch_value;

      double sum = 0.0;
      for(int i = 0; i < m_slowing_period; ++i)
         sum += m_dtosc_buffer[i];
      m_current_dt.dtosc = sum / m_slowing_period;

      for(int i = m_signal_period - 1; i > 0; --i)
         m_dtoss_buffer[i] = m_dtoss_buffer[i - 1];
      m_dtoss_buffer[0] = m_current_dt.dtosc;

      sum = 0.0;
      for(int i = 0; i < m_signal_period; ++i)
         sum += m_dtoss_buffer[i];
      m_current_dt.dtoss = sum / m_signal_period;
   }

   bool UpdateData(const double last_close)
   {
      if(!EnsureIndicators())
         return false;

      double ema_short_buf[];
      double ema_long_buf[];
      ArraySetAsSeries(ema_short_buf, true);
      ArraySetAsSeries(ema_long_buf, true);
      if(CopyBuffer(m_ma_short_handle, 0, 0, 2, ema_short_buf) != 2 ||
         CopyBuffer(m_ma_long_handle, 0, 0, 2, ema_long_buf) != 2)
         return false;

      m_previous_dt = m_current_dt;
      m_last_close = last_close;
      m_ema_short = ema_short_buf[1];
      m_ema_long = ema_long_buf[1];

      const double rsi_value = CalculateRsi(m_last_close);
      const double stoch_rsi = CalculateStochRsi(rsi_value);
      CalculateDto(stoch_rsi);
      return true;
   }

   bool IsBuySignalInternal()
   {
      const bool up_trend = m_ema_short > m_ema_long * (1.0 + m_ma_dist / 100.0);
      const bool cross_up = m_previous_dt.dtosc < m_previous_dt.dtoss &&
                            m_current_dt.dtosc > m_current_dt.dtoss &&
                            MathAbs(m_current_dt.dtosc - m_current_dt.dtoss) >= m_dt_distance;
      const bool below_zone = m_current_dt.dtosc < m_lower_zone && m_current_dt.dtoss < m_lower_zone;
      const bool price_above = m_last_close > m_ema_short;
      const bool pattern_ok = true;//IsBuyPatternSignal(m_last_pattern);
      const bool signal = cross_up && below_zone && price_above && up_trend && pattern_ok;
      if(m_debug)
      {
         Print("DT BUY signal=", signal,
               " upTrend=", up_trend,
               " crossUp=", cross_up,
               " belowZone=", below_zone,
               " priceAbove=", price_above,
               " pattern=", pattern_ok);
      }
      return signal;
   }

   bool IsSellSignalInternal()
   {
      const bool down_trend = m_ema_short < m_ema_long * (1.0 - m_ma_dist / 100.0);
      const bool cross_down = m_previous_dt.dtosc > m_previous_dt.dtoss &&
                              m_current_dt.dtosc < m_current_dt.dtoss &&
                              MathAbs(m_current_dt.dtosc - m_current_dt.dtoss) >= m_dt_distance;
      const bool above_zone = m_current_dt.dtosc > m_upper_zone && m_current_dt.dtoss > m_upper_zone;
      const bool price_below = m_last_close < m_ema_short;
      const bool pattern_ok = true;//IsSellPatternSignal(m_last_pattern);
      const bool signal = cross_down && above_zone && price_below && down_trend && pattern_ok;
      if(m_debug)
      {
         Print("DT SELL signal=", signal,
               " downTrend=", down_trend,
               " crossDown=", cross_down,
               " aboveZone=", above_zone,
               " priceBelow=", price_below,
               " pattern=", pattern_ok);
      }
      return signal;
   }

public:
   DtStrategy()
   {
      m_timeframe = PERIOD_CURRENT;
      m_rsi_period = 14;
      m_stoch_period = 14;
      m_slowing_period = 3;
      m_signal_period = 3;
      m_dt_distance = 5.0;
      m_symbol = "";
      m_ma_short_period = 9;
      m_ma_long_period = 21;
      m_ma_short_handle = INVALID_HANDLE;
      m_ma_long_handle = INVALID_HANDLE;
      m_lower_zone = 30;
      m_upper_zone = 70;
      m_ma_dist = 0.3;
      m_last_close = 0.0;
      m_ema_short = 0.0;
      m_ema_long = 0.0;
      m_last_signal = 0;
      m_last_atr = 0.0;
      m_last_pattern = PATTERN_NONE;
      m_debug = false;
      ResetBuffers();
   }

   ~DtStrategy()
   {
      ReleaseIndicators();
   }

   void Configure(const StrategyContext &ctx)
   {
      StrategyBase::Configure(ctx);
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_debug = ctx.debug;
      m_rsi_period = ctx.rsi_period;
      m_stoch_period = ctx.stoch_period;
      m_slowing_period = ctx.slowing_period;
      m_signal_period = ctx.signal_period;
      m_dt_distance = ctx.dt_distance;
      m_ma_short_period = ctx.ma_short_period;
      m_ma_long_period = ctx.ma_long_period;
      m_ma_dist = ctx.ma_dist;
      m_lower_zone = ctx.lower_zone;
      m_upper_zone = ctx.upper_zone;
      m_last_signal = 0;
      ResetBuffers();
      ReleaseIndicators();
      EnsureIndicators();
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      m_last_signal = 0;
      if(m_debug)
      {
         Print("DT OnNewCandle symbol=", market.symbol,
               " tf=", EnumToString(m_timeframe),
               " atr=", DoubleToString(atr, 5),
               " history=", history.count);
      }
      if(!enabled)
      {
         if(m_debug)
            Print("DT skip: strategy disabled");
         return;
      }
      if(atr <= 0.0)
      {
         if(m_debug)
            Print("DT skip: atr invalid", DoubleToString(atr, 5));
         return;
      }
      if(history.count <= 0)
      {
         if(m_debug)
            Print("DT skip: history empty");
         return;
      }
      m_last_atr = atr;
      if(m_symbol == "")
         m_symbol = market.symbol;
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;
      const MqlRates candle = history.rates[0];
      m_last_pattern = IdentifyPatternByAtr(
         candle.open,
         candle.high,
         candle.low,
         candle.close,
         0.0,
         0.0,
         m_last_atr,
         market.point,
         market.symbol
      );
      if(m_debug)
      {
         Print("DT pattern=", GetCandlePatternName(m_last_pattern),
               " atr=", DoubleToString(m_last_atr, 5),
               " point=", DoubleToString(market.point, 6),
               " close=", DoubleToString(candle.close, 5),
               " open=", DoubleToString(candle.open, 5));
      }
      if(!UpdateData(candle.close))
      {
         if(m_debug)
            Print("DT skip: UpdateData failed");
         return;
      }
      if(IsBuySignalInternal())
         m_last_signal = 1;
      else if(IsSellSignalInternal())
         m_last_signal = -1;
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

#endif // EA_DTSTRATEGY_MQH
