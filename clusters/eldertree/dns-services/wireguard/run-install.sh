#!/bin/bash
# One-liner to copy and run on Pi after SSH authentication

cat << 'EOF'
# Copy this entire block and paste into SSH session to Pi:

cd /tmp
cat > install-wireguard.sh << 'SCRIPT_EOF'
EOF

cat install-wireguard.sh

cat << 'EOF'
SCRIPT_EOF

chmod +x install-wireguard.sh
sudo ./install-wireguard.sh

# After installation, get server public key:
echo "Server Public Key:"
sudo cat /etc/wireguard/server_public.key

# Get public IP:
echo "Public IP:"
curl -s ifconfig.me

EOF

