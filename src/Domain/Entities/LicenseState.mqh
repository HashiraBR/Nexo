// Represents the decoded license permissions.
#ifndef EA_LICENSESTATE_MQH
#define EA_LICENSESTATE_MQH

class LicenseState
{
public:
   bool     valid;
   long     account;
   datetime expires_at;
   string   symbols_csv;
   string   timeframes_csv;
   double   max_lot;
   string   strategies_csv;
   bool     demo_only;
};

#endif // EA_LICENSESTATE_MQH
