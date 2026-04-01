// Unit test runner for Nexo.
#property strict

#include "../src/App/AppConfig.mqh"
#include "../src/Infra/Integrity/ConfigIntegrity.mqh"
#include "../src/Domain/ValueObjects/TimeWindow.mqh"
#include "../src/Shared/OrderTag.mqh"
#include "../src/Infra/Licensing/LicenseService.mqh"
#include "TestHarness.mqh"

string NormalizeBase64Url(const string text)
{
   string s = text;
   while(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '=')
      s = StringSubstr(s, 0, StringLen(s) - 1);
   StringReplace(s, "+", "-");
   StringReplace(s, "/", "_");
   return s;
}

string Base64UrlEncode(const string text)
{
   uchar data[];
   StringToCharArray(text, data, 0, WHOLE_ARRAY, CP_UTF8);
   uchar key[];
   ArrayResize(key, 0);
   uchar out[];
   if(!CryptEncode(CRYPT_BASE64, data, key, out))
      return "";
   string b64 = CharArrayToString(out, 0, ArraySize(out));
   return NormalizeBase64Url(b64);
}

string SignatureBase64Url(const string secret, const string payload)
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
   uchar out[];
   if(!CryptEncode(CRYPT_BASE64, truncated, key, out))
      return "";
   string b64 = CharArrayToString(out, 0, ArraySize(out));
   return NormalizeBase64Url(b64);
}

string BuildLicenseKey(const string payload)
{
   const string payload_b64 = Base64UrlEncode(payload);
   const string signature_b64 = SignatureBase64Url(LICENSE_SECRET, payload);
   return payload_b64 + "." + signature_b64;
}

AppConfig BuildValidConfig()
{
   AppConfig cfg;
   cfg.session_start_hour = 9;
   cfg.session_start_minute = 0;
   cfg.session_end_hour = 17;
   cfg.session_end_minute = 0;
   cfg.close_grace_minutes = 10;
   cfg.max_orders_global = 5;
   cfg.enable_time_window = true;
   cfg.enable_order_limits = true;
   cfg.trade_symbol = "WINJ25";
   cfg.max_trades_daily = 0;
   cfg.max_loss_trades_daily = 0;
   cfg.daily_loss_limit = 0.0;
   cfg.daily_profit_limit = 0.0;
   cfg.enable_daily_risk = true;
   cfg.atr_period = 14;
   cfg.atr_smooth_period = 10;
   cfg.atr_timeframe = PERIOD_M5;
   cfg.execution_timeframe = PERIOD_M5;
   cfg.strat1_enabled = true;
   cfg.strat1_max_orders = 1;
   cfg.strat1_pending_ttl_minutes = 60;
   cfg.strat1_max_hold_minutes = 0;
   cfg.strat1_param1 = 14;
   cfg.strat1_param2 = 7;
   cfg.strat1_sl_atr_factor = 2.0;
   cfg.strat1_tp_atr_factor = 3.0;
   cfg.strat1_stop_type = 0;
   cfg.strat1_trailing_atr_factor = 1.0;
   cfg.strat1_breakeven_trigger_atr = 1.0;
   cfg.strat1_progressive_trigger_atr = 1.8;
   cfg.strat1_progressive_step_atr = 1.0;
   cfg.strat1_tp_type = 0;
   cfg.strat2_enabled = true;
   cfg.strat2_max_orders = 1;
   cfg.strat2_pending_ttl_minutes = 60;
   cfg.strat2_max_hold_minutes = 0;
   cfg.strat2_param1 = 20;
   cfg.strat2_param2 = 10;
   cfg.strat2_sl_atr_factor = 1.5;
   cfg.strat2_tp_atr_factor = 2.5;
   cfg.strat2_stop_type = 0;
   cfg.strat2_trailing_atr_factor = 1.0;
   cfg.strat2_breakeven_trigger_atr = 1.0;
   cfg.strat2_progressive_trigger_atr = 1.8;
   cfg.strat2_progressive_step_atr = 1.0;
   cfg.strat2_tp_type = 0;
   cfg.enable_logging = true;
   cfg.enable_email = false;
   cfg.enable_push = false;
   cfg.enable_notifications = true;
   cfg.enable_time_exit = true;
   cfg.lot_size = 1.0;
   cfg.license_key = "test";
   cfg.enable_integrity = true;
   return cfg;
}

void TestConfigIntegrity()
{
   ConfigIntegrity integrity;
   string error = "";

   AppConfig cfg = BuildValidConfig();
   TestAssertTrue("Config valid", integrity.Validate(cfg, error));
   TestAssertEqualString("Config valid error", "", error);

   cfg = BuildValidConfig();
   cfg.session_start_hour = 24;
   TestAssertTrue("Invalid session hour", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid session hour msg", "Invalid session hour", error);

   cfg = BuildValidConfig();
   cfg.session_start_minute = 60;
   TestAssertTrue("Invalid session minute", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid session minute msg", "Invalid session minute", error);

   cfg = BuildValidConfig();
   cfg.close_grace_minutes = -1;
   TestAssertTrue("Invalid grace minutes", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid grace minutes msg", "Invalid close grace minutes", error);

   cfg = BuildValidConfig();
   cfg.trade_symbol = "";
   TestAssertTrue("Missing symbol", !integrity.Validate(cfg, error));
   TestAssertEqualString("Missing symbol msg", "Trade symbol is required", error);

   cfg = BuildValidConfig();
   cfg.atr_period = 0;
   TestAssertTrue("Invalid ATR period", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid ATR period msg", "Invalid ATR periods", error);

   cfg = BuildValidConfig();
   cfg.lot_size = 0.0;
   TestAssertTrue("Invalid lot size", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid lot size msg", "Invalid lot size", error);

   cfg = BuildValidConfig();
   cfg.strat1_pending_ttl_minutes = -1;
   TestAssertTrue("Invalid pending ttl", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid pending ttl msg", "Invalid pending TTL", error);

   cfg = BuildValidConfig();
   cfg.strat1_progressive_step_atr = 2.0;
   cfg.strat1_progressive_trigger_atr = 1.0;
   TestAssertTrue("Invalid progressive step", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid progressive step msg", "Progressive step must be <= trigger (strat1)", error);

   cfg = BuildValidConfig();
   cfg.strat1_stop_type = 9;
   TestAssertTrue("Invalid stop type", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid stop type msg", "Invalid stop type", error);

   cfg = BuildValidConfig();
   cfg.strat1_tp_type = -1;
   TestAssertTrue("Invalid tp type", !integrity.Validate(cfg, error));
   TestAssertEqualString("Invalid tp type msg", "Invalid TP type", error);
}

void TestTimeWindow()
{
   TimeWindow window;
   window.start = 100;
   window.end = 200;
   TestAssertTrue("TimeWindow start inclusive", TimeWindowContains(window, 100));
   TestAssertTrue("TimeWindow end inclusive", TimeWindowContains(window, 200));
   TestAssertTrue("TimeWindow below", !TimeWindowContains(window, 99));
   TestAssertTrue("TimeWindow above", !TimeWindowContains(window, 201));
}

void TestOrderTag()
{
   const string comment = BuildStrategyComment("S1");
   TestAssertEqualString("OrderTag comment", "NEXO|S1", comment);

   const string comment_atr = BuildStrategyCommentWithAtr("S1", 10.0, 0.5);
   TestAssertEqualString("OrderTag comment ATR", "NEXO|S1|ATR=10", comment_atr);

   TestAssertEqualString("OrderTag extract id", "S1", ExtractStrategyId(comment_atr));
   TestAssertTrue("OrderTag matches", CommentMatchesStrategy(comment_atr, "S1"));
   TestAssertTrue("OrderTag mismatch", !CommentMatchesStrategy(comment_atr, "S2"));
   TestAssertEqualDouble("OrderTag extract ATR", 10.0, ExtractAtrFromComment(comment_atr));
   TestAssertEqualDouble("OrderTag extract ATR missing", 0.0, ExtractAtrFromComment("NEXO|S1"));
}

void TestLicenseService()
{
   LicenseService service;
   LicenseState state;
   string error = "";

   TestAssertTrue("License invalid format", !service.Decode("invalidkey", state, error));
   TestAssertEqualString("License invalid format msg", "Invalid license format", error);

   TestAssertTrue("License invalid payload", !service.Decode("!!!.sig", state, error));
   TestAssertEqualString("License invalid payload msg", "Invalid Base64 payload", error);

   const string payload = "a=123|e=2030-12-31|s=WIN*,WDO*|t=M2,M5|l=1|g=*|d=0";
   const string key = BuildLicenseKey(payload);
   TestAssertTrue("License decode valid", service.Decode(key, state, error));
   TestAssertTrue("License valid flag", state.valid);
   TestAssertEqualLong("License account", 123, state.account);
   TestAssertEqualString("License symbols", "WIN*,WDO*", state.symbols_csv);
   TestAssertEqualString("License timeframes", "M2,M5", state.timeframes_csv);
   TestAssertEqualDouble("License max lot", 1.0, state.max_lot);
   TestAssertEqualString("License strategies", "*", state.strategies_csv);
   TestAssertTrue("License demo false", !state.demo_only);
   TestAssertTrue("License expires set", state.expires_at > 0);

   const string key_bad = Base64UrlEncode(payload) + ".invalidsig";
   TestAssertTrue("License invalid signature", !service.Decode(key_bad, state, error));
   TestAssertEqualString("License invalid signature msg", "Invalid license signature", error);

   TestAssertTrue("License symbol allowed wildcard", service.IsSymbolAllowed(state, "WINJ25"));
   TestAssertTrue("License symbol denied", !service.IsSymbolAllowed(state, "PETR4"));
   TestAssertTrue("License timeframe allowed", service.IsTimeframeAllowed(state, PERIOD_M5));
   TestAssertTrue("License timeframe denied", !service.IsTimeframeAllowed(state, PERIOD_H1));
   TestAssertTrue("License lot allowed", service.IsLotAllowed(state, 1.0));
   TestAssertTrue("License lot denied", !service.IsLotAllowed(state, 1.1));
   TestAssertTrue("License strategy allowed all", service.IsStrategyAllowed(state, "S1"));

   LicenseState demo_state;
   demo_state.valid = true;
   demo_state.account = 0;
   demo_state.expires_at = TimeCurrent() + 86400;
   demo_state.symbols_csv = "*";
   demo_state.timeframes_csv = "M1";
   demo_state.max_lot = 0.0;
   demo_state.strategies_csv = "S1,S2";
   demo_state.demo_only = true;
   TestAssertTrue("License demo any lot", service.IsLotAllowed(demo_state, 10.0));
   TestAssertTrue("License demo strategy allow", service.IsStrategyAllowed(demo_state, "S2"));
   TestAssertTrue("License demo strategy deny", !service.IsStrategyAllowed(demo_state, "S3"));

   const datetime now = TimeCurrent();
   TestAssertTrue("License not expired", !service.IsExpired(demo_state, now));
   demo_state.expires_at = now - 1;
   TestAssertTrue("License expired", service.IsExpired(demo_state, now));
}

void OnStart()
{
   TestConfigIntegrity();
   TestTimeWindow();
   TestOrderTag();
   TestLicenseService();
   TestReport();
}
