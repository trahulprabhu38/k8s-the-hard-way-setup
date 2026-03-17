#!/bin/bash
# =============================================================================
# Kubernetes The Hard Way - Full Automated Setup
# Run this script from the vagrant/ directory on your host (Mac) machine.
# Usage: bash k8s-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[1;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "\n${BLUE}========================================${NC}"; \
         echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC}"; \
         echo -e "${BLUE}========================================${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
err()  { echo -e "${RED}[ERROR] $*${NC}" >&2; exit 1; }

# Run a script on a specific node
run_on() {
    local node="$1"; local script="$2"
    echo -e "${YELLOW}  --> Running $script on $node${NC}"
    vagrant ssh "$node" -- "bash /vagrant/scripts/$script"
}

# Run scripts on two nodes in parallel and wait for both
run_parallel() {
    local script="$1"
    local node1="$2"
    local node2="$3"
    echo -e "${YELLOW}  --> Running $script on $node1 and $node2 in parallel${NC}"
    vagrant ssh "$node1" -- "bash /vagrant/scripts/$script" &
    local pid1=$!
    vagrant ssh "$node2" -- "bash /vagrant/scripts/$script" &
    local pid2=$!
    wait $pid1 || err "$script failed on $node1"
    wait $pid2 || err "$script failed on $node2"
}

cd "$SCRIPT_DIR"

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║     Kubernetes The Hard Way - Automated Setup        ║"
echo "  ║     2x controlplane + 2x workers + 1 loadbalancer    ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# --------------------------------------------------------------------------
log "STEP 1/15: Bringing up Vagrant VMs (this may take 10-15 minutes)..."
# --------------------------------------------------------------------------
vagrant up
echo "All VMs are up."

# --------------------------------------------------------------------------
log "STEP 2/15: Setting up password-less SSH from controlplane01 to all nodes..."
# --------------------------------------------------------------------------
run_on controlplane01 01-ssh-setup.sh

# --------------------------------------------------------------------------
log "STEP 3/15: Installing kubectl on controlplane01..."
# --------------------------------------------------------------------------
run_on controlplane01 02-kubectl-install.sh

# --------------------------------------------------------------------------
log "STEP 4/15: Generating all TLS certificates..."
# --------------------------------------------------------------------------
run_on controlplane01 03-gen-certs.sh

# --------------------------------------------------------------------------
log "STEP 5/15: Generating kubeconfig files..."
# --------------------------------------------------------------------------
run_on controlplane01 04-gen-kubeconfigs.sh

# --------------------------------------------------------------------------
log "STEP 6/15: Generating data encryption config..."
# --------------------------------------------------------------------------
run_on controlplane01 05-encryption.sh

# --------------------------------------------------------------------------
log "STEP 7/15: Bootstrapping etcd on both controlplane nodes (parallel)..."
# --------------------------------------------------------------------------
run_parallel 06-etcd.sh controlplane01 controlplane02
echo "Waiting 15s for etcd cluster to stabilize..."
sleep 15

# --------------------------------------------------------------------------
log "STEP 8/15: Bootstrapping Kubernetes control plane (parallel)..."
# --------------------------------------------------------------------------
run_parallel 07-kube-control-plane.sh controlplane01 controlplane02
echo "Waiting 20s for API servers to fully initialize..."
sleep 20

# --------------------------------------------------------------------------
log "STEP 9/15: Setting up HAProxy load balancer..."
# --------------------------------------------------------------------------
run_on loadbalancer 08-haproxy.sh
sleep 5

# --------------------------------------------------------------------------
log "STEP 10/15: Installing Container Runtime (containerd) on worker nodes (parallel)..."
# --------------------------------------------------------------------------
run_parallel 09-worker-cri.sh node01 node02

# --------------------------------------------------------------------------
log "STEP 11/15: Generating node01 certificates and kubeconfig (on controlplane01)..."
# --------------------------------------------------------------------------
run_on controlplane01 10-node01-certs.sh

# --------------------------------------------------------------------------
log "STEP 12/15: Setting up Kubernetes on worker node01 (manual cert)..."
# --------------------------------------------------------------------------
run_on node01 11-node01-setup.sh

# --------------------------------------------------------------------------
log "STEP 13/15: Configuring TLS bootstrapping on controlplane01..."
# --------------------------------------------------------------------------
run_on controlplane01 12-tls-bootstrap-setup.sh

# --------------------------------------------------------------------------
log "STEP 14/15: Setting up worker node02 (TLS bootstrap mode)..."
# --------------------------------------------------------------------------
run_on node02 13-node02-setup.sh

# --------------------------------------------------------------------------
log "STEP 15/15: Finalizing - RBAC, CNI (Weave), CoreDNS, kubectl config..."
# --------------------------------------------------------------------------
# Approve node02's CSR first
run_on controlplane01 14-approve-csr.sh
# Then finalize the cluster
run_on controlplane01 15-finalize.sh

echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║        KUBERNETES CLUSTER IS READY!                  ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "To access the cluster:"
echo "  vagrant ssh controlplane01"
echo "  kubectl get nodes"
echo ""
echo "Node IPs:"
echo "  controlplane01 : 192.168.56.11"
echo "  controlplane02 : 192.168.56.12"
echo "  loadbalancer   : 192.168.56.30"
echo "  node01         : 192.168.56.21"
echo "  node02         : 192.168.56.22"
