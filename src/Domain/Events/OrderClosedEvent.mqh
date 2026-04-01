#pragma once

struct OrderClosedEvent
{
   long   ticket;
   string strategy_id;
   double pnl;
};
