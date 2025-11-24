#!/bin/bash
# LibreChat Helm Deployment Script with Automatic User Creation
# This script automates the full deployment including optional user creation

set -e

NAMESPACE="${NAMESPACE:-librechat}"
RELEASE_NAME="${RELEASE_NAME:-librechat}"
CREATE_USER="${CREATE_USER:-false}"

echo "=== LibreChat Deployment Script ==="
echo "Namespace: $NAMESPACE"
echo "Release Name: $RELEASE_NAME"
echo "Auto-create user: $CREATE_USER"
echo ""

# Step 1: Create namespace if it doesn't exist
echo "Step 1: Ensuring namespace exists..."
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
  echo "Creating namespace $NAMESPACE..."
  oc create namespace "$NAMESPACE"
else
  echo "Namespace $NAMESPACE already exists"
fi

# Step 2: Apply secrets
echo ""
echo "Step 2: Applying secrets..."
oc apply -f secrets-librechat.yaml

# Step 3: Install/upgrade Helm chart
echo ""
echo "Step 3: Deploying LibreChat via Helm..."
helm upgrade --install "$RELEASE_NAME" \
  oci://ghcr.io/danny-avila/librechat-chart/librechat \
  -n "$NAMESPACE" \
  -f librechat-values.yaml \
  --wait \
  --timeout 5m

# Step 4: Wait for deployment to be ready
echo ""
echo "Step 4: Waiting for deployment to be ready..."
oc rollout status deployment/librechat-librechat -n "$NAMESPACE" --timeout=5m

# Step 5: Optionally create default user
if [ "$CREATE_USER" = "true" ]; then
  echo ""
  echo "Step 5: Creating default user..."
  oc apply -f user-init-job.yaml

  echo "Waiting for user creation job to complete..."
  oc wait --for=condition=complete --timeout=2m job/librechat-create-user -n "$NAMESPACE" || {
    echo "User creation job did not complete successfully. Check logs with:"
    echo "  oc logs job/librechat-create-user -n $NAMESPACE"
  }
else
  echo ""
  echo "Step 5: Skipping user creation (set CREATE_USER=true to enable)"
fi

# Step 6: Display route
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "LibreChat route:"
oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}' && echo ""
echo ""
echo "To access LibreChat, visit:"
echo "  http://$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}')"
echo ""

if [ "$CREATE_USER" = "true" ]; then
  echo "Default user credentials:"
  echo "  Email: $(oc get secret librechat-credentials-env -n "$NAMESPACE" -o jsonpath='{.data.DEFAULT_USER_EMAIL}' | base64 -d)"
  echo "  Password: [stored in secret]"
  echo ""
fi
