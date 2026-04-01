// Monte Carlo optimization criteria utilities for MT5 Tester.
#ifndef EA_TESTER_MONTE_CARLO_MQH
#define EA_TESTER_MONTE_CARLO_MQH

#include <Math\Stat\Uniform.mqh>

#define TESTER_MC_RESIZE_STEP 30
#define TESTER_MC_SAMPLES 10000
#define TESTER_MC_MIN_DEALS 5

double g_tester_drawdown_min = 0.9;
double g_tester_forward_share = 0.5;

void TesterMonteCarloSetParameters(const double drawdown_min, const double forward_share)
{
   g_tester_drawdown_min = (drawdown_min > 0.0 && drawdown_min < 1.0) ? drawdown_min : 0.9;
   g_tester_forward_share = (forward_share > 0.0 && forward_share < 1.0) ? forward_share : 0.5;
}

bool TesterMonteCarloBuildMultipliers(double &multipliers[])
{
   if(!HistorySelect(0, TimeCurrent()))
      return false;

   const uint deals_total = HistoryDealsTotal();
   int count = 0;
   double capital = TesterStatistics(STAT_INITIAL_DEPOSIT);

   ArrayResize(multipliers, 0);

   for(uint i = 0; i < deals_total; ++i)
   {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      long deal_type = 0;
      if(!HistoryDealGetInteger(ticket, DEAL_TYPE, deal_type))
         return false;

      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      const double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      const double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      const double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(commission == 0.0 && swap == 0.0 && profit == 0.0)
         continue;

      ++count;
      ArrayResize(multipliers, count, TESTER_MC_RESIZE_STEP);

      const double total_pl = commission + swap + profit;
      multipliers[count - 1] = 1.0 + total_pl / capital;
      capital += total_pl;
   }

   return (count > 0);
}

void TesterMonteCarloSample(double &source[], double &sample[])
{
   int error = 0;
   const int size = ArraySize(source);
   ArrayResize(sample, size);
   for(int i = 0; i < size; ++i)
   {
      const double rnd = MathRandomUniform(0, size, error);
      if(!MathIsValidNumber(rnd))
      {
         Print("MathRandomUniform error ", error);
         ExpertRemove();
         return;
      }

      int index = (int)rnd;
      if(index == size)
         index = size - 1;
      sample[i] = source[index];
   }
}

double TesterMonteCarloMeanStdDev(double &multipliers[])
{
   double sample[], results[TESTER_MC_SAMPLES];
   const int size = ArraySize(multipliers);
   ArrayResize(sample, size);
   for(int n = 0; n < TESTER_MC_SAMPLES; ++n)
   {
      TesterMonteCarloSample(multipliers, sample);
      results[n] = 1.0;
      for(int i = 0; i < size; ++i)
         results[n] *= sample[i];
      results[n] -= 1.0;
   }

   const double deviation = MathStandardDeviation(results);
   if(deviation == 0.0)
      return 0.0;
   return MathMean(results) / deviation;
}

double TesterMonteCarloMedianIqr(double &multipliers[])
{
   double sample[], results[TESTER_MC_SAMPLES];
   const int size = ArraySize(multipliers);
   ArrayResize(sample, size);
   for(int n = 0; n < TESTER_MC_SAMPLES; ++n)
   {
      TesterMonteCarloSample(multipliers, sample);
      results[n] = 1.0;
      for(int i = 0; i < size; ++i)
         results[n] *= sample[i];
      results[n] -= 1.0;
   }

   ArraySort(results);
   const double iqr = results[(int)(0.75 * TESTER_MC_SAMPLES)] - results[(int)(0.25 * TESTER_MC_SAMPLES)];
   if(iqr == 0.0)
      return 0.0;
   return results[(int)(0.5 * TESTER_MC_SAMPLES)] / iqr;
}

double TesterMonteCarloAbsoluteDrawdown(double &multipliers[])
{
   if(g_tester_drawdown_min <= 0.0 || g_tester_drawdown_min >= 1.0)
      return 0.0;

   double sample[], results[TESTER_MC_SAMPLES];
   const int size = ArraySize(multipliers);
   ArrayResize(sample, size);
   for(int n = 0; n < TESTER_MC_SAMPLES; ++n)
   {
      TesterMonteCarloSample(multipliers, sample);
      results[n] = 1.0;
      for(int i = 0; i < size; ++i)
      {
         results[n] *= sample[i];
         if(results[n] < g_tester_drawdown_min)
            break;
      }
      results[n] -= 1.0;
   }

   return MathMean(results);
}

double TesterMonteCarloRelativeDrawdown(double &multipliers[])
{
   if(g_tester_drawdown_min <= 0.0 || g_tester_drawdown_min >= 1.0)
      return 0.0;

   double sample[], results[TESTER_MC_SAMPLES], peak;
   const int size = ArraySize(multipliers);
   ArrayResize(sample, size);
   for(int n = 0; n < TESTER_MC_SAMPLES; ++n)
   {
      TesterMonteCarloSample(multipliers, sample);
      peak = results[n] = 1.0;
      for(int i = 0; i < size; ++i)
      {
         results[n] *= sample[i];
         if(results[n] > peak)
            peak = results[n];
         else if(results[n] / peak < g_tester_drawdown_min)
            break;
      }
      results[n] -= 1.0;
   }

   return MathMean(results);
}

double TesterMonteCarloForwardWmw(double &multipliers[])
{
   if(g_tester_forward_share <= 0.0 || g_tester_forward_share >= 1.0)
      return 0.0;

   const int size = ArraySize(multipliers);
   const int future_size = (int)(g_tester_forward_share * size);
   const int past_size = size - future_size;
   if(future_size < TESTER_MC_MIN_DEALS || past_size < TESTER_MC_MIN_DEALS)
      return 0.0;

   double u = 0.0;
   for(int i = 0; i < past_size; ++i)
      for(int j = 0; j < future_size; ++j)
         if(multipliers[i] > multipliers[past_size + j])
            ++u;

   return 1.0 - MathAbs(1.0 - 2.0 * u / (future_size * past_size));
}

double TesterMonteCarloForwardWmwProfit(double &multipliers[])
{
   const int size = ArraySize(multipliers);
   double profit = 1.0;
   for(int n = 0; n < size; ++n)
      profit *= multipliers[n];
   profit -= 1.0;
   if(profit > 0.0)
      profit *= TesterMonteCarloForwardWmw(multipliers);
   return profit;
}

#endif // EA_TESTER_MONTE_CARLO_MQH
