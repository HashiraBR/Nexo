// Evaluates daily limits and risk rules.
#pragma once

class RiskManager
{
public:
   bool CanTrade();
   void OnTradeOpened();
   void OnTradeClosed(double pnl);
   bool ShouldForceCloseAll();
};
