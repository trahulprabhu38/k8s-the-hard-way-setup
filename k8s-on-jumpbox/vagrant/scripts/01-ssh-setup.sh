#!/bin/bash
# =============================================================================
# Script 01: Setup password-less SSH from controlplane01 to all other nodes
# Runs on: controlplane01
# =============================================================================
set -e

echo "[01] Setting up SSH keys on controlplane01..."

# Generate SSH key pair non-interactively (skip if already exists)
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
    echo "SSH key pair generated."
else
    echo "SSH key pair already exists."
fi

# Add own key to authorized_keys (for scp to self)
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Copy SSH key to all other nodes using sshpass (password: vagrant)
for node in controlplane02 loadbalancer node01 node02; do
    echo "Copying SSH key to ${node}..."
    sshpass -p vagrant ssh-copy-id \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        vagrant@${node}
done

# Verify connections
echo "Verifying SSH connections..."
for node in controlplane02 loadbalancer node01 node02; do
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${node} "echo '  OK: Connected to ${node}'"
done

echo "[01] SSH setup complete."
