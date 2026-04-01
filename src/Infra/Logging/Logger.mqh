// Persistent logger adapter.
#ifndef EA_LOGGER_MQH
#define EA_LOGGER_MQH

class Logger
{
public:
   bool Initialize(const string file_name)
   {
      m_file_name = file_name;
      m_ready = false;
      return TestWrite();
   }

   void Info(const string message)
   {
      Write("INFO", message);
   }

   void Warn(const string message)
   {
      Write("WARN", message);
   }

   void Error(const string message)
   {
      Write("ERROR", message);
   }

private:
   string m_file_name;
   bool   m_ready;

   void Write(const string level, const string message)
   {
      if(m_file_name == "" || !m_ready)
         return;
      const int handle = FileOpen(m_file_name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_WRITE | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return;
      FileSeek(handle, 0, SEEK_END);
      const string line = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " [" + level + "] " + message;
      FileWrite(handle, line);
      FileClose(handle);
   }

   bool TestWrite()
   {
      if(m_file_name == "")
      {
         m_ready = false;
         return false;
      }
      const int handle = FileOpen(m_file_name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_WRITE | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
      {
         m_ready = false;
         return false;
      }
      FileClose(handle);
      m_ready = true;
      return true;
   }
};

#endif // EA_LOGGER_MQH
