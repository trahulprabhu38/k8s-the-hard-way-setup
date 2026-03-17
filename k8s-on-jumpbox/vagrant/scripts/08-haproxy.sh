#!/bin/bash
# =============================================================================
# Script 08: Configure HAProxy load balancer
# Runs on: loadbalancer
# =============================================================================
set -e

echo "[08] Configuring HAProxy on $(hostname)..."

sudo apt-get update -q
sudo apt-get install -y haproxy

CONTROL01=$(dig +short controlplane01)
CONTROL02=$(dig +short controlplane02)
LOADBALANCER=$(dig +short loadbalancer)

echo "  controlplane01: ${CONTROL01}"
echo "  controlplane02: ${CONTROL02}"
echo "  loadbalancer  : ${LOADBALANCER}"

# Write HAProxy config (layer 4 / TCP passthrough - no SSL offloading)
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 2000
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend kubernetes
    bind ${LOADBALANCER}:6443
    option tcplog
    mode tcp
    default_backend kubernetes-controlplane-nodes

backend kubernetes-controlplane-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server controlplane01 ${CONTROL01}:6443 check fall 3 rise 2
    server controlplane02 ${CONTROL02}:6443 check fall 3 rise 2
EOF

sudo systemctl enable haproxy
sudo systemctl restart haproxy

# Quick verification
sleep 3
curl -sk https://${LOADBALANCER}:6443/version | grep -q "gitVersion" && \
  echo "  Load balancer is forwarding API requests successfully." || \
  echo "  WARNING: Load balancer check failed - API servers may still be starting up."

echo "[08] HAProxy configured on loadbalancer."
