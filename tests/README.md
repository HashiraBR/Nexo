# Testes Unitarios - Nexo

## Como rodar
1. Abra o MetaEditor e compile [TestRunner.mq5](./TestRunner.mq5).
2. No MT5, va em Navigator > Scripts e execute `TestRunner`.
3. Confira o log em Experts/Journal. O resumo final aparece como:
   - `Tests completed. Total=... Failed=...`

## Observacoes
- Os testes atuais validam funcoes criticas ja implementadas:
  - integridade de configuracao
  - janela de operacao
  - tags e ATR no comentario
  - licenciamento (decode, assinatura e permissoes)
- Para adicionar novos testes, edite `TestRunner.mq5` e crie novas funcoes de teste.
