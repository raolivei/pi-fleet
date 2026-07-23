# Finance BR Skill

Fetch real-time Brazilian financial indicators using public APIs.

**NEVER use exec, Python scripts, or Yahoo Finance for financial data.**
**NEVER say you lack access to Brazilian financial data — all endpoints below work.**

## BCB — Indicators (no auth required)

Use `web_fetch` GET directly.

### bcb_selic
HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "14.25"}]
Example: "Qual a Selic hoje?"

### bcb_cdi
HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.4389/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "14.15"}]
Example: "Qual o CDI atual?"

### bcb_ipca
HTTP: GET https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados/ultimos/1?formato=json
Returns: [{"data": "DD/MM/YYYY", "valor": "0.16"}]
Example: "Qual foi o IPCA do último mês?"

### bcb_ptax_usd
HTTP: GET https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarPeriodo(dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?@dataInicial='MM-DD-YYYY'&@dataFinalCotacao='MM-DD-YYYY'&$top=1&$orderby=dataHoraCotacao%20desc&$format=json&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao

Replace both dates: dataInicial = 10 days ago, dataFinalCotacao = today, in MM-DD-YYYY format.
Returns: {"value": [{"cotacaoCompra": 5.117, "cotacaoVenda": 5.1176, "dataHoraCotacao": "..."}]}
Example: "Quanto está o dólar?"

### BCB series reference
URL pattern: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{SERIE}/dados/ultimos/{N}?formato=json`

| Indicador | Série |
|-----------|-------|
| Selic meta | 432 |
| CDI | 4389 |
| IPCA | 433 |
| Selic efetiva diária | 11 |
| IGP-M | 189 |

## BRAPI — B3 Stocks and Funds (token required)

Token: `$BRAPI_API_KEY` env var. Always append `?token=$BRAPI_API_KEY`.

### brapi_quote
HTTP: GET https://brapi.dev/api/quote/{TICKER}?token=$BRAPI_API_KEY
Example tickers: PETR4, VALE3, ITUB4, BBDC4, B3SA3, WEGE3
Returns: {"results": [{"symbol": "PETR4", "regularMarketPrice": 41.66, "regularMarketChangePercent": 1.24, "regularMarketDayHigh": 41.70, "regularMarketDayLow": 41.13}]}
Example: "Qual a cotação da PETR4?" → GET /api/quote/PETR4?token=$BRAPI_API_KEY

### brapi_funds (FIIs)
HTTP: GET https://brapi.dev/api/v2/funds/{TICKER}?token=$BRAPI_API_KEY

## Mercado Bitcoin — Crypto in BRL (no auth required)

**Use this for ALL crypto prices in BRL — BRAPI does not support crypto in BRL.**

HTTP: GET https://www.mercadobitcoin.net/api/{COIN}/ticker/
Example coins: BTC, ETH, SOL, BNB, ADA, XRP, MATIC
Returns: {"ticker": {"last": "338473.00", "high": "341655.00", "low": "333194.00", "vol": "26.43"}}

Examples:
- "Quanto está o Bitcoin em reais?" → GET https://www.mercadobitcoin.net/api/BTC/ticker/
- "Qual o preço do Ethereum?" → GET https://www.mercadobitcoin.net/api/ETH/ticker/
- "Quanto está a Solana?" → GET https://www.mercadobitcoin.net/api/SOL/ticker/

## Example Conversations

User: "Qual a Selic atual?"
Assistant: *web_fetch BCB série 432 → "Selic meta: 14,25% a.a."*

User: "Quanto está o dólar?"
Assistant: *web_fetch BCB PTAX com datas atuais → "USD/BRL: R$ 5,12 (compra/venda) — PTAX de DD/MM/YYYY"*

User: "Qual a cotação da VALE3?"
Assistant: *web_fetch https://brapi.dev/api/quote/VALE3?token=$BRAPI_API_KEY → preço + variação do dia*

User: "Quanto está o Bitcoin em reais?"
Assistant: *web_fetch https://www.mercadobitcoin.net/api/BTC/ticker/ → "BTC: R$ 338.473 (máx R$ 341.655, mín R$ 333.194)"*

User: "No que devo investir no Brasil no curto prazo?"
Assistant: *web_fetch Selic (432) + CDI (4389) + IPCA (433) → analisa: Selic 14,25%, CDI benchmark, IPCA recente → Tesouro Selic, CDBs 100%+ CDI, LCI/LCA isentos*
