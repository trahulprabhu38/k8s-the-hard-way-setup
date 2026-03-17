#!/bin/bash
# =============================================================================
# Script 07: Bootstrap Kubernetes control plane
# Runs on: controlplane01 AND controlplane02 (run on both, ideally in parallel)
# =============================================================================
set -e

export PRIMARY_IP=$(grep PRIMARY_IP /etc/environment | cut -d= -f2)
export ARCH=$(dpkg --print-architecture)

cd ~

echo "[07] Bootstrapping Kubernetes control plane on $(hostname) (IP: ${PRIMARY_IP})..."

KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
LOADBALANCER=$(dig +short loadbalancer)
CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16

# ── Download Kubernetes binaries ─────────────────────────────────────────────
if [ ! -f "/usr/local/bin/kube-apiserver" ]; then
  echo "  Downloading Kubernetes ${KUBE_VERSION} binaries..."
  wget -q --show-progress --https-only --timestamping \
    "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-apiserver" \
    "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-controller-manager" \
    "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kube-scheduler" \
    "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl"

  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
  echo "  Kubernetes binaries installed."
else
  echo "  Kubernetes binaries already installed."
fi

# ── Configure PKI directory ──────────────────────────────────────────────────
echo "  Setting up PKI directory..."
sudo mkdir -p /var/lib/kubernetes/pki

# Copy CA (keep original in ~ for later use)
sudo cp ~/ca.crt ~/ca.key /var/lib/kubernetes/pki/

# Move control-plane certs to PKI
for cert in kube-apiserver service-account apiserver-kubelet-client etcd-server kube-scheduler kube-controller-manager; do
  [ -f ~/${cert}.crt ] && sudo mv ~/${cert}.crt /var/lib/kubernetes/pki/ || true
  [ -f ~/${cert}.key ] && sudo mv ~/${cert}.key /var/lib/kubernetes/pki/ || true
done

sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*

# ── kube-apiserver service ───────────────────────────────────────────────────
echo "  Creating kube-apiserver service..."
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${PRIMARY_IP} \\
  --allow-privileged=true \\
  --apiserver-count=2 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --enable-admission-plugins=NodeRestriction,ServiceAccount \\
  --enable-bootstrap-token-auth=true \\
  --etcd-cafile=/var/lib/kubernetes/pki/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/pki/etcd-server.crt \\
  --etcd-keyfile=/var/lib/kubernetes/pki/etcd-server.key \\
  --etcd-servers=https://${CONTROL01}:2379,https://${CONTROL02}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/pki/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/pki/apiserver-kubelet-client.crt \\
  --kubelet-client-key=/var/lib/kubernetes/pki/apiserver-kubelet-client.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/var/lib/kubernetes/pki/service-account.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/pki/service-account.key \\
  --service-account-issuer=https://${LOADBALANCER}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/pki/kube-apiserver.crt \\
  --tls-private-key-file=/var/lib/kubernetes/pki/kube-apiserver.key \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── kube-controller-manager service ─────────────────────────────────────────
echo "  Creating kube-controller-manager service..."
sudo mv ~/kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --authentication-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --authorization-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --bind-address=127.0.0.1 \\
  --client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/pki/ca.crt \\
  --cluster-signing-key-file=/var/lib/kubernetes/pki/ca.key \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --node-cidr-mask-size=24 \\
  --requestheader-client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --root-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --service-account-private-key-file=/var/lib/kubernetes/pki/service-account.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── kube-scheduler service ───────────────────────────────────────────────────
echo "  Creating kube-scheduler service..."
sudo mv ~/kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 600 /var/lib/kubernetes/*.kubeconfig

# ── Start control plane services ─────────────────────────────────────────────
echo "  Starting control plane services..."
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

echo "[07] Kubernetes control plane started on $(hostname)."
