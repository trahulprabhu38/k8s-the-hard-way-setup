#!/bin/bash
# =============================================================================
# Script 02: Install kubectl on controlplane01
# Runs on: controlplane01
# =============================================================================
set -e

# Load environment variables (ARCH is set during vagrant provisioning)
export ARCH=$(dpkg --print-architecture)

echo "[02] Installing kubectl (arch: ${ARCH})..."

if command -v kubectl &>/dev/null; then
    echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    exit 0
fi

KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
echo "Downloading kubectl ${KUBE_VERSION}..."

curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "[02] kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
