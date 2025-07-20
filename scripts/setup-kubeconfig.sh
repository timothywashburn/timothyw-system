#!/bin/bash

set -e

CONNECTION_STRING="${1}"
CONTEXT_NAME="${2}"

if [[ -z "$CONNECTION_STRING" ]] || [[ -z "$CONTEXT_NAME" ]]; then
    echo "Usage: $0 USER@VPS_IP CONTEXT_NAME"
    echo "Example: $0 root@192.168.1.100 vps"
    echo "Example: $0 client_3982_1@64.71.152.179 production"
    exit 1
fi

if [[ ! "$CONNECTION_STRING" =~ ^([^@]+)@(.+)$ ]]; then
    echo "Error: Invalid connection string format. Use USER@IP"
    exit 1
fi
VPS_USER="${BASH_REMATCH[1]}"
VPS_IP="${BASH_REMATCH[2]}"

if [[ -f ~/.kube/config ]]; then
    echo "Backing up existing kubeconfig"
    cp ~/.kube/config ~/.kube/config.backup."$(date +%Y-%m-%d_%H-%M-%S)"
fi

echo "Setting up kubectl access to K3s cluster at $VPS_IP as context '$CONTEXT_NAME'"
mkdir -p ~/.kube
ssh "$CONNECTION_STRING" "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-config.yaml

echo "Extracting certificates"
CA_DATA=$(grep 'certificate-authority-data:' /tmp/k3s-config.yaml | awk '{print $2}')
CLIENT_CERT_DATA=$(grep 'client-certificate-data:' /tmp/k3s-config.yaml | awk '{print $2}')
CLIENT_KEY_DATA=$(grep 'client-key-data:' /tmp/k3s-config.yaml | awk '{print $2}')
echo "$CA_DATA" | base64 -d > /tmp/ca.crt
echo "$CLIENT_CERT_DATA" | base64 -d > /tmp/client.crt
echo "$CLIENT_KEY_DATA" | base64 -d > /tmp/client.key

echo "Adding new context to kubeconfig"
kubectl config set-cluster "$CONTEXT_NAME" \
  --server=https://"$VPS_IP":6443 \
  --certificate-authority=/tmp/ca.crt \
  --embed-certs=true
kubectl config set-credentials "$CONTEXT_NAME" \
  --client-certificate=/tmp/client.crt \
  --client-key=/tmp/client.key \
  --embed-certs=true
kubectl config set-context "$CONTEXT_NAME" \
  --cluster="$CONTEXT_NAME" \
  --user="$CONTEXT_NAME"

rm -f /tmp/k3s-config.yaml /tmp/ca.crt /tmp/client.crt /tmp/client.key

kubectl config use-context "$CONTEXT_NAME"

echo "Testing connection"
if kubectl get nodes; then
    echo "✅ Successfully configured kubectl access to K3s cluster!"
    echo "Current context: $(kubectl config current-context)"
else
    echo "❌ Failed to connect to cluster. Check your connection and SSH access."
    exit 1
fi