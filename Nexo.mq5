// Main EA entry point.
#property strict
#property description "Nexo - Framework modular de Expert Advisor para MT5"
#property description "Funcionalidades:"
#property description "- Multiplas estrategias com ATR global suavizado"
#property description "- Gestao de risco centralizada e janela de operacao"
#property description "- Stops configuraveis, time-exit e licenciamento"
#property description " "
#property description "Uso:"
#property description "- Configure simbolo, timeframe e limites de risco"
#property description "- Otimize no Strategy Tester e opere em conta real ou demo"
#property description " "
#property description "Produto da AutoTradex | autotradex.com.br | contato@autotradex.com.br"

#include "src/App/EAController.mqh"
#include "src/App/AppConfig.mqh"
#include "src/Shared/StopTypes.mqh"
#include "src/Shared/TakeProfitTypes.mqh"
#include "src/Shared/CandlePatterns.mqh"
#include "src/Tester/TesterOptimization.mqh"

input string InpDividerGeneral = "==================="; //#### Geral ####
input string InpSymbol = ""; //Simbolo de operacao (obrigatorio)
input ENUM_TIMEFRAMES InpExecutionTimeframe = PERIOD_CURRENT; //Timeframe de execucao
input int InpMaxOpenOrders      = 5;    //Maximo de ordens abertas (globais)
input bool InpEnableOrderLimits = true; //Habilitar limite de ordens

input string InpDividerTimeWindow = "==================="; //#### Horario de Operacao ####
input bool InpEnableTimeWindow = true; //Habilitar controle de horario
input int InpSessionStartHour   = 9;    //Hora inicial
input int InpSessionStartMinute = 0;    //Minuto inicial
input int InpSessionEndHour     = 17;   //Hora final
input int InpSessionEndMinute   = 0;    //Minuto final
input int InpCloseGraceMinutes  = 10;   //Minutos de tolerancia para encerrar

input string InpDividerDailyRisk = "==================="; //#### Gestao diaria ####
input bool InpEnableDailyRisk = true; //Habilitar gestao diaria
input double InpDailyLossLimit = 0.0; //Limite de perda diaria (0 = sem limite)
input double InpDailyProfitLimit = 0.0; //Limite de ganho diario (0 = sem limite)
input int InpMaxTradesDaily = 0; //Maximo de trades no dia (0 = sem limite)
input int InpMaxLossTradesDaily = 0; //Maximo de trades com loss (0 = sem limite)

input string InpDividerATR = "===================";        //#### ATR Suavizado ####
input int InpATRPeriod = 14;            //Periodo do ATR
input int InpATRSmoothPeriod = 10;      //Periodo da EMA do ATR
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_CURRENT; //Timeframe do ATR

input string InpDividerTrendFilter = "==================="; //#### Filtro de Tendencia (CWAVE/TRENDREV) ####
input bool InpTrendFilterEnabled = false; //Habilitar filtro de tendencia (Candle Wave/Trend Reversal)
input int InpTrendMaShortPeriod = 9;      //Periodo da EMA curta
input int InpTrendMaMediumPeriod = 21;    //Periodo da EMA media
input int InpTrendMaLongPeriod = 50;      //Periodo da EMA longa
input double InpTrendDistSM = 0.3;        //Distancia curta-media (%)
input double InpTrendDistML = 0.3;        //Distancia media-longa (%)

input string InpDividerLot = "==================="; //#### Lote ####
input double InpLotSize = 1.0; //Lote base (B3: inteiro)

input string InpDividerNotifications = "==================="; //#### Notificacoes e Log ####
input bool InpEnableNotifications = true; //Habilitar notificacoes/log
input bool InpEnableLogging = true; //Habilitar log em arquivo
input bool InpEnableEmail = false; //Habilitar envio de e-mail
input bool InpEnablePush = false; //Habilitar push notification

input string InpDividerTimeExit = "==================="; //#### Encerramento por tempo ####
input bool InpEnableTimeExit = true; //Habilitar encerramento por tempo

input string InpDividerLicense = "==================="; //#### Licenciamento ####
input string InpLicenseKey = "YT0wfGU9MjAzMC0xMi0zMXxzPVdJTiosV0RPKnx0PU0yLE01fGw9MS4wfGc9KnxkPTE.PpZaXUHv-BkjQyXV_S5z0g"; //Chave de validacao

input string InpDividerStrategy1 = "===================";  //#### Estrategia ADX ####
input bool InpStrat1Enabled = true;     //Ativar estrategia ADX
input int InpStrat1MaxOrders = 1;       //Maximo de ordens abertas da estrategia ADX
input int InpStrat1PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat1MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat1Param1 = 14;         //ADX periodo
input int InpStrat1Param2 = 7;          //ADX step
input double InpStrat1AdxMin = 20.0;     //Minimo ADX para trend
input double InpStrat1DiDiffMin = 2.0;   //Minimo DIF entre +DI e -DI
input double InpStrat1AtrMin = 0.05;     //Minimo ATR para evitar mercado parado
input double InpStrat1SLAtrFactor = 2.0; //Fator ATR para SL
input double InpStrat1TPAtrFactor = 3.0; //Fator ATR para TP
input StopType InpStrat1StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat1TPType = TP_FIXED; //Tipo de TP
input double InpStrat1TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat1BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat1ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat1ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerStrategy2 = "===================";  //#### Estrategia DT Oscillator ####
input bool InpStrat2Enabled = true;     //Ativar estrategia DT Oscillator
input int InpStrat2MaxOrders = 1;       //Maximo de ordens abertas da estrategia DT Oscillator
input int InpStrat2PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat2MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat2Param1 = 14;         //RSI periodo
input int InpStrat2Param2 = 14;         //Stoch periodo
input int InpStrat2SlowingPeriod = 3;   //DT smoothing
input int InpStrat2SignalPeriod = 3;    //DT signal
input double InpStrat2Distance = 5.0;   //Distancia DT
input int InpStrat2MaShortPeriod = 9;   //EMA curta
input int InpStrat2MaLongPeriod = 21;   //EMA longa
input double InpStrat2MaDist = 0.3;     //Distancia EMA (%)
input int InpStrat2LowerZone = 30;      //Zona inferior
input int InpStrat2UpperZone = 70;      //Zona superior
input double InpStrat2SLAtrFactor = 1.5; //Fator ATR para SL
input double InpStrat2TPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpStrat2StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat2TPType = TP_FIXED; //Tipo de TP
input double InpStrat2TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat2BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat2ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat2ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerStrategy3 = "===================";  //#### Estrategia Trend Accelerator ####
input bool InpStrat3Enabled = true;     //Ativar estrategia Trend Accelerator
input int InpStrat3MaxOrders = 1;       //Maximo de ordens abertas da estrategia Trend Accelerator
input int InpStrat3PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat3MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat3RsiPeriod = 14;      //RSI periodo
input int InpStrat3RsiUpper = 70;       //RSI limite superior
input int InpStrat3RsiLower = 30;       //RSI limite inferior
input int InpStrat3MaShortPeriod = 9;   //EMA curta
input int InpStrat3MaLongPeriod = 21;   //EMA longa
input double InpStrat3MaDist = 0.3;     //Distancia EMA longa (%)
input double InpStrat3AccelDist = 0.2;  //Aceleracao da EMA curta (%)
input double InpStrat3SLAtrFactor = 1.5; //Fator ATR para SL
input double InpStrat3TPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpStrat3StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat3TPType = TP_FIXED; //Tipo de TP
input double InpStrat3TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat3BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat3ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat3ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerStrategy4 = "===================";  //#### Estrategia Candle Wave ####
input bool InpStrat4Enabled = true;     //Ativar estrategia Candle Wave
input int InpStrat4MaxOrders = 1;       //Maximo de ordens abertas da estrategia Candle Wave
input int InpStrat4PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat4MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat4VolumeAvgPeriod = 20; //Periodo da media de volume
input int InpStrat4TrendMaPeriod = 50; //Periodo da EMA de tendencia
input double InpStrat4SLAtrFactor = 1.5; //Fator ATR para SL
input double InpStrat4TPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpStrat4StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat4TPType = TP_FIXED; //Tipo de TP
input double InpStrat4TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat4BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat4ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat4ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerCandlePatterns = "==================="; //#### Candle Patterns (ATR) ####
input bool InpCandleDojiEnabled = true; //Padrao Doji habilitado
input double InpCandleDojiMinAtr = 0.1; //Doji ATR minimo
input double InpCandleDojiMaxAtr = 1.0; //Doji ATR maximo (0 = sem limite)
input bool InpCandleMarubozuGreenEnabled = true; //Padrao Marubozu Green habilitado
input double InpCandleMarubozuGreenMinAtr = 0.2; //Marubozu Green ATR minimo
input double InpCandleMarubozuGreenMaxAtr = 0.0; //Marubozu Green ATR maximo (0 = sem limite)
input bool InpCandleMarubozuRedEnabled = true; //Padrao Marubozu Red habilitado
input double InpCandleMarubozuRedMinAtr = 0.2; //Marubozu Red ATR minimo
input double InpCandleMarubozuRedMaxAtr = 0.0; //Marubozu Red ATR maximo (0 = sem limite)
input bool InpCandleShootingStarRedEnabled = true; //Padrao Shooting Star Red habilitado
input double InpCandleShootingStarRedMinAtr = 0.2; //Shooting Star Red ATR minimo
input double InpCandleShootingStarRedMaxAtr = 0.0; //Shooting Star Red ATR maximo (0 = sem limite)
input bool InpCandleShootingStarGreenEnabled = true; //Padrao Shooting Star Green habilitado
input double InpCandleShootingStarGreenMinAtr = 0.2; //Shooting Star Green ATR minimo
input double InpCandleShootingStarGreenMaxAtr = 0.0; //Shooting Star Green ATR maximo (0 = sem limite)
input bool InpCandleSpinningTopEnabled = true; //Padrao Spinning Top habilitado
input double InpCandleSpinningTopMinAtr = 0.1; //Spinning Top ATR minimo
input double InpCandleSpinningTopMaxAtr = 1.5; //Spinning Top ATR maximo (0 = sem limite)
input bool InpCandleHammerGreenEnabled = true; //Padrao Hammer Green habilitado
input double InpCandleHammerGreenMinAtr = 0.2; //Hammer Green ATR minimo
input double InpCandleHammerGreenMaxAtr = 0.0; //Hammer Green ATR maximo (0 = sem limite)
input bool InpCandleHammerRedEnabled = true; //Padrao Hammer Red habilitado
input double InpCandleHammerRedMinAtr = 0.2; //Hammer Red ATR minimo
input double InpCandleHammerRedMaxAtr = 0.0; //Hammer Red ATR maximo (0 = sem limite)

input string InpDividerStrategy5 = "===================";  //#### Estrategia Trend Reversal ####
input bool InpStrat5Enabled = true;     //Ativar estrategia Trend Reversal
input int InpStrat5MaxOrders = 1;       //Maximo de ordens abertas da estrategia Trend Reversal
input int InpStrat5PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat5MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat5VolumeAvgPeriod = 20; //Periodo da media de volume (real)
input int InpStrat5TrendMaPeriod = 50; //Periodo da EMA de tendencia
input double InpStrat5CandleLongPercent = 20.0; //Candle longo: % acima do corpo anterior
input double InpStrat5CandleMaxAtr = 1.0; //Candle maximo: fator de ATR (1.0 = 1x ATR)
input double InpStrat5SLAtrFactor = 1.5; //Fator ATR para SL
input double InpStrat5TPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpStrat5StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat5TPType = TP_FIXED; //Tipo de TP
input double InpStrat5TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat5BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat5ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat5ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerStrategy6 = "===================";  //#### Estrategia Outsider Bar ####
input bool InpStrat6Enabled = true;     //Ativar estrategia Outsider Bar
input int InpStrat6MaxOrders = 1;       //Maximo de ordens abertas da estrategia Outsider Bar
input int InpStrat6PendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpStrat6MaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpStrat6MaPeriod = 50;      //Periodo da EMA
input int InpStrat6RsiPeriod = 14;     //RSI periodo
input int InpStrat6RsiBuyLow = 55;     //RSI compra minimo
input int InpStrat6RsiBuyHigh = 70;    //RSI compra maximo
input int InpStrat6RsiSellLow = 30;    //RSI venda minimo
input int InpStrat6RsiSellHigh = 45;   //RSI venda maximo
input double InpStrat6BodyRatio = 0.6; //Corpo minimo (0-1) do candle
input double InpStrat6SafeRange = 0.25; //Distancia minima da EMA (%)
input double InpStrat6SLAtrFactor = 1.5; //Fator ATR para SL
input double InpStrat6TPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpStrat6StopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpStrat6TPType = TP_FIXED; //Tipo de TP
input double InpStrat6TrailingAtr = 1.0; //Fator ATR do trailing
input double InpStrat6BreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpStrat6ProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpStrat6ProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerTester = "==================="; //#### Tester ####
input TesterOptimizationCriterion InpTesterCriterion = TESTER_MEAN_SD; //Criterio de otimizacao
input double InpTesterDrawdownMin = 0.9; //Restricao de drawdown (0-1)
input double InpTesterForwardShare = 0.5; //Share do forward (0-1)

EAController g_controller;

int OnInit()
{
   AppConfig config;
   config.session_start_hour   = InpSessionStartHour;
   config.session_start_minute = InpSessionStartMinute;
   config.session_end_hour     = InpSessionEndHour;
   config.session_end_minute   = InpSessionEndMinute;
   config.close_grace_minutes  = InpCloseGraceMinutes;
   config.max_orders_global    = InpMaxOpenOrders;
   config.enable_time_window   = InpEnableTimeWindow;
   config.enable_order_limits  = InpEnableOrderLimits;
   config.trade_symbol         = InpSymbol;
   config.execution_timeframe  = InpExecutionTimeframe;
   config.atr_period           = InpATRPeriod;
   config.atr_smooth_period    = InpATRSmoothPeriod;
   config.atr_timeframe        = InpATRTimeframe;
   config.trend_filter_enabled = InpTrendFilterEnabled;
   config.trend_ma_short_period = InpTrendMaShortPeriod;
   config.trend_ma_medium_period = InpTrendMaMediumPeriod;
   config.trend_ma_long_period = InpTrendMaLongPeriod;
   config.trend_dist_sm        = InpTrendDistSM;
   config.trend_dist_ml        = InpTrendDistML;
   config.daily_loss_limit     = InpDailyLossLimit;
   config.daily_profit_limit   = InpDailyProfitLimit;
   config.max_trades_daily     = InpMaxTradesDaily;
   config.max_loss_trades_daily = InpMaxLossTradesDaily;
   config.enable_daily_risk    = InpEnableDailyRisk;

   config.strat1_enabled       = InpStrat1Enabled;
   config.strat1_max_orders    = InpStrat1MaxOrders;
   config.strat1_pending_ttl_minutes = InpStrat1PendingTtlMinutes;
   config.strat1_max_hold_minutes = InpStrat1MaxHoldMinutes;
   config.strat1_param1        = InpStrat1Param1;
   config.strat1_param2        = InpStrat1Param2;
   config.strat1_param3        = InpStrat1AdxMin;
   config.strat1_param4        = InpStrat1DiDiffMin;
   config.strat1_param5        = InpStrat1AtrMin;
   config.strat1_sl_atr_factor = InpStrat1SLAtrFactor;
   config.strat1_tp_atr_factor = InpStrat1TPAtrFactor;
   config.strat1_stop_type     = InpStrat1StopType;
   config.strat1_tp_type       = InpStrat1TPType;
   config.strat1_trailing_atr_factor = InpStrat1TrailingAtr;
   config.strat1_breakeven_trigger_atr = InpStrat1BreakEvenTriggerAtr;
   config.strat1_progressive_trigger_atr = InpStrat1ProgressiveTriggerAtr;
   config.strat1_progressive_step_atr = InpStrat1ProgressiveStepAtr;

   config.strat2_enabled       = InpStrat2Enabled;
   config.strat2_max_orders    = InpStrat2MaxOrders;
   config.strat2_pending_ttl_minutes = InpStrat2PendingTtlMinutes;
   config.strat2_max_hold_minutes = InpStrat2MaxHoldMinutes;
   config.strat2_param1        = InpStrat2Param1;
   config.strat2_param2        = InpStrat2Param2;
   config.strat2_rsi_period    = InpStrat2Param1;
   config.strat2_stoch_period  = InpStrat2Param2;
   config.strat2_slowing_period = InpStrat2SlowingPeriod;
   config.strat2_signal_period  = InpStrat2SignalPeriod;
   config.strat2_dt_distance   = InpStrat2Distance;
   config.strat2_ma_short_period = InpStrat2MaShortPeriod;
   config.strat2_ma_long_period = InpStrat2MaLongPeriod;
   config.strat2_ma_dist       = InpStrat2MaDist;
   config.strat2_lower_zone    = InpStrat2LowerZone;
   config.strat2_upper_zone    = InpStrat2UpperZone;
   config.strat2_sl_atr_factor = InpStrat2SLAtrFactor;
   config.strat2_tp_atr_factor = InpStrat2TPAtrFactor;
   config.strat2_stop_type     = InpStrat2StopType;
   config.strat2_tp_type       = InpStrat2TPType;
   config.strat2_trailing_atr_factor = InpStrat2TrailingAtr;
   config.strat2_breakeven_trigger_atr = InpStrat2BreakEvenTriggerAtr;
   config.strat2_progressive_trigger_atr = InpStrat2ProgressiveTriggerAtr;
   config.strat2_progressive_step_atr = InpStrat2ProgressiveStepAtr;

   config.strat3_enabled       = InpStrat3Enabled;
   config.strat3_max_orders    = InpStrat3MaxOrders;
   config.strat3_pending_ttl_minutes = InpStrat3PendingTtlMinutes;
   config.strat3_max_hold_minutes = InpStrat3MaxHoldMinutes;
   config.strat3_rsi_period    = InpStrat3RsiPeriod;
   config.strat3_rsi_upper     = InpStrat3RsiUpper;
   config.strat3_rsi_lower     = InpStrat3RsiLower;
   config.strat3_ma_short_period = InpStrat3MaShortPeriod;
   config.strat3_ma_long_period = InpStrat3MaLongPeriod;
   config.strat3_ma_dist       = InpStrat3MaDist;
   config.strat3_accel_dist    = InpStrat3AccelDist;
   config.strat3_sl_atr_factor = InpStrat3SLAtrFactor;
   config.strat3_tp_atr_factor = InpStrat3TPAtrFactor;
   config.strat3_stop_type     = InpStrat3StopType;
   config.strat3_tp_type       = InpStrat3TPType;
   config.strat3_trailing_atr_factor = InpStrat3TrailingAtr;
   config.strat3_breakeven_trigger_atr = InpStrat3BreakEvenTriggerAtr;
   config.strat3_progressive_trigger_atr = InpStrat3ProgressiveTriggerAtr;
   config.strat3_progressive_step_atr = InpStrat3ProgressiveStepAtr;

   config.strat4_enabled       = InpStrat4Enabled;
   config.strat4_max_orders    = InpStrat4MaxOrders;
   config.strat4_pending_ttl_minutes = InpStrat4PendingTtlMinutes;
   config.strat4_max_hold_minutes = InpStrat4MaxHoldMinutes;
   config.strat4_volume_avg_period = InpStrat4VolumeAvgPeriod;
   config.strat4_trend_ma_period = InpStrat4TrendMaPeriod;
   config.strat4_sl_atr_factor = InpStrat4SLAtrFactor;
   config.strat4_tp_atr_factor = InpStrat4TPAtrFactor;
   config.strat4_stop_type     = InpStrat4StopType;
   config.strat4_tp_type       = InpStrat4TPType;
   config.strat4_trailing_atr_factor = InpStrat4TrailingAtr;
   config.strat4_breakeven_trigger_atr = InpStrat4BreakEvenTriggerAtr;
   config.strat4_progressive_trigger_atr = InpStrat4ProgressiveTriggerAtr;
   config.strat4_progressive_step_atr = InpStrat4ProgressiveStepAtr;
   for(int i = 0; i < CANDLE_PATTERN_COUNT; ++i)
   {
      config.strat4_pattern_configs[i].enabled = false;
      config.strat4_pattern_configs[i].min_atr = 0.0;
      config.strat4_pattern_configs[i].max_atr = 0.0;
   }
   config.strat4_pattern_configs[PATTERN_DOJI].enabled = InpCandleDojiEnabled;
   config.strat4_pattern_configs[PATTERN_DOJI].min_atr = InpCandleDojiMinAtr;
   config.strat4_pattern_configs[PATTERN_DOJI].max_atr = InpCandleDojiMaxAtr;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_GREEN].enabled = InpCandleMarubozuGreenEnabled;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_GREEN].min_atr = InpCandleMarubozuGreenMinAtr;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_GREEN].max_atr = InpCandleMarubozuGreenMaxAtr;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_RED].enabled = InpCandleMarubozuRedEnabled;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_RED].min_atr = InpCandleMarubozuRedMinAtr;
   config.strat4_pattern_configs[PATTERN_MARUBOZU_RED].max_atr = InpCandleMarubozuRedMaxAtr;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_RED].enabled = InpCandleShootingStarRedEnabled;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_RED].min_atr = InpCandleShootingStarRedMinAtr;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_RED].max_atr = InpCandleShootingStarRedMaxAtr;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].enabled = InpCandleShootingStarGreenEnabled;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].min_atr = InpCandleShootingStarGreenMinAtr;
   config.strat4_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].max_atr = InpCandleShootingStarGreenMaxAtr;
   config.strat4_pattern_configs[PATTERN_SPINNING_TOP].enabled = InpCandleSpinningTopEnabled;
   config.strat4_pattern_configs[PATTERN_SPINNING_TOP].min_atr = InpCandleSpinningTopMinAtr;
   config.strat4_pattern_configs[PATTERN_SPINNING_TOP].max_atr = InpCandleSpinningTopMaxAtr;
   config.strat4_pattern_configs[PATTERN_HAMMER_GREEN].enabled = InpCandleHammerGreenEnabled;
   config.strat4_pattern_configs[PATTERN_HAMMER_GREEN].min_atr = InpCandleHammerGreenMinAtr;
   config.strat4_pattern_configs[PATTERN_HAMMER_GREEN].max_atr = InpCandleHammerGreenMaxAtr;
   config.strat4_pattern_configs[PATTERN_HAMMER_RED].enabled = InpCandleHammerRedEnabled;
   config.strat4_pattern_configs[PATTERN_HAMMER_RED].min_atr = InpCandleHammerRedMinAtr;
   config.strat4_pattern_configs[PATTERN_HAMMER_RED].max_atr = InpCandleHammerRedMaxAtr;

   config.strat5_enabled       = InpStrat5Enabled;
   config.strat5_max_orders    = InpStrat5MaxOrders;
   config.strat5_pending_ttl_minutes = InpStrat5PendingTtlMinutes;
   config.strat5_max_hold_minutes = InpStrat5MaxHoldMinutes;
   config.strat5_volume_avg_period = InpStrat5VolumeAvgPeriod;
   config.strat5_trend_ma_period = InpStrat5TrendMaPeriod;
   config.strat5_candle_long_percent = InpStrat5CandleLongPercent;
   config.strat5_candle_max_atr = InpStrat5CandleMaxAtr;
   config.strat5_sl_atr_factor = InpStrat5SLAtrFactor;
   config.strat5_tp_atr_factor = InpStrat5TPAtrFactor;
   config.strat5_stop_type     = InpStrat5StopType;
   config.strat5_tp_type       = InpStrat5TPType;
   config.strat5_trailing_atr_factor = InpStrat5TrailingAtr;
   config.strat5_breakeven_trigger_atr = InpStrat5BreakEvenTriggerAtr;
   config.strat5_progressive_trigger_atr = InpStrat5ProgressiveTriggerAtr;
   config.strat5_progressive_step_atr = InpStrat5ProgressiveStepAtr;

   config.strat6_enabled       = InpStrat6Enabled;
   config.strat6_max_orders    = InpStrat6MaxOrders;
   config.strat6_pending_ttl_minutes = InpStrat6PendingTtlMinutes;
   config.strat6_max_hold_minutes = InpStrat6MaxHoldMinutes;
   config.strat6_ma_period     = InpStrat6MaPeriod;
   config.strat6_rsi_period    = InpStrat6RsiPeriod;
   config.strat6_rsi_buy_low   = InpStrat6RsiBuyLow;
   config.strat6_rsi_buy_high  = InpStrat6RsiBuyHigh;
   config.strat6_rsi_sell_low  = InpStrat6RsiSellLow;
   config.strat6_rsi_sell_high = InpStrat6RsiSellHigh;
   config.strat6_body_ratio    = InpStrat6BodyRatio;
   config.strat6_safe_range    = InpStrat6SafeRange;
   config.strat6_sl_atr_factor = InpStrat6SLAtrFactor;
   config.strat6_tp_atr_factor = InpStrat6TPAtrFactor;
   config.strat6_stop_type     = InpStrat6StopType;
   config.strat6_tp_type       = InpStrat6TPType;
   config.strat6_trailing_atr_factor = InpStrat6TrailingAtr;
   config.strat6_breakeven_trigger_atr = InpStrat6BreakEvenTriggerAtr;
   config.strat6_progressive_trigger_atr = InpStrat6ProgressiveTriggerAtr;
   config.strat6_progressive_step_atr = InpStrat6ProgressiveStepAtr;

   config.lot_size             = InpLotSize;
   config.enable_notifications = InpEnableNotifications;
   config.enable_time_exit     = InpEnableTimeExit;
   config.enable_logging       = InpEnableLogging;
   config.enable_email         = InpEnableEmail;
   config.enable_push          = InpEnablePush;
   config.license_key          = InpLicenseKey;
   config.enable_integrity     = true;

   if(!g_controller.Initialize(config))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnTick()
{
   g_controller.OnTick();
}

void OnDeinit(const int reason)
{
   g_controller.Shutdown();
}

double OnTester()
{
   return SelectTesterOptimizationCriterion(InpTesterCriterion, InpTesterDrawdownMin, InpTesterForwardShare);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   g_controller.OnTradeTransaction(trans, request, result);
}
