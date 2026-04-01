#pragma once

struct RiskLimits
{
   double daily_loss;
   double daily_profit;
   int    max_trades;
   int    max_loss_trades;
};
