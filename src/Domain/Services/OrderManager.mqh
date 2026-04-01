// Manages pending orders and global/strategy order limits.
#pragma once

class OrderManager
{
public:
   bool CanPlaceOrder(string strategy_id);
   bool PlaceOrder(string strategy_id);
   void ExpireOrders();
};
