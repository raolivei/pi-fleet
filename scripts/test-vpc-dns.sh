#!/bin/bash
# Script para testar qual DNS resolve hostnames do ambiente non-prod
# Uso: ./test-vpc-dns.sh [hostname-non-prod]

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Hostname para testar (padrão: ArgoCD non-prod)
HOSTNAME=${1:-"argo-hq.shipyard.non-prod.us-west-2.momentive.internal"}

echo -e "${GREEN}🔍 Testando DNS resolvers para ambiente NON-PROD${NC}"
echo "=================================================="
echo ""
echo "Hostname alvo: $HOSTNAME"
echo ""

# DNS candidates baseados nas rotas mostradas
# Rotas: 10.36/17, 10.37/16, 10.40/16, 10.48/17, 10.56/17, 10.59.128/17, 10.88/16, 10.89/16, 10.91/16
# DNS 10.56.0.2 é PROD (já confirmado), então testamos os outros

DNS_CANDIDATES=(
    "10.48.0.2"   # 10.48/17
    "10.40.0.2"   # 10.40/16
    "10.37.0.2"   # 10.37/16
    "10.36.0.2"   # 10.36/17
    "10.88.0.2"   # 10.88/16
    "10.89.0.2"   # 10.89/16
    "10.91.0.2"   # 10.91/16
)

echo -e "${YELLOW}Testando DNS candidates...${NC}"
echo ""

FOUND=0
for dns in "${DNS_CANDIDATES[@]}"; do
    echo -n "Testing $dns... "
    
    # Tentar resolver o hostname
    RESULT=$(nslookup "$HOSTNAME" "$dns" 2>&1)
    
    if echo "$RESULT" | grep -q "Non-authoritative answer\|Name:"; then
        echo -e "${GREEN}✅ RESOLVE!${NC}"
        echo "$RESULT" | grep -A 5 "Name:"
        echo ""
        FOUND=1
        
        echo -e "${GREEN}🎯 DNS correto encontrado: $dns${NC}"
        echo ""
        echo "Para corrigir o Client VPN endpoint:"
        echo "  ./fix-aws-vpn-dns.sh <endpoint-id> $dns"
        echo ""
        break
    else
        echo -e "${RED}❌ Não resolve${NC}"
    fi
done

if [ $FOUND -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Nenhum DNS candidate resolveu o hostname${NC}"
    echo ""
    echo "Possíveis causas:"
    echo "1. Hostname incorreto ou não existe"
    echo "2. DNS resolver não está nas rotas da VPN"
    echo "3. Precisa identificar VPC non-prod via AWS Console"
    echo ""
    echo "Para identificar a VPC non-prod:"
    echo "  aws ec2 describe-vpcs --filters \"Name=tag:Environment,Values=non-prod\" \\"
    echo "    --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==\`Name\`].Value|[0]]' --output table"
fi



