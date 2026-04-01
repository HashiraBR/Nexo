#ifndef EA_TIMEWINDOW_MQH
#define EA_TIMEWINDOW_MQH

struct TimeWindow
{
   datetime start;
   datetime end;
};

bool TimeWindowContains(const TimeWindow &window, const datetime value)
{
   return (value >= window.start && value <= window.end);
}

#endif // EA_TIMEWINDOW_MQH
