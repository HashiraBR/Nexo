#ifndef EA_MARKETSNAPSHOT_MQH
#define EA_MARKETSNAPSHOT_MQH

struct MarketSnapshot
{
   string   symbol;
   double   bid;
   double   ask;
   double   last;
   double   point;
   int      digits;
   datetime time;
};

#endif // EA_MARKETSNAPSHOT_MQH
