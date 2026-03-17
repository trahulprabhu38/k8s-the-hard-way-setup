#!/bin/bash
# =============================================================================
# Script 11: Configure kubelet and kube-proxy on node01 (manual cert method)
# Runs on: node01
# =============================================================================
set -e

export PRIMARY_IP=$(grep PRIMARY_IP /etc/environment | cut -d= -f2)
export ARCH=$(dpkg --print-architecture)

cd ~

echo "[11] Setting up Kubernetes worker node01 (IP: ${PRIMARY_IP})..."

KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16
CLUSTER_DNS=$(echo $SERVICE_CIDR | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s.10", $1, $2, $3) }')

# ── Create required directories ───────────────────────────────────────────────
sudo mkdir -p \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes/pki \
  /var/run/kubernetes

# ── Download kubelet and kube-proxy ──────────────────────────────────────────
if [ ! -f "/usr/local/bin/kubelet" ]; then
  echo "  Downloading kubelet and kube-proxy ${KUBE_VERSION}..."
  wget -q --show-progress --https-only --timestamping \
    https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-proxy \
    https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubelet

  chmod +x kube-proxy kubelet
  sudo mv kube-proxy kubelet /usr/local/bin/
  echo "  kubelet and kube-proxy installed."
fi

# ── Move certificates and kubeconfig into place ───────────────────────────────
{
  sudo mv ~/node01.key ~/node01.crt /var/lib/kubernetes/pki/
  sudo mv ~/node01.kubeconfig /var/lib/kubelet/kubelet.kubeconfig
  sudo mv ~/ca.crt /var/lib/kubernetes/pki/
  sudo mv ~/kube-proxy.crt ~/kube-proxy.key /var/lib/kubernetes/pki/
  sudo chown root:root /var/lib/kubernetes/pki/*
  sudo chmod 600 /var/lib/kubernetes/pki/*
  sudo chown root:root /var/lib/kubelet/kubelet.kubeconfig
  sudo chmod 600 /var/lib/kubelet/kubelet.kubeconfig
}

# ── kubelet configuration ─────────────────────────────────────────────────────
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /var/lib/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
clusterDomain: cluster.local
clusterDNS:
  - ${CLUSTER_DNS}
cgroupDriver: systemd
resolvConf: /run/systemd/resolve/resolv.conf
runtimeRequestTimeout: "15m"
tlsCertFile: /var/lib/kubernetes/pki/node01.crt
tlsPrivateKeyFile: /var/lib/kubernetes/pki/node01.key
registerNode: true
EOF

# ── kubelet systemd service ───────────────────────────────────────────────────
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubelet.kubeconfig \\
  --node-ip=${PRIMARY_IP} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── kube-proxy configuration ──────────────────────────────────────────────────
sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy/

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.kubeconfig
mode: iptables
clusterCIDR: ${POD_CIDR}
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── Disable swap (kubelet refuses to start with swap on) ──────────────────────
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# ── Start worker services ─────────────────────────────────────────────────────
sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

echo "[11] node01 worker services started."
