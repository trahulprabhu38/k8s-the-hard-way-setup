#!/bin/bash
# =============================================================================
# Script 12: Configure TLS bootstrapping for node02 (on controlplane01)
# Creates bootstrap token, RBAC bindings for automatic cert approval
# Runs on: controlplane01
# =============================================================================
set -e

cd ~

echo "[12] Configuring TLS bootstrapping..."

EXPIRATION=$(date -u --date "+7 days" +"%Y-%m-%dT%H:%M:%SZ")

# ── Create bootstrap token secret ────────────────────────────────────────────
cat > bootstrap-token-07401b.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-07401b
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  description: "Bootstrap token for worker nodes"
  token-id: 07401b
  token-secret: f395accd246ae52d
  expiration: ${EXPIRATION}
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:worker
EOF

kubectl apply -f bootstrap-token-07401b.yaml --kubeconfig ~/admin.kubeconfig
echo "  Bootstrap token created (expires: ${EXPIRATION})"

# ── Authorize bootstrappers to create CSRs ────────────────────────────────────
kubectl create clusterrolebinding create-csrs-for-bootstrapping \
  --clusterrole=system:node-bootstrapper \
  --group=system:bootstrappers \
  --kubeconfig ~/admin.kubeconfig 2>/dev/null || \
  echo "  ClusterRoleBinding create-csrs-for-bootstrapping already exists."

# ── Auto-approve CSRs for bootstrapping nodes ─────────────────────────────────
kubectl create clusterrolebinding auto-approve-csrs-for-group \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:nodeclient \
  --group=system:bootstrappers \
  --kubeconfig ~/admin.kubeconfig 2>/dev/null || \
  echo "  ClusterRoleBinding auto-approve-csrs-for-group already exists."

# ── Auto-approve CSR renewals for established nodes ───────────────────────────
kubectl create clusterrolebinding auto-approve-renewals-for-nodes \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeclient \
  --group=system:nodes \
  --kubeconfig ~/admin.kubeconfig 2>/dev/null || \
  echo "  ClusterRoleBinding auto-approve-renewals-for-nodes already exists."

echo "[12] TLS bootstrapping configured. Token: 07401b.f395accd246ae52d"
