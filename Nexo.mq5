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
input double InpMaxRiskPerTrade = 0.0; //Limite máximo de risco (R$) por operação (0 = sem limite)

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
input bool InpEnableDebug = false; //Habilitar log de debug generalizado

input string InpDividerTimeExit = "==================="; //#### Encerramento por tempo ####
input bool InpEnableTimeExit = true; //Habilitar encerramento por tempo

input string InpDividerLicense = "==================="; //#### Licenciamento ####
input string InpLicenseKey = "YT0wfGU9MjAzMC0xMi0zMXxzPVdJTiosV0RPKnx0PU0yLE01fGw9MS4wfGc9KnxkPTE.PpZaXUHv-BkjQyXV_S5z0g"; //Chave de validacao

input string InpDividerAdx = "===================";  //#### Estrategia ADX ####
input bool InpAdxEnabled = true;     //Ativar estrategia ADX
input int InpAdxMaxOrders = 1;       //Maximo de ordens abertas da estrategia ADX
input int InpAdxPendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpAdxMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpAdxParam1 = 14;         //ADX periodo
input int InpAdxParam2 = 7;          //ADX step
input double InpAdxMin = 20.0;     //Minimo ADX para trend
input double InpAdxDiDiffMin = 2.0;   //Minimo DIF entre +DI e -DI
input double InpAdxAtrMin = 0.05;     //Minimo ATR para evitar mercado parado
input double InpAdxSLAtrFactor = 2.0; //Fator ATR para SL
input double InpAdxTPAtrFactor = 3.0; //Fator ATR para TP
input StopType InpAdxStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpAdxTPType = TP_FIXED; //Tipo de TP
input double InpAdxTrailingAtr = 1.0; //Fator ATR do trailing
input double InpAdxBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpAdxProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpAdxProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerDtOsc = "===================";  //#### Estrategia DT Oscillator ####
input bool InpDtOscEnabled = true;     //Ativar estrategia DT Oscillator
input int InpDtOscMaxOrders = 1;       //Maximo de ordens abertas da estrategia DT Oscillator
input int InpDtOscPendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpDtOscMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpDtOscRsiPeriod = 14;         //RSI periodo
input int InpDtOscStochPeriod = 14;         //Stoch periodo
input int InpDtOscSlowingPeriod = 3;   //DT smoothing
input int InpDtOscSignalPeriod = 3;    //DT signal
input double InpDtOscDistance = 5.0;   //Distancia DT
input int InpDtOscMaShortPeriod = 9;   //EMA curta
input int InpDtOscMaLongPeriod = 21;   //EMA longa
input double InpDtOscMaDist = 0.3;     //Distancia EMA (%)
input int InpDtOscLowerZone = 30;      //Zona inferior
input int InpDtOscUpperZone = 70;      //Zona superior
input double InpDtOscSLAtrFactor = 1.5; //Fator ATR para SL
input double InpDtOscTPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpDtOscStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpDtOscTPType = TP_FIXED; //Tipo de TP
input double InpDtOscTrailingAtr = 1.0; //Fator ATR do trailing
input double InpDtOscBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpDtOscProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpDtOscProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerTrendAccel = "===================";  //#### Estrategia Trend Accelerator ####
input bool InpTrendAccelEnabled = true;     //Ativar estrategia Trend Accelerator
input int InpTrendAccelMaxOrders = 1;       //Maximo de ordens abertas da estrategia Trend Accelerator
input int InpTrendAccelPendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpTrendAccelMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpTrendAccelRsiPeriod = 14;      //RSI periodo
input int InpTrendAccelRsiUpper = 70;       //RSI limite superior
input int InpTrendAccelRsiLower = 30;       //RSI limite inferior
input int InpTrendAccelMaShortPeriod = 9;   //EMA curta
input int InpTrendAccelMaLongPeriod = 21;   //EMA longa
input double InpTrendAccelMaDist = 0.3;     //Distancia EMA longa (%)
input double InpTrendAccelAccelDist = 0.2;  //Aceleracao da EMA curta (%)
input double InpTrendAccelSLAtrFactor = 1.5; //Fator ATR para SL
input double InpTrendAccelTPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpTrendAccelStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpTrendAccelTPType = TP_FIXED; //Tipo de TP
input double InpTrendAccelTrailingAtr = 1.0; //Fator ATR do trailing
input double InpTrendAccelBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpTrendAccelProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpTrendAccelProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerCandleWave = "===================";  //#### Estrategia Candle Wave ####
input bool InpCandleWaveEnabled = true;     //Ativar estrategia Candle Wave
input int InpCandleWaveMaxOrders = 1;       //Maximo de ordens abertas da estrategia Candle Wave
input int InpCandleWavePendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpCandleWaveMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpCandleWaveVolumeAvgPeriod = 20; //Periodo da media de volume
input int InpCandleWaveTrendMaPeriod = 50; //Periodo da EMA de tendencia
input double InpCandleWaveSLAtrFactor = 1.5; //Fator ATR para SL
input double InpCandleWaveTPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpCandleWaveStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpCandleWaveTPType = TP_FIXED; //Tipo de TP
input double InpCandleWaveTrailingAtr = 1.0; //Fator ATR do trailing
input double InpCandleWaveBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpCandleWaveProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpCandleWaveProgressiveStepAtr = 1.0; //ATR de salto do SL

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

input string InpDividerTrendReversal = "===================";  //#### Estrategia Trend Reversal ####
input bool InpTrendReversalEnabled = true;     //Ativar estrategia Trend Reversal
input int InpTrendReversalMaxOrders = 1;       //Maximo de ordens abertas da estrategia Trend Reversal
input int InpTrendReversalPendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpTrendReversalMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpTrendReversalVolumeAvgPeriod = 20; //Periodo da media de volume (real)
input int InpTrendReversalTrendMaPeriod = 50; //Periodo da EMA de tendencia
input double InpTrendReversalCandleLongPercent = 20.0; //Candle longo: % acima do corpo anterior
input double InpTrendReversalCandleMaxAtr = 1.0; //Candle maximo: fator de ATR (1.0 = 1x ATR)
input double InpTrendReversalSLAtrFactor = 1.5; //Fator ATR para SL
input double InpTrendReversalTPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpTrendReversalStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpTrendReversalTPType = TP_FIXED; //Tipo de TP
input double InpTrendReversalTrailingAtr = 1.0; //Fator ATR do trailing
input double InpTrendReversalBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpTrendReversalProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpTrendReversalProgressiveStepAtr = 1.0; //ATR de salto do SL

input string InpDividerOutsiderBar = "===================";  //#### Estrategia Outsider Bar ####
input bool InpOutsiderBarEnabled = true;     //Ativar estrategia Outsider Bar
input int InpOutsiderBarMaxOrders = 1;       //Maximo de ordens abertas da estrategia Outsider Bar
input int InpOutsiderBarPendingTtlMinutes = 60; //Validade das pendentes (min)
input int InpOutsiderBarMaxHoldMinutes = 0; //Duracao maxima do trade (0 = sem limite)
input int InpOutsiderBarMaPeriod = 50;      //Periodo da EMA
input int InpOutsiderBarRsiPeriod = 14;     //RSI periodo
input int InpOutsiderBarRsiBuyLow = 55;     //RSI compra minimo
input int InpOutsiderBarRsiBuyHigh = 70;    //RSI compra maximo
input int InpOutsiderBarRsiSellLow = 30;    //RSI venda minimo
input int InpOutsiderBarRsiSellHigh = 45;   //RSI venda maximo
input double InpOutsiderBarBodyRatio = 0.6; //Corpo minimo (0-1) do candle
input double InpOutsiderBarSafeRange = 0.25; //Distancia minima da EMA (%)
input double InpOutsiderBarSLAtrFactor = 1.5; //Fator ATR para SL
input double InpOutsiderBarTPAtrFactor = 2.5; //Fator ATR para TP
input StopType InpOutsiderBarStopType = STOP_FIXED; //Fixo/Trailing/BreakEven/Progressivo
input TakeProfitType InpOutsiderBarTPType = TP_FIXED; //Tipo de TP
input double InpOutsiderBarTrailingAtr = 1.0; //Fator ATR do trailing
input double InpOutsiderBarBreakEvenTriggerAtr = 1.0; //ATR necessario para break-even
input double InpOutsiderBarProgressiveTriggerAtr = 1.8; //ATR para salto progressivo
input double InpOutsiderBarProgressiveStepAtr = 1.0; //ATR de salto do SL

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

   config.adx_enabled       = InpAdxEnabled;
   config.adx_max_orders    = InpAdxMaxOrders;
   config.adx_pending_ttl_minutes = InpAdxPendingTtlMinutes;
   config.adx_max_hold_minutes = InpAdxMaxHoldMinutes;
   config.adx_param1        = InpAdxParam1;
   config.adx_param2        = InpAdxParam2;
   config.adx_param3        = InpAdxMin;
   config.adx_param4        = InpAdxDiDiffMin;
   config.adx_param5        = InpAdxAtrMin;
   config.adx_sl_atr_factor = InpAdxSLAtrFactor;
   config.adx_tp_atr_factor = InpAdxTPAtrFactor;
   config.adx_stop_type     = InpAdxStopType;
   config.adx_tp_type       = InpAdxTPType;
   config.adx_trailing_atr_factor = InpAdxTrailingAtr;
   config.adx_breakeven_trigger_atr = InpAdxBreakEvenTriggerAtr;
   config.adx_progressive_trigger_atr = InpAdxProgressiveTriggerAtr;
   config.adx_progressive_step_atr = InpAdxProgressiveStepAtr;

   config.dtosc_enabled       = InpDtOscEnabled;
   config.dtosc_max_orders    = InpDtOscMaxOrders;
   config.dtosc_pending_ttl_minutes = InpDtOscPendingTtlMinutes;
   config.dtosc_max_hold_minutes = InpDtOscMaxHoldMinutes;
   config.dtosc_param1        = InpDtOscRsiPeriod;
   config.dtosc_param2        = InpDtOscStochPeriod;
   config.dtosc_rsi_period    = InpDtOscRsiPeriod;
   config.dtosc_stoch_period  = InpDtOscStochPeriod;
   config.dtosc_slowing_period = InpDtOscSlowingPeriod;
   config.dtosc_signal_period  = InpDtOscSignalPeriod;
   config.dtosc_dt_distance   = InpDtOscDistance;
   config.dtosc_ma_short_period = InpDtOscMaShortPeriod;
   config.dtosc_ma_long_period = InpDtOscMaLongPeriod;
   config.dtosc_ma_dist       = InpDtOscMaDist;
   config.dtosc_lower_zone    = InpDtOscLowerZone;
   config.dtosc_upper_zone    = InpDtOscUpperZone;
   config.dtosc_sl_atr_factor = InpDtOscSLAtrFactor;
   config.dtosc_tp_atr_factor = InpDtOscTPAtrFactor;
   config.dtosc_stop_type     = InpDtOscStopType;
   config.dtosc_tp_type       = InpDtOscTPType;
   config.dtosc_trailing_atr_factor = InpDtOscTrailingAtr;
   config.dtosc_breakeven_trigger_atr = InpDtOscBreakEvenTriggerAtr;
   config.dtosc_progressive_trigger_atr = InpDtOscProgressiveTriggerAtr;
   config.dtosc_progressive_step_atr = InpDtOscProgressiveStepAtr;

   config.trend_accel_enabled       = InpTrendAccelEnabled;
   config.trend_accel_max_orders    = InpTrendAccelMaxOrders;
   config.trend_accel_pending_ttl_minutes = InpTrendAccelPendingTtlMinutes;
   config.trend_accel_max_hold_minutes = InpTrendAccelMaxHoldMinutes;
   config.trend_accel_rsi_period    = InpTrendAccelRsiPeriod;
   config.trend_accel_rsi_upper     = InpTrendAccelRsiUpper;
   config.trend_accel_rsi_lower     = InpTrendAccelRsiLower;
   config.trend_accel_ma_short_period = InpTrendAccelMaShortPeriod;
   config.trend_accel_ma_long_period = InpTrendAccelMaLongPeriod;
   config.trend_accel_ma_dist       = InpTrendAccelMaDist;
   config.trend_accel_accel_dist    = InpTrendAccelAccelDist;
   config.trend_accel_sl_atr_factor = InpTrendAccelSLAtrFactor;
   config.trend_accel_tp_atr_factor = InpTrendAccelTPAtrFactor;
   config.trend_accel_stop_type     = InpTrendAccelStopType;
   config.trend_accel_tp_type       = InpTrendAccelTPType;
   config.trend_accel_trailing_atr_factor = InpTrendAccelTrailingAtr;
   config.trend_accel_breakeven_trigger_atr = InpTrendAccelBreakEvenTriggerAtr;
   config.trend_accel_progressive_trigger_atr = InpTrendAccelProgressiveTriggerAtr;
   config.trend_accel_progressive_step_atr = InpTrendAccelProgressiveStepAtr;

   config.candle_wave_enabled       = InpCandleWaveEnabled;
   config.candle_wave_max_orders    = InpCandleWaveMaxOrders;
   config.candle_wave_pending_ttl_minutes = InpCandleWavePendingTtlMinutes;
   config.candle_wave_max_hold_minutes = InpCandleWaveMaxHoldMinutes;
   config.candle_wave_volume_avg_period = InpCandleWaveVolumeAvgPeriod;
   config.candle_wave_trend_ma_period = InpCandleWaveTrendMaPeriod;
   config.candle_wave_sl_atr_factor = InpCandleWaveSLAtrFactor;
   config.candle_wave_tp_atr_factor = InpCandleWaveTPAtrFactor;
   config.candle_wave_stop_type     = InpCandleWaveStopType;
   config.candle_wave_tp_type       = InpCandleWaveTPType;
   config.candle_wave_trailing_atr_factor = InpCandleWaveTrailingAtr;
   config.candle_wave_breakeven_trigger_atr = InpCandleWaveBreakEvenTriggerAtr;
   config.candle_wave_progressive_trigger_atr = InpCandleWaveProgressiveTriggerAtr;
   config.candle_wave_progressive_step_atr = InpCandleWaveProgressiveStepAtr;
   for(int i = 0; i < CANDLE_PATTERN_COUNT; ++i)
   {
   config.candle_wave_pattern_configs[i].enabled = false;
   config.candle_wave_pattern_configs[i].min_atr = 0.0;
   config.candle_wave_pattern_configs[i].max_atr = 0.0;
   }
   config.candle_wave_pattern_configs[PATTERN_DOJI].enabled = InpCandleDojiEnabled;
   config.candle_wave_pattern_configs[PATTERN_DOJI].min_atr = InpCandleDojiMinAtr;
   config.candle_wave_pattern_configs[PATTERN_DOJI].max_atr = InpCandleDojiMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_GREEN].enabled = InpCandleMarubozuGreenEnabled;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_GREEN].min_atr = InpCandleMarubozuGreenMinAtr;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_GREEN].max_atr = InpCandleMarubozuGreenMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_RED].enabled = InpCandleMarubozuRedEnabled;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_RED].min_atr = InpCandleMarubozuRedMinAtr;
   config.candle_wave_pattern_configs[PATTERN_MARUBOZU_RED].max_atr = InpCandleMarubozuRedMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_RED].enabled = InpCandleShootingStarRedEnabled;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_RED].min_atr = InpCandleShootingStarRedMinAtr;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_RED].max_atr = InpCandleShootingStarRedMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].enabled = InpCandleShootingStarGreenEnabled;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].min_atr = InpCandleShootingStarGreenMinAtr;
   config.candle_wave_pattern_configs[PATTERN_SHOOTING_STAR_GREEN].max_atr = InpCandleShootingStarGreenMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_SPINNING_TOP].enabled = InpCandleSpinningTopEnabled;
   config.candle_wave_pattern_configs[PATTERN_SPINNING_TOP].min_atr = InpCandleSpinningTopMinAtr;
   config.candle_wave_pattern_configs[PATTERN_SPINNING_TOP].max_atr = InpCandleSpinningTopMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_GREEN].enabled = InpCandleHammerGreenEnabled;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_GREEN].min_atr = InpCandleHammerGreenMinAtr;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_GREEN].max_atr = InpCandleHammerGreenMaxAtr;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_RED].enabled = InpCandleHammerRedEnabled;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_RED].min_atr = InpCandleHammerRedMinAtr;
   config.candle_wave_pattern_configs[PATTERN_HAMMER_RED].max_atr = InpCandleHammerRedMaxAtr;

   config.trend_reversal_enabled       = InpTrendReversalEnabled;
   config.trend_reversal_max_orders    = InpTrendReversalMaxOrders;
   config.trend_reversal_pending_ttl_minutes = InpTrendReversalPendingTtlMinutes;
   config.trend_reversal_max_hold_minutes = InpTrendReversalMaxHoldMinutes;
   config.trend_reversal_volume_avg_period = InpTrendReversalVolumeAvgPeriod;
   config.trend_reversal_trend_ma_period = InpTrendReversalTrendMaPeriod;
   config.trend_reversal_candle_long_percent = InpTrendReversalCandleLongPercent;
   config.trend_reversal_candle_max_atr = InpTrendReversalCandleMaxAtr;
   config.trend_reversal_sl_atr_factor = InpTrendReversalSLAtrFactor;
   config.trend_reversal_tp_atr_factor = InpTrendReversalTPAtrFactor;
   config.trend_reversal_stop_type     = InpTrendReversalStopType;
   config.trend_reversal_tp_type       = InpTrendReversalTPType;
   config.trend_reversal_trailing_atr_factor = InpTrendReversalTrailingAtr;
   config.trend_reversal_breakeven_trigger_atr = InpTrendReversalBreakEvenTriggerAtr;
   config.trend_reversal_progressive_trigger_atr = InpTrendReversalProgressiveTriggerAtr;
   config.trend_reversal_progressive_step_atr = InpTrendReversalProgressiveStepAtr;

   config.outsider_bar_enabled       = InpOutsiderBarEnabled;
   config.outsider_bar_max_orders    = InpOutsiderBarMaxOrders;
   config.outsider_bar_pending_ttl_minutes = InpOutsiderBarPendingTtlMinutes;
   config.outsider_bar_max_hold_minutes = InpOutsiderBarMaxHoldMinutes;
   config.outsider_bar_ma_period     = InpOutsiderBarMaPeriod;
   config.outsider_bar_rsi_period    = InpOutsiderBarRsiPeriod;
   config.outsider_bar_rsi_buy_low   = InpOutsiderBarRsiBuyLow;
   config.outsider_bar_rsi_buy_high  = InpOutsiderBarRsiBuyHigh;
   config.outsider_bar_rsi_sell_low  = InpOutsiderBarRsiSellLow;
   config.outsider_bar_rsi_sell_high = InpOutsiderBarRsiSellHigh;
   config.outsider_bar_body_ratio    = InpOutsiderBarBodyRatio;
   config.outsider_bar_safe_range    = InpOutsiderBarSafeRange;
   config.outsider_bar_sl_atr_factor = InpOutsiderBarSLAtrFactor;
   config.outsider_bar_tp_atr_factor = InpOutsiderBarTPAtrFactor;
   config.outsider_bar_stop_type     = InpOutsiderBarStopType;
   config.outsider_bar_tp_type       = InpOutsiderBarTPType;
   config.outsider_bar_trailing_atr_factor = InpOutsiderBarTrailingAtr;
   config.outsider_bar_breakeven_trigger_atr = InpOutsiderBarBreakEvenTriggerAtr;
   config.outsider_bar_progressive_trigger_atr = InpOutsiderBarProgressiveTriggerAtr;
   config.outsider_bar_progressive_step_atr = InpOutsiderBarProgressiveStepAtr;

   config.lot_size             = InpLotSize;
   config.enable_notifications = InpEnableNotifications;
   config.enable_time_exit     = InpEnableTimeExit;
   config.enable_logging       = InpEnableLogging;
   config.enable_email         = InpEnableEmail;
   config.enable_push          = InpEnablePush;
   config.enable_debug         = InpEnableDebug;
   config.max_trade_risk       = InpMaxRiskPerTrade;
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
