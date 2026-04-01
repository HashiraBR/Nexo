#ifndef EA_ORDERTAG_MQH
#define EA_ORDERTAG_MQH

#include "EaInfo.mqh"

string BuildStrategyComment(const string strategy_id)
{
   return (string)EA_ID + "|" + strategy_id;
}

string BuildStrategyCommentWithAtr(const string strategy_id, const double atr, const double tick_size)
{
   double atr_adj = atr;
   if(tick_size > 0.0)
      atr_adj = MathCeil(atr / tick_size) * tick_size;
   return (string)EA_ID + "|" + strategy_id + "|ATR=" + DoubleToString(atr_adj, 0);
}

string ExtractStrategyId(const string comment)
{
   const string prefix = (string)EA_ID + "|";
   const int pos = StringFind(comment, prefix);
   if(pos != 0)
      return "";
   const int start = StringLen(prefix);
   const int end = StringFind(comment, "|", start);
   if(end < 0)
      return StringSubstr(comment, start);
   return StringSubstr(comment, start, end - start);
}

bool CommentMatchesStrategy(const string comment, const string strategy_id)
{
   return (ExtractStrategyId(comment) == strategy_id);
}

double ExtractAtrFromComment(const string comment)
{
   const string key = "ATR=";
   int pos = StringFind(comment, key);
   if(pos < 0)
      return 0.0;
   pos += StringLen(key);
   int end = pos;
   while(end < StringLen(comment))
   {
      const ushort c = StringGetCharacter(comment, end);
      if((c < '0' || c > '9') && c != '.' && c != '-')
         break;
      end++;
   }
   const string num = StringSubstr(comment, pos, end - pos);
   return StringToDouble(num);
}

#endif // EA_ORDERTAG_MQH
