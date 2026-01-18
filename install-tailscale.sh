#!/bin/bash
#
# Tailscale Installation Script for Baby NAS
# Run this in TrueNAS SCALE System Shell (System → Shell)
#

set -e

echo "==================================="
echo "Installing Tailscale on Baby NAS"
echo "==================================="

# Install Tailscale
echo ""
echo "[1/5] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start Tailscaled service
echo ""
echo "[2/5] Enabling Tailscale service..."
systemctl enable --now tailscaled

# Enable IP forwarding for subnet routing
echo ""
echo "[3/5] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Make IP forwarding persistent
echo ""
echo "[4/5] Making IP forwarding persistent..."
cat > /etc/sysctl.d/99-tailscale.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Start Tailscale with subnet routing
echo ""
echo "[5/5] Starting Tailscale with subnet routing..."
echo ""
echo "Running: tailscale up --advertise-routes=10.0.0.0/24 --accept-dns=false"
echo ""
tailscale up --advertise-routes=10.0.0.0/24 --accept-dns=false

echo ""
echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Copy the authentication URL from above"
echo "2. Open it in your browser to authorize this device"
echo "3. In Tailscale admin console, approve the subnet routes"
echo "4. Test connection from your MacBook"
echo ""
