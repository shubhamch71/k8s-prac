#!/bin/bash

# === CONFIG ===
NAMESPACE="test"
SERVICE_ACCOUNT="dev-user"
ROLE_NAME="pod-reader"
ROLE_BINDING="${ROLE_NAME}-binding"
SECRET_NAME="${SERVICE_ACCOUNT}-token"
KUBECONFIG_FILE="dev-user.kubeconfig"

echo "🗑️ Cleaning up resources..."

echo "🔹 Deleting RoleBinding: $ROLE_BINDING"
kubectl delete rolebinding "$ROLE_BINDING" -n "$NAMESPACE" --ignore-not-found

echo "🔹 Deleting Role: $ROLE_NAME"
kubectl delete role "$ROLE_NAME" -n "$NAMESPACE" --ignore-not-found

echo "🔹 Deleting ServiceAccount: $SERVICE_ACCOUNT"
kubectl delete serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" --ignore-not-found

echo "🔹 Deleting Secret: $SECRET_NAME"
kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found

echo "🔹 Deleting Namespace (optional): $NAMESPACE"
read -p "❓ Do you want to delete the namespace '$NAMESPACE'? [y/N]: " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  kubectl delete namespace "$NAMESPACE"
else
  echo "✅ Skipping namespace deletion."
fi

echo "🔹 Removing generated kubeconfig file: $KUBECONFIG_FILE"
rm -f "$KUBECONFIG_FILE"

echo "✅ Cleanup complete."

