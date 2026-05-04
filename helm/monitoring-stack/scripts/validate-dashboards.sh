#!/usr/bin/env bash
# Validate Grafana dashboard files and folder mappings
# Usage: ./scripts/validate-dashboards.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DASHBOARDS_DIR="${CHART_DIR}/dashboards"
VALUES_FILE="${CHART_DIR}/values.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Grafana Dashboard Validation ===${NC}\n"

# Check if dashboards directory exists
if [[ ! -d "${DASHBOARDS_DIR}" ]]; then
    echo -e "${RED}ERROR: Dashboards directory not found: ${DASHBOARDS_DIR}${NC}"
    exit 1
fi

# Check if values.yaml exists
if [[ ! -f "${VALUES_FILE}" ]]; then
    echo -e "${RED}ERROR: values.yaml not found: ${VALUES_FILE}${NC}"
    exit 1
fi

# Find all dashboard JSON files
mapfile -t dashboard_files < <(find "${DASHBOARDS_DIR}" -maxdepth 1 -name "*.json" -type f | sort)

if [[ ${#dashboard_files[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No dashboard files found in ${DASHBOARDS_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#dashboard_files[@]} dashboard file(s)${NC}\n"

errors=0
warnings=0

# Validate each dashboard
for filepath in "${dashboard_files[@]}"; do
    filename=$(basename "${filepath}")
    basename="${filename%.json}"

    echo -e "${BLUE}Validating: ${filename}${NC}"

    # 1. Check JSON syntax
    if ! jq empty "${filepath}" 2>/dev/null; then
        echo -e "  ${RED}✗ Invalid JSON syntax${NC}"
        errors=$((errors + 1))
        continue
    else
        echo -e "  ${GREEN}✓ Valid JSON syntax${NC}"
    fi

    # 2. Check for required fields
    uid=$(jq -r '.uid // empty' "${filepath}")
    title=$(jq -r '.title // empty' "${filepath}")
    tags=$(jq -r '.tags // empty' "${filepath}")

    if [[ -z "${uid}" ]]; then
        echo -e "  ${RED}✗ Missing required field: uid${NC}"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✓ Has uid: ${uid}${NC}"
    fi

    if [[ -z "${title}" ]]; then
        echo -e "  ${RED}✗ Missing required field: title${NC}"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✓ Has title: ${title}${NC}"
    fi

    if [[ "${tags}" == "null" ]] || [[ -z "${tags}" ]]; then
        echo -e "  ${YELLOW}⚠ Missing tags (recommended for discoverability)${NC}"
        warnings=$((warnings + 1))
    else
        tag_count=$(jq -r '.tags | length' "${filepath}")
        echo -e "  ${GREEN}✓ Has ${tag_count} tag(s)${NC}"
    fi

    # 3. Check for folder mapping in values.yaml
    if grep -q "^[[:space:]]*${basename}:" "${VALUES_FILE}"; then
        folder=$(grep "^[[:space:]]*${basename}:" "${VALUES_FILE}" | sed 's/.*: *"\(.*\)".*/\1/')
        echo -e "  ${GREEN}✓ Folder mapping found: ${folder}${NC}"
    else
        echo -e "  ${YELLOW}⚠ No folder mapping in values.yaml (will default to 'Platform')${NC}"
        echo -e "    ${YELLOW}Add to values.yaml dashboardFolders: ${basename}: \"Category/Subcategory\"${NC}"
        warnings=$((warnings + 1))
    fi

    # 4. Check UID matches basename convention (recommended but not required)
    if [[ "${uid}" != "${basename}" ]] && [[ "${uid}" != *"${basename}"* ]]; then
        echo -e "  ${YELLOW}⚠ UID '${uid}' doesn't match basename '${basename}' (not enforced, but recommended)${NC}"
        warnings=$((warnings + 1))
    fi

    echo ""
done

# Summary
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo -e "Dashboards validated: ${#dashboard_files[@]}"
echo -e "Errors: ${RED}${errors}${NC}"
echo -e "Warnings: ${YELLOW}${warnings}${NC}"

if [[ ${errors} -gt 0 ]]; then
    echo -e "\n${RED}Validation failed with ${errors} error(s)${NC}"
    exit 1
elif [[ ${warnings} -gt 0 ]]; then
    echo -e "\n${YELLOW}Validation passed with ${warnings} warning(s)${NC}"
    exit 0
else
    echo -e "\n${GREEN}All validations passed!${NC}"
    exit 0
fi
