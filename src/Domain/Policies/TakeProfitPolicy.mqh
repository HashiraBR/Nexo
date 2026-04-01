// Base take-profit policy.
#pragma once

class TakeProfitPolicy
{
public:
   virtual ~TakeProfitPolicy() {}
   virtual double ComputeTakeProfit(double entry_price, double atr) = 0;
};
