#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

docker build \
  --tag "${CONSUMER_IMAGE}:${CONSUMER_TAG}" \
  apps/consumer

kind load docker-image \
  "${CONSUMER_IMAGE}:${CONSUMER_TAG}" \
  --name "${KIND_CLUSTER_NAME}"
