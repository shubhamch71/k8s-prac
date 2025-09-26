#!/bin/bash

NAMESPACE="test"
SERVICEACCOUNT="dev-user"
KUBECONFIG_FILE="dev-user.kubeconfig"
CLUSTER_NAME="minikube"

echo "[+] Creating namespace: $NAMESPACE"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

echo "[+] Creating ServiceAccount: $SERVICEACCOUNT"
kubectl create serviceaccount "$SERVICEACCOUNT" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Creating Role with pod read access"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

echo "[+] Creating RoleBinding"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SERVICEACCOUNT
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

echo "[+] Creating token Secret for the ServiceAccount"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICEACCOUNT}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: "$SERVICEACCOUNT"
type: kubernetes.io/service-account-token
EOF

echo "[+] Waiting for token to be populated..."
sleep 5

SECRET_NAME="${SERVICEACCOUNT}-token"
USER_TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)
CA_CRT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' | base64 -d)

CLUSTER_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

echo "[+] Writing CA cert to file"
echo "$CA_CRT" > "${SERVICEACCOUNT}-ca.crt"

echo "[+] Building kubeconfig: $KUBECONFIG_FILE"
kubectl config set-cluster "$CLUSTER_NAME" \
  --server="$CLUSTER_ENDPOINT" \
  --certificate-authority="${SERVICEACCOUNT}-ca.crt" \
  --embed-certs=true \
  --kubeconfig="$KUBECONFIG_FILE" >/dev/null

kubectl config set-credentials "$SERVICEACCOUNT" \
  --token="$USER_TOKEN" \
  --kubeconfig="$KUBECONFIG_FILE" >/dev/null

kubectl config set-context "${SERVICEACCOUNT}-context" \
  --cluster="$CLUSTER_NAME" \
  --namespace="$NAMESPACE" \
  --user="$SERVICEACCOUNT" \
  --kubeconfig="$KUBECONFIG_FILE" >/dev/null

kubectl config use-context "${SERVICEACCOUNT}-context" --kubeconfig="$KUBECONFIG_FILE" >/dev/null

echo "✅ Kubeconfig created: $KUBECONFIG_FILE"
echo "👉 Try it: kubectl --kubeconfig=$KUBECONFIG_FILE get pods"
