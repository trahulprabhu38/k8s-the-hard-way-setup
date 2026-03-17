#!/bin/bash
# =============================================================================
# Script 14: Approve pending kubelet-serving CSRs from node02 (TLS bootstrap)
# Runs on: controlplane01
#
# After TLS bootstrap, two CSR types are submitted:
#   1. kube-apiserver-client-kubelet  → auto-approved by our RBAC bindings
#   2. kubelet-serving                → needs manual approval (this script)
# =============================================================================
set -e

echo "[14] Waiting for pending kubelet-serving CSRs..."

MAX_ATTEMPTS=20   # 20 x 15s = 5 minutes max
SLEEP_SECS=15

for i in $(seq 1 $MAX_ATTEMPTS); do
  # Look specifically for kubelet-serving CSRs that are Pending (not Approved/Denied)
  PENDING=$(kubectl get csr --kubeconfig ~/admin.kubeconfig --no-headers 2>/dev/null \
    | grep "kubelet-serving" \
    | grep -v "Approved" | grep -v "Denied" \
    | awk '{print $1}') || true

  if [ -n "$PENDING" ]; then
    echo "  Found pending kubelet-serving CSR(s): $PENDING"
    for csr in $PENDING; do
      kubectl certificate approve --kubeconfig ~/admin.kubeconfig "$csr" && \
        echo "  Approved: $csr" || echo "  Could not approve $csr"
    done
    break
  fi

  echo "  No pending kubelet-serving CSRs yet (attempt $i/$MAX_ATTEMPTS), waiting ${SLEEP_SECS}s..."
  sleep $SLEEP_SECS
done

echo ""
echo "  Current CSR status:"
kubectl get csr --kubeconfig ~/admin.kubeconfig

echo "[14] CSR approval complete."
