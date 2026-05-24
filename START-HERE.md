# 🎯 Start Here: O Seu Mapa do IDP

> **TL;DR**: Você quer construir uma plataforma que permite que devs façam deploy em 1 clique.
> Começamos do zero, aprendemos no caminho.

---

## A Visão (em 30 segundos)

```
ANTES                              DEPOIS
──────                             ──────
Dev A: "Como faço deploy?"         Dev A: git push
       → espera DevOps             Dev B: git push
       → 1 semana depois           Dev C: git push
       → deploy manual             
       → erros em prod             ✓ Todos automaticamente
       → rollback manual           ✓ Seguro (políticas aplicadas)
                                   ✓ Observável (alertas automáticos)
Dev B: "Qual serviço causa         ✓ Rápido (< 15 min)
       incidente?"                 ✓ Rastreável (audit log)
       → ninguém sabe
       → 3 horas para achar

Dev C: "Preciso de nova            Dev D novo:
       infraestrutura"             "Consegui fazer deploy no dia 1!"
       → ticket para infra
       → 2 semanas later
```

---

## A Estrutura (arquitetura simplificada)

```
┌─────────────────────────────────────────────────────┐
│                  DEVELOPER WORKFLOW                 │
│  (qualquer dev, qualquer time, qualquer tech)      │
└─────────────────────────────────────────────────────┘
                        ↓
                   git push origin
                        ↓
        ┌───────────────────────────────────┐
        │  GitHub Actions Trigger          │
        │  (automático, sempre)            │
        └───────────────────────────────────┘
                        ↓
         ┌──────────────────────────────────┐
         │  Validator (CLI) — Fase 1       │
         │  Lê MongoDB, exporta vars       │
         │  (20+ variáveis de infra)       │
         └──────────────────────────────────┘
                        ↓
        ┌─────────────────────────────────┐
        │  Golden Path (Workflows)        │
        │  ├─ Build                       │
        │  ├─ Test                        │
        │  ├─ Scan (SAST/SCA)            │
        │  ├─ Docker                      │
        │  ├─ Helm                        │
        │  ├─ Deploy (hml/uat)            │
        │  ├─ Approve (manual for prod)   │
        │  ├─ Deploy (prod)               │
        │  └─ Verify                      │
        └─────────────────────────────────┘
                        ↓
        ┌──────────────────────────────────┐
        │  Kubernetes (ArgoCD — Fase 3)   │
        │  Atualiza aplicação             │
        └──────────────────────────────────┘
                        ↓
        ┌──────────────────────────────────┐
        │  Observabilidade                │
        │  ├─ Prometheus (métricas)       │
        │  ├─ Grafana (dashboard)         │
        │  ├─ Logs (ELK/Loki)             │
        │  └─ Alerts (Slack)              │
        └──────────────────────────────────┘


TUDO ISTO ALIMENTADO POR:
────────────────────────
MongoDB (3 coleções):
  aplicacoes    = squads/times
  configuracoes = infra (AWS account, region, K8s cluster)
  servicos      = cada microserviço (nome, tech, repo, etc)

CLI Python:
  catalog servicos add/get/list
  catalog configuracoes get
  catalog validator validate
  catalog chart values
  [future] catalog ai check
```

---

## As 5 Fases (e o tempo)

| # | Fase | Focus | Tempo | Resultado |
|---|------|-------|-------|-----------|
| **1** | **Infraestrutura Base** | Kind + MongoDB + CLI | 3-4 dias | CLI funciona, dados em MongoDB |
| **2** | **Golden Path .NET** | Primeiro workflow | 1-2 dias | Deploy automático de 1 app |
| **3** | **Multi-Stack** | 5 tipos de app (Go, Python, Node, React, Batch) | 2-3 dias | Qualquer tech funciona |
| **4** | **Self-Service** | Portal/CLI para criar novo serviço | 2-3 dias | Dev novo faz deploy dia 1 |
| **5** | **IA & Obs** | LLM para validação, DORA metrics | 3-5 dias | Sugestões automáticas, dashboard |

**Total**: 2 semanas até ter um IDP funcional

---

## Arquivo Por Arquivo — O Que Você Criará

### Documentação (já pronto!)

```
📄 IDP-CONCEPTS.md ← leia isso primeiro! (teoria)
📄 IDP-IMPLEMENTATION-PLAN.md ← roadmap detalhado
📄 TEAM_TOPOLOGIES.md ← como organizar times
📄 PHASE-1-CHECKLIST.md ← step-by-step executável ← COMECE AQUI!
```

### Infraestrutura (Terraform, Kind, Helm)

```
📁 terraform/
  ├── 1-kind-cluster/
  │   └── kind-config.yaml  ← Kubernetes local
  ├── 2-mongodb/
  │   └── values.yaml       ← banco de dados
  ├── 3-rbac/
  │   └── main.tf           ← namespaces, roles
  ├── 4-observability/
  │   ├── prometheus.tf
  │   └── grafana.tf
  └── 5-argocd/
      └── main.tf           ← GitOps
```

### CLI Python (o coração)

```
📁 catalog-cli/
  ├── setup.py
  ├── requirements.txt
  ├── catalog/
  │   ├── cli.py             ← entry point
  │   ├── mongo.py           ← conexão MongoDB
  │   └── commands/
  │       ├── servicos.py    ← `catalog servicos add/get/list`
  │       ├── configuracoes.py
  │       ├── validator.py
  │       └── chart.py
  └── tests/
      └── test_mongo.py
```

### Pipelines (GitHub Actions)

```
📁 .github/workflows/
  ├── validate.yml           ← valida CI
  ├── test-cli.yml
  ├── _template-dotnet.yml   ← reutilizável ← FASE 2
  ├── _template-go.yml
  ├── _template-python.yml
  ├── _template-frontend.yml
  ├── _template-batch.yml
  └── onboarding.yml         ← cria novo serviço ← FASE 4
```

### Helm Charts (deploy padrão)

```
📁 helm-charts/
  ├── dotnet-service/
  ├── go-service/
  ├── python-service/
  ├── frontend/
  └── batch-job/
```

### Aplicações de Exemplo

```
📁 samples/
  ├── payment-api-dotnet/    ← .NET 8 API
  ├── order-service-go/      ← Go gRPC
  ├── notification-batch-python/  ← Python + Celery
  ├── user-service-node/     ← Node.js Express
  └── dashboard-react/       ← React frontend
```

---

## ⚡ Primeira Tarefa (hoje, agora!)

**Objetivo**: Entender a visão e o plano

### Passo 1: Leia os 4 arquivos documentação

```bash
# Em ordem:
1. IDP-CONCEPTS.md (você já leu!)
2. TEAM_TOPOLOGIES.md (10 min)
3. IDP-IMPLEMENTATION-PLAN.md (20 min)
4. PHASE-1-CHECKLIST.md (skim, referência)

Tempo total: 30 min
```

### Passo 2: Decida

- [ ] Usar `k8s-helm-argo-lab` como base?
- [ ] Ou criar novo repo `idp-platform`?

**Recomendação**: Criar novo repo (mais limpo, começa do zero)

### Passo 3: Prepare seu ambiente

Certifique que tem:
- [ ] Docker instalado
- [ ] kubectl instalado
- [ ] Python 3.9+
- [ ] Git

Se não tiver algo, avise que eu guio a instalação.

---

## 📚 Conceitos Chave que Você Aprenderá

Enquanto constrói o IDP, você vai aprender:

### 🎯 Conceitos
- **Internal Developer Platform (IDP)** = plataforma de dev interna
- **Golden Path** = pipeline padrão reusável
- **Platform as a Product** = Platform Team trabalha como um time de produto
- **Team Topologies** = como organizar times para escalar
- **DORA Metrics** = como medir sucesso
- **GitOps** = infraestrutura como código, git é source of truth

### 🛠️ Tecnologias
- **Kubernetes** (orquestração de containers)
- **Helm** (package manager para K8s)
- **MongoDB** (catálogo central)
- **GitHub Actions** (CI/CD)
- **ArgoCD** (GitOps deploy)
- **Python** (CLI e scripting)
- **Terraform** (infraestrutura como código)
- **Docker** (containerização)

### 📊 Arquitetura
- Como estruturar um catálogo central
- Como fazer pipeline reutilizável
- Como escalar de 1 serviço → 100 serviços
- Como integrar observabilidade
- Como integrar IA para validação

### 🎓 Melhores Práticas
- Segregação de ambientes (dev/staging/prod)
- RBAC (quem pode fazer o quê)
- Secrets management
- Audit trail
- Cost tracking por serviço
- On-call automation

---

## 🚀 Cronograma Sugerido

```
SEMANA 1 (agora):
  Dia 1: Lê documentação (hoje, 2h)
  Dia 2-3: Fase 1 — Infra base (Kind + MongoDB + CLI)
  Dia 4-5: Fase 1 — GitHub Actions

SEMANA 2:
  Dia 1-2: Fase 2 — Golden Path (.NET workflow)
  Dia 3-4: Fase 3 — Multi-stack (Go, Python, Node, React, Batch)

SEMANA 3:
  Dia 1-2: Fase 4 — Self-service portal
  Dia 3-4: Fase 5 — IA & observabilidade

DEPOIS:
  Fine-tuning, performance, cost optimization
  Integração com Backstage (opcional)
  Multi-cloud (AWS + Azure)
  Disaster recovery
```

---

## 💡 Perguntas Frequentes

### P: Isso é robusto o suficiente para produção?
**R**: Sim! O padrão que você construir é usado por Spotify, Netflix, Google, Uber.
A única diferença é escala. Para começar, você terá 5-10 serviços. Depois escala para 100+.

### P: Preciso de uma equipe dedicada?
**R**: Para começar, você sozinho consegue fazer.
Depois, recomenda-se: 1 Platform Engineer + 1 DevOps (2-3 pessoas minimum).
A visão é que isso se torne um time dedicado (Platform Team).

### P: E se tiver 100 serviços?
**R**: MongoDB roda bem com 1000+ serviços. Em produção, você terá:
- 1 Platform Team (4-8 pessoas)
- 10-20 Stream-Aligned Teams (cada uma responsável por seus serviços)
- 1 Enabling Team (temporária, coaching)
- 1 SRE Team (on-call, observabilidade)

### P: Quando adiciono IA?
**R**: Fase 5. Depois que tudo estiver rodando. IA é "nice to have", não é core.

### P: Vale a pena investir tempo nisso?
**R**: SIM! Maior ROI possível:
- Antes: 1 deploy/mês, lead time 2 semanas, MTTR 1-2 dias
- Depois: múltiplos deploys/dia, lead time < 1 hora, MTTR < 30 min
- Ganho: velocidade de negócio, confiança em deploy, reduz estresse on-call

---

## 🎓 Recursos Extras (Leitura/Referência)

### Livros
- **Team Topologies** (Skelton, Pais) — o livro que define como organizar times
- **The DevOps Handbook** (Gene Kim) — practical DevOps patterns
- **Accelerate** (Nicole Forsgren) — DORA metrics (baseado em pesquisa)
- **Site Reliability Engineering** (Google) — SRE principles

### Artigos
- [Spotify Engineering Culture](https://engineering.atspotify.com/)
- [Golden Path — Spotify](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/)
- [Platform Engineering — Gartner](https://www.gartner.com/en/articles/platform-engineering)
- [Internal Developer Platforms — Martin Fowler](https://martinfowler.com/articles/internal-developer-platform.html)

### Comunidades
- [Platform Engineering.org](https://platformengineering.org/)
- [Internal Developer Platform.org](https://internaldeveloperplatform.org/)
- [CNCF Landscape](https://landscape.cncf.io/) — ferramentas open source

---

## ✋ Próximo Passo: Confirmar Visão

Antes de começar a Fase 1 (código), quero confirmar:

### Decisões

1. **Nome do projeto**: `idp-platform` ou usar `k8s-helm-argo-lab`?
2. **Repositório**: novo repo ou neste mesmo?
3. **Ambientes iniciais**: dev/staging/prod?
4. **Tecnologias preferidas** para aplicações de exemplo?
   - Backend: .NET, Go, Python, Node?
   - Frontend: React, Vue, Angular?

### Confirmação

- [ ] Entendeu a visão?
- [ ] Leu a documentação?
- [ ] Pronto para começar Fase 1?

Responda aí, daí a gente começa a codar de verdade! 🚀

---

**Last Updated**: 21 de maio de 2026  
**Status**: Ready to Start Phase 1
