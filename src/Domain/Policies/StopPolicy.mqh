// Base stop-loss policy.
#pragma once

class StopPolicy
{
public:
   virtual ~StopPolicy() {}
   virtual double ComputeStop(double entry_price, double atr) = 0;
   virtual void   UpdateStop(long position_ticket, double atr) = 0;
};
