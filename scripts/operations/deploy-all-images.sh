#!/bin/bash
# Build and deploy all project images to pi-fleet
# This script builds images locally, pushes to GHCR, then pulls them into k3s on the cluster node

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REMOTE_HOST="192.168.2.83"
REMOTE_USER="${REMOTE_USER:-$(whoami)}"
REGISTRY="ghcr.io"
IMAGE_PREFIX="${REGISTRY}/raolivei"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Determine k3s command (might need sudo)
K3S_CMD="sudo k3s"

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🐳 Building and Deploying All Project Images to Pi-Fleet${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Function to get GitHub token from Vault
get_ghcr_token_from_vault() {
    if ! command -v kubectl &> /dev/null; then
        return 1
    fi
    
    # Check if kubeconfig is set
    if [ -z "${KUBECONFIG:-}" ] && [ ! -f ~/.kube/config-eldertree ]; then
        return 1
    fi
    
    # Try to get token from Vault
    export KUBECONFIG="${KUBECONFIG:-~/.kube/config-eldertree}"
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$VAULT_POD" ]; then
        return 1
    fi
    
    VAULT_TOKEN=$(kubectl logs -n vault $VAULT_POD 2>/dev/null | grep "Root Token" | tail -1 | awk '{print $NF}')
    if [ -z "$VAULT_TOKEN" ]; then
        VAULT_TOKEN="root"  # Default for dev mode
    fi
    
    kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='${VAULT_TOKEN}' && vault kv get -field=token secret/canopy/ghcr-token 2>/dev/null" 2>/dev/null
}

# Check if logged into GHCR
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo -e "${YELLOW}Not logged into Docker. Attempting to login to GHCR...${NC}"
    
    # Try to get token from Vault first
    GITHUB_TOKEN=$(get_ghcr_token_from_vault)
    
    # If not in Vault, try gh CLI
    if [ -z "$GITHUB_TOKEN" ] && command -v gh &> /dev/null; then
        GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
    fi
    
    if [ -n "$GITHUB_TOKEN" ]; then
        if [ -n "$(get_ghcr_token_from_vault)" ]; then
            echo -e "${GREEN}Using GitHub token from Vault${NC}"
        else
            echo -e "${GREEN}Using GitHub token from gh CLI${NC}"
        fi
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u raolivei --password-stdin || {
            echo -e "${RED}Login failed. The token may not have 'write:packages' scope.${NC}"
            echo -e "${YELLOW}Please create a GitHub Personal Access Token with 'write:packages' scope:${NC}"
            echo -e "  1. Go to: https://github.com/settings/tokens/new"
            echo -e "  2. Select 'write:packages' scope"
            echo -e "  3. Store in Vault or login manually:"
            echo -e "     echo YOUR_TOKEN | docker login ghcr.io -u raolivei --password-stdin"
            exit 1
        }
    else
        echo -e "${RED}Could not find GitHub token in Vault or gh CLI${NC}"
        echo -e "${YELLOW}Please create a GitHub Personal Access Token with 'write:packages' scope:${NC}"
        echo -e "  1. Go to: https://github.com/settings/tokens/new"
        echo -e "  2. Select 'write:packages' scope"
        echo -e "  3. Login manually:"
        echo -e "     echo YOUR_TOKEN | docker login ghcr.io -u raolivei --password-stdin"
        exit 1
    fi
fi

# Array to store images that need to be pulled on cluster
declare -a IMAGES_TO_PULL=()

# Function to build and push image
build_and_push() {
    local project_dir=$1
    local dockerfile_path=$2
    local image_name=$3
    local tag=$4
    local build_target=$5  # Optional: --target flag
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Building ${IMAGE_PREFIX}/${image_name}:${tag}...${NC}"
    if [ -n "$build_target" ]; then
        echo -e "${YELLOW}Target: ${build_target}${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cd "${WORKSPACE_ROOT}/${project_dir}"
    
    local build_cmd="docker build"
    if [ -n "$build_target" ]; then
        build_cmd="${build_cmd} --target ${build_target}"
    fi
    build_cmd="${build_cmd} -t ${IMAGE_PREFIX}/${image_name}:${tag} -t ${IMAGE_PREFIX}/${image_name}:latest -f ${dockerfile_path} ."
    
    if eval "$build_cmd"; then
        echo -e "${GREEN}✅ Image built successfully${NC}"
    else
        echo -e "${RED}❌ Failed to build image${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Pushing ${IMAGE_PREFIX}/${image_name}:${tag}...${NC}"
    if docker push "${IMAGE_PREFIX}/${image_name}:${tag}"; then
        echo -e "${GREEN}✅ Image pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to push image${NC}"
        echo -e "${YELLOW}This may be due to:${NC}"
        echo -e "  1. Missing 'write:packages' scope in GitHub token"
        echo -e "  2. Not logged into GHCR"
        echo -e "${YELLOW}To fix:${NC}"
        echo -e "  echo YOUR_TOKEN | docker login ghcr.io -u raolivei --password-stdin"
        exit 1
    fi
    
    echo -e "${YELLOW}Pushing ${IMAGE_PREFIX}/${image_name}:latest...${NC}"
    if docker push "${IMAGE_PREFIX}/${image_name}:latest"; then
        echo -e "${GREEN}✅ Latest tag pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to push latest tag${NC}"
        echo -e "${YELLOW}This may be due to:${NC}"
        echo -e "  1. Missing 'write:packages' scope in GitHub token"
        echo -e "  2. Not logged into GHCR"
        echo -e "${YELLOW}To fix:${NC}"
        echo -e "  echo YOUR_TOKEN | docker login ghcr.io -u raolivei --password-stdin"
        exit 1
    fi
    
    IMAGES_TO_PULL+=("${IMAGE_PREFIX}/${image_name}:${tag}")
    IMAGES_TO_PULL+=("${IMAGE_PREFIX}/${image_name}:latest")
    
    echo ""
}

# Build Canopy Backend
build_and_push "canopy/backend" "Dockerfile" "canopy-api" "latest"

# Build Canopy Frontend
build_and_push "canopy/frontend" "Dockerfile" "canopy-frontend" "latest"

# Build NIMA
build_and_push "nima" "Dockerfile" "nima-api" "v0.3.1"

# Build SwimTO API
SWIMTO_VERSION=$(cat swimTO/VERSION | tr -d '[:space:]')
build_and_push "swimTO/apps/api" "Dockerfile" "swimto-api" "v${SWIMTO_VERSION}"

# Build SwimTO Web
build_and_push "swimTO/apps/web" "Dockerfile" "swimto-web" "v${SWIMTO_VERSION}"

# Build US Law Severity Map
build_and_push "us-law-severity-map" "Dockerfile" "us-law-severity-map-web" "v1.0.0"

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Pulling images into k3s on cluster node...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Pull images into k3s on cluster node
for image in "${IMAGES_TO_PULL[@]}"; do
    echo -e "${YELLOW}Pulling ${image} into k3s...${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} "${K3S_CMD} ctr images pull ${image}" || {
        echo -e "${RED}❌ Failed to pull ${image}${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ ${image} pulled successfully${NC}"
    echo ""
done

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Restarting deployments...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Restart deployments
export KUBECONFIG=~/.kube/config-eldertree

echo -e "${YELLOW}Restarting canopy-api...${NC}"
kubectl rollout restart deployment/canopy-api -n canopy || echo -e "${YELLOW}⚠️  canopy-api deployment not found or already restarting${NC}"

echo -e "${YELLOW}Restarting canopy-frontend...${NC}"
kubectl rollout restart deployment/canopy-frontend -n canopy || echo -e "${YELLOW}⚠️  canopy-frontend deployment not found or already restarting${NC}"

echo -e "${YELLOW}Restarting nima-api...${NC}"
kubectl rollout restart deployment/nima-api -n nima || echo -e "${YELLOW}⚠️  nima-api deployment not found or already restarting${NC}"

echo -e "${YELLOW}Restarting swimto-api...${NC}"
kubectl rollout restart deployment/swimto-api -n swimto || echo -e "${YELLOW}⚠️  swimto-api deployment not found or already restarting${NC}"

echo -e "${YELLOW}Restarting swimto-web...${NC}"
kubectl rollout restart deployment/swimto-web -n swimto || echo -e "${YELLOW}⚠️  swimto-web deployment not found or already restarting${NC}"

echo -e "${YELLOW}Restarting us-law-severity-map-web...${NC}"
kubectl rollout restart deployment/us-law-severity-map-web -n us-law-severity-map || echo -e "${YELLOW}⚠️  us-law-severity-map-web deployment not found or already restarting${NC}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All images built, pushed, and deployed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Check deployment status:"
echo -e "     kubectl get pods -A"
echo -e "  2. Watch rollout status:"
echo -e "     kubectl rollout status deployment/canopy-api -n canopy"
echo -e "     kubectl rollout status deployment/canopy-frontend -n canopy"
echo -e "     kubectl rollout status deployment/nima-api -n nima"
echo -e "     kubectl rollout status deployment/swimto-api -n swimto"
echo -e "     kubectl rollout status deployment/swimto-web -n swimto"
echo -e "     kubectl rollout status deployment/us-law-severity-map-web -n us-law-severity-map"
echo -e "  3. Check logs if needed:"
echo -e "     kubectl logs -f deployment/canopy-api -n canopy"

