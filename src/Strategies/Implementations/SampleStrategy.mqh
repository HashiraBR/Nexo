// Sample strategy placeholder.
#ifndef EA_SAMPLESTRATEGY_MQH
#define EA_SAMPLESTRATEGY_MQH

#include "../Base/StrategyBase.mqh"

class SampleStrategy : public StrategyBase
{
public:
   SampleStrategy();
   void   OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history);
   void   OnTick();
   bool   ShouldOpen();
   bool   ShouldOpenBuy();
   bool   ShouldOpenSell();
   bool   ShouldClose(const ulong position_ticket,
                      const MarketSnapshot &market,
                      const MarketHistory &history);
};

SampleStrategy::SampleStrategy()
{
}

void SampleStrategy::OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history)
{
   // Placeholder: use context.param1/param2 and atr with context.sl_atr_factor/tp_atr_factor.
}

void SampleStrategy::OnTick()
{
}

bool SampleStrategy::ShouldOpen()
{
   return false;
}

bool SampleStrategy::ShouldOpenBuy()
{
   return false;
}

bool SampleStrategy::ShouldOpenSell()
{
   return false;
}

bool SampleStrategy::ShouldClose(const ulong position_ticket,
                                 const MarketSnapshot &market,
                                 const MarketHistory &history)
{
   return false;
}

#endif // EA_SAMPLESTRATEGY_MQH
