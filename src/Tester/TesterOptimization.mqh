// Tester optimization criteria selector.
#ifndef EA_TESTER_OPTIMIZATION_MQH
#define EA_TESTER_OPTIMIZATION_MQH

#include "TesterMonteCarlo.mqh"
#include "TesterLinearRegression.mqh"

enum TesterOptimizationCriterion
{
   TESTER_MEAN_SD = 1,
   TESTER_MEDIAN_IQR,
   TESTER_ABSOLUTE_DRAWDOWN,
   TESTER_RELATIVE_DRAWDOWN,
   TESTER_FORWARD_WMW,
   TESTER_FORWARD_WMW_PROFIT,
   TESTER_LINEAR_REGRESSION_PL
};

double SelectTesterOptimizationCriterion(const TesterOptimizationCriterion criterion,
                                         const double drawdown_min,
                                         const double forward_share)
{
   double multipliers[];

   if(criterion >= TESTER_MEAN_SD && criterion <= TESTER_FORWARD_WMW_PROFIT)
   {
      TesterMonteCarloSetParameters(drawdown_min, forward_share);
      if(!TesterMonteCarloBuildMultipliers(multipliers) || ArraySize(multipliers) < TESTER_MC_MIN_DEALS)
         return 0.0;
   }

   switch(criterion)
   {
      case TESTER_MEAN_SD:             return TesterMonteCarloMeanStdDev(multipliers);
      case TESTER_MEDIAN_IQR:          return TesterMonteCarloMedianIqr(multipliers);
      case TESTER_ABSOLUTE_DRAWDOWN:   return TesterMonteCarloAbsoluteDrawdown(multipliers);
      case TESTER_RELATIVE_DRAWDOWN:   return TesterMonteCarloRelativeDrawdown(multipliers);
      case TESTER_FORWARD_WMW:         return TesterMonteCarloForwardWmw(multipliers);
      case TESTER_FORWARD_WMW_PROFIT:  return TesterMonteCarloForwardWmwProfit(multipliers);
      case TESTER_LINEAR_REGRESSION_PL: return TesterLinearRegressionCriterion();
      default: return 0.0;
   }
}

#endif // EA_TESTER_OPTIMIZATION_MQH
