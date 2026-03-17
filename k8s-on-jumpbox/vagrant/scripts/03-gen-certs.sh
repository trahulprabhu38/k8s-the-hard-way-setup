#!/bin/bash
# =============================================================================
# Script 03: Generate all TLS certificates and distribute them
# Runs on: controlplane01
# =============================================================================
set -e

cd ~

echo "[03] Gathering IP addresses..."
CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
LOADBALANCER=$(dig +short loadbalancer)

# Certificate SAN uses /24 to compute the first service IP (10.96.0.1)
SERVICE_CIDR=10.96.0.0/24
API_SERVICE=$(echo $SERVICE_CIDR | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s.1", $1, $2, $3) }')

echo "  CONTROL01   = ${CONTROL01}"
echo "  CONTROL02   = ${CONTROL02}"
echo "  LOADBALANCER= ${LOADBALANCER}"
echo "  API_SERVICE = ${API_SERVICE}"

# ── Certificate Authority ────────────────────────────────────────────────────
echo "[03] Generating CA certificate..."
{
  openssl genrsa -out ca.key 2048
  openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA/O=Kubernetes" -out ca.csr
  openssl x509 -req -in ca.csr -signkey ca.key -CAcreateserial -out ca.crt -days 1000
}

# ── Admin client certificate ─────────────────────────────────────────────────
echo "[03] Generating admin certificate..."
{
  openssl genrsa -out admin.key 2048
  openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr
  openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.crt -days 1000
}

# ── Controller Manager certificate ──────────────────────────────────────────
echo "[03] Generating kube-controller-manager certificate..."
{
  openssl genrsa -out kube-controller-manager.key 2048
  openssl req -new -key kube-controller-manager.key \
    -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager" \
    -out kube-controller-manager.csr
  openssl x509 -req -in kube-controller-manager.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-controller-manager.crt -days 1000
}

# ── Kube Proxy certificate ───────────────────────────────────────────────────
echo "[03] Generating kube-proxy certificate..."
{
  openssl genrsa -out kube-proxy.key 2048
  openssl req -new -key kube-proxy.key \
    -subj "/CN=system:kube-proxy/O=system:node-proxier" -out kube-proxy.csr
  openssl x509 -req -in kube-proxy.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-proxy.crt -days 1000
}

# ── Scheduler certificate ────────────────────────────────────────────────────
echo "[03] Generating kube-scheduler certificate..."
{
  openssl genrsa -out kube-scheduler.key 2048
  openssl req -new -key kube-scheduler.key \
    -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" -out kube-scheduler.csr
  openssl x509 -req -in kube-scheduler.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-scheduler.crt -days 1000
}

# ── Kubernetes API Server certificate ───────────────────────────────────────
echo "[03] Generating kube-apiserver certificate..."
cat > openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = ${API_SERVICE}
IP.2 = ${CONTROL01}
IP.3 = ${CONTROL02}
IP.4 = ${LOADBALANCER}
IP.5 = 127.0.0.1
EOF

{
  openssl genrsa -out kube-apiserver.key 2048
  openssl req -new -key kube-apiserver.key \
    -subj "/CN=kube-apiserver/O=Kubernetes" -out kube-apiserver.csr -config openssl.cnf
  openssl x509 -req -in kube-apiserver.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-apiserver.crt \
    -extensions v3_req -extfile openssl.cnf -days 1000
}

# ── API Server Kubelet Client certificate ────────────────────────────────────
echo "[03] Generating apiserver-kubelet-client certificate..."
cat > openssl-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

{
  openssl genrsa -out apiserver-kubelet-client.key 2048
  openssl req -new -key apiserver-kubelet-client.key \
    -subj "/CN=kube-apiserver-kubelet-client/O=system:masters" \
    -out apiserver-kubelet-client.csr -config openssl-kubelet.cnf
  openssl x509 -req -in apiserver-kubelet-client.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver-kubelet-client.crt \
    -extensions v3_req -extfile openssl-kubelet.cnf -days 1000
}

# ── ETCD Server certificate ──────────────────────────────────────────────────
echo "[03] Generating etcd-server certificate..."
cat > openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${CONTROL01}
IP.2 = ${CONTROL02}
IP.3 = 127.0.0.1
EOF

{
  openssl genrsa -out etcd-server.key 2048
  openssl req -new -key etcd-server.key \
    -subj "/CN=etcd-server/O=Kubernetes" -out etcd-server.csr -config openssl-etcd.cnf
  openssl x509 -req -in etcd-server.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd-server.crt \
    -extensions v3_req -extfile openssl-etcd.cnf -days 1000
}

# ── Service Account key pair ─────────────────────────────────────────────────
echo "[03] Generating service-account key pair..."
{
  openssl genrsa -out service-account.key 2048
  openssl req -new -key service-account.key \
    -subj "/CN=service-accounts/O=Kubernetes" -out service-account.csr
  openssl x509 -req -in service-account.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial -out service-account.crt -days 1000
}

# ── Distribute to controlplane nodes ────────────────────────────────────────
echo "[03] Distributing certificates to controlplane nodes..."
for instance in controlplane01 controlplane02; do
  scp -o StrictHostKeyChecking=no \
    ca.crt ca.key \
    kube-apiserver.key kube-apiserver.crt \
    apiserver-kubelet-client.crt apiserver-kubelet-client.key \
    service-account.key service-account.crt \
    etcd-server.key etcd-server.crt \
    kube-controller-manager.key kube-controller-manager.crt \
    kube-scheduler.key kube-scheduler.crt \
    ${instance}:~/
done

# ── Distribute to worker nodes ───────────────────────────────────────────────
echo "[03] Distributing certificates to worker nodes..."
for instance in node01 node02; do
  scp -o StrictHostKeyChecking=no \
    ca.crt kube-proxy.crt kube-proxy.key \
    ${instance}:~/
done

echo "[03] All certificates generated and distributed."
