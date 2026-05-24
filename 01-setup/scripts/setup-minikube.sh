#!/bin/bash

# setup-minikube.sh
# Script para setup completo do Minikube com Argo Workflows

set -e

echo "🚀 Setup Minikube + Argo Workflows"
echo ""

# 1. Inicia Minikube
echo "1️⃣ Iniciando Minikube..."
minikube start --cpus=4 --memory=8192 --driver=docker

# 2. Aguarda estar pronto
echo "2️⃣ Aguardando Minikube ficar pronto..."
kubectl wait --for=condition=Ready node/minikube --timeout=300s

# 3. Cria namespace Argo
echo "3️⃣ Criando namespace argo..."
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -

# 4. Instala Argo Workflows
echo "4️⃣ Instalando Argo Workflows..."
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.6.0/install.yaml

# 5. Aguarda Argo estar pronto
echo "5️⃣ Aguardando Argo ficar pronto..."
kubectl wait --for=condition=available --timeout=300s deployment/argo-server -n argo

# 6. Ativa Argo UI
echo "6️⃣ Ativando Argo UI (port-forward)..."
echo ""
echo "✅ Setup completo!"
echo ""
echo "Para acessar o Argo UI, rode em outro terminal:"
echo "  kubectl port-forward -n argo svc/argo-server 2746:2746"
echo ""
echo "Depois acessa: http://localhost:2746"
echo ""
echo "Para submeter um workflow:"
echo "  argo submit -n argo workflow-name.yaml"
echo ""
