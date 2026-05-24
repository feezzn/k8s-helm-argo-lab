# Team Topologies para IDP

> Baseado no livro "Team Topologies" de Matthew Skelton e Manuel Pais.
> Objetivo: definir estrutura de times para que o IDP funcione bem.

---

## O Problema: Microserviços sem Topologia = Caos

Muitas empresas adotam microserviços mas mantêm estrutura de times antiga (por camada ou tecnologia).

```
Estrutura Antiga (anti-pattern)
├─ Time "Backend" (12 pessoas)
├─ Time "Frontend" (8 pessoas)
├─ Time "DevOps" (4 pessoas — gargalo!)
├─ Time "QA" (5 pessoas)
└─ Time "DBA" (2 pessoas)

Resultado:
  - "DevOps" é gargalo: toda mudança infra passa por eles
  - Frontend faz deploy esperando Backend
  - Ninguém sabe quem é dono de qual serviço
  - Deploy leva 2 meses (passa por 5 times)
  - MTTR é impossível (quem resolve o incidente?)
  - Comunicação: 100+ daily standups

Exemplo: Spotify, Netflix, Google (tudo em 2007 era assim)
```

---

## As 4 Topologias Fundamentais

### 1️⃣  **Stream-Aligned Team** (O Time de Produto)

**Definição**: Time responsável por END-TO-END de uma capability do negócio.

```
┌────────────────────────────────────┐
│  Stream-Aligned: "Payments Squad"  │
│                                    │
│  Responsável por:                  │
│  ├─ Payment API (.NET)             │
│  ├─ Payment Dashboard (React)      │
│  ├─ Billing Notification (Python)  │
│  ├─ Database schema                │
│  ├─ Observability (Grafana board)  │
│  ├─ On-call (eles resolvem) [!!]   │
│  └─ Deploy (eles fazem)            │
│                                    │
│  Time: 6-9 pessoas (Amazon rule)   │
│  - 2 Backend devs                  │
│  - 1 Frontend dev                  │
│  - 1 QA                            │
│  - 1 Platform Engineer (embedded)  │
│  - Tech Lead                       │
└────────────────────────────────────┘
```

**Autonomia**: ALTA
- Escolhem a tecnologia (com restrições da Platform Team)
- Fazem deploy quando quiserem (sem esperar DevOps)
- Resolvem próprios incidentes (SLA de MTTR é deles)

**Comunicação**: Síncrona dentro do time, assíncrona com outros times

**Exemplo de contato com Platform Team**:
```
Payments Squad quer adicionar nova fila RabbitMQ
  ↓
Criam issue: "Add RabbitMQ operator to K8s"
  ↓
Platform Team agenda semanal: "tá bom, próximo sprint"
  ↓
Platform Team faz, notifica: "ready to use"
  ↓
Payments Squad usa — sem bloquear
```

---

### 2️⃣  **Platform Team** (O IDP que você está construindo)

**Definição**: Time responsável por ferramentas, pipelines, e infraestrutura que permite Stream-Aligned Teams serem autônomas.

```
┌──────────────────────────────────────┐
│  Platform Team: "Platform Eng"       │
│                                      │
│  Responsável por:                    │
│  ├─ IDP (CLI + MongoDB)              │
│  ├─ Golden Paths (workflows)         │
│  ├─ Helm charts                      │
│  ├─ Kubernetes clusters              │
│  ├─ CI/CD infrastructure             │
│  ├─ Secrets management               │
│  ├─ Observability (Prometheus setup) │
│  ├─ Onboarding de novos times        │
│  └─ Documentação & training          │
│                                      │
│  Time: 4-8 pessoas                   │
│  - 2 Platform Engineers              │
│  - 1 DevOps/SRE                      │
│  - 1 Platform Architect              │
│  - Tech Lead                         │
└──────────────────────────────────────┘
```

**Autonomia**: ALTA (serve os times, não é subordinado a eles)

**Métricas de sucesso da Platform Team**:
- DORA metrics dos times estão subindo? ✅ = sucesso
- Lead time para deploy < 1 hora? ✅
- Novo time consegue fazer deploy em < 2 horas? ✅
- % de deploys automáticos = 100%? ✅
- MTTR dos times < 1 hora? ✅

**NÃO faz**:
- ❌ Deploy de aplicações (Stream-Aligned teams fazem)
- ❌ Resolver bugs de negócio (Squad faz)
- ❌ Suporte 24/7 de serviços (Squad em on-call)

**Exemplo de Request do Payments Squad**:
```
Issue: "Deploy tá lento, leva 40 min"
  ↓
Platform Team analisa: "problema é no registry ECR"
  ↓
Platform Team cria issue interna: "Optimize ECR pull @ K8s"
  ↓
Platform Team resolve: cache local, agora é 5 min
  ↓
Todos os times se beneficiam (não é só Payments!)
```

---

### 3️⃣  **Enabling Team** (O Coach)

**Definição**: Time que ajuda Stream-Aligned teams a adotar novas tecnologias/práticas. Tem prazo curto (3-6 meses).

```
┌──────────────────────────────────────┐
│  Enabling Team: "Cloud Enablement"   │
│                                      │
│  Responsável por:                    │
│  ├─ Treinar em Go (novo na empresa)  │
│  ├─ Migrar monolito → microserviços  │
│  ├─ Adotar Kubernetes                │
│  ├─ Implementar observabilidade      │
│  ├─ Security best practices          │
│  └─ Internal training + workshops    │
│                                      │
│  Time: 2-4 pessoas (temporário!)     │
│  - 1 Go expert (3 meses)             │
│  - 1 Kubernetes coach (2 meses)      │
│  - 1 Observability expert (ongoing)  │
└──────────────────────────────────────┘

IMPORTANTE: Enabling team tem END DATE!
Depois que disseminarem o conhecimento, dissolvem.
```

**Autonomia**: MÉDIA (tem agenda própria + serve os times)

**NÃO vira suporte de longo prazo**:
```
❌ ERRADO: Enabling Team faz observabilidade para todos os times
✅ CORRETO: Enabling Team treina times a fazer observabilidade, depois sai

Caso contrário vira um Time Complicado Subsystem (veja item 4)
```

---

### 4️⃣  **Complicated Subsystem Team** (O Especialista)

**Definição**: Time responsável por subsistema complexo que requer expertise concentrada. Pode ser permanente.

```
┌──────────────────────────────────────┐
│  Complicated Subsystem: "ML Infra"   │
│                                      │
│  Responsável por:                    │
│  ├─ ML model training pipelines      │
│  ├─ Feature store                    │
│  ├─ Model serving (Seldon, KServe)   │
│  ├─ Model monitoring & retraining    │
│  └─ Support para Data Science times  │
│                                      │
│  Time: 3-5 pessoas (pode ser perm.)  │
│  - 1 ML Engineer                     │
│  - 1 Data Engineer                   │
│  - 1 SRE/DevOps                      │
└──────────────────────────────────────┘

IMPORTANTE: Separado por COMPLEXIDADE TÉCNICA, não por camada!
Exemplo: não é "Database Team", é "Time de Machine Learning"
```

**Comunicação com Stream-Aligned teams**: Assíncrona (API clara, documentada)

---

## Os 3 Modos de Interação

Essencial para não criar caos de comunicação:

### 1. **Collaboration** (Trabalham juntos)
```
Quando: resolvendo problema novo, sem precedente
Padrão: daily sync, shared workspace, tight feedback loop

Exemplo:
  Payments Squad + Platform Team
  Objetivo: "integrar fila de mensagens"
  Modo: Collaboration (1-2 sprints)
  Resultado: padrão estabelecido, todos aprendem
  Próximas squads: X-as-a-Service (não é collaboration mais)
```

### 2. **X-as-a-Service** (Contrato claro)
```
Quando: serviço maduro, interface estável, sem mudanças
Padrão: documentação, SLA, request/response assíncrono

Exemplo:
  Payments Squad usa "Helm Charts as a Service"
  Interface: catalog chart values <service> > values.yaml
  SLA: Platform Team responde issues em < 24h
  Comunicação: Slack #platform-engineering
```

### 3. **Facilitating** (Coaching, suporte)
```
Quando: Enabling Team treinando um time novo
Padrão: workshops, pair programming, feedback loop rápido

Exemplo:
  Enabling Team + New Go Team
  Objetivo: "implementar first Go service"
  Modo: Facilitating (1 mês)
  Resultado: team consegue sozinho
  Depois: X-as-a-Service (Platform Team)
```

---

## Aplicação: Seu IDP na BMG (ou Nova Empresa)

### Estrutura Proposta para BMG

```
┌─────────────────────────────────────────────────────────┐
│             DIRETOR DE ENGENHARIA                        │
└─────────────────────────────────────────────────────────┘
              ↓
    ┌─────────────────────────────────────────────┐
    │  PLATAFORMA & INFRAESTRUTURA (8 pessoas)   │
    └─────────────────────────────────────────────┘
              ↓
    ┌──────────────┬──────────────┬──────────────┐
    │              │              │              │
    v              v              v              v
┌────────┐  ┌────────┐  ┌─────────┐  ┌──────────┐
│Platform│  │Platform│  │Enabling │  │  SRE    │
│ Eng #1 │  │ Eng #2 │  │ Team    │  │ Team    │
└────────┘  └────────┘  └─────────┘  └──────────┘
    (IDP)      (IDP)      (Training)   (On-call)


┌──────────────────────────────────────────────────┐
│         SQUADS DE NEGÓCIO (múltiplos)           │
└──────────────────────────────────────────────────┘
    ↓                ↓                ↓
┌────────────┐ ┌────────────┐ ┌────────────┐
│  Payments  │ │   Orders   │ │    Auth    │
│  6-8 ppl   │ │  6-8 ppl   │ │  6-8 ppl   │
│            │ │            │ │            │
│ .NET API   │ │ Go Service │ │ Python API │
│ React UI   │ │ K8s Ingress│ │ Redis      │
│ Postgres   │ │ ...        │ │ ...        │
└────────────┘ └────────────┘ └────────────┘

Modo: Stream-Aligned Teams
  - Deploy próprio
  - On-call próprio
  - Autonomia: ALTA
  - Dependência: BAIXA (exceto com Platform Team)
```

---

## Exemplo de Fluxo: Novo Squad Onboarding

```
DIA 1: Squad "Notifications" é criado (6 pessoas)
  └─ Enabling Team: "bem-vindo, vocês vão usar nosso IDP"

DIA 2: Enabling Team + Notifications Squad → Collaboration
  ├─ Workshop: "CLI commands" (30 min)
  ├─ Pair programming: "first service registration" (1h)
  ├─ Q&A: como funciona golden path (30 min)
  └─ Assignments: "vocês que fazem agora, a gente assiste"

DIA 3: Notifications Squad sozinhos → Facilitating
  ├─ Criam repo novo
  ├─ Registram no catálogo (catalog servicos add ...)
  ├─ Push → GitHub Actions
  └─ Slack: "Deploy successful! Check logs:"

SEMANA 2: X-as-a-Service
  ├─ Notifications Squad usa platform como black box
  ├─ Documentação é source of truth
  ├─ Issues: async no GitHub (não é sync anymore)
  └─ Enabling Team → Next squad onboarding

RESULTADO:
  ✓ Novo squad faz deploy no dia 1
  ✓ Platform Team não é gargalo
  ✓ DORA metrics: lead time < 2 horas (desde dia 1!)
```

---

## Anti-Patterns: O Que NÃO Fazer

### ❌ Anti-Pattern 1: Pedir Permission (DRI quebrado)

```
ERRADO:
  Payments Squad quer fazer deploy
    → pede permission ao Platform Team
    → Platform Team libera (ou nega)
    → Squad faz deploy

RESULTADO:
  - Platform Team é gargalo
  - MTTR ruim (squad espera platform)
  - Lead time alto

CORRETO:
  Payments Squad faz deploy (eles têm autorização)
    → Platform Team monitora (observabilidade) mas não interfere
    → Problema? Squad resolve (on-call deles)
```

### ❌ Anti-Pattern 2: Comunicação Transversal Excessiva

```
ERRADO:
  Squad A fala com Squad B com Squad C com Platform Team
  todos os dias, múltiplas sync calls
    → Comunicação = 40% do tempo dos devs
    → Decisões lentas
    → Caos

CORRETO:
  Squad A → Platform Team (contrato)
  Squad B → Platform Team (contrato)
  Squad C → Platform Team (contrato)
  
  Squads precisam falar? RFC no GitHub (assíncrono)
  Platform Team coordena (1x/semana max)
```

### ❌ Anti-Pattern 3: Enabling Team Virou Suporte

```
ERRADO:
  Enabling Team treinou todos em Go
  Agora: Go Squad faz issue, pede Enabling Team resolver
    → Enabling Team virou suporte permanente
    → Nunca saem (viram Complicated Subsystem sem avisar)

CORRETO:
  Enabling Team treina em Go
  Go Squad aprende tudo
  Enabling Team SAI (documentação é source of truth)
  Go Squad sozinhos:
    - Issues: resolvem
    - Help: vem de outro dev senior em Go, não de Enabling Team
```

---

## Checklist: Implementando Team Topologies no IDP

```
[ ] FASE 1: Definir Stream-Aligned Teams
    ├─ [ ] Identificar capabilities do negócio
    ├─ [ ] Mapear cada squad (quem, onde, qual capability)
    ├─ [ ] Documentar DRI (directly responsible individual) de cada squad
    └─ [ ] Definir on-call rotation (squad resolve próprios incidentes)

[ ] FASE 2: Criar Platform Team
    ├─ [ ] Montar time (idealmente 4-8 pessoas)
    ├─ [ ] Definir charter (o que fazem, o que não fazem)
    ├─ [ ] Criar roadmap (IDP roadmap, não roadmap de negócio)
    └─ [ ] Setup SLA (Platform Team responde issues em < 24h)

[ ] FASE 3: Estabelecer Enabling Team (temporária)
    ├─ [ ] Selecionar expertise needed (Go? K8s? Observability?)
    ├─ [ ] Definir duration (3-6 meses)
    ├─ [ ] Planejar training (workshops, documentation, pair prog)
    └─ [ ] Exit plan (como transicionar para X-as-a-Service)

[ ] FASE 4: Documentar Interação Modes
    ├─ [ ] Criar guia: "quando é Collaboration"
    ├─ [ ] Criar guia: "quando é X-as-a-Service"
    ├─ [ ] Criar guia: "quando é Facilitating"
    └─ [ ] Comunicar para todos os times

[ ] FASE 5: Medir Sucesso
    ├─ [ ] Dashboard: DORA metrics (deploy frequency, lead time, MTTR, CFR)
    ├─ [ ] Survey: "quão autônomo você sente seu squad?"
    ├─ [ ] On-call: "MTTR está caindo?"
    └─ [ ] Satisfação: "Platform Team é gargalo ou helper?"

```

---

## Recursos Adicionais

- **Team Topologies book**: https://teamtopologies.com/
- **Spotify Model** (base do conceito): https://engineering.atspotify.com/2014/03/spotify-engineering-culture-part-1/
- **Amazon: Two Pizza Rule**: https://rf.readthedocs.io/en/latest/5_designing_your_system/two_pizza_team.html
- **Google: SRE Book (Team Structure)**: https://sre.google/books/
- **Netflix: Freedom & Responsibility**: https://jobs.netflix.com/culture

---

**Last Updated**: 21 de maio de 2026
