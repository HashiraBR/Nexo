// Email and push notification adapter.
#ifndef EA_NOTIFIER_MQH
#define EA_NOTIFIER_MQH

#include "../../Shared/EaInfo.mqh"

class Notifier
{
public:
   void Configure(const bool enable_email, const bool enable_push)
   {
      m_enable_email = enable_email;
      m_enable_push = enable_push;
   }

   void Send(const string message)
   {
      if(m_enable_email)
         SendMail(EA_ID, message);
      if(m_enable_push)
         SendNotification(message);
   }

private:
   bool m_enable_email;
   bool m_enable_push;
};

#endif // EA_NOTIFIER_MQH
