#!/bin/bash
# Store Cloudflare Origin Certificate in Vault
#
# This script stores the Cloudflare Origin Certificate and private key in Vault
# for use with External Secrets Operator.

set -e

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
VAULT_NAMESPACE="vault"

# Certificate and private key (provided by user)
CERTIFICATE="-----BEGIN CERTIFICATE-----
MIIEuTCCA6GgAwIBAgIUfEl68LiaUdsq7p3skYAGQ8Nao28wDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTI2MDExMDAwNTMwMFoXDTQxMDEwNjAwNTMwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4aLvyoDOirhWfpukMoYi6Z/OuQEUniQs9DWQ
at3+8nhBxaue3YJ06Pp7PjoEe0U+Thew17LgF7ti5FFAhTjVqxhphISrndvwXQG1
uCjWbz2j6fl+G2cPc5U19qtuE0s0GH6qP5GfiG2ofE0RZIdu4tMgyF6+JfIWbyG6
QfwlqqA85VczCDK1CKPCeRJU0rGGdds+9SnmPmgcR76+kxoJffixp1FbCRuVhkzV
ubenabt9Ds4ZS03A80iDUjuXdT5OJyACgt3vJb/nd3FsqePrPPQtU7iBQw669Dni
H5hBDPyq4C37NexYOYchrQJBLxslRl45c5Nc8HyADCv0+TRaAwIDAQABo4IBOzCC
ATcwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBSaI0MEKvuvjO6Vp/v68Uk/+GGdzzAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTA8BgNVHREENTAzgg8qLnBpdGFuZ2EuY2xvdWSCDXBpdGFuZ2EuY2xvdWSCEXd3
dy5waXRhbmdhLmNsb3VkMDgGA1UdHwQxMC8wLaAroCmGJ2h0dHA6Ly9jcmwuY2xv
dWRmbGFyZS5jb20vb3JpZ2luX2NhLmNybDANBgkqhkiG9w0BAQsFAAOCAQEAC6vL
dtZFkhvi/S2Y2GHh8NgmEhUhdXc9LGejU8+iVbT0GwDJmEQ4b6Rd55BLPhZDzpfF
dU8Yngloqy5KxCrEN0AyBqvThKYhGSs22QvuX+vB4EFWnLxG4ppaiB9fUihT3Y5N
MnSKH8a1ry4AXtABt/Y4FVaZdbXgiovr2q8g+RdptVN/BSUbatxTxzcNrbLL4NP5
YzhZazSV6Ykj6UiDT0aGlEhLqY8QPqQmCHn7EVv5Gx8gorjTlMAy6tIz3PgS94Vr
IgTjbe0KankvlbKDj3pQvWAGYqjhMqsd8bTW0I0/0VG/5/f55hV6M63CTTuxcbfz
YYynqSF1G3kyLzllcQ==
-----END CERTIFICATE-----"

PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDhou/KgM6KuFZ+
m6QyhiLpn865ARSeJCz0NZBq3f7yeEHFq57dgnTo+ns+OgR7RT5OF7DXsuAXu2Lk
UUCFONWrGGmEhKud2/BdAbW4KNZvPaPp+X4bZw9zlTX2q24TSzQYfqo/kZ+Ibah8
TRFkh27i0yDIXr4l8hZvIbpB/CWqoDzlVzMIMrUIo8J5ElTSsYZ12z71KeY+aBxH
vr6TGgl9+LGnUVsJG5WGTNW5t6dpu30OzhlLTcDzSINSO5d1Pk4nIAKC3e8lv+d3
cWyp4+s89C1TuIFDDrr0OeIfmEEM/KrgLfs17Fg5hyGtAkEvGyVGXjlzk1zwfIAM
K/T5NFoDAgMBAAECggEAC59FaheO/yuckbvsze9r1L9qOf9/80XAwDl448N+8mu9
IFq4ZAeB6k6dbE8Eh3on44Tdeb0y3sLeE3P99n6/C435c9Dga1EQK4vYs0PJojds
fhl5F4QMLAA913CGfhCFflRNhHKFsAgAW2eEcFQR8AJymCLAX5r9iqIUAnpKHf43
LXb2UK9aLxk4QypZCg6DZ0nA3aWg7mA+O3Q60X9bkE1+dFvEQHDPN/MQ5h8+yyOK
k3BDXXzqSN69crC9iET9PJIRTCY3EDvosQhabtiT9OaGwc1yhCXmnkgDdz4iCpXC
b5dsQmB9TDDJcLYJ/pUhVD18WOGt1AVm4Soyf4GzSQKBgQD6AaPQoLP3vUq8FFcT
Q1M5kk4CMcD4RiF+ZAKVQPcs7hGJritUWJi/mb7BDJLqWxe1ruRacMthBiR8U875
l0l7Gcdr+xMc3fXHEWBUhmBl3LeR4636gYewhU8SV32odIZXwXQidF95M9A85CD/
sahQpNPMcR7VIb374CHx5xsT6QKBgQDnC7tJvSG2r2XnqIFkjOwlslhMti1JPu8v
RnYbKQEl1JVW/NcUd+cAyiwNI55yXBx+Xmalt7O1S9H8hrHxv6ScsiM7bV65QDNR
ILn2EMvr6mOBuh4VRm/E6mgHV688cCmu4LuptRRBeWs092RK6jIYkyk8NiaT6ypR
OlQRm7InCwKBgG7k91L9VZbYYiQXKaCjxnDNEskqZJw8D3NOzU6DKKDHYQQfO50I
R4kFm3VqLGjDyzqNv0DWs3/wB5MWYcKYdsGh57FgB1RQqEqKzJ3xlSTZyJtv0KZD
enq0RyStplFojoayit8Vm5vZfc7kqjaBCVXsJv6SVsjXVLw66ROyHXKxAoGBAI9t
rPp9uqwZ/nztEkZFZWORb1dP0JUjyH/kkfUSY3AEpCC4HRzLwk+vMeGGNxpvLBEW
sUo23Ayz4MuPInActCfCPjTqFF+UB0dZtZeXnb/6ZYNm8r3qWAA6NBI60MIILxgs
0tLrYoOyyGa9HTmUYTz4PiTuyMwStNZwCzhTGyk5AoGBANTMMW95BXS8rnZyt4hD
76AO5wEoVcAyI5gkjK+9bj0zhnF6J0sDAdBjDnvlRbyQa1rk6y/lhWEqiWyE+frX
hHEnZPIHQCAfABBM7ONc+9s1VqzSwtcfEHEiycFoV7LZ2bHQUvZyGqSFEKUgSShp
YKeosIXgNpxYQLAK1ULzMO6t
-----END PRIVATE KEY-----"

echo "🔐 Storing Cloudflare Origin Certificate in Vault..."
echo ""

# Get Vault pod
VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

if [ -z "$VAULT_POD" ]; then
    echo "❌ Error: Vault pod not found in namespace '$VAULT_NAMESPACE'"
    exit 1
fi

echo "✓ Found Vault pod: $VAULT_POD"
echo ""

# Store certificate in Vault
echo "Storing certificate and private key in Vault..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
vault kv put secret/pitanga/cloudflare-origin-cert \
  certificate='$CERTIFICATE' \
  private-key='$PRIVATE_KEY'
"

echo ""
echo "✅ Certificate stored successfully in Vault!"
echo ""
echo "Vault path: secret/pitanga/cloudflare-origin-cert"
echo ""
echo "Next steps:"
echo "1. Apply the ExternalSecret: kubectl apply -f cloudflare-origin-cert-external.yaml"
echo "2. Verify sync: kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga"
echo "3. Check secret: kubectl get secret pitanga-cloudflare-origin-tls -n pitanga"
echo ""



