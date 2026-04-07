// Candle Wave strategy using configurable candle patterns and ATR-based sizing.
#ifndef EA_CANDLEWAVESTRATEGY_MQH
#define EA_CANDLEWAVESTRATEGY_MQH

#include "../Base/StrategyBase.mqh"
#include "../../Shared/CandlePatterns.mqh"
#include "../../Shared/TrendDirection.mqh"

class CandleWaveStrategy : public StrategyBase
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int    m_volume_avg_period;
   int    m_trend_ma_period;
   CandlePatternConfig m_pattern_configs[CANDLE_PATTERN_COUNT];

   int    m_last_signal; // 0=none, 1=buy, -1=sell
   double m_last_atr;
   bool   m_debug;
   int    m_trend_ma_handle;
   TrendDirection m_market_trend;

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
         return true;
      m_trend_ma_handle = iMA(m_symbol, m_timeframe, m_trend_ma_period, 0, MODE_EMA, PRICE_CLOSE);
      if(m_trend_ma_handle == INVALID_HANDLE)
         return false;
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

   bool DetectPattern(const MarketSnapshot &snapshot,
                      const MqlRates &candle,
                      CandlePattern &out_pattern) const
   {
      for(int i = 1; i < CANDLE_PATTERN_COUNT; ++i)
      {
         if(!m_pattern_configs[i].enabled)
            continue;
         const CandlePattern pattern = IdentifyPatternByAtr(
            candle.open,
            candle.high,
            candle.low,
            candle.close,
            m_pattern_configs[i].min_atr,
            m_pattern_configs[i].max_atr,
            m_last_atr,
            snapshot.point,
            snapshot.symbol
         );
         if(pattern == (CandlePattern)i)
         {
            out_pattern = pattern;
            return true;
         }
      }
      return false;
   }

   /*
   bool ReadTrendEma(double &out_ema)
   {
      if(m_trend_ma_period <= 0)
         return true;
      if(!EnsureIndicators())
         return false;
      double ema_buf[];
      ArraySetAsSeries(ema_buf, true);
      if(CopyBuffer(m_trend_ma_handle, 0, 0, 2, ema_buf) != 2)
         return false;
      out_ema = ema_buf[1];
      return true;
   }
*/

   bool ReadTrendEma(double &out_ema)
   {
      if(m_trend_ma_period <= 0)
         return true;
      if(!EnsureIndicators())
         return false;
      double ema_buf[];
      ArraySetAsSeries(ema_buf, true);
      if(CopyBuffer(m_trend_ma_handle, 0, 0, 2, ema_buf) != 2)
         return false;
      out_ema = ema_buf[1];
      return true;
   }

public:
   CandleWaveStrategy()
   {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_volume_avg_period = 0;
      m_trend_ma_period = 0;
      m_debug = false;
      m_trend_ma_handle = INVALID_HANDLE;
      m_market_trend = TREND_NONE;
      for(int i = 0; i < CANDLE_PATTERN_COUNT; ++i)
      {
         m_pattern_configs[i].enabled = false;
         m_pattern_configs[i].min_atr = 0.0;
         m_pattern_configs[i].max_atr = 0.0;
      }
      ResetState();
   }

   ~CandleWaveStrategy()
   {
      ReleaseIndicators();
   }

   void SetMarketTrend(const TrendDirection trend)
   {
      m_market_trend = trend;
   }

   void Configure(const StrategyContext &ctx)
   {
      StrategyBase::Configure(ctx);
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_volume_avg_period = ctx.volume_avg_period;
      m_trend_ma_period = ctx.trend_ma_period;
      for(int i = 0; i < CANDLE_PATTERN_COUNT; ++i)
         m_pattern_configs[i] = ctx.pattern_configs[i];
      ResetState();
      ReleaseIndicators();
      EnsureIndicators();
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      m_last_signal = 0;
      if(!enabled)
         return;
      if(atr <= 0.0)
         return;
      m_last_atr = atr;
      if(m_symbol == "")
         m_symbol = market.symbol;
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;
      if(!EnsureIndicators())
         return;

      const int needed = MathMax(2, m_volume_avg_period);
      if(history.count < needed)
         return;
      if(!VolumeAboveAverage(history.rates, history.count))
         return;

      const MqlRates candle = history.rates[0];
      CandlePattern pattern = PATTERN_NONE;
      if(!DetectPattern(market, candle, pattern))
         return;

      const bool is_buy_pattern = IsBuyPatternSignal(pattern);
      const bool is_sell_pattern = IsSellPatternSignal(pattern);
      double ema_trend = 0.0;
      if(!ReadTrendEma(ema_trend))
         return;
      const bool trend_up = (m_trend_ma_period <= 0) ? true : (candle.close > ema_trend);
      const bool trend_down = (m_trend_ma_period <= 0) ? true : (candle.close < ema_trend);
      const bool allow_buy = true;//(m_market_trend == TREND_UP);
      const bool allow_sell = true;//(m_market_trend == TREND_DOWN);

      if(is_buy_pattern && trend_up && allow_buy)
         m_last_signal = 1;
      else if(is_sell_pattern && trend_down && allow_sell)
         m_last_signal = -1;

      if(m_debug)
      {
         Print("CandleWave signal=" + (string)m_last_signal +
               " pattern=" + GetCandlePatternName(pattern) +
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

#endif // EA_CANDLEWAVESTRATEGY_MQH
