#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

kubectl apply -f infra/kafka/namespace.yaml
kubectl apply -f infra/kafka/kafka-single-node.yaml

kubectl wait pod/kafka-0 \
  --namespace "${KAFKA_NAMESPACE}" \
  --for=condition=Ready \
  --timeout=240s

kubectl delete job orders-topic \
  --namespace "${KAFKA_NAMESPACE}" \
  --ignore-not-found=true

kubectl apply -f infra/kafka/orders-topic-job.yaml

kubectl wait job/orders-topic \
  --namespace "${KAFKA_NAMESPACE}" \
  --for=condition=Complete \
  --timeout=120s

kubectl get pods,svc,jobs --namespace "${KAFKA_NAMESPACE}"
