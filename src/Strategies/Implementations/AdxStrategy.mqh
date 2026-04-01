// ADX strategy - signal generation based on DI cross and ADX acceleration.
#ifndef EA_ADXSTRATEGY_MQH
#define EA_ADXSTRATEGY_MQH

#include "../Base/StrategyBase.mqh"

class AdxStrategy : public StrategyBase
{
private:
   int    m_adx_handle;
   double m_adx_values[];
   double m_plus_di[];
   double m_minus_di[];

   bool   m_trade_buy_flag;
   bool   m_trade_sell_flag;
   int    m_last_signal; // 0=none, 1=buy, -1=sell

   int    m_adx_period;
   double m_adx_step;
   double m_adx_min;
   double m_di_diff_min;
   double m_atr_min;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   void ResetSignals()
   {
      m_trade_buy_flag = false;
      m_trade_sell_flag = false;
   }

   bool EnsureIndicator()
   {
      if(m_adx_handle != INVALID_HANDLE)
         return true;
      if(m_adx_period <= 0)
         return false;
      m_adx_handle = iADX(m_symbol, m_timeframe, m_adx_period);
      if(m_adx_handle == INVALID_HANDLE)
         return false;
      return true;
   }

   void ReleaseIndicator()
   {
      if(m_adx_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_adx_handle);
         m_adx_handle = INVALID_HANDLE;
      }
   }

   bool UpdateData()
   {
      if(!EnsureIndicator())
         return false;
      if(CopyBuffer(m_adx_handle, 0, 0, 3, m_adx_values) != 3 ||
         CopyBuffer(m_adx_handle, 1, 0, 3, m_plus_di) != 3 ||
         CopyBuffer(m_adx_handle, 2, 0, 3, m_minus_di) != 3)
         return false;

      if(!m_trade_buy_flag && m_plus_di[2] < m_minus_di[2] && m_plus_di[1] > m_minus_di[1])
         m_trade_buy_flag = true;
      if(!m_trade_sell_flag && m_plus_di[2] > m_minus_di[2] && m_plus_di[1] < m_minus_di[1])
         m_trade_sell_flag = true;
      return true;
   }

   bool IsBuySignal()
   {
      const bool buy_signal = ((m_plus_di[1] > m_adx_values[1]) &&
                               (m_adx_values[2] < MathAbs(m_adx_values[1] - m_adx_step)) &&
                               (m_plus_di[1] > m_minus_di[1])) && m_trade_buy_flag;
      if(buy_signal)
         ResetSignals();
      return buy_signal;
   }

   bool IsSellSignal()
   {
      const bool sell_signal = ((m_minus_di[1] > m_adx_values[1]) &&
                                (m_adx_values[2] < MathAbs(m_adx_values[1] - m_adx_step)) &&
                                (m_minus_di[1] > m_plus_di[1])) && m_trade_sell_flag;
      if(sell_signal)
         ResetSignals();
      return sell_signal;
   }

public:
   AdxStrategy()
   {
      m_adx_handle = INVALID_HANDLE;
      m_trade_buy_flag = false;
      m_trade_sell_flag = false;
      m_last_signal = 0;
      ArraySetAsSeries(m_adx_values, true);
      ArraySetAsSeries(m_plus_di, true);
      ArraySetAsSeries(m_minus_di, true);
      m_adx_period = 0;
      m_adx_step = 0.0;
      m_adx_min = 0.0;
      m_di_diff_min = 0.0;
      m_atr_min = 0.0;
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
   }

   ~AdxStrategy()
   {
      ReleaseIndicator();
   }

   void Configure(const StrategyContext &ctx)
   {
      StrategyBase::Configure(ctx);
      m_adx_period = ctx.param1;
      m_adx_step = (double)ctx.param2;
      m_adx_min = ctx.param3;
      m_di_diff_min = ctx.param4;
      m_atr_min = ctx.param5;
      m_symbol = ctx.symbol;
      m_timeframe = ctx.timeframe;
      m_last_signal = 0;
      ResetSignals();
      ReleaseIndicator();
      EnsureIndicator();
   }

   void OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
   {
      m_last_signal = 0;
      if(!enabled)
         return;
      if(m_symbol == "")
         m_symbol = market.symbol;
      if(m_timeframe == PERIOD_CURRENT)
         m_timeframe = context.timeframe;
      if(!UpdateData())
         return;

      // 1) Filtro de ADX minimo para mercado lateral
      if(m_adx_min > 0.0 && m_adx_values[1] < m_adx_min)
      {
         return;
      }

      // 2) Confirmacao de tendencia em 3 candles (ADX acelerando)
      if(!(m_adx_values[0] > m_adx_values[1] && m_adx_values[1] > m_adx_values[2]))
      {
         return;
      }

      // 3) Diferenca minima entre +DI e -DI (valor absoluto)
      {
         const double di_diff = MathAbs(m_plus_di[1] - m_minus_di[1]);
         if(di_diff < m_di_diff_min)
            return;
      }

      // 4) ATR minimo para evitar mercado parado
      if(m_atr_min > 0.0 && atr < m_atr_min)
      {
         return;
      }

      if(IsBuySignal())
         m_last_signal = 1;
      else if(IsSellSignal())
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

#endif // EA_ADXSTRATEGY_MQH
