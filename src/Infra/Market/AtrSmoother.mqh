// Smoothed ATR (EMA) calculator using a global ATR handle.
#ifndef EA_ATRSMOOTHER_MQH
#define EA_ATRSMOOTHER_MQH

class AtrSmoother
{
public:
   bool Initialize(const string symbol, const ENUM_TIMEFRAMES tf, const int atr_period, const int smooth_period)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_atr_period = atr_period;
      m_smooth_period = smooth_period;
      m_last_bar_time = 0;
      m_ready = false;
      m_atr_ema = 0.0;
      m_handle = INVALID_HANDLE;

      m_handle = iATR(m_symbol, m_tf, m_atr_period);
      return (m_handle != INVALID_HANDLE);
   }

   void Shutdown()
   {
      if(m_handle != INVALID_HANDLE)
         IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }

   void Update()
   {
      if(m_handle == INVALID_HANDLE)
         return;

      const datetime bar_time = iTime(m_symbol, m_tf, 0);
      if(bar_time == 0 || bar_time == m_last_bar_time)
         return;

      double buffer[1];
      if(CopyBuffer(m_handle, 0, 1, 1, buffer) != 1)
         return;

      const double atr_value = buffer[0];
      const double alpha = 2.0 / (m_smooth_period + 1.0);

      if(!m_ready)
      {
         m_atr_ema = atr_value;
         m_ready = true;
      }
      else
      {
         m_atr_ema = (alpha * atr_value) + ((1.0 - alpha) * m_atr_ema);
      }

      m_last_bar_time = bar_time;
   }

   double Value() const
   {
      return m_atr_ema;
   }

   bool IsReady() const
   {
      return m_ready;
   }

private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int             m_atr_period;
   int             m_smooth_period;
   int             m_handle;
   datetime        m_last_bar_time;
   double          m_atr_ema;
   bool            m_ready;
};

#endif // EA_ATRSMOOTHER_MQH
