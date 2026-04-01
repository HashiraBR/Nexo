// Linear regression criterion for MT5 Tester.
#ifndef EA_TESTER_LINEAR_REGRESSION_MQH
#define EA_TESTER_LINEAR_REGRESSION_MQH

bool TesterLinearRegressionGetTradeResults(double &pl_results[])
{
   if(!HistorySelect(0, TimeCurrent()))
      return false;

   const uint total_deals = HistoryDealsTotal();
   ArrayResize(pl_results, total_deals);
   int count = 0;

   for(uint i = 0; i < total_deals; ++i)
   {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      const ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      const long deal_type = HistoryDealGetInteger(ticket, DEAL_TYPE);
      const double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      if(deal_entry != DEAL_ENTRY_IN)
      {
         pl_results[count] = deal_profit;
         ++count;
      }
   }

   ArrayResize(pl_results, count);
   return (count > 0);
}

bool TesterLinearRegressionCalculate(double &changes[], double &chartline[], double &a_coef, double &b_coef)
{
   if(ArraySize(changes) < 3)
      return false;

   const int size = ArraySize(changes);
   ArrayResize(chartline, size);
   chartline[0] = changes[0];
   for(int i = 1; i < size; ++i)
      chartline[i] = chartline[i - 1] + changes[i];

   double x = 0.0;
   double y = 0.0;
   double x2 = 0.0;
   double xy = 0.0;

   for(int i = 0; i < size; ++i)
   {
      x += i;
      y += chartline[i];
      xy += i * chartline[i];
      x2 += i * i;
   }

   a_coef = (size * xy - x * y) / (size * x2 - x * x);
   b_coef = (y - a_coef * x) / size;
   return true;
}

bool TesterLinearRegressionStdError(double &data[], const double a_coef, const double b_coef, double &std_err)
{
   const int size = ArraySize(data);
   if(size <= 2)
      return false;

   double error = 0.0;
   for(int i = 0; i < size; ++i)
      error += MathPow(a_coef * i + b_coef - data[i], 2);

   std_err = MathSqrt(error / (size - 2));
   return true;
}

double TesterLinearRegressionCriterion()
{
   double changes[];
   if(!TesterLinearRegressionGetTradeResults(changes))
      return 0.0;

   const int trades = ArraySize(changes);
   if(trades < 10)
      return 0.0;

   double average_pl = 0.0;
   for(int i = 0; i < trades; ++i)
      average_pl += changes[i];
   average_pl /= trades;

   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
      PrintFormat("%s: Trades=%d, Average P/L=%.2f", __FUNCTION__, trades, average_pl);

   double a = 0.0;
   double b = 0.0;
   double std_error = 0.0;
   double chart[];
   if(!TesterLinearRegressionCalculate(changes, chart, a, b))
      return 0.0;
   if(!TesterLinearRegressionStdError(chart, a, b, std_error))
      return 0.0;

   return (std_error == 0.0) ? a * trades : a * trades / std_error;
}

#endif // EA_TESTER_LINEAR_REGRESSION_MQH
