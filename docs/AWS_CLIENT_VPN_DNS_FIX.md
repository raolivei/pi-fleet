# AWS Client VPN DNS Configuration Fix

## Problema

A VPN **US-non-prod** conecta corretamente e as rotas aparecem ok (utun6), mas o DNS está usando `10.56.0.2` que resolve hostnames do ambiente **PROD** em vez do ambiente **NON-PROD**.

**Sintomas:**

- DNS `10.56.0.2` funciona e resolve hostnames (ex: `argo-hq.shipyard.prod.us-west-2.momentive.internal`)
- Mas não resolve hostnames do ambiente **non-prod** (ex: `argo-hq.shipyard.non-prod.us-west-2.momentive.internal`)
- Causa falhas em:
  - EKS cluster access (non-prod)
  - ArgoCD (non-prod)
  - Atlantis (non-prod)
  - Outros serviços internos da VPC non-prod

## ⚠️ Sem Acesso à Conta AWS?

Se você **não tem acesso** à conta AWS onde o Client VPN endpoint está configurado, veja a seção [**Reportar Problema para Admin AWS**](#reportar-problema-para-admin-aws) abaixo para instruções de como reportar o problema com todas as informações necessárias.

Para workarounds locais temporários, veja [**Workaround Local (macOS)**](#workaround-local-macos).

## Diagnóstico

### Verificar DNS Atual no macOS

```bash
# Verificar qual DNS está sendo usado pela VPN
scutil --dns | grep -A 5 "utun6"

# Verificar rotas da VPN
netstat -rn | grep utun6

# Testar resolução DNS (vai resolver PROD, não NON-PROD)
nslookup argo-hq.shipyard.prod.us-west-2.momentive.internal 10.56.0.2
# ✅ Funciona - mas é o ambiente errado!

# Testar resolução NON-PROD (deve falhar com DNS atual)
nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal 10.56.0.2
# ❌ Não resolve - precisa do DNS correto do non-prod
```

### Identificar DNS Correto da VPC US-non-prod

Baseado nas rotas mostradas, a VPN tem acesso a múltiplas VPCs:

- `10.36/17`, `10.37/16`, `10.40/16`, `10.48/17`, `10.56/17`, `10.59.128/17`, `10.88/16`, `10.89/16`, `10.91/16`

O DNS `10.56.0.2` provavelmente corresponde à VPC `10.56/17` (ambiente PROD).

**Para encontrar o DNS correto do NON-PROD:**

1. **Identificar qual CIDR corresponde ao non-prod:**

   ```bash
   # Listar VPCs e identificar qual é non-prod
   aws ec2 describe-vpcs \
     --filters "Name=tag:Environment,Values=non-prod" \
     --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
     --output table
   ```

2. **DNS resolver geralmente é o segundo IP do CIDR:**

   - Se a VPC non-prod é `10.48.0.0/17` → DNS pode ser `10.48.0.2`
   - Se a VPC non-prod é `10.40.0.0/16` → DNS pode ser `10.40.0.2`
   - Se a VPC non-prod é `10.37.0.0/16` → DNS pode ser `10.37.0.2`

3. **Verificar Route53 Resolver Endpoints:**

   ```bash
   # Listar DNS resolvers da VPC non-prod
   aws route53resolver list-resolver-endpoints \
     --filters "Name=VpcId,Values=<vpc-id-non-prod>"
   ```

4. **Via AWS Console:**

   - VPC Dashboard → VPCs
   - Filtrar por tags: `Environment: non-prod` ou `Name: *non-prod*`
   - Selecionar VPC US-non-prod
   - Verificar CIDR block (ex: `10.48.0.0/17`)
   - DNS resolver geralmente é: `<primeiro-octeto>.<segundo-octeto>.0.2`

5. **Testar DNS candidates:**
   ```bash
   # Testar cada DNS candidate para ver qual resolve non-prod
   for dns in 10.48.0.2 10.40.0.2 10.37.0.2; do
     echo "Testing $dns:"
     nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal $dns
     echo "---"
   done
   ```

## Solução: Corrigir DNS no Client VPN Endpoint

### Opção 1: Via AWS Console (Recomendado)

1. **Acessar AWS Console:**

   - VPC Dashboard → Client VPN Endpoints
   - Selecionar o endpoint da VPN US-non-prod

2. **Modificar DNS Servers:**

   - Clique em **Actions** → **Modify Client VPN Endpoint**
   - Na seção **DNS Servers**, edite os servidores DNS:
     - **Remover:** `10.56.0.2` (DNS do outro ambiente)
     - **Adicionar:** `<DNS-correto-da-VPC>` (ex: `10.10.0.2`)

3. **Salvar alterações:**

   - Clique em **Modify Client VPN Endpoint**
   - Aguarde a modificação completar (pode levar alguns minutos)

4. **Reconectar VPN:**
   - Desconecte e reconecte a VPN no macOS
   - Verifique o DNS novamente:
     ```bash
     scutil --dns | grep -A 5 "utun6"
     ```

### Opção 2: Via AWS CLI

```bash
# 1. Identificar o Client VPN Endpoint ID
aws ec2 describe-client-vpn-endpoints \
  --filters "Name=tag:Name,Values=*us-non-prod*" \
  --query 'ClientVpnEndpoints[*].[ClientVpnEndpointId,DnsName]' \
  --output table

# 2. Modificar DNS servers
aws ec2 modify-client-vpn-endpoint \
  --client-vpn-endpoint-id <endpoint-id> \
  --dns-servers <dns-correto-1> <dns-correto-2>

# Exemplo:
# aws ec2 modify-client-vpn-endpoint \
#   --client-vpn-endpoint-id cvpn-endpoint-xxxxx \
#   --dns-servers 10.10.0.2 10.10.0.3
```

### Opção 3: Via Terraform (Se gerenciado via IaC)

Se o Client VPN endpoint é gerenciado via Terraform, atualize o recurso:

```hcl
resource "aws_ec2_client_vpn_endpoint" "us_non_prod" {
  # ... outras configurações ...

  dns_servers = [
    "10.10.0.2",  # DNS correto da VPC US-non-prod
    "10.10.0.3"   # DNS secundário (opcional)
  ]

  # ... outras configurações ...
}
```

Depois aplicar:

```bash
terraform plan
terraform apply
```

## Verificação Pós-Correção

### 1. Identificar DNS Correto (Antes de Corrigir)

Use o script de teste para encontrar qual DNS resolve o ambiente non-prod:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/diagnostics/test-vpc-dns.sh

# Ou testar hostname específico:
./scripts/diagnostics/test-vpc-dns.sh argo-hq.shipyard.non-prod.us-west-2.momentive.internal
```

O script vai testar todos os DNS candidates baseados nas rotas da VPN e identificar qual resolve o ambiente non-prod.

### 2. Verificar DNS no macOS (Após Correção)

```bash
# Verificar DNS da VPN
scutil --dns | grep -A 10 "utun6"

# Deve mostrar o DNS correto da VPC non-prod (não mais 10.56.0.2)
```

### 3. Testar Resolução DNS

```bash
# Testar resolução de hostnames NON-PROD (deve funcionar agora)
nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal
# ✅ Deve resolver com o DNS correto

# Testar resolução de hostnames PROD (ainda deve funcionar se necessário)
nslookup argo-hq.shipyard.prod.us-west-2.momentive.internal
# ✅ Deve resolver (mas pode precisar do DNS 10.56.0.2 se necessário)

# Testar outros serviços non-prod
nslookup <eks-endpoint-non-prod>
nslookup <atlantis-hostname-non-prod>
```

### 4. Testar Acesso aos Serviços

```bash
# Testar acesso ao EKS non-prod
kubectl get nodes --context=<eks-non-prod-context>

# Testar acesso ao ArgoCD non-prod
curl -k https://argo-hq.shipyard.non-prod.us-west-2.momentive.internal

# Testar acesso ao Atlantis non-prod
curl https://<atlantis-hostname-non-prod>
```

## Troubleshooting Adicional

### DNS ainda não funciona após correção

1. **Limpar cache DNS no macOS:**

   ```bash
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   ```

2. **Verificar se há múltiplas VPNs conectadas:**

   ```bash
   # Listar todas as interfaces VPN
   ifconfig | grep -E "^utun|^tun"

   # Verificar rotas conflitantes
   netstat -rn | grep -E "10\.|172\.|192\."
   ```

3. **Verificar configuração de split-tunnel:**
   - Se usando split-tunnel, certifique-se que o DNS server está na lista de rotas permitidas

### DNS funciona mas serviços ainda não acessíveis

1. **Verificar Security Groups:**

   - Certifique-se que o Security Group do Client VPN permite tráfego para os serviços

2. **Verificar Route Tables:**

   - Verifique que as rotas estão corretas na VPC
   - O Client VPN deve ter rotas para as subnets onde os serviços estão

3. **Verificar Network ACLs:**
   - Verifique que os Network ACLs permitem tráfego entre a VPN e os serviços

## Prevenção Futura

### Naming Convention

Use tags consistentes nos recursos AWS:

- `Environment: us-non-prod`
- `Name: vpn-us-non-prod`
- `ManagedBy: terraform` (se aplicável)

### Documentação

Mantenha documentação atualizada com:

- DNS servers de cada ambiente
- VPC CIDR blocks
- Client VPN endpoint IDs

### Validação Automatizada

Considere criar um script de validação:

```bash
#!/bin/bash
# validate-vpn-dns.sh

VPN_ENDPOINT=$1
EXPECTED_DNS=$2

ACTUAL_DNS=$(aws ec2 describe-client-vpn-endpoints \
  --client-vpn-endpoint-ids $VPN_ENDPOINT \
  --query 'ClientVpnEndpoints[0].DnsServers' \
  --output text)

if [ "$ACTUAL_DNS" == "$EXPECTED_DNS" ]; then
  echo "✅ DNS correto: $ACTUAL_DNS"
  exit 0
else
  echo "❌ DNS incorreto. Esperado: $EXPECTED_DNS, Atual: $ACTUAL_DNS"
  exit 1
fi
```

## Reportar Problema para Admin AWS

Se você não tem acesso à conta AWS, use este template para reportar o problema ao administrador:

### Template de Report

```
Assunto: Client VPN US-non-prod - DNS incorreto configurado

Problema:
O Client VPN endpoint "US-non-prod" está configurado com DNS 10.56.0.2,
que resolve hostnames do ambiente PROD em vez de NON-PROD.

Informações Técnicas:
- Client VPN Endpoint: [preencher após identificar]
- DNS Atual (incorreto): 10.56.0.2
- DNS Esperado (non-prod): [preencher após identificar com script]
- VPC non-prod CIDR: [preencher]
- Hostname de teste: argo-hq.shipyard.non-prod.us-west-2.momentive.internal

Diagnóstico Local:
[Executar script de diagnóstico e colar output]

Ação Necessária:
Modificar Client VPN endpoint para usar DNS correto da VPC non-prod.
```

### Coletar Informações para o Report

Execute os comandos abaixo e inclua os outputs no report:

```bash
# 1. Identificar DNS correto do non-prod
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/diagnostics/test-vpc-dns.sh argo-hq.shipyard.non-prod.us-west-2.momentive.internal

# 2. Verificar rotas da VPN
netstat -rn | grep utun6

# 3. Verificar DNS atual
scutil --dns | grep -A 10 "utun6"

# 4. Testar resolução (deve falhar com DNS atual)
nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal 10.56.0.2
```

## Workaround Local (macOS)

Se você precisa de acesso imediato enquanto aguarda a correção no AWS, pode configurar DNS manualmente no macOS:

### Opção 1: Script Automático (Recomendado)

Use o script que identifica e configura o DNS automaticamente:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/fix-vpn-dns-local.sh
```

O script vai:

1. Identificar a interface VPN conectada
2. Testar DNS candidates para encontrar qual resolve non-prod
3. Configurar o DNS correto automaticamente
4. Verificar se está funcionando

**Ou forneça o DNS manualmente se já souber:**

```bash
./scripts/fix-vpn-dns-local.sh 10.48.0.2
```

**⚠️ Nota:** Esta configuração é temporária e será perdida ao desconectar/reconectar a VPN. Execute o script novamente após reconectar.

### Opção 2: Configurar DNS Manualmente na Interface VPN

1. **Identificar DNS correto:**

   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet
   ./scripts/diagnostics/test-vpc-dns.sh
   ```

   Anote o DNS que resolve o non-prod (ex: `10.48.0.2`)

2. **Configurar DNS manualmente:**

   ```bash
   # Obter nome da interface VPN
   INTERFACE=$(ifconfig | grep -E "^utun[0-9]+" | head -1 | awk '{print $1}' | tr -d ':')
   echo "Interface: $INTERFACE"

   # Configurar DNS (substitua 10.48.0.2 pelo DNS correto)
   sudo networksetup -setdnsservers "$INTERFACE" 10.48.0.2
   ```

3. **Verificar:**
   ```bash
   scutil --dns | grep -A 5 "$INTERFACE"
   nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal
   ```

**⚠️ Nota:** Esta configuração é temporária e será perdida ao desconectar/reconectar a VPN.

### Opção 3: Usar /etc/resolver (Mais Permanente)

Criar arquivo de resolver para domínios específicos:

```bash
# Criar diretório se não existir
sudo mkdir -p /etc/resolver

# Criar arquivo de resolver para domínio non-prod
sudo tee /etc/resolver/shipyard.non-prod.us-west-2.momentive.internal > /dev/null <<EOF
nameserver 10.48.0.2
EOF

# Testar
nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal
```

**⚠️ Nota:** Substitua `10.48.0.2` pelo DNS correto identificado pelo script de teste.

### Opção 4: Script Manual de Configuração

Criar script que configura DNS automaticamente ao conectar VPN:

```bash
#!/bin/bash
# ~/bin/fix-vpn-dns.sh

# Identificar interface VPN
INTERFACE=$(ifconfig | grep -E "^utun[0-9]+" | head -1 | awk '{print $1}' | tr -d ':')

if [ -z "$INTERFACE" ]; then
    echo "VPN não conectada"
    exit 1
fi

# DNS correto do non-prod (atualizar após identificar)
DNS_NON_PROD="10.48.0.2"

echo "Configurando DNS $DNS_NON_PROD na interface $INTERFACE"
sudo networksetup -setdnsservers "$INTERFACE" "$DNS_NON_PROD"

echo "DNS configurado. Testando..."
nslookup argo-hq.shipyard.non-prod.us-west-2.momentive.internal
```

Tornar executável e usar após conectar VPN:

```bash
chmod +x ~/bin/fix-vpn-dns.sh
~/bin/fix-vpn-dns.sh
```

## Referências

- [AWS Client VPN Documentation](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html)
- [AWS Client VPN DNS Configuration](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-working-dns.html)
- [AWS VPC DNS](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html)
- [macOS networksetup man page](https://ss64.com/osx/networksetup.html)
