// Order entity tracks pending/market orders and origin strategy.
#pragma once

class Order
{
public:
   long     ticket;
   string   strategy_id;
   datetime created_at;
   datetime expires_at;
   double   requested_price;
   double   volume;
   int      type; // market/limit/stop mapping
};
