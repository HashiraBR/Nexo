// Tracks daily risk state.
#ifndef EA_DAILYSTATE_MQH
#define EA_DAILYSTATE_MQH

class DailyState
{
public:
   datetime day;
   int      trades_count;
   int      loss_trades_count;
   double   pnl;
};

#endif // EA_DAILYSTATE_MQH
