# ArgoCD Image Updater Setup for Projects

This guide explains how to configure your project's ArgoCD Application to use automatic image updates.

## Prerequisites

- ArgoCD Image Updater must be installed (see BOOTSTRAP.md)
- Your project must use Helm or Kustomize
- Container images must be pushed to a registry (e.g., GitLab Container Registry)
- Registry access credentials must be configured as Kubernetes secrets

## Step 1: Create Registry Credentials Secret

If using GitLab Container Registry, create the docker registry secret in your application's namespace:

```bash
kubectl create secret docker-registry gitlab-registry \
  --docker-server=registry.gitlab.com \
  --docker-username="your-username" \
  --docker-password="your-token" \
  --namespace=your-app-namespace
```

## Step 2: Add Annotations to ArgoCD Application

Edit your ArgoCD Application (via UI or YAML) and add these annotations:

```yaml
metadata:
  annotations:
    # Required: List of images to monitor
    argocd-image-updater.argoproj.io/image-list: |
      server=registry.gitlab.com/your-project/server,
      client=registry.gitlab.com/your-project/client
    
    # Required: How to apply updates
    argocd-image-updater.argoproj.io/write-back-method: argocd
    
    # Required: Update strategy for each image
    argocd-image-updater.argoproj.io/server.update-strategy: newest-build
    argocd-image-updater.argoproj.io/client.update-strategy: newest-build
    
    # Required: Registry credentials for each image
    argocd-image-updater.argoproj.io/server.pull-secret: pullsecret:your-namespace/gitlab-registry
    argocd-image-updater.argoproj.io/client.pull-secret: pullsecret:your-namespace/gitlab-registry
```

## Step 3: Configure Auto-Sync (Recommended)

For automatic deployments, enable auto-sync in your ArgoCD Application:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Step 4: Verify Configuration

Check the ArgoCD Image Updater logs to confirm it's monitoring your application:

```bash
kubectl logs -n argocd deployment/argocd-image-updater --tail=20
```

Look for:
- `considering X annotated application(s) for update` (X > 0)
- `errors=0` in processing results
- No "Invalid credential reference" warnings

## How It Works

1. **Image Detection**: Image Updater checks your registry every 2 minutes for new tags
2. **Update Strategy**: Uses `newest-build` to get the most recently created image
3. **Application Update**: Updates the ArgoCD Application with new image tags
4. **Deployment**: ArgoCD syncs the changes to your cluster (if auto-sync enabled)

## Troubleshooting

- **"Invalid credential reference"**: Check secret name and namespace
- **"Access forbidden"**: Verify registry credentials and permissions
- **"0 annotated applications"**: Ensure annotations are correctly formatted
- **Updates not deploying**: Check if auto-sync is enabled or manually sync in ArgoCD

## Update Strategies

- `newest-build`: Use the most recently created image (recommended for `latest` tag)
- `semver`: Use semantic versioning constraints (e.g., `~1.2.0`)
- `alphabetical`: Use alphabetically last tag name

Example for semver:
```yaml
argocd-image-updater.argoproj.io/server.update-strategy: semver
argocd-image-updater.argoproj.io/server.semver.constraint: ~1.0.0
```