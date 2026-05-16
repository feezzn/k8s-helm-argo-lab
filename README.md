# k8s-helm-argo-lab 🚀

Um laboratório completo para aprender Kubernetes, Helm, Argo Workflows, Terraform e Ansible em um ambiente local.

## 📚 O que você vai aprender

- ✅ **Kubernetes local** com Minikube
- ✅ **Helm** - package manager pra K8s
- ✅ **Argo Workflows** - CI/CD pipelines como código
- ✅ **Terraform** - Infrastructure as Code (local + cloud-ready)
- ✅ **Ansible** - Automação de deploy e configuração

## 🏗️ Estrutura do Projeto

```
k8s-helm-argo-lab/
├── 01-setup/                      ← Setup inicial (Minikube + ferramentas)
├── 02-helm/                       ← Helm charts e práticas
├── 03-argo-workflows/             ← Pipelines com Argo
├── 04-terraform/                  ← IaC (local + cloud-ready)
├── 05-ansible/                    ← Automação
├── 06-projects/                   ← Projetos práticos completos
├── docs/                          ← Documentação geral
└── README.md (este arquivo)
```

## 🚀 Quick Start

```bash
# 1. Clone o repo
git clone https://github.com/feezzn/k8s-helm-argo-lab.git
cd k8s-helm-argo-lab

# 2. Setup inicial
chmod +x 01-setup/scripts/setup-minikube.sh
./01-setup/scripts/setup-minikube.sh

# 3. Acessa Argo UI
kubectl port-forward -n argo svc/argo-workflows-server 2746:2746
# http://localhost:2746
```

## 📋 Pré-requisitos

- ✅ Minikube v1.38.1+
- ✅ Kubectl v1.35.5+
- ✅ Helm v3.20.0+
- ✅ Terraform v1.15.3+
- ✅ Ansible v2.16.3+
- ✅ Argo v3.6.0+
- ✅ Git v2.43.0+

## 📖 Guias por tópico

- [01-setup](01-setup/README.md) - Setup Minikube + Argo
- [02-helm](02-helm/README.md) - Helm charts
- [03-argo-workflows](03-argo-workflows/README.md) - Pipelines CI/CD
- [04-terraform](04-terraform/README.md) - Infrastructure as Code
- [05-ansible](05-ansible/README.md) - Automação
- [06-projects](06-projects/README.md) - Projetos práticos

## 🎯 Roadmap

- [ ] Setup do Minikube
- [ ] Instalar Argo no cluster
- [ ] Deploy primeiro Helm chart
- [ ] Criar primeiro Argo workflow
- [ ] Fazer projeto Python app
- [ ] Setup Terraform local
- [ ] Automatizar com Ansible

## 💡 Dicas

- Sempre use namespaces para organizar recursos
- Teste tudo localmente antes de fazer commit
- Use tags git pra marcar versões estáveis
- Mantenha valores sensíveis em `.env` (não commit!)

## 🤝 Estrutura de commits

```
feat: adiciona novo Helm chart
fix: corrige bug em workflow
docs: atualiza README
test: adiciona testes ao pipeline
chore: atualiza dependências
```

---

**Happy learning!** 🚀

Criado em: Maio 2026
