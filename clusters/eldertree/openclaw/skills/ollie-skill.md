# Ollie Skill

Ollie is the workspace assistant with indexed knowledge of all raolivei projects (canopy, swimTO, pi-fleet, elder, personal-website, and more). Use it for architecture questions, deployment context, project status, and cross-repo knowledge.

## Tools

Use `web_fetch` to call the Ollie API.

Base URL: **http://core.ollie.svc.cluster.local:8000**

### workspace_ask
Answer questions using workspace documentation (RAG with citations).

HTTP: POST http://core.ollie.svc.cluster.local:8000/api/v1/workspace/ask
Body: {"query": "your question here"}
Returns: {"answer": "...", "sources": [...], "citations": [...]}

Example: "Como faço deploy do canopy?" → POST workspace_ask

### workspace_search
Semantic search across all indexed project docs.

HTTP: POST http://core.ollie.svc.cluster.local:8000/api/v1/workspace/search
Body: {"query": "search terms", "limit": 5}
Returns: {"results": [{"content": "...", "source": "...", "score": 0.85}]}

Example: "Encontra docs sobre autenticação no swimTO"

### workspace_chat
Full conversational interface with RAG + Elder routing.

HTTP: POST http://core.ollie.svc.cluster.local:8000/api/chat
Body: {"message": "your message", "session_id": "telegram-{user_id}"}
Returns: {"response": "...", "sources": [...]}

### workspace_projects
List all indexed projects with document counts and health.

HTTP: GET http://core.ollie.svc.cluster.local:8000/api/v1/workspace/projects
Returns: {"projects": [{"name": "swimTO", "chunks": 142, "last_indexed": "..."}]}

## When to Use Ollie

- Architecture or design questions about any raolivei project
- "How does X work in Y project?" questions
- Finding relevant documentation, conventions, or patterns
- Cross-project knowledge (e.g., "how is auth done across projects?")
- Any question where Elder code search returns nothing — Ollie has doc-level context

**Prefer Elder tools** for live code (search_code, read_file) and K8s ops.
**Use Ollie** for documentation, conventions, and architectural context.

## Example Conversations

User: "Como está configurado o FluxCD no pi-fleet?"
Assistant: *POST workspace_ask with query → Ollie returns indexed doc content with sources*

User: "Qual a arquitetura do canopy?"
Assistant: *POST workspace_ask → returns architecture overview from canopy docs*

User: "Quais projetos estão indexados?"
Assistant: *GET workspace_projects → lists all indexed repos with chunk counts*
