#!/usr/bin/env bash
set -euo pipefail

KEDA_NAMESPACE="${KEDA_NAMESPACE:-keda}"

echo "== Context =="
kubectl config current-context
kubectl version

echo
echo "== Nodes =="
kubectl get nodes -o wide

echo
echo "== KEDA CRDs =="
kubectl get crd | grep -i keda || true

echo
echo "== KEDA API resources =="
kubectl api-resources | grep -i keda || true

echo
echo "== KEDA namespace components =="
kubectl get deploy,pod,svc,secret,job -n "${KEDA_NAMESPACE}" || true

echo
echo "== KEDA component images =="
kubectl get deploy -n "${KEDA_NAMESPACE}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.template.spec.containers[*].image}{"\n"}{end}' || true

echo
echo "== Helm releases matching KEDA =="
helm list -A | grep -i keda || true

echo
echo "== External metrics APIService =="
kubectl get apiservice | grep -i external.metrics || true

echo
echo "== Webhooks matching KEDA =="
kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration | grep -i keda || true

echo
echo "== ScaledObjects =="
kubectl get scaledobject -A || true

echo
echo "== ScaledObjects summary =="
kubectl get scaledobject -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicaCount,MAX:.spec.maxReplicaCount,TRIGGERS:.spec.triggers[*].type,READY:.status.conditions[?(@.type=="Ready")].status,ACTIVE:.status.conditions[?(@.type=="Active")].status' || true

echo
echo "== ScaledJobs =="
kubectl get scaledjob -A || true

echo
echo "== TriggerAuthentications =="
kubectl get triggerauthentication -A || true

echo
echo "== ClusterTriggerAuthentications =="
kubectl get clustertriggerauthentication || true

echo
echo "== HPAs that look KEDA-managed =="
kubectl get hpa -A | grep -i keda || true

echo
echo "== KEDA operator recent logs =="
kubectl logs -n "${KEDA_NAMESPACE}" deploy/keda-operator --tail=120 || true
