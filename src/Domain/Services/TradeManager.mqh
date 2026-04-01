// Coordinates trade lifecycle and stop/take policies.
#pragma once

class TradeManager
{
public:
   bool OpenTrade(string strategy_id);
   bool CloseTrade(long position_ticket, string reason);
   void UpdateStops();
};
