// Time utilities wrapper.
#ifndef EA_CLOCK_MQH
#define EA_CLOCK_MQH

class Clock
{
public:
   datetime Now()
   {
      return TimeLocal();
   }

   datetime ServerNow()
   {
      return TimeCurrent();
   }
};

#endif // EA_CLOCK_MQH
