#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

kubectl delete job orders-producer \
  --namespace "${KAFKA_NAMESPACE}" \
  --ignore-not-found=true

kubectl apply -f infra/kafka/orders-producer-job.yaml

kubectl wait job/orders-producer \
  --namespace "${KAFKA_NAMESPACE}" \
  --for=condition=Complete \
  --timeout=120s

kubectl logs job/orders-producer \
  --namespace "${KAFKA_NAMESPACE}"
