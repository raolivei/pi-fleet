# Finance BR Skill

Fetch real-time Brazilian financial indicators using public APIs — no authentication required.

## Tools

Use `web_fetch` to call these endpoints directly.

### bcb_selic
Current Selic target rate (% per year).

HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "14.25"}]

Example: "Qual a Selic hoje?"

### bcb_cdi
Current CDI rate (% per year, effective daily rate).

HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.4389/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "14.15"}]

Example: "Qual o CDI atual?"

### bcb_ipca
Latest IPCA monthly inflation (% for the month).

HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "0.16"}]

Example: "Qual foi o IPCA do último mês?"

### bcb_selic_efetiva
Daily effective Selic rate (annualized, last business day).

HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "0.052531"}]

### bcb_ptax_usd
Latest USD/BRL PTAX rate (last 5 business days, most recent first).

HTTP: GET https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarPeriodo(dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?@dataInicial='07-01-2026'&@dataFinalCotacao='07-20-2026'&$top=1&$orderby=dataHoraCotacao%20desc&$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao

**Important**: Replace dates with actual current and 10-days-ago dates in MM-DD-YYYY format before calling.
Returns: {"value": [{"cotacaoCompra": 5.117, "cotacaoVenda": 5.1176, "dataHoraCotacao": "2026-07-17 13:10:18"}]}

Example: "Qual o dólar hoje?"

## BCB Series Reference

| Indicador | Série | Frequência |
|-----------|-------|-----------|
| Selic meta | 432 | Por reunião COPOM |
| CDI | 4389 | Diária |
| IPCA | 433 | Mensal |
| Selic efetiva | 11 | Diária |
| IGP-M | 189 | Mensal |
| Taxa de câmbio EUR | 21619 | Diária |

URL pattern: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{SERIE}/dados/ultimos/{N}?formato=json`

## BRAPI — B3 Stocks, Crypto, Funds (requires token)

Token is available in the `BRAPI_API_KEY` environment variable.
Always append `?token=$BRAPI_API_KEY` to BRAPI requests.

Base URL: `https://brapi.dev`

### brapi_quote
Real-time B3 stock or BDR quote.

HTTP: GET https://brapi.dev/api/quote/{ticker}?token=$BRAPI_API_KEY
Example tickers: PETR4, VALE3, ITUB4, BBDC4, B3SA3
Returns: {"results": [{"symbol": "PETR4", "regularMarketPrice": 38.50, "regularMarketChangePercent": 1.2, ...}]}

Example: "Qual a cotação da PETR4?" → GET /api/quote/PETR4?token=...

### brapi_crypto
Crypto price in BRL or USD.

HTTP: GET https://brapi.dev/api/v2/crypto?coin={coin}&currency=BRL&token=$BRAPI_API_KEY
Example coins: BTC, ETH, SOL, BNB
Returns: {"coins": [{"coin": "BTC", "regularMarketPrice": 620000, "regularMarketChangePercent": 2.1, ...}]}

Example: "Qual o Bitcoin em reais?" → GET /api/v2/crypto?coin=BTC&currency=BRL&token=...

### brapi_funds
Brazilian investment fund (FII or fundo) data.

HTTP: GET https://brapi.dev/api/v2/funds/{ticker}?token=$BRAPI_API_KEY

### brapi_available
List all available tickers.

HTTP: GET https://brapi.dev/api/available?token=$BRAPI_API_KEY

## Example Conversations

User: "Qual a Selic atual?"
Assistant: *web_fetch GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados/ultimos/1?formato=json → "A Selic meta está em 14,25% a.a. (decisão de 05/08/2026)"*

User: "Qual o CDI e quanto rende em 1 ano?"
Assistant: *web_fetch CDI (4389) → calcula rendimento bruto e líquido (IR 15%)*

User: "Quanto está o dólar?"
Assistant: *web_fetch PTAX com datas atuais → "USD/BRL: R$ 5,12 (compra) / R$ 5,12 (venda) — PTAX de 17/07/2026"*

User: "Qual a cotação da VALE3?"
Assistant: *web_fetch GET https://brapi.dev/api/quote/VALE3?token=$BRAPI_API_KEY → mostra preço, variação % do dia*

User: "Quanto está o Bitcoin em reais?"
Assistant: *web_fetch GET https://brapi.dev/api/v2/crypto?coin=BTC&currency=BRL&token=$BRAPI_API_KEY*

User: "No que devo investir no Brasil no curto prazo?"
Assistant: *web_fetch Selic (432) + CDI (4389) + IPCA (433) → analisa contexto: Selic 14.25%, IPCA recente, CDI como benchmark → recomendações: Tesouro Selic, CDBs 100%+ CDI, LCI/LCA isentos*
