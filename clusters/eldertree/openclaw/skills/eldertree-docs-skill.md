# Eldertree Documentation Skill

You have access to Eldertree's official documentation and blog. Use these for troubleshooting, architecture context, and infrastructure decisions.

## Documentation Sources

### 1. Runbook (eldertree-docs)
- **URL**: https://docs.eldertree.xyz (public) or https://docs.eldertree.local (cluster network)
- **Content**: Searchable incident runbook with error messages, symptoms, and resolution steps
- **Use elder_search_code** and **elder_read_file** with repo `eldertree-docs` to find runbook content
- **Key paths**: `runbook/` (overview), `runbook/issues/` (DNS, Cloudflare, Node, Boot, Network, Storage, SSH)
- **Workflow**: See `runbook/workflow.md` for agent instructions on using the runbook

### 2. Blog (pi-fleet-blog)
- **URL**: https://blog.eldertree.xyz (when deployed)
- **Content**: Infrastructure journey, cluster setup, networking, monitoring, lessons learned
- **Use elder_search_code** and **elder_read_file** with repo `pi-fleet-blog` to find blog content
- **Key paths**: `chapters/` (01-vision through 18-reusable-workflows), `chapters/index.md` (all links)

### 3. Infrastructure Code (pi-fleet)
- **Repo**: pi-fleet - cluster manifests, Ansible, Terraform, scripts
- **Use elder_search_code** and **elder_read_file** with repo `pi-fleet` for docs/SERVICES_REFERENCE.md, docs/, scripts/

## When to Use

- **Troubleshooting**: Search eldertree-docs runbook for error messages or symptoms first
- **Architecture questions**: Search pi-fleet-blog chapters for design decisions and context
- **Service URLs, IPs, credentials**: See pi-fleet/docs/SERVICES_REFERENCE.md
- **Runbook workflow**: Follow eldertree-docs/runbook/workflow.md for incident resolution

## Example

User: "Vault is sealed, how do I unseal it?"
Assistant: *elder_search_code with repo="eldertree-docs" query="unseal vault" → elder_read_file runbook/issues/storage/VAULT-001.md*
