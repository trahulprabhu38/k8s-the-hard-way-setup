#!/bin/bash
# =============================================================================
# Script 15: Finalize cluster - RBAC, Weave CNI, CoreDNS, local kubectl config
# Runs on: controlplane01
# =============================================================================
set -e

cd ~

LOADBALANCER=$(dig +short loadbalancer)

echo "[15] Finalizing Kubernetes cluster setup..."

# ── Configure local kubectl to use the load balancer ─────────────────────────
echo "  Configuring kubectl context..."
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=$HOME/ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER}:6443

  kubectl config set-credentials admin \
    --client-certificate=$HOME/admin.crt \
    --client-key=$HOME/admin.key

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
echo "  kubectl context 'kubernetes-the-hard-way' configured."

# ── RBAC: Allow API server to access kubelet API ──────────────────────────────
echo "  Applying RBAC for kube-apiserver to kubelet..."
cat <<EOF | kubectl apply --kubeconfig ~/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig ~/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kube-apiserver
EOF
echo "  RBAC configured."

# ── Deploy Weave CNI (pod networking) ─────────────────────────────────────────
echo "  Deploying Weave CNI..."
kubectl apply -f "https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml"

echo "  Waiting up to 90s for Weave pods to be ready..."
kubectl rollout status daemonset weave-net -n kube-system --timeout=90s || \
  echo "  WARNING: Weave may still be starting up."

# ── Deploy CoreDNS ────────────────────────────────────────────────────────────
echo "  Deploying CoreDNS..."
kubectl apply -f https://raw.githubusercontent.com/mmumshad/kubernetes-the-hard-way/master/deployments/coredns.yaml

echo "  Waiting up to 90s for CoreDNS to be ready..."
kubectl wait deployment -n kube-system coredns --for condition=Available=True --timeout=90s || \
  echo "  WARNING: CoreDNS may still be starting up."

# ── Final status ──────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  CLUSTER STATUS"
echo "════════════════════════════════════════"
echo ""
echo "Nodes:"
kubectl get nodes --kubeconfig ~/admin.kubeconfig -o wide
echo ""
echo "Control plane components:"
kubectl get componentstatuses --kubeconfig ~/admin.kubeconfig 2>/dev/null || true
echo ""
echo "System pods:"
kubectl get pods -n kube-system --kubeconfig ~/admin.kubeconfig
echo ""
echo "[15] Cluster finalization complete!"
echo ""
echo "  To use kubectl from this node:"
echo "    kubectl get nodes"
echo ""
echo "  Admin kubeconfig is at: ~/admin.kubeconfig"
