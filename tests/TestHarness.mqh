// Lightweight unit test harness for MQL5.
#ifndef NEXO_TEST_HARNESS_MQH
#define NEXO_TEST_HARNESS_MQH

int g_test_total = 0;
int g_test_failed = 0;

void TestAssertTrue(const string name, const bool condition)
{
   g_test_total++;
   if(!condition)
   {
      g_test_failed++;
      Print("FAIL: ", name);
   }
}

void TestAssertEqualInt(const string name, const int expected, const int actual)
{
   g_test_total++;
   if(expected != actual)
   {
      g_test_failed++;
      Print("FAIL: ", name, " expected=", expected, " actual=", actual);
   }
}

void TestAssertEqualLong(const string name, const long expected, const long actual)
{
   g_test_total++;
   if(expected != actual)
   {
      g_test_failed++;
      Print("FAIL: ", name, " expected=", expected, " actual=", actual);
   }
}

void TestAssertEqualDouble(const string name, const double expected, const double actual, const double eps = 1e-6)
{
   g_test_total++;
   if(MathAbs(expected - actual) > eps)
   {
      g_test_failed++;
      Print("FAIL: ", name, " expected=", DoubleToString(expected, 8),
            " actual=", DoubleToString(actual, 8));
   }
}

void TestAssertEqualString(const string name, const string expected, const string actual)
{
   g_test_total++;
   if(expected != actual)
   {
      g_test_failed++;
      Print("FAIL: ", name, " expected=\"", expected, "\" actual=\"", actual, "\"");
   }
}

void TestReport()
{
   Print("Tests completed. Total=", g_test_total, " Failed=", g_test_failed);
}

bool TestsAllPassed()
{
   return (g_test_failed == 0);
}

#endif // NEXO_TEST_HARNESS_MQH
