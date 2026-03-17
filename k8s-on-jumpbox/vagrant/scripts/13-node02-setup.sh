#!/bin/bash
# =============================================================================
# Script 13: Configure kubelet and kube-proxy on node02 (TLS bootstrap method)
# node02 generates its own cert via the Kubernetes Certificates API
# Runs on: node02
# =============================================================================
set -e

export PRIMARY_IP=$(grep PRIMARY_IP /etc/environment | cut -d= -f2)
export ARCH=$(dpkg --print-architecture)

cd ~

echo "[13] Setting up Kubernetes worker node02 via TLS bootstrap (IP: ${PRIMARY_IP})..."

KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
LOADBALANCER=$(dig +short loadbalancer)
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16
CLUSTER_DNS=$(echo $SERVICE_CIDR | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s.10", $1, $2, $3) }')

# ── Create required directories ───────────────────────────────────────────────
sudo mkdir -p \
  /var/lib/kubelet/pki \
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

# ── Move CA and kube-proxy certs into place ───────────────────────────────────
{
  sudo mv ~/ca.crt ~/kube-proxy.crt ~/kube-proxy.key /var/lib/kubernetes/pki/
  sudo chown root:root /var/lib/kubernetes/pki/*
  sudo chmod 600 /var/lib/kubernetes/pki/*
}

# ── Bootstrap kubeconfig (uses token, node generates its own cert) ────────────
cat <<EOF | sudo tee /var/lib/kubelet/bootstrap-kubeconfig
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/pki/ca.crt
    server: https://${LOADBALANCER}:6443
  name: bootstrap
contexts:
- context:
    cluster: bootstrap
    user: kubelet-bootstrap
  name: bootstrap
current-context: bootstrap
kind: Config
preferences: {}
users:
- name: kubelet-bootstrap
  user:
    token: 07401b.f395accd246ae52d
EOF

# ── kubelet configuration ─────────────────────────────────────────────────────
# Note: no tlsCertFile/tlsPrivateKeyFile - kubelet will generate via TLS bootstrap
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
cgroupDriver: systemd
clusterDomain: "cluster.local"
clusterDNS:
  - ${CLUSTER_DNS}
registerNode: true
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: "15m"
serverTLSBootstrap: true
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
  --bootstrap-kubeconfig="/var/lib/kubelet/bootstrap-kubeconfig" \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --cert-dir=/var/lib/kubelet/pki/ \\
  --node-ip=${PRIMARY_IP} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── kube-proxy configuration ──────────────────────────────────────────────────
{
  sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy/
  sudo chown root:root /var/lib/kube-proxy/kube-proxy.kubeconfig
  sudo chmod 600 /var/lib/kube-proxy/kube-proxy.kubeconfig
}

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

echo "[13] node02 worker services started (will TLS bootstrap with the cluster)."
