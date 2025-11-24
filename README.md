# LibreChat Helm Deployment for OpenShift

This directory contains the configuration files for deploying LibreChat on OpenShift using the official Helm chart.

## Files

- `librechat-values.yaml` - Helm values file with OpenShift-specific configurations
- `secrets-librechat.yaml.example` - Sample secrets file template (copy and customize)
- `secrets-librechat.yaml` - Your actual secrets file (git ignored, not in repo)
- `user-init-job.yaml` - Kubernetes Job for automatic user creation
- `install.sh` - Automated deployment script
- `README.md` - This file

## Prerequisites

1. OpenShift CLI (`oc`) installed and logged in
2. Helm 3.x installed
3. A namespace created (e.g., `librechat`)

## Configuration Overview

The `librechat-values.yaml` includes:

- **OpenShift Security Compatibility**: Removes hardcoded UIDs/GIDs that conflict with OpenShift SCC
- **MongoDB Configuration**: Uses `latest` tag with forced OpenShift adaptation
- **Meilisearch Configuration**: Security context overrides for OpenShift
- **Log Volumes**: EmptyDir volumes mounted at `/app/logs` and `/app/api/logs` for writable log directories
- **Ingress/Route**: Configured for OpenShift route with correct hostname

## Quick Start (Automated)

### 1. Create your secrets file

Copy the sample secrets file and customize it:

```bash
cp secrets-librechat.yaml.example secrets-librechat.yaml
```

Edit `secrets-librechat.yaml` and replace all placeholder values:
- Generate random secrets: `openssl rand -hex 32` or use the [LibreChat Credentials Generator](https://www.librechat.ai/toolkit/creds_generator)
- Add your OpenAI API key (or other AI provider keys)
- Set default user credentials

### 2. Deploy LibreChat

For a fully automated deployment with user creation:

```bash
# Deploy everything including automatic user creation
CREATE_USER=true ./install.sh
```

Or without automatic user creation:

```bash
./install.sh
```

## Manual Deployment Steps

### 1. Create the Namespace

```bash
oc create namespace librechat
```

### 2. Configure Secrets

Create your secrets file from the template:

```bash
cp secrets-librechat.yaml.example secrets-librechat.yaml
```

Edit `secrets-librechat.yaml` and update all values:

**Required secrets**:
- `CREDS_KEY`: Random 32-byte hex string for credential encryption
- `JWT_SECRET`: Random 32-byte hex string for JWT signing
- `JWT_REFRESH_SECRET`: Random 32-byte hex string for refresh tokens
- `MEILI_MASTER_KEY`: Random 16-byte hex string

Generate these with `openssl rand -hex 32` (or `openssl rand -hex 16` for MEILI_MASTER_KEY), or use the [LibreChat Credentials Generator](https://www.librechat.ai/toolkit/creds_generator)

**Optional API keys** (add as needed):
- `OPENAI_API_KEY`: Your OpenAI API key from https://platform.openai.com/api-keys
- `ANTHROPIC_API_KEY`: Claude API key (if using Anthropic models)
- `GOOGLE_API_KEY`: Google AI API key (if using Google models)
- `AZURE_OPENAI_API_KEY`: Azure OpenAI key (if using Azure)

**Default user credentials** (for automatic user creation):
- `DEFAULT_USER_EMAIL`: Email for auto-created admin user
- `DEFAULT_USER_PASSWORD`: Password for admin user (use a strong password)
- `DEFAULT_USER_NAME`: Display name for admin user

**Namespace**:
- Update `metadata.namespace` to match your OpenShift namespace (default: `librechat`)

### 3. Apply the Secret

```bash
oc apply -f secrets-librechat.yaml
```

### 4. Update the Ingress Hostname

Edit `librechat-values.yaml` and update the ingress host on line 17:

```yaml
ingress:
  enabled: true
  hosts:
    - host: your-hostname.apps.your-cluster.com  # Update this
      paths:
        - path: /
          pathType: ImplementationSpecific
```

### 5. Install the Helm Chart

```bash
helm install librechat oci://ghcr.io/danny-avila/librechat-chart/librechat \
  -n librechat \
  -f librechat-values.yaml
```

### 6. Verify Deployment

Check that all pods are running:

```bash
oc get pods -n librechat
```

You should see:
- `librechat-librechat-*` (1/1 Running)
- `librechat-mongodb-*` (1/1 Running)
- `librechat-meilisearch-0` (1/1 Running)

### 7. Get the Route

```bash
oc get route -n librechat
```

Access LibreChat at the displayed hostname.

### 8. (Optional) Create Default User Automatically

To create a default admin user automatically on deployment:

```bash
oc apply -f user-init-job.yaml
```

This will create a user with credentials from your secrets file:
- Email: `DEFAULT_USER_EMAIL` (default: admin@example.com)
- Password: `DEFAULT_USER_PASSWORD` (default: ChangeMe123!)

The job will skip creation if the user already exists.

## Updating the Deployment

To update the deployment with new values:

```bash
helm upgrade librechat oci://ghcr.io/danny-avila/librechat-chart/librechat \
  -n librechat \
  -f librechat-values.yaml
```

## Uninstalling

To remove the deployment:

```bash
helm uninstall librechat -n librechat
oc delete secret librechat-credentials-env -n librechat
```

## Troubleshooting

### Pods in ImagePullBackOff

**Issue**: MongoDB image tag doesn't exist
**Solution**: Already configured to use `latest` tag due to Bitnami catalog changes in 2025

### Pods in CrashLoopBackOff with "permission denied" errors

**Issue**: OpenShift SCC blocking hardcoded UIDs
**Solution**: Already configured with `runAsUser: null` and `fsGroup: null`

### Application cannot write logs

**Issue**: No write permissions to log directories
**Solution**: Already configured with emptyDir volumes at `/app/logs` and `/app/api/logs`

### "Application is not available" in browser

**Possible causes**:
- Browser cache - try hard refresh (Ctrl+Shift+R)
- DNS propagation - wait a few minutes
- Check pods are running: `oc get pods -n librechat`
- Check route: `oc get route -n librechat`

## Components

- **LibreChat**: Main chat application (v0.8.1-rc1)
- **MongoDB**: Database (bitnami/mongodb:latest)
- **Meilisearch**: Search engine (v1.7.3)

## Notes

- This configuration is specifically designed for OpenShift
- Security contexts are removed to allow OpenShift to assign UIDs dynamically
- MongoDB uses Bitnami's OpenShift compatibility mode
- Log directories use ephemeral emptyDir volumes (logs are not persisted across pod restarts)

## Reference

- [LibreChat Documentation](https://www.librechat.ai/docs/local/helm_chart) - Official Helm chart documentation
- [LibreChat GitHub](https://github.com/danny-avila/LibreChat)
- [LibreChat Helm Chart](https://github.com/danny-avila/LibreChat/tree/main/charts)
- [LibreChat Credentials Generator](https://www.librechat.ai/toolkit/creds_generator) - Web-based tool for generating secrets
- [Bitnami MongoDB on OpenShift](https://github.com/bitnami/containers/blob/main/bitnami/mongodb/README.md)
