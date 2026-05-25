#!/usr/bin/env bash
set -euo pipefail

echo "Cluster context"
kubectl config current-context
kubectl version

echo
echo "kube-system health"
kubectl get pods -n kube-system -o wide

echo
echo "kube-proxy logs"
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=120 || true

echo
echo "CoreDNS describe"
kubectl describe pod -n kube-system -l k8s-app=kube-dns || true

echo
echo "KEDA pods"
kubectl get pods -n keda -o wide || true

echo
echo "KEDA secrets and jobs"
kubectl get secret,job -n keda || true

echo
echo "KEDA Helm values"
helm get values keda -n keda || true

echo
echo "KEDA Helm manifest references to certificates"
helm get manifest keda -n keda | grep -n "kedaorg-certs\\|certificates\\|admission" || true
