# Web Browsing Skill

Use built-in tools to fetch web pages, read URLs, and search the internet.

## Tools

### web_fetch (built-in)
Fetch any URL — GET or POST. Use for reading articles, API responses, documentation pages.

Examples:
- Read a news article: web_fetch GET https://example.com/article
- Call a public API: web_fetch GET https://api.example.com/data
- POST to an API: web_fetch POST https://api.example.com/query with JSON body

### Brave Search (built-in, key auto-loaded from BRAVE_API_KEY env)
Search the web when you need current events, news, prices, or information not available from cluster services.

**Use Brave Search when:**
- The user asks about current events or recent news
- You need real-world context not in cluster docs
- A URL fetch returns a 404 or unhelpful content
- The user asks to "search" or "look up" something on the internet

**Do NOT use for:**
- Cluster ops → use kubectl or elder_*
- Project docs → use workspace_ask (Ollie) or elder_search_code
- Brazilian financial indicators → use finance-br-skill (BCB API, no key needed)

## Example Conversations

User: "Por que o preço do petróleo subiu em Toronto esses dias?"
Assistant: *Brave Search "oil price spike Toronto July 2026" → summarizes top results*

User: "Lê esse artigo pra mim: https://..."
Assistant: *web_fetch GET <url> → summarizes content*

User: "Qual a cotação do Bitcoin agora?"
Assistant: *Brave Search "Bitcoin BRL price" → returns current price*
