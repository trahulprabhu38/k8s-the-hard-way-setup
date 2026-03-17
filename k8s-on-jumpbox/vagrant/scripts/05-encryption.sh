#!/bin/bash
# =============================================================================
# Script 05: Generate data encryption config and distribute to controlplane nodes
# Runs on: controlplane01
# =============================================================================
set -e

cd ~

echo "[05] Generating encryption config..."

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "[05] Distributing encryption config to controlplane nodes..."

# Handle controlplane01 locally (we are already on it - avoid scp-then-mv deleting the source)
sudo mkdir -p /var/lib/kubernetes/
sudo cp ~/encryption-config.yaml /var/lib/kubernetes/

# Distribute to controlplane02 via scp
scp -o StrictHostKeyChecking=no ~/encryption-config.yaml controlplane02:~/
ssh -o StrictHostKeyChecking=no controlplane02 \
  "sudo mkdir -p /var/lib/kubernetes/ && sudo mv ~/encryption-config.yaml /var/lib/kubernetes/"

echo "[05] Encryption config generated and deployed."
