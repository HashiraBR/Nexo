// Position entity mirrors an open market position.
#pragma once

class Position
{
public:
   long     ticket;
   string   strategy_id;
   datetime opened_at;
   double   entry_price;
   double   volume;
   int      direction; // buy/sell mapping
};
