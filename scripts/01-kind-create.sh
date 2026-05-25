#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

kind create cluster \
  --name "${KIND_CLUSTER_NAME}" \
  --config infra/kind/kind-v1.27.yaml

kubectl cluster-info --context "kind-${KIND_CLUSTER_NAME}"
