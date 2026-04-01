// Strategy interface for plug-in implementations.
#ifndef EA_STRATEGY_MQH
#define EA_STRATEGY_MQH

#include "../Entities/StrategyContext.mqh"
#include "../ValueObjects/MarketSnapshot.mqh"
#include "../ValueObjects/MarketHistory.mqh"

class Strategy
{
public:
   virtual ~Strategy() {}
   virtual string Id() = 0;
   virtual bool   IsEnabled() = 0;
   virtual StrategyContext GetContext() = 0;
   virtual void   Configure(const StrategyContext &ctx) = 0;
   virtual void   OnNewCandle(const double atr, const MarketSnapshot &market, const MarketHistory &history) = 0;
   virtual void   OnTick() = 0;
   virtual bool   ShouldOpen() = 0;
   virtual bool   ShouldOpenBuy() = 0;
   virtual bool   ShouldOpenSell() = 0;
   virtual bool   UsesPendingOrders() { return false; }
   virtual int    PendingOrderType() { return -1; }
   virtual double PendingEntryPrice() { return 0.0; }
   virtual double PendingStopLoss() { return 0.0; }
   virtual double PendingTakeProfit() { return 0.0; }
   virtual bool   ShouldClose(const ulong position_ticket,
                              const MarketSnapshot &market,
                              const MarketHistory &history) = 0;
};

#endif // EA_STRATEGY_MQH
