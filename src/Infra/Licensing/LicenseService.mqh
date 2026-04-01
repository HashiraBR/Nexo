// License decoding and signature verification.
#ifndef EA_LICENSESERVICE_MQH
#define EA_LICENSESERVICE_MQH

#include "../../Domain/Entities/LicenseState.mqh"
#include "../../Shared/EaInfo.mqh"

class LicenseService
{
public:
   bool Decode(const string license_key, LicenseState &out_state, string &out_error)
   {
      out_error = "";
      out_state.valid = false;

      string payload_b64 = "";
      string signature_b64 = "";
      if(!SplitKey(license_key, payload_b64, signature_b64))
      {
         out_error = "Invalid license format";
         return false;
      }

      string payload = "";
      if(!DecodeBase64Url(payload_b64, payload))
      {
         out_error = "Invalid Base64 payload";
         return false;
      }

      const string expected = SignatureBase64Url(LICENSE_SECRET, payload);
      if(NormalizeBase64Url(signature_b64) != expected)
      {
         out_error = "Invalid license signature";
         return false;
      }

      if(!ParsePayload(payload, out_state, out_error))
         return false;

      out_state.valid = true;
      return true;
   }

   bool IsExpired(const LicenseState &state, const datetime now) const
   {
      return (state.expires_at > 0 && now > state.expires_at);
   }

   bool IsSymbolAllowed(const LicenseState &state, const string symbol) const
   {
      return CsvContains(state.symbols_csv, symbol);
   }

   bool IsTimeframeAllowed(const LicenseState &state, const ENUM_TIMEFRAMES tf) const
   {
      const string tf_str = TimeframeToString(tf);
      return CsvContains(state.timeframes_csv, tf_str);
   }

   bool IsLotAllowed(const LicenseState &state, const double lot) const
   {
      if(state.max_lot <= 0.0)
         return true;
      return (lot <= state.max_lot);
   }

   bool IsStrategyAllowed(const LicenseState &state, const string strategy_id) const
   {
      if(state.strategies_csv == "*")
         return true;
      return CsvContains(state.strategies_csv, strategy_id);
   }

private:
   bool DecodeBase64Url(const string text, string &out)
   {
      string b64 = NormalizeBase64(text);
      uchar src[];
      StringToCharArray(b64, src, 0, WHOLE_ARRAY, CP_UTF8);
      uchar key[];
      ArrayResize(key, 0);
      uchar dst[];
      if(!CryptDecode(CRYPT_BASE64, src, key, dst))
         return false;
      out = CharArrayToString(dst, 0, ArraySize(dst));
      return true;
   }

   bool SplitKey(const string key, string &out_payload_b64, string &out_signature_b64)
   {
      const int sep = StringFind(key, ".");
      if(sep <= 0)
         return false;
      out_payload_b64 = StringSubstr(key, 0, sep);
      out_signature_b64 = StringSubstr(key, sep + 1);
      return (out_payload_b64 != "" && out_signature_b64 != "");
   }

   bool ParsePayload(const string payload, LicenseState &out_state, string &out_error)
   {
      out_state.account = (long)ParseKeyNumber(payload, "a");
      const string exp = ParseKeyString(payload, "e");
      out_state.expires_at = ParseDate(exp);
      out_state.symbols_csv = ParseKeyString(payload, "s");
      out_state.timeframes_csv = ParseKeyString(payload, "t");
      out_state.max_lot = ParseKeyNumber(payload, "l");
      out_state.strategies_csv = ParseKeyString(payload, "g");
      out_state.demo_only = (ParseKeyNumber(payload, "d") > 0.5);

      if(!out_state.demo_only && out_state.account <= 0)
      {
         out_error = "Invalid account in license";
         return false;
      }
      if(out_state.expires_at <= 0)
      {
         out_error = "Invalid expiration in license";
         return false;
      }
      return true;
   }

   string ParseKeyString(const string text, const string key) const
   {
      const string pattern = key + "=";
      int pos = StringFind(text, pattern);
      if(pos < 0)
         return "";
      const int start = pos + StringLen(pattern);
      const int end = StringFind(text, "|", start);
      if(end < 0)
         return StringSubstr(text, start);
      return StringSubstr(text, start, end - start);
   }

   double ParseKeyNumber(const string text, const string key) const
   {
      const string pattern = key + "=";
      int pos = StringFind(text, pattern);
      if(pos < 0)
         return 0.0;
      int start = pos + StringLen(pattern);
      int end = start;
      while(end < StringLen(text))
      {
         const ushort c = StringGetCharacter(text, end);
         if((c < '0' || c > '9') && c != '.' && c != '-')
            break;
         end++;
      }
      const string num = StringSubstr(text, start, end - start);
      return StringToDouble(num);
   }

   datetime ParseDate(const string ymd) const
   {
      if(StringLen(ymd) < 10)
         return 0;
      const int y = (int)StringToInteger(StringSubstr(ymd, 0, 4));
      const int m = (int)StringToInteger(StringSubstr(ymd, 5, 2));
      const int d = (int)StringToInteger(StringSubstr(ymd, 8, 2));
      if(y <= 0 || m <= 0 || d <= 0)
         return 0;
      MqlDateTime dt;
      dt.year = y;
      dt.mon = m;
      dt.day = d;
      dt.hour = 23;
      dt.min = 59;
      dt.sec = 59;
      return StructToTime(dt);
   }

   string TimeframeToString(const ENUM_TIMEFRAMES tf) const
   {
      switch(tf)
      {
         case PERIOD_M1: return "M1";
         case PERIOD_M2: return "M2";
         case PERIOD_M3: return "M3";
         case PERIOD_M4: return "M4";
         case PERIOD_M5: return "M5";
         case PERIOD_M6: return "M6";
         case PERIOD_M10: return "M10";
         case PERIOD_M12: return "M12";
         case PERIOD_M15: return "M15";
         case PERIOD_M20: return "M20";
         case PERIOD_M30: return "M30";
         case PERIOD_H1: return "H1";
         case PERIOD_H2: return "H2";
         case PERIOD_H3: return "H3";
         case PERIOD_H4: return "H4";
         case PERIOD_H6: return "H6";
         case PERIOD_H8: return "H8";
         case PERIOD_H12: return "H12";
         case PERIOD_D1: return "D1";
         case PERIOD_W1: return "W1";
         case PERIOD_MN1: return "MN1";
         default: return "";
      }
   }

   bool CsvContains(const string csv, const string value) const
   {
      if(csv == "*")
         return true;
      const string list = csv + ",";
      const int value_len = StringLen(value);
      int start = 0;
      while(true)
      {
         const int end = StringFind(list, ",", start);
         if(end < 0)
            break;
         const string token = StringSubstr(list, start, end - start);
         if(token == value)
            return true;
         const int star_pos = StringFind(token, "*");
         if(star_pos == StringLen(token) - 1 && star_pos > 0)
         {
            const string prefix = StringSubstr(token, 0, star_pos);
            if(StringLen(prefix) > 0 && StringSubstr(value, 0, StringLen(prefix)) == prefix)
               return true;
         }
         start = end + 1;
      }
      return false;
   }

   string SignatureBase64Url(const string secret, const string payload) const
   {
      uchar data[];
      StringToCharArray(secret + payload, data, 0, WHOLE_ARRAY, CP_UTF8);
      uchar key[];
      ArrayResize(key, 0);
      uchar hash[];
      if(!CryptEncode(CRYPT_HASH_SHA256, data, key, hash))
         return "";
      uchar truncated[];
      ArrayResize(truncated, 16);
      for(int i = 0; i < 16; ++i)
         truncated[i] = hash[i];
      return BytesToBase64Url(truncated);
   }

   string BytesToBase64Url(const uchar &data[]) const
   {
      uchar key[];
      ArrayResize(key, 0);
      uchar out[];
      if(!CryptEncode(CRYPT_BASE64, data, key, out))
         return "";
      string b64 = CharArrayToString(out, 0, ArraySize(out));
      return NormalizeBase64Url(b64);
   }

   string NormalizeBase64Url(const string text) const
   {
      string s = text;
      // remove padding
      while(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '=')
         s = StringSubstr(s, 0, StringLen(s) - 1);
      StringReplace(s, "+", "-");
      StringReplace(s, "/", "_");
      return s;
   }

   string NormalizeBase64(const string text) const
   {
      string s = text;
      StringReplace(s, "-", "+");
      StringReplace(s, "_", "/");
      while(StringLen(s) % 4 != 0)
         s += "=";
      return s;
   }
};

#endif // EA_LICENSESERVICE_MQH
