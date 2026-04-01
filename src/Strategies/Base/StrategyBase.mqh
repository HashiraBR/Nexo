// Base class to simplify plugable strategies.
#ifndef EA_STRATEGYBASE_MQH
#define EA_STRATEGYBASE_MQH

#include "../../Domain/Services/Strategy.mqh"

class StrategyBase : public Strategy
{
protected:
   string id;
   bool   enabled;
   StrategyContext context;

public:
   string Id();
   bool   IsEnabled();
   StrategyContext GetContext();
   void   Configure(const StrategyContext &ctx);
};

string StrategyBase::Id()
{
   return id;
}

bool StrategyBase::IsEnabled()
{
   return enabled;
}

StrategyContext StrategyBase::GetContext()
{
   return context;
}

void StrategyBase::Configure(const StrategyContext &ctx)
{
   context = ctx;
   id = ctx.id;
   enabled = ctx.enabled;
}

#endif // EA_STRATEGYBASE_MQH
