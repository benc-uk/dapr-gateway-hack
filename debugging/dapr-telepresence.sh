#!/bin/bash
set -e

# ===============================================================================================================
# Horrible script for assisting running & debugging daprd via telepresence with mTLS
#
# IMPORTANT: Run telepresence with `--mount /tmp/teleroot` argument so it can be passed to this script
# ===============================================================================================================

# First arg is path to custom certs on disk
CERT_PATH=$1

# Second arg is path to telepresence root
TELEPRESENCE_ROOT=$2

# Third arg is workspace dir where to put the .env file
WORKSPACE_ROOT=$3

echo -e "### 🎩 Dapr & telepresence prelaunch script doohicky"
echo -e "### 🔐 Mashing certs into .env file like a madman"
echo "DAPR_TRUST_ANCHORS=\"$(cat "$CERT_PATH/root.pem" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')\"" > $WORKSPACE_ROOT/.vscode/.env
echo "DAPR_CERT_CHAIN=\"$(cat "$CERT_PATH/issuer.pem" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')\"" >> $WORKSPACE_ROOT/.vscode/.env
echo "DAPR_CERT_KEY=\"$(cat "$CERT_PATH/issuer.key" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}')\"" >> $WORKSPACE_ROOT/.vscode/.env

echo -e "### 🎫 Fudging the serviceaccount/token from telepresence"
sudo rm -rf /var/run/secrets/kubernetes.io/serviceaccount/token
sudo mkdir -p /var/run/secrets/kubernetes.io/serviceaccount
sudo ln -s $TELEPRESENCE_ROOT/var/run/secrets/kubernetes.io/serviceaccount/token /var/run/secrets/kubernetes.io/serviceaccount/token

