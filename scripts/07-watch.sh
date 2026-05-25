#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../versions.env"

watch -n 2 "kubectl get scaledobject,hpa,deploy,pods --namespace ${LAB_NAMESPACE}; echo; kubectl get jobs --namespace ${KAFKA_NAMESPACE}"
