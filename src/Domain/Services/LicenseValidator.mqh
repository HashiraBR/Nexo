// Validates license and permissions.
#pragma once

class LicenseValidator
{
public:
   bool Validate();
   bool IsSymbolAllowed(string symbol);
   bool IsTimeframeAllowed(ENUM_TIMEFRAMES tf);
   bool IsLotAllowed(double lot);
};
