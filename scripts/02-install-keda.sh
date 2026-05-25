#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  --namespace "${KEDA_NAMESPACE}" \
  --create-namespace \
  --version "${KEDA_CHART_VERSION}"

kubectl rollout status deploy/keda-operator \
  --namespace "${KEDA_NAMESPACE}" \
  --timeout=180s

kubectl rollout status deploy/keda-operator-metrics-apiserver \
  --namespace "${KEDA_NAMESPACE}" \
  --timeout=180s

kubectl get pods --namespace "${KEDA_NAMESPACE}"
