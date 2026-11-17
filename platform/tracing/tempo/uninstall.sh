#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

# Grafana's sidecar drops the Tempo datasource with its ConfigMap.
kubectl delete configmap tempo-grafana-datasource --namespace "$NAMESPACE" --ignore-not-found

echo "Uninstalling Tempo..."
helm uninstall tempo --namespace "$NAMESPACE" 2>/dev/null || true

# Clean up PVCs
kubectl delete pvc -l app.kubernetes.io/name=tempo -n "$NAMESPACE" --ignore-not-found

echo "Tempo uninstalled."
