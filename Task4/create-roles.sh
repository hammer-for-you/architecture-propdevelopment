#!/bin/bash

set -euo pipefail

kubectl create namespace development || true
kubectl create namespace production || true

echo "Создаём роли"
echo "----------------------------------"

# Роли
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-reader
rules:
- apiGroups: ["", "apps", "batch", "extensions"]
  resources: 
    - pods
    - services
    - deployments
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
    - replicasets
    - configmaps
  verbs: ["get", "list", "watch"]
EOF

for namespace in development production; do
  cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-devops
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "get", "list", "watch", "update", "patch"]
EOF
done

for namespace in development production; do
  cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
EOF
done

for namespace in development production; do
  cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF
done

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-supervisor
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

# Привязка ролей к группам пользователей
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: resource-reader-binding
subjects:
- kind: Group
  name: qa-team
roleRef:
  kind: ClusterRole
  name: resource-reader
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-devops-binding
subjects:
- kind: Group
  name: developers
roleRef:
  kind: Role
  name: namespace-devops
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-secret-reader-binding
subjects:
- kind: Group
  name: senior-developers
roleRef:
  kind: Role
  name: namespace-secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-admin-binding
subjects:
- kind: Group
  name: senior-devops-engineers
- kind: Group
  name: cluster-administrators
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-supervisor-binding
subjects:
- kind: Group
  name: cluster-administrators
roleRef:
  kind: ClusterRole
  name: cluster-supervisor
  apiGroup: rbac.authorization.k8s.io
EOF

echo "  [✓] Роли и привязки успешно созданы!"