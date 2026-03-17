#!/bin/bash
# =============================================================================
# Script 09: Install Container Runtime Interface (containerd) on worker nodes
# Runs on: node01 AND node02 (run on both, ideally in parallel)
# =============================================================================
set -e

echo "[09] Installing container runtime on $(hostname)..."

# ── Prerequisites ─────────────────────────────────────────────────────────────
sudo apt-get update -q
sudo apt-get install -y apt-transport-https ca-certificates curl

# ── Kernel modules ────────────────────────────────────────────────────────────
{
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
  sudo modprobe overlay
  sudo modprobe br_netfilter
}

# ── Kernel parameters ─────────────────────────────────────────────────────────
{
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
  sudo sysctl --system > /dev/null
}

# ── Add Kubernetes apt repository ────────────────────────────────────────────
KUBE_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt | awk 'BEGIN { FS="." } { printf "%s.%s", $1, $2 }')
echo "  Using Kubernetes repo: ${KUBE_LATEST}"

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBE_LATEST}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBE_LATEST}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# ── Install containerd + CNI + kubectl + ipvs tools ──────────────────────────
sudo apt-get update -q
sudo apt-get install -y containerd kubernetes-cni kubectl ipvsadm ipset

# ── Configure containerd to use systemd cgroups ──────────────────────────────
# (Critical: without this, kubelet will crash loop)
sudo mkdir -p /etc/containerd
containerd config default | \
  sed 's/SystemdCgroup = false/SystemdCgroup = true/' | \
  sudo tee /etc/containerd/config.toml > /dev/null

sudo systemctl enable containerd
sudo systemctl restart containerd

echo "[09] Container runtime installed on $(hostname)."
