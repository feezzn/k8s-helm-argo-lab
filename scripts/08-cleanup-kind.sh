#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./versions.env

kind delete cluster --name "${KIND_CLUSTER_NAME}"
