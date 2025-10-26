# Bootstrap Instructions

This document provides step-by-step instructions for setting up the infrastructure on a fresh K3s cluster.

## Prerequisites

- kubectl installed locally
- Helmfile installed locally
- SSH access (via ssh key) to vps

## Step 1: Install K3s and Configure System

```bash
# SSH into VPS
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes

# Configure system limits for monitoring workloads
echo 'fs.inotify.max_user_instances = 8192' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf
sysctl -p
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

If there are port-forward networking issues after the sync, restart k3s:

```bash
# SSH into VPS
sudo systemctl restart k3s
```

## Step 4: Access ArgoCD

```bash
# Get the ArgoCD password
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
   - **Revision** : `main` (branch)
   - **Path**: `helm`
   
   **Destination:**
   - **Cluster URL**: `https://kubernetes.default.svc` (internal cluster URL)
   - **Namespace**: `timothyw-system`

3. Click **CREATE**

## Step 6: Sync the Infrastructure Configuration

1. In ArgoCD, open the application
2. Click **SYNC**
3. Let ArgoCD deploy the infrastructure components

## Step 7: Patch timothyw-system to Ignore Image Updater Changes

After the initial sync, run the patch script to prevent drift detection from ArgoCD Image Updater:

```bash
./scripts/patch-timothyw-system.sh
```

This configures the timothyw-system Application to ignore changes to image parameters made by the Image Updater.

## Step 8: DNS Configuration

Point DNS records to cluster's external IP:
- `argo.timothyw.dev` → `EXTERNAL_IP`
- `k8s.timothyw.dev` → `EXTERNAL_IP`
- `grafana.timothyw.dev` → `EXTERNAL_IP`

## Step 9: Get Kubernetes Dashboard Token

To access the Kubernetes Dashboard, get the admin token:

```bash
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

This token never expires and provides full cluster admin access.

## Step 10: Configure ArgoCD Image Updater

The ArgoCD Image Updater is already installed via helmfile. To complete the setup:

1. **Generate API token via ArgoCD Web UI**:
   - Go to https://argocd.timothyw.dev
   - Navigate to **Settings** → **Accounts**
   - Find the `image-updater` account
   - Click **Generate Token**
   - Copy the generated token

2. **Create the token secret**:
   ```bash
   kubectl create secret generic argocd-image-updater-secret \
     --from-literal argocd.token=$YOUR_TOKEN \
     --namespace argocd
   ```

3. **Apply additional RBAC permissions**:
   ```bash
   helmfile apply
   ```

The image updater will now automatically update applications that have the proper annotations.

## Step 11: Access Monitoring Stack

### Grafana (Observability Dashboard)
- URL: https://grafana.timothyw.dev
- Username: `admin`
- Password: `adminadminadmin` ⚠️ **Change this default password for production use**

**Getting Started with Grafana:**
1. Go to **Explore** → **Prometheus** for metrics queries
2. Go to **Explore** → **Loki** for log queries

**Prometheus Queries (Metrics):**
```promql
# Show all targets
up

# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Kubernetes pod status
kube_pod_info
```

**Loki Queries (Logs):**
```logql
# Monitoring namespace logs
{namespace="monitoring"}

# ArgoCD logs
{namespace="argocd"}

# Error logs from monitoring namespace
{namespace="monitoring"} |= "error"

# All logs containing "restart"
{namespace="monitoring"} |= "restart"
```

## Step 12: Verify Setup

After DNS propagation, access the dashboards here:
- ArgoCD: https://argo.timothyw.dev
- Kubernetes Dashboard: https://k8s.timothyw.dev
- Grafana: https://grafana.timothyw.dev

## Monitoring Stack Components

The following monitoring components are automatically deployed:

- **Loki**: Log aggregation and storage
- **Prometheus**: Metrics collection and storage  
- **Grafana**: Visualization dashboard (with Loki + Prometheus datasources)
- **Grafana Alloy**: Data collection agents that gather:
  - Pod logs → Loki
  - Cluster events → Loki
  - Cluster metrics → Prometheus
  - Node metrics → Prometheus