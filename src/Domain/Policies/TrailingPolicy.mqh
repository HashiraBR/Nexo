#pragma once

class TrailingPolicy : public StopPolicy
{
public:
   double ComputeStop(double entry_price, double atr);
   void   UpdateStop(long position_ticket, double atr);
};
