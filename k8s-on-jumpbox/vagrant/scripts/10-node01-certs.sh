#!/bin/bash
# =============================================================================
# Script 10: Generate node01 kubelet certificate and kubeconfig (manual method)
# Runs on: controlplane01
# =============================================================================
set -e

cd ~

NODE01=$(dig +short node01)
LOADBALANCER=$(dig +short loadbalancer)

echo "[10] Generating node01 kubelet certificate (IP: ${NODE01})..."

# ── node01 TLS certificate ────────────────────────────────────────────────────
cat > openssl-node01.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = node01
IP.1 = ${NODE01}
EOF

openssl genrsa -out node01.key 2048
openssl req -new -key node01.key \
  -subj "/CN=system:node:node01/O=system:nodes" \
  -out node01.csr -config openssl-node01.cnf
openssl x509 -req -in node01.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out node01.crt -extensions v3_req -extfile openssl-node01.cnf -days 1000

echo "  node01 certificate generated."

# ── node01 kubeconfig ─────────────────────────────────────────────────────────
# References /var/lib/kubernetes/pki/ paths (files placed there in script 11)
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
    --server=https://${LOADBALANCER}:6443 \
    --kubeconfig=node01.kubeconfig

  kubectl config set-credentials system:node:node01 \
    --client-certificate=/var/lib/kubernetes/pki/node01.crt \
    --client-key=/var/lib/kubernetes/pki/node01.key \
    --kubeconfig=node01.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:node01 \
    --kubeconfig=node01.kubeconfig

  kubectl config use-context default --kubeconfig=node01.kubeconfig
}
echo "  node01 kubeconfig generated."

# ── Copy to node01 ────────────────────────────────────────────────────────────
scp -o StrictHostKeyChecking=no \
  ca.crt node01.crt node01.key node01.kubeconfig \
  node01:~/

echo "[10] node01 certificates and kubeconfig distributed."
