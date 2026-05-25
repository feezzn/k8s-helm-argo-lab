#!/usr/bin/env bash
set -euo pipefail

echo "Current context"
kubectl config current-context

echo
echo "Nodes"
kubectl get nodes -o wide

echo
echo "kube-system pods"
kubectl get pods -n kube-system -o wide

echo
echo "Waiting for node"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo
echo "Waiting for kube-proxy"
kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=120s

echo
echo "kube-proxy current container status"
kubectl -n kube-system get pods -l k8s-app=kube-proxy \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,STATE:.status.containerStatuses[0].state,AGE:.metadata.creationTimestamp'

echo
echo "kube-proxy recent logs"
kubectl -n kube-system logs daemonset/kube-proxy --tail=80 || true

echo
echo "kube-proxy previous logs"
kubectl -n kube-system logs daemonset/kube-proxy --previous --tail=80 || true

echo
echo "Waiting for CoreDNS"
kubectl -n kube-system rollout status deployment/coredns --timeout=120s

echo
echo "CoreDNS logs"
kubectl -n kube-system logs deployment/coredns --tail=120 || true

echo
echo "Cluster base is healthy."
