#ifndef EA_MARKETHISTORY_MQH
#define EA_MARKETHISTORY_MQH

struct MarketHistory
{
   MqlRates rates[];
   int count;
};

#endif // EA_MARKETHISTORY_MQH
