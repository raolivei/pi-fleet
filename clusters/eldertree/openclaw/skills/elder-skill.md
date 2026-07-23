# Elder Skill

Elder is your AI agent that can browse codebases, manage GitHub issues/PRs,
monitor Kubernetes, trigger deployments, and plan project features.
Elder has its own GitHub App identity ("Elder [bot]").

## How to Call Skills

Skills below describe HTTP calls you make using your `web_fetch` tool.
The Elder API base URL is: **http://elder.openclaw.svc.cluster.local:8000**

**Every Elder API call requires this header — always include it:**
```
X-API-Key: $ELDER_API_KEY
```
The key is in the `ELDER_API_KEY` environment variable. Do not skip it or try to discover it — just use `$ELDER_API_KEY` directly.

Example — `elder_list_repos`:
  `web_fetch GET http://elder.openclaw.svc.cluster.local:8000/api/code/repos`
  Headers: `{"X-API-Key": "$ELDER_API_KEY"}`

Example — `elder_create_pr`:
  `web_fetch POST http://elder.openclaw.svc.cluster.local:8000/api/code/pr`
  Headers: `{"X-API-Key": "$ELDER_API_KEY"}`
  Body: `{"repo": "swimTO", "branch": "elder/...", "title": "...", "body": "..."}`

Elder handles GitHub App auth internally — you do NOT need a PAT, gh CLI,
or any GitHub token. Never use exec or gh for Git/GitHub operations.

**Auto-approved** operations run immediately. **Approval-required** operations
return an approval ID — ask the user to confirm before executing.

## Tools

### elder_list_repos
List all project repos Elder has cloned. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/code/repos

### elder_search_code
Search code across all repos using ripgrep. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/code/search
Body: {"query": "search term", "repo": "optional-repo-name", "file_pattern": "*.py", "max_results": 50}

Example: "Search for authentication in SwimTO"

### elder_read_file
Read contents of a file from a repo. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/code/read?repo=swimTO&path=backend/main.py

### elder_tree
Get directory structure of a repo. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/code/tree?repo=swimTO&path=backend

### elder_edit_file
Edit a file: creates a branch, commits, and pushes. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/code/edit
Body: {"repo": "swimTO", "path": "backend/main.py", "content": "new content", "commit_message": "fix: description"}

Returns an approval_id. Ask the user to approve before executing.

### elder_create_pr
Create a pull request as Elder [bot]. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/code/pr
Body: {"repo": "swimTO", "branch": "elder/fix-123", "title": "fix: description", "body": "PR body"}

### elder_merge_pr
Merge an existing pull request. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/code/pr/merge
Body: {"repo": "pitanga-website", "pr_number": 6, "merge_method": "squash"}
merge_method options: "squash" (default), "merge", "rebase"

### elder_list_issues
List GitHub issues across one or all repos. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/github/issues/list
Body: {"repo": "swimTO", "state": "open", "max_results": 20}

### elder_create_issue
Create a GitHub issue as Elder [bot]. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/github/issues
Body: {"repo": "swimTO", "title": "feat: new feature", "body": "Description", "labels": ["enhancement"]}

### elder_trigger_workflow
Trigger a GitHub Actions workflow. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/github/trigger-workflow
Body: {"repo": "swimTO", "workflow": "build-and-push.yml", "ref": "main"}

### elder_list_pods
List Kubernetes pods. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/k8s/pods?namespace=swimto

### elder_pod_logs
Get pod logs. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/k8s/logs
Body: {"namespace": "swimto", "pod": "swimto-api-xxx", "tail_lines": 100}

### elder_events
List cluster events. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/k8s/events?namespace=swimto

### elder_cluster_health
Get cluster health summary with FluxCD status. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/k8s/health

### elder_scale
Scale a deployment. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/k8s/scale
Body: {"namespace": "swimto", "deployment": "swimto-api", "replicas": 2}

### elder_flux_reconcile
Trigger FluxCD reconciliation. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/k8s/flux/reconcile
Body: {"kustomization": "flux-system"}

### elder_project_status
Get status of all managed projects (versions, health, last commits). (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/projects/status

### elder_roadmap
Aggregate TODO/roadmap items from all projects. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/projects/roadmap

### elder_plan_feature
Generate a feature plan and optionally create GitHub issues. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/projects/plan
Body: {"project": "swimTO", "feature": "Push notifications", "description": "Add web push...", "create_issues": true}

### elder_run_tests
Trigger test workflow. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/tests/run?repo=swimTO&workflow=python-ci.yml

### elder_test_status
Get latest test run status. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/tests/status?repo=swimTO

### elder_pending_approvals
List pending approval requests. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/approvals/pending

### elder_approve
Approve a pending action after user confirms. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/approvals/{id}/approve

### elder_reject
Reject a pending action. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/approvals/{id}/reject

### elder_best_answer
Get the best possible answer by querying Gemini, Groq, and Ollama in parallel, then having
a judge select/synthesize the best response. Use for important questions or double-checking. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/llm/best-answer
Body: {"prompt": "user question", "system_prompt": "optional context", "providers": ["gemini", "groq", "ollama"], "timeout_seconds": 30}

### elder_llm_providers
Check which LLM providers (Gemini, Groq, Ollama) are currently available. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/llm/providers

### elder_upgrade
Trigger OpenClaw or Elder image rebuild via GitHub Actions. Requires approval. (approval required)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/meta/upgrade
Body: {"component": "openclaw" or "elder", "version": "latest"}

### elder_version
Get current versions of Elder and OpenClaw. (auto-approved)

HTTP: GET http://elder.openclaw.svc.cluster.local:8000/api/meta/version

### elder_store_insight
Store something you learned from this interaction. Call this when you learn useful info
from a user question, your answer, or a resolved issue. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/memory/store
Body: {"topic": "short-label", "content": "what was learned", "source": "interaction"}

### elder_recall_insights
Recall stored insights before answering. Use to include relevant learned context. (auto-approved)

HTTP: POST http://elder.openclaw.svc.cluster.local:8000/api/memory/recall
Body: {"query": "optional search term", "topic": "optional exact topic", "limit": 20}

## Learning (Always Learn)

You should ALWAYS learn from interactions:
1. **Before answering**: Call elder_recall_insights with a query related to the user's question
2. **After resolving**: Call elder_store_insight with topic and content summarizing what was learned
3. **After explaining**: If your answer contains reusable knowledge (e.g. "Vault unseal uses X"), store it

Topics: Use short labels like "vault-unseal", "swimto-deploy", "flux-reconcile", "node-troubleshoot"

## Approval Workflow

When a user asks you to do something destructive (deploy, scale, edit code, trigger CI):
1. Call the Elder endpoint — it returns an approval_id and description
2. Show the user what will happen and ask for confirmation
3. If they say yes, call elder_approve with the approval_id
4. If they say no, call elder_reject

## Repo Names (use exactly for API calls)

- canopy, swimTO, pi-fleet, pi-fleet-blog, eldertree-docs, elder, journey, nima, ollie, pitanga-website, northwaysignal-website, fragment

## Projects Managed by Elder

| Project | Description | Cluster URL |
|---------|-------------|-------------|
| canopy | Personal finance | https://canopy.eldertree.local |
| swimTO | Toronto pools | https://swimto.eldertree.xyz |
| journey | AI career pathfinder | https://journey.eldertree.local |
| nima | ML experiments | https://nima.eldertree.local |
| ollie | Local AI assistant | - |
| pi-fleet | Cluster infra | - |
| pi-fleet-blog | Eldertree blog (chapters, journey) | https://blog.eldertree.xyz |
| eldertree-docs | Runbook, troubleshooting | https://docs.eldertree.xyz |
| pitanga-website | Company site | https://pitanga.cloud |
| elder | This agent! | http://elder.openclaw.svc.cluster.local:8000 |

## Example Conversations

User: "What's the status of all my projects?"
Assistant: *calls elder_project_status, formats a summary table*

User: "Search for the auth middleware in swimTO"
Assistant: *calls elder_search_code with query="auth" and repo="swimTO"*

User: "Deploy the latest SwimTO"
Assistant: *calls elder_flux_reconcile → gets approval_id → shows plan → asks user to confirm → calls elder_approve*

User: "Create an issue in swimTO for adding push notifications"
Assistant: *calls elder_create_issue with title and body*

User: "Let's work on the GitHub issues for canopy"
Assistant: *calls elder_list_issues with repo="canopy" → presents list → asks which to tackle first*

User: "What pods are failing?"
Assistant: *calls elder_cluster_health, checks for failed pods and warnings*
