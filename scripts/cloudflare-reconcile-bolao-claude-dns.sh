#!/usr/bin/env bash
# Remove stale Cloudflare DNS records for bolao-claude.eldertree.xyz so Terraform can
# create the tunnel CNAME (cloudflare_record.bolao_claude_eldertree_xyz_tunnel).
#
# Usage:
#   source scripts/lib/load-terraform-secrets-from-vault.sh
#   export TF_VAR_cloudflare_api_token TF_VAR_cloudflare_zone_id
#   ./scripts/cloudflare-reconcile-bolao-claude-dns.sh

set -euo pipefail

TOKEN="${TF_VAR_cloudflare_api_token:-${CLOUDFLARE_API_TOKEN:-}}"
ZONE_ID="${TF_VAR_cloudflare_zone_id:-${CLOUDFLARE_ZONE_ID:-}}"
NAME="bolao-claude"

if [[ -z "$TOKEN" || -z "$ZONE_ID" ]]; then
  echo "Need TF_VAR_cloudflare_api_token and TF_VAR_cloudflare_zone_id" >&2
  exit 1
fi

api() {
  curl -sfS -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" "$@"
}

echo "Listing Cloudflare records for ${NAME}.eldertree.xyz (zone ${ZONE_ID})..."
RECORDS="$(api "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}.eldertree.xyz")"
echo "$RECORDS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data.get('success'):
    print('API error:', data, file=sys.stderr)
    sys.exit(1)
for r in data.get('result', []):
    print(f\"{r['id']}\t{r['type']}\t{r.get('content','')}\")
"

while IFS=$'\t' read -r id rtype content; do
  [[ -z "$id" ]] && continue
  if [[ "$rtype" == "CNAME" && "$content" == *".cfargotunnel.com" ]]; then
    echo "OK: tunnel CNAME already present ($id)"
    continue
  fi
  echo "Deleting ${rtype} record $id (${content})..."
  api -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${id}" >/dev/null
  echo "Deleted."
done < <(echo "$RECORDS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('result', []):
    print(r['id'], r['type'], r.get('content',''), sep='\t')
")

echo "Done. Re-run: cd terraform && terraform apply"
