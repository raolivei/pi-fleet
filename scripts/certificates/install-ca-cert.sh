#!/bin/bash
# Install Eldertree CA certificate on macOS
# This makes browsers trust certificates issued by the Eldertree Local CA

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CERT_PATH="${SCRIPT_DIR}/../eldertree-ca.crt"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is for macOS only"
    exit 1
fi

# Extract CA certificate from Kubernetes if not already present
if [ ! -f "$CA_CERT_PATH" ]; then
    echo "Extracting CA certificate from Kubernetes..."
    kubectl get secret -n vault vault-tls -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d > "$CA_CERT_PATH" || {
        echo "Error: Could not extract CA certificate. Make sure kubectl is configured and vault is running."
        exit 1
    }
fi

# Verify certificate
echo "Verifying CA certificate..."
openssl x509 -in "$CA_CERT_PATH" -noout -subject -issuer -dates

# Install to System keychain
echo ""
echo "Installing CA certificate to System keychain..."
echo "You will be prompted for your password."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_CERT_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ CA certificate installed successfully!"
    echo ""
    echo "The certificate is now trusted. You may need to:"
    echo "1. Restart your browser"
    echo "2. Clear browser cache (Cmd+Shift+Delete)"
    echo "3. Visit https://vault.eldertree.local again"
    echo ""
    echo "To verify, check Keychain Access → System → Certificates → 'Eldertree Local CA'"
else
    echo ""
    echo "❌ Failed to install certificate. Try installing manually:"
    echo "1. Open Keychain Access"
    echo "2. Drag $CA_CERT_PATH to 'System' keychain"
    echo "3. Double-click the certificate"
    echo "4. Expand 'Trust' and set to 'Always Trust'"
    echo "5. Close and enter your password"
    exit 1
fi

