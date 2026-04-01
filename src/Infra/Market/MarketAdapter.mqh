// Wraps MQL5 trading and market data APIs.
#ifndef EA_MARKETADAPTER_MQH
#define EA_MARKETADAPTER_MQH

#include "../../Domain/ValueObjects/MarketSnapshot.mqh"
#include "../../Domain/ValueObjects/MarketHistory.mqh"

class MarketAdapter
{
public:
   double GetATR();
   bool   SendOrder(string strategy_id);
   bool   ClosePosition(long position_ticket);

   MarketSnapshot Snapshot(const string symbol)
   {
      MarketSnapshot snap;
      snap.symbol = symbol;
      snap.bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      snap.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      snap.last = SymbolInfoDouble(symbol, SYMBOL_LAST);
      snap.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      snap.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      snap.time = TimeCurrent();
      return snap;
   }

   MarketHistory History(const string symbol, const ENUM_TIMEFRAMES tf, const int count)
   {
      MarketHistory history;
      ArrayResize(history.rates, count);
      ArraySetAsSeries(history.rates, true);
      const int copied = CopyRates(symbol, tf, 1, count, history.rates);
      if(copied > 0)
      {
         history.count = copied;
      }
      else
      {
         history.count = 0;
      }
      return history;
   }
};

#endif // EA_MARKETADAPTER_MQH
