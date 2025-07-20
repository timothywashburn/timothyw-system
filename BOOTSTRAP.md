# Bootstrap Instructions

This document provides step-by-step instructions for setting up the infrastructure on a fresh K3s cluster.

## Prerequisites

- kubectl installed locally
- Helmfile installed locally
- SSH access (via ssh key) to server

## Step 1: Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes
```

## Step 2: Configure Local kubectl Access

Run the setup script to add a new context to your local `kubectl` configuration:

```bash
./scripts/setup-kubeconfig.sh USER@VPS_IP CONTEXT_NAME
```

## Step 3: Install Infrastructure Components

Use Helmfile to install the core infrastructure components:

```bash
helmfile sync
```

## Step 4: Access ArgoCD

```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access locally
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

- Open browser to https://localhost:8080
- Username: `admin`
- Password: (from the command above)

## Step 5: Configure ArgoCD to Manage Infrastructure

1. In the ArgoCD UI, click **"+ NEW APP"**
2. Configure the application:
   - **Application Name**: `timothyw-system`
   - **Project**: `default`
   - **Sync Policy**: `Manual`
   
   **Source:**
   - **Repository URL**: `https://github.com/timothywashburn/timothyw.dev`
   - **Revision**: `HEAD`
   - **Path**: `helm`
   
   **Destination:**
   - **Cluster URL**: `https://kubernetes.default.svc` (internal cluster URL)
   - **Namespace**: `timothyw-system`

3. Click **CREATE**

## Step 6: Sync the Infrastructure Configuration

1. In ArgoCD, open the application
2. Click **SYNC**
3. Let ArgoCD deploy the infrastructure components

## Step 7: DNS Configuration

Point DNS records to cluster's external IP:
- `argo.timothyw.dev` → `EXTERNAL_IP`
- `k8s.timothyw.dev` → `EXTERNAL_IP`

## Step 8: Get Kubernetes Dashboard Token

To access the Kubernetes Dashboard, get the admin token:

```bash
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

This token never expires and provides full cluster admin access.

## Step 9: Verify Setup

After DNS propagation, access the dashboards here:
- ArgoCD: https://argo.timothyw.dev
- Kubernetes Dashboard: https://k8s.timothyw.dev