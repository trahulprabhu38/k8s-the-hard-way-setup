#!/bin/bash
# =============================================================================
# Script 06: Bootstrap etcd
# Runs on: controlplane01 AND controlplane02 (run on both, ideally in parallel)
# =============================================================================
set -e

# Load node-specific env vars set during vagrant provisioning
export PRIMARY_IP=$(grep PRIMARY_IP /etc/environment | cut -d= -f2)
export ARCH=$(dpkg --print-architecture)

ETCD_VERSION="v3.5.9"
cd ~

echo "[06] Bootstrapping etcd on $(hostname) (IP: ${PRIMARY_IP})..."

# ── Download and install etcd ────────────────────────────────────────────────
if [ ! -f "/usr/local/bin/etcd" ]; then
  echo "  Downloading etcd ${ETCD_VERSION}..."
  wget -q --show-progress --https-only --timestamping \
    "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz"

  tar -xf etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz
  sudo mv etcd-${ETCD_VERSION}-linux-${ARCH}/etcd* /usr/local/bin/
  rm -rf etcd-${ETCD_VERSION}-linux-${ARCH}*
  echo "  etcd installed."
else
  echo "  etcd already installed."
fi

# ── Configure etcd ───────────────────────────────────────────────────────────
echo "  Configuring etcd..."
sudo mkdir -p /etc/etcd /var/lib/etcd /var/lib/kubernetes/pki

sudo cp ~/etcd-server.key ~/etcd-server.crt /etc/etcd/
sudo cp ~/ca.crt /var/lib/kubernetes/pki/
sudo chown root:root /etc/etcd/*
sudo chmod 600 /etc/etcd/*
sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*

# Create symlink so etcd can find ca.crt
sudo ln -sf /var/lib/kubernetes/pki/ca.crt /etc/etcd/ca.crt

CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
ETCD_NAME=$(hostname -s)

# ── Create etcd systemd unit ─────────────────────────────────────────────────
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/etcd-server.crt \\
  --key-file=/etc/etcd/etcd-server.key \\
  --peer-cert-file=/etc/etcd/etcd-server.crt \\
  --peer-key-file=/etc/etcd/etcd-server.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${PRIMARY_IP}:2380 \\
  --listen-peer-urls https://${PRIMARY_IP}:2380 \\
  --listen-client-urls https://${PRIMARY_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${PRIMARY_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controlplane01=https://${CONTROL01}:2380,controlplane02=https://${CONTROL02}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── Start etcd ───────────────────────────────────────────────────────────────
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

echo "[06] etcd started on $(hostname)."
