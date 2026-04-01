// Persists trade/order state when needed.
#pragma once

class TradeRepository
{
public:
   void SaveTrade(long ticket);
   void SaveOrder(long ticket);
};
