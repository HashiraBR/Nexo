// Trade entity represents a lifecycle of a position.
#pragma once

class Trade
{
public:
   long     ticket;
   string   strategy_id;
   datetime opened_at;
   datetime closed_at;
   double   open_price;
   double   close_price;
   double   volume;
   bool     is_open;
};
