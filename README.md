# Nexo – Framework Modular de Expert Advisor (MT5)

## Visao geral
Nexo e um framework modular de Expert Advisor (EA) para MT5, com multiplas estrategias independentes, regras de risco centralizadas e arquitetura baseada em Clean Architecture + DDD. A ideia e separar regras de negocio do acesso ao mercado, facilitando a manutencao, a evolucao e o teste no Strategy Tester.

Requisito de conta:
- O EA exige conta em modo hedge (ACCOUNT_MARGIN_MODE_RETAIL_HEDGE).

Observacoes gerais:
- O EA opera sempre no simbolo configurado por input, independente do simbolo da janela.
- O timeframe de execucao e configurado por input.

## Requisitos implementados ate agora

### RF01 – Controle de janela de operacao
O EA so permite novas operacoes dentro de um horario definido. O horario e configurado por inputs (hora e minuto de inicio e fim). Fora da janela, novas entradas sao bloqueadas.

### RF02 – Encerramento fora do horario
Ao sair da janela, o EA aguarda um tempo de tolerancia (em minutos) e, apos esse periodo, fecha todas as posicoes abertas. A contagem usa horario do servidor.

### RF03 – Execucao por novo candle
A logica de estrategias roda apenas quando abre um novo candle no timeframe definido por input. Isso evita executar sinais em cada tick.

Observacao de performance:
- Sinais de estrategia rodam no novo candle.
- Regras de risco/seguranca rodam a cada tick (limites, time-exit, stops, licenca).

### RF04 – Multiplas estrategias
O EA suporta mais de uma estrategia simultaneamente. Cada estrategia:
- pode ser ativada/desativada via input
- possui parametros proprios
- usa multiplicadores proprios de SL/TP baseados no ATR suavizado global
- nao calcula ATR por conta propria

Estrategias atuais:
- ADX (tendencia + aceleracao do ADX)
- DT Oscillator (retomada/reversao com RSI/Stoch + EMA + padroes de candle)
- Trend Accelerator (tendencia + aceleracao da EMA curta + filtro RSI)
- Candle Wave (padroes de candle configuraveis com ATR + filtro de volume)
- Trend Reversal (reversao por candle longo + EMA + volume)
- Outsider Bar (breakout pendente com EMA + RSI + outside bar)

### RF05 – Controle de ordens (global e por estrategia)
O EA controla limites de ordens abertas e expira pendentes:
- Limite global baseado em posicoes abertas. Ao atingir o limite, o EA cancela todas as ordens pendentes automaticamente.
- Limite por estrategia: cada estrategia pode ter um maximo de posicoes abertas (ate o limite global).
- Ordens pendentes por estrategia podem ter tempo de vida (TTL). Ao vencer, sao removidas automaticamente.
- O EA identifica a estrategia de cada ordem via comentario padronizado (strategy_id).

### RF06 – Notificacoes e logging
Eventos monitorados:
- abertura de ordem
- fechamento (SL, TP, manual, tempo, etc.)

Saidas:
- log em arquivo persistente
- e-mail (SendMail)
- push notification (SendNotification)

Observacoes:
- Notificacoes/Log so sao verificados se o usuario habilitar os respectivos inputs.
- Permissoes do terminal (email/push/trade) sao validadas e avisos sao registrados.

### RF07 – Gestao diaria de risco
Parametros:
- limite de perda diaria
- limite de ganho diario
- limite maximo de trades no dia
- limite maximo de trades com loss no dia

Regra:
ao atingir qualquer limite, o EA bloqueia novas operacoes, cancela pendentes e fecha todas as posicoes abertas.

### RF08 – Configuracao de lote (B3)
O EA valida o lote base informado e exige que seja inteiro (1.0, 2.0, etc). Se o lote nao for inteiro, a inicializacao falha.

### RF09 – ATR suavizado (global)
O ATR e calculado uma unica vez (global) com suavizacao EMA e baseado no timeframe configurado por input. As estrategias recebem esse valor e aplicam apenas seus multiplicadores de SL/TP.

### RF10 – Stop Loss
Tipos suportados:
- fixo
- trailing
- break-even
- progressivo (por saltos)

Cada estrategia escolhe o tipo via input e pode definir fatores de ATR para trailing, break-even e progressivo. A atualizacao do stop ocorre a cada tick.

O stop e normalizado pelo tick size do simbolo (B3), para evitar rejeicao de ordens.

Observacao:
- O ATR usado para SL/TP e o ATR da abertura, armazenado no comentario da ordem.

### RF11 – Take Profit
Tipo minimo:
- fixo (baseado no fator de ATR suavizado)

Estrutura extensivel:
- implementada via enum de tipo de TP.

### RF12 – Encerramento por estrategia
Cada estrategia pode sinalizar saida. No novo candle, o EA verifica as posicoes abertas, identifica a estrategia pelo comentario e fecha a posicao se `ShouldClose()` retornar verdadeiro.

### RF13 – Encerramento por tempo (por estrategia)
Cada estrategia define um tempo maximo de permanencia. No novo candle, se a posicao exceder esse tempo, o EA fecha a posicao automaticamente.

### RF14 – Licenciamento
O EA exige uma chave de ativacao. A licenca define:
- conta permitida (ACCOUNT_LOGIN)
- ativos permitidos (lista CSV)
- timeframes permitidos (lista CSV)
- lote maximo permitido
- validade (YYYY-MM-DD, horario do servidor)
- estrategias permitidas (lista CSV ou "*")

Regras:
- Se a licenca for invalida ou expirada, o EA nao opera.
- Se o simbolo/timeframe/lote nao estiverem permitidos, o EA bloqueia novas operacoes.
- Estrategias nao autorizadas sao desativadas no init.

Formato da licenca:
- Payload compacto (`a=...|e=...|s=...|t=...|l=...|g=...|d=...`).
- Assinatura: SHA256(secret+payload), truncada em 16 bytes e codificada em Base64URL.
- Chave: `base64url(payload).base64url(signature)`.

Licenca demo:
- Se `d=1`, a licenca e valida apenas para contas DEMO.
- Nesse modo, o campo `a` pode ser `0` (qualquer conta demo).
- O EA ja vem com uma licenca demo padrao nos inputs.
- Demo padrao: WIN*/WDO*, timeframes M2/M5, max lot 1, estrategias "*", validade ate 2030-12-31.
- Se voce mudar `LICENSE_SECRET`, gere uma nova licenca demo e atualize o input.

### RF15 – Habilitacao de modulos
Cada modulo pode ser ativado/desativado via input:
- controle de horario
- gestao diaria
- limite de trades (diario)
- limite de ordens
- encerramento por tempo
- notificacoes/log

### RF16 – Protecao de parametros
O EA valida parametros criticos para garantir valores coerentes (ex.: ATR > 0, lotes > 0, limites nao negativos). Se invalido, o EA nao inicia ou interrompe a execucao.

### RF17 – Criterios de otimizacao no Tester
O EA permite escolher criterios de otimizacao no Strategy Tester, incluindo metricas Monte Carlo e regressao linear sobre o P/L. O criterio e escolhido por input e aplicado no `OnTester`.

## Estrategias

### ADX
Objetivo: operar movimentos com aceleracao do ADX apos cruzamento de DI.

Regras (resumo):
- aguarda cruzamento de +DI/-DI
- confirma quando o ADX acelera (`ADX[t-1] - ADX[t-2] >= step`)
- compra: +DI dominante
- venda: -DI dominante

Parametros principais:
- ADX periodo
- ADX step

### DT Oscillator
Objetivo: capturar retomadas/reversoes com DT Oscillator + tendencia por EMA + padrao de candle.

Regras (resumo):
- tendencia por EMA curta/longa com distancia percentual
- cruzamento DTOSC/DTOSS com distancia minima
- zonas (inferior/superior)
- confirmacao pelo candle (padroes de compra/venda)

Parametros principais:
- RSI periodo
- Stoch periodo
- DT smoothing e DT signal
- Distancia DT
- EMA curta e EMA longa
- Distancia EMA (%)
- Zona inferior e zona superior

### Trend Accelerator
Objetivo: capturar aceleracoes de tendencia com EMA curta/longa e filtro de RSI.

Regras (resumo):
- tendencia por EMA curta/longa com distancia opcional
- aceleracao da EMA curta acima/abaixo de um percentual minimo
- filtro de RSI (limites superior e inferior)
- confirmacao de preco (ultimo low acima da EMA curta para compra; ultimo high abaixo para venda)
- entrada por ordem pendente (BUY_LIMIT/SELL_LIMIT) no pullback do low/high recente

Parametros principais:
- RSI periodo, limite superior e inferior
- EMA curta e EMA longa
- Distancia EMA longa (%)
- Aceleracao da EMA curta (%)

### Candle Wave
Objetivo: operar padroes de candle configuraveis usando tamanho relativo ao ATR, com filtro de tendencia e volume.

Regras (resumo):
- filtro de tendencia por EMA longa (close acima = compra, abaixo = venda)
- padrao de candle identificavel com min/max em fator de ATR
- filtro de volume acima da media
- padroes de compra e venda sao fixos (ex.: Marubozu/Hammer para compra, Shooting Star/Marubozu red para venda)

Parametros principais:
- Periodo da EMA de tendencia
- Periodo da media de volume
- Habilitar/Min ATR/Max ATR por padrao de candle

### Trend Reversal
Objetivo: operar reversoes com candle longo, filtro de EMA e confirmacao de volume.

Regras (resumo):
- tendencia por EMA curta (close acima = compra, abaixo = venda)
- candle atual com corpo maior que o anterior em X%
- reversao simples (candle atual fecha acima/abaixo da abertura anterior)
- filtro de volume real acima da media
- limite maximo do candle por fator de ATR

Parametros principais:
- Periodo da EMA de tendencia
- Periodo da media de volume (real)
- Candle longo: % acima do corpo anterior
- Candle maximo: fator de ATR

### Outsider Bar
Objetivo: operar rompimentos com outside bar e filtro de EMA/RSI.

Regras (resumo):
- candle atual e outside bar (high maior e low menor que o candle anterior)
- corpo do candle acima de um percentual minimo do range
- close acima/abaixo da EMA por distancia percentual
- RSI dentro da faixa configurada para compra/venda
- entrada por ordem pendente (BUY_STOP/SELL_STOP) no high/low do candle

Parametros principais:
- Periodo da EMA
- RSI periodo e faixas de compra/venda
- Corpo minimo (0-1) do candle
- Distancia minima da EMA (%)

## Gestores e logica principal (explicacao simples)

### Janela de operacao
1. Dentro do horario: permite analisar sinais.
2. Fora do horario:
   - antes do inicio: nao abre novas operacoes.
   - depois do fim: aguarda X minutos e fecha todas as posicoes.

### Execucao por candle
Mesmo dentro do horario, a logica de estrategia so roda na abertura de um novo candle. Isso padroniza o comportamento e evita sinais repetidos no mesmo candle.

### ATR suavizado global
O ATR e calculado uma vez (global) e suavizado por EMA. O calculo usa apenas candles fechados. As estrategias recebem esse valor e aplicam seus multiplicadores de SL/TP.

### Dados de mercado para estrategias
As estrategias recebem:
- `MarketSnapshot`: bid/ask/last, ponto, digitos e horario do servidor.
- `MarketHistory`: OHLC de candles fechados (historico).

Com isso, a estrategia pode analisar padroes de candles sem chamar diretamente a API do MT5.

### Normalizacao por tick size
SL (e futuramente TP/entrada) sao normalizados para o tick size do simbolo, garantindo compatibilidade com ativos da B3 (ex.: mini indice de 5 em 5 pontos).

## Estrutura de diretorios

```
Nexo/
  Nexo.mq5                 -> ponto de entrada do EA
  src/
    App/                   -> orquestracao do fluxo
    Domain/                -> entidades, value objects e contratos de negocio
    Infra/                 -> adaptadores para MT5 (mercado, licenca, logs)
    Strategies/            -> estrategias plugaveis
    Shared/                -> utilitarios e tipos genericos
    UI/Dashboard/          -> placeholder para painel futuro
```

## Inputs principais (resumo)
- Simbolo de operacao (obrigatorio)
- Horario de operacao (inicio/fim)
- Minutos de tolerancia para encerramento
- Limite global de posicoes abertas
- Limites diarios (loss/profit/trades/loss trades)
- ATR: periodo, periodo da EMA e timeframe
- Filtro de tendencia (3 MAs + distancias percentuais) aplicado a Candle Wave e Trend Reversal
- Timeframe de execucao (novo candle)
- Lote base (inteiro para B3)
- Parametros das estrategias (ativacao, fatores SL/TP, parametros internos)
- Tipo de stop por estrategia e parametros (trailing, break-even, progressivo)
- Notificacoes e log (habilitar e-mail/push/arquivo)
- Tester (inputs finais): criterio de otimizacao, restricao de drawdown e share do forward

## Automacao de testes no Strategy Tester

Para organizar testes automatizados no tester do MT5 criamos uma estrutura em `tests/automation`:

- `tests/automation/inputs/` deve receber os arquivos `.ini` que configuram cada execução (EA, timeframe, periodo, otimizacao, etc.).
- `tests/automation/reports/` recebe os relatórios `.htm` copiados logo após cada teste.

O script `tools/run-tester-tests.ps1` percorre todos os `.ini` dentro de `tests/automation/inputs`, dispara o terminal MT5 com `/config:<ini>` e copia o novo `.htm` gerado da pasta de resultados para `tests/automation/reports`. Ele aceita parâmetros opcionais:

```
pwsh tools/run-tester-tests.ps1 `
  -TerminalPath 'C:\Program Files\MetaTrader 5\terminal64.exe' `
  -InputsDir tests/automation/inputs `
  -ReportsDir tests/automation/reports `
  -TesterFilesDir "$env:APPDATA\MetaQuotes\Terminal\<INSTANCE>\MQL5\Tester\Files" `
  -ExtraTerminalArgs '/quit' # ou outros parâmetros que queira passar
```

Como o MT5 escreve os `.htm` em uma pasta conhecida, informe o caminho correto em `-TesterFilesDir` para que o script possa copiar o relatório e renomeá-lo com o mesmo nome do `.ini`. Se preferir, mantenha os parâmetros padrões e certifique-se de que o script consegue localizar `terminal64.exe` e a pasta de relatórios.

O fluxo típico é:
1. colocar cada cenário em um `.ini` dentro de `tests/automation/inputs`;
2. rodar `tools/run-tester-tests.ps1` (pode ser agendado);
3. os relatórios recém gerados vão para `tests/automation/reports` com nomes únicos (`<iniBase>_<timestamp>.htm`) e os arquivos auxiliares como `<iniBase>_<timestamp>.xml` também são copiados.

Essa automação facilita cronogramas de teste contínuo e mantém os assets separados do código principal.
