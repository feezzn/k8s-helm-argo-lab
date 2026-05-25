#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

helm upgrade --install "${CONSUMER_RELEASE}" ./charts/consumer-keda \
  --namespace "${LAB_NAMESPACE}" \
  --create-namespace \
  --set "image.repository=${CONSUMER_IMAGE}" \
  --set "image.tag=${CONSUMER_TAG}"

kubectl get deploy,scaledobject,hpa \
  --namespace "${LAB_NAMESPACE}"
