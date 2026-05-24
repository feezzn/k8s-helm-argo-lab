# IDP Implementation Plan — Do Zero ao Deploy Bem Funcional

> Objetivo: construir um IDP produção-ready em fases, aprendendo melhores práticas no caminho.
> Baseado em padrões reais (BMG, Spotify, Google Cloud, Uber).

---

## 📊 Visão Geral da Arquitetura

```
┌────────────────────────────────────────────────────────────────┐
│                        DEVELOPER FLOW                          │
├────────────────────────────────────────────────────────────────┤
│  Dev: git push                                                  │
│   └─→ GitHub Actions (Webhook automático)                      │
│        └─→ Validator: lê MongoDB, exporta variáveis (20+)      │
│             └─→ Build/Test/Scan/Deploy (automático)           │
│                  └─→ Slack notification com resultado         │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                    O IDP POR BAIXO                             │
├────────────────────────────────────────────────────────────────┤
│  📦 3 Bancos de Dados (MongoDB)                                │
│     ├─ aplicacoes   (squads/times)                            │
│     ├─ configuracoes (infra por ambiente)                     │
│     └─ servicos     (cada microserviço)                       │
│                                                                │
│  🔧 CLI Python (catalog-cli)                                  │
│     ├─ catalog servicos add/get/list                          │
│     ├─ catalog validator validate pipeline dotnet             │
│     ├─ catalog chart values <nome>                            │
│     └─ [Future] catalog ai check <nome> --report               │
│                                                                │
│  🚀 Golden Path (GitHub Actions templates)                    │
│     ├─ .github/workflows/pipeline-dotnet.yml                  │
│     ├─ .github/workflows/pipeline-go.yml                      │
│     ├─ .github/workflows/pipeline-python.yml                  │
│     ├─ .github/workflows/pipeline-frontend.yml                │
│     └─ .github/workflows/pipeline-batch.yml                   │
│                                                                │
│  🏗️ Infraestrutura (Terraform + Helm)                         │
│     ├─ Kubernetes (local: kind, prod: AKS/EKS)                │
│     ├─ PostgreSQL/MongoDB (stateful)                          │
│     ├─ ArgoCD (GitOps para deploy)                            │
│     ├─ Prometheus/Grafana (observabilidade)                   │
│     └─ Sealed Secrets (para dados sensíveis)                  │
│                                                                │
│  🎨 Portal (Fase 4+, opcional com Backstage)                 │
│     ├─ Catálogo com UI                                        │
│     ├─ Software Templates (cria repo em 1 clique)             │
│     └─ Scorecard de qualidade por serviço                     │
└────────────────────────────────────────────────────────────────┘
```

---

## 📋 Fases do Projeto

### FASE 1: Infraestrutura Base (Semana 1)
**Objetivo**: ter um Kubernetes funcional + MongoDB + GitHub Actions + CLI básica

```
[ ] 1.1 - Crear cluster Kubernetes local (kind)
[ ] 1.2 - Deploy MongoDB (Helm)
[ ] 1.3 - Setup repositório de IDP (GitHub)
[ ] 1.4 - Criar pastas: .github/workflows, catalog-cli, helm-charts, terraform
[ ] 1.5 - CLI básica em Python (primeiros comandos)
[ ] 1.6 - Criar as 3 coleções MongoDB manualmente
```

**Infraestrutura necessária:**
- **Mínimo**: 1 cluster K8s (local: kind, prod: AKS/EKS)
- **Armazenamento**: MongoDB (pode ser container)
- **CI**: GitHub Actions (grátis)
- **Observabilidade**: Prometheus/Grafana (básico)
- **Segredos**: Sealed Secrets ou External Secrets Operator

**Recursos:**
- [kind — Kubernetes in Docker](https://kind.sigs.k8s.io/)
- [MongoDB Operator para Kubernetes](https://www.mongodb.com/docs/kubernetes-operator/)
- [Helm Charts oficial](https://helm.sh/docs/)
- [GitHub Actions: Introduction](https://docs.github.com/en/actions)

---

### FASE 2: Golden Path Básico (Semana 2-3)
**Objetivo**: criar um pipeline que funciona para 1 tipo de aplicação (ex: .NET)

```
[ ] 2.1 - Criar primeira aplicação exemplo (.NET Console)
[ ] 2.2 - Registrá-la no MongoDB
[ ] 2.3 - Criar GitHub Actions workflow (dotnet.yml)
[ ] 2.4 - Workflow: build + test + docker push
[ ] 2.5 - Workflow: deploy com Helm
[ ] 2.6 - Verificar deploy no K8s
[ ] 2.7 - Setup rollback automático
```

**Aplicação de exemplo: Serviço .NET**
```
Nome: payment-api
Tipo: REST API (ASP.NET Core)
Stack: .NET 8, EF Core, xUnit
Deploy: Docker → ECR → Helm → K8s
```

**Recursos:**
- [GitHub Actions for .NET](https://github.com/actions/setup-dotnet)
- [.NET Test Template](https://docs.microsoft.com/en-us/dotnet/core/testing/)
- [Helm .NET Chart](https://github.com/helm/charts)
- [ArgoCD Integration](https://argo-cd.readthedocs.io/)

---

### FASE 3: Multi-Stack Applications (Semana 3-4)
**Objetivo**: ter pipeline funcional para 5 tipos diferentes de aplicação

```
[ ] 3.1 - Criar aplicação Python (FastAPI + Celery batch)
[ ] 3.2 - Criar aplicação Go (gRPC service)
[ ] 3.3 - Criar aplicação Frontend (React/Vue)
[ ] 3.4 - Criar aplicação Node.js (Express API)
[ ] 3.5 - Criar workflow de batch job (Kubernetes CronJob)
[ ] 3.6 - Testar deployment das 5 aplicações
[ ] 3.7 - Documentar golden path por tecnologia
```

**Aplicações de exemplo:**

| App | Tipo | Stack | Propósito |
|---|---|---|---|
| **payment-api** | REST API | .NET 8 + EF Core | Processamento de pagamentos |
| **order-service** | gRPC | Go + Protobuf | Serviço de pedidos (interno) |
| **notification-batch** | Batch Job | Python + Celery | Processa notificações em background |
| **dashboard** | Frontend | React + TypeScript | Portal para devs verem serviços |
| **user-service** | REST API | Node.js + Express | Gerenciamento de usuários |

**Recursos:**
- [Go gRPC Tutorial](https://grpc.io/docs/languages/go/)
- [Python FastAPI + Celery](https://fastapi.tiangolo.com/)
- [React Best Practices](https://react.dev/)
- [Node.js Dockerfile best practices](https://github.com/nodejs/docker-node/blob/main/docs/usage.md)

---

### FASE 4: Self-Service + Portal (Semana 4-5)
**Objetivo**: dev consegue criar novo serviço com 1 clique (sem pedir para infra)

```
[ ] 4.1 - Criar pipeline de onboarding (GitHub Actions)
[ ] 4.2 - Template para criar novo repo (cookiecutter/template)
[ ] 4.3 - Registrar automaticamente no MongoDB
[ ] 4.4 - Provisionar namespace + RBAC no K8s
[ ] 4.5 - Deploy Backstage (opcional) ou CLI interativa
[ ] 4.6 - Criar dashboard de serviços (Grafana/Prometheus)
[ ] 4.7 - Setup Slack notifications para eventos
```

**Resultado:**
```bash
$ catalog new-service --name order-processor --type python --team payments
✓ Created repo: github.com/bmg-internal/order-processor
✓ Registered in MongoDB
✓ Created K8s namespace: order-processor-dev
✓ RBAC roles: dev, devops, readonly
✓ First CI/CD run started

Ready to push code!
```

**Recursos:**
- [Backstage Software Templates](https://backstage.io/docs/features/software-templates/)
- [Cookiecutter — Python project templates](https://cookiecutter.readthedocs.io/)
- [Terraform for Kubernetes RBAC](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)

---

### FASE 5: IA & Observabilidade (Semana 5+)
**Objetivo**: IA valida qualidade, sugere melhorias, alerta sobre issues

```
[ ] 5.1 - Integrar LLM para análise de código (GitHub Copilot API ou local)
[ ] 5.2 - Criar "agent jobs" (como em BMG: self-hosted agents)
[ ] 5.3 - Agent valida: SAST/SCA/Cobertura/Performance
[ ] 5.4 - Agent sugere: "seu Go requer 30 linhas menos"
[ ] 5.5 - Setup Dynatrace/New Relic para observabilidade
[ ] 5.6 - Criar runbooks automáticos (ex: "service degraded → aqui está o fix")
[ ] 5.7 - DORA metrics dashboard (deploy frequency, MTTR, etc.)
```

**Recursos:**
- [GitHub Copilot for Enterprise](https://github.com/features/copilot)
- [LangChain — LLM Framework](https://langchain.com/)
- [Dynatrace API](https://docs.dynatrace.com/docs/dynatrace-api)
- [OpenTelemetry](https://opentelemetry.io/)

---

## 🗂️ Estrutura do Repositório

```
idp-platform/
├── README.md
├── PHASE-CHECKLIST.md
├── TEAM_TOPOLOGIES.md ← (referência: como organizar o time)
├── DORA_METRICS.md ← (como medir sucesso)
│
├── catalog-cli/
│   ├── setup.py
│   ├── catalog/__init__.py
│   ├── catalog/cli.py (main entry point)
│   ├── catalog/commands/
│   │   ├── servicos.py (add, get, list, validate)
│   │   ├── configuracoes.py (AWS account info)
│   │   ├── aplicacoes.py (squads)
│   │   ├── validator.py (pipeline validator)
│   │   ├── chart.py (Helm values generator)
│   │   └── ai_agent.py (IA para análise)
│   ├── catalog/mongo.py (connection + queries)
│   ├── tests/
│   └── requirements.txt
│
├── .github/workflows/
│   ├── _template-dotnet.yml (reutilizável)
│   ├── _template-go.yml
│   ├── _template-python.yml
│   ├── _template-frontend.yml
│   ├── _template-batch.yml
│   ├── onboarding.yml (cria novo serviço)
│   └── validate-catalog.yml (valida MongoDB)
│
├── helm-charts/
│   ├── dotnet-service/
│   ├── go-service/
│   ├── python-service/
│   ├── frontend/
│   └── batch-job/
│
├── terraform/
│   ├── 1-kind-cluster/
│   │   ├── main.tf (cria K8s local)
│   │   └── output.tf
│   ├── 2-mongodb/
│   │   └── main.tf (deploy MongoDB)
│   ├── 3-rbac/
│   │   └── main.tf (namespaces, roles)
│   ├── 4-observability/
│   │   ├── prometheus.tf
│   │   └── grafana.tf
│   └── 5-argocd/ (GitOps)
│       └── main.tf
│
├── samples/
│   ├── payment-api-dotnet/
│   ├── order-service-go/
│   ├── notification-batch-python/
│   ├── user-service-node/
│   └── dashboard-react/
│
├── docs/
│   ├── GETTING-STARTED.md
│   ├── FIRST-DEPLOY.md
│   ├── ADD-NEW-SERVICE.md
│   ├── TROUBLESHOOTING.md
│   ├── TEAM-TOPOLOGIES.md
│   └── ARCHITECTURE.md
└── scripts/
    ├── setup-mongodb.sh (populate demo data)
    └── test-e2e.sh (test full pipeline)
```

---

## 🎯 Team Topologies — Como Estruturar o Time

Este é um conceito crítico! Vem do livro "Team Topologies" de Matthew Skelton e Manuel Pais.

### As 4 Topologias Fundamentais

```
1️⃣  STREAM-ALIGNED TEAM
    Responsável por: um product/serviço/capacidade do negócio
    Time de Pagamentos, Time de Pedidos, etc.
    Autonomia: alta
    Tamanho: 6-9 pessoas
    Exemplo: "Payment Squad"

2️⃣  PLATFORM TEAM
    Responsável por: o IDP, ferramentas, pipelines
    Cria golden paths, mantém MongoDB, atualiza templates
    Autonomia: alta (mas serve os times 1-aligned)
    Tamanho: 4-10 pessoas
    Exemplo: "Platform Engineering @ BMG"

3️⃣  ENABLING TEAM
    Responsável por: coaching + expertise
    Ajuda stream-aligned teams a adotar novas techs/practices
    Exemplo: "Cloud Enablement Team"

4️⃣  COMPLICATED SUBSYSTEM TEAM
    Responsável por: subsistema complexo isolado
    Performance-critical, domain-specific
    Exemplo: "Machine Learning Infra Team"

```

### Como isso se aplica ao seu IDP

```
Platform Team (você agora!)
├─ Mantém catálogo MongoDB
├─ Cria/atualiza golden paths (workflows)
├─ Mantém Helm charts
├─ Onboarding de novos serviços
└─ Suporte aos times

Stream-Aligned Teams (Payment, Orders, Users, etc.)
├─ Push código → pipeline automático
├─ Registram serviço novo via CLI
├─ Resolvem issues de negócio
└─ Medem DORA metrics

Enabling Teams (Observability, Security)
├─ Adicionam novas features ao IDP
├─ Treinam times em Kubernetes
├─ Audit + compliance
└─ Otimizações
```

**Recurso:**
- [Team Topologies Book](https://teamtopologies.com/)
- [Interaction Modes between Teams](https://teamtopologies.com/key-concepts-content/interaction-modes)

---

## 📊 DORA Metrics — Como Medir Sucesso

Seu IDP será um sucesso se movimentar estas 4 métricas:

```
ANTES do IDP           DEPOIS do IDP (Elite)
──────────────────     ─────────────────────
Deploy Frequency       1x/mês    →  Múltiplos/dia
Lead Time              1-2 meses →  < 1 hora
MTTR                   2-3 dias  →  < 1 hora
Change Failure Rate    30-40%    →  < 5%
```

### Como medir (coleta via GitHub API + MongoDB)

```bash
# Deployment Frequency: contar quantos pushes → main em 7 dias
SELECT COUNT(*) FROM commits WHERE branch='main' AND date >= NOW() - 7 days

# Lead Time: tempo do primeiro commit na branch → merge em main
SELECT AVG(merged_at - created_at) FROM pull_requests WHERE merged_at >= NOW() - 7 days

# MTTR: tempo do alert → recovery (Prometheus + Grafana)
SELECT AVG(resolved_at - fired_at) FROM incidents WHERE resolved_at >= NOW() - 7 days

# Change Failure Rate: % de deployments que causaram incidente em 24h
SELECT COUNT(CASE WHEN incident_detected=true THEN 1 END) / 
       COUNT(*) * 100 
FROM deployments WHERE deployed_at >= NOW() - 7 days
```

---

## 🚀 Primeiros Passos (Próximos 2-3 dias)

### Dia 1: Ambiente Local + MongoDB
```bash
# Clonar repo
git clone <seu-idp-repo> && cd idp-platform

# Criar cluster Kubernetes local
kind create cluster --name idp-dev

# Deploy MongoDB
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mongodb bitnami/mongodb --namespace mongodb --create-namespace

# Verificar
kubectl get pods -n mongodb
```

### Dia 2: CLI Python + Primeiros Dados
```bash
# Setup CLI
cd catalog-cli
pip install -e .

# Criar coleções e dados
python scripts/setup-mongodb.sh

# Testar
catalog aplicacoes list
catalog configuracoes get prb
```

### Dia 3: Primeira Aplicação + Pipeline
```bash
# Criar app .NET
dotnet new webapi -n PaymentApi
cd PaymentApi

# Registrar no catálogo
catalog servicos add payment-api acaf dotnet 8 --path src/PaymentApi/

# Push → GitHub Actions → Deploy → Status no Slack
git push
```

---

## 📚 Recursos & Referências Documentadas

Toda vez que você aprender algo novo, adicione aqui:

### Team Topologies
- [O livro](https://teamtopologies.com/)
- [Interaction Modes](https://teamtopologies.com/key-concepts-content/interaction-modes)
- Relação: Platform Team = seu IDP

### DORA Metrics
- [DORA Research](https://dora.dev/)
- [Como implementar](https://cloud.google.com/architecture/devops-measurement-cre-fundamentals)

### Padrões de IDP
- [Platform Engineering](https://platformengineering.org/)
- [Internal Developer Platform](https://internaldeveloperplatform.org/)
- [Spotify Golden Path](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/)

### Kubernetes
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
- [ArgoCD GitOps](https://argo-cd.readthedocs.io/)

### Python CLI
- [Click Framework](https://click.palletsprojects.com/)
- [Typer (asyncio-friendly)](https://typer.tiangolo.com/)
- [Poetry para pacotes](https://python-poetry.org/)

### GitHub Actions
- [Actions Marketplace](https://github.com/marketplace?type=actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-job-runs)

---

## ⚠️ Decisões Importantes

### 1. Kubernetes: Kind (dev) vs AKS/EKS (prod)?
- **Recomendação**: Começar com Kind, depois migrar para AKS/EKS quando escalar
- Kind roda local, é rápido, perfeito para aprender
- AKS/EKS = quando houver produção real

### 2. CLI vs Backstage?
- **Recomendação**: CLI primeiro, depois Backstage
- CLI é simples, versível, pode mover do GitHub para GitLab sem problema
- Backstage é mais completo mas requer time dedicado

### 3. MongoDB vs PostgreSQL?
- **Recomendação**: MongoDB (flexibilidade de schema)
- O catálogo tem documento por serviço, e cada tipo tem propriedades diferentes
- PostgreSQL funcionaria mas seria mais rígido (mais migrations)

### 4. ArgoCD vs Flux?
- **Recomendação**: ArgoCD (mais maduro, UI melhor)
- Ambos são GitOps, ArgoCD tem mais ecosystem

---

## 🎓 Próximas Discussões

Conforme avançamos, documentaremos:

- [ ] Como estruturar um pull request review com o IDP
- [ ] Escalabilidade: 10 serviços → 100 serviços (quando mudar MongoDB para PostgreSQL?)
- [ ] Observabilidade: Prometheus + Grafana + alertas
- [ ] Segurança: Sealed Secrets, RBAC, network policies
- [ ] IA Agent Jobs: como implementar o padrão do BMG
- [ ] Cost Optimization: rastrear custo por serviço/squad
- [ ] Multi-cloud: suportar AWS + Azure + GCP
- [ ] Disaster Recovery: como fazer backup/restore do catálogo

---

**Last Updated**: 21 de maio de 2026  
**Status**: Planning Phase
