# IDP Platform — Internal Developer Platform

> Projeto pessoal de estudo baseado no padrão de grandes empresas (Netflix, Spotify, Nubank).
> Objetivo: criar uma plataforma que permite qualquer dev fazer deploy de uma aplicação sem saber nada sobre AWS, Kubernetes ou Helm — só fazendo commit.

---

## O que você vai construir

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER EXPERIENCE                      │
│                                                             │
│  git push → pipeline lê o catálogo → deploy automático     │
│  Dev não precisa saber: AWS, EKS, Helm, Kubernetes          │
└─────────────────────────────────────────────────────────────┘

Componentes:
  1. catalog-cli     → CLI Python que lê/escreve no MongoDB
  2. platform-infra  → Terraform: MongoDB Atlas, GitHub repos, ECR
  3. platform-charts → Helm charts genéricos por tipo de app
  4. platform-workflows → GitHub Actions reusáveis (o "pipeline padrão")
```

---

## Arquitetura

```
                   ┌──────────────────────────────────┐
                   │          MongoDB Atlas             │
                   │  (catálogo de serviços + configs) │
                   └──────────────┬───────────────────┘
                                  │
                          ┌───────▼──────┐
                          │  catalog-cli  │  ← pip install
                          │  (Python CLI) │
                          └───────┬──────┘
                                  │ chamada pelos pipelines
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
┌────────▼────────┐    ┌──────────▼──────────┐   ┌────────▼──────┐
│  reusable-      │    │   onboard-service    │   │  rollback /   │
│  deploy.yml     │    │   (cadastra no Mongo)│   │  notify       │
│  (GitHub Actions│    └─────────────────────┘   └───────────────┘
│   reutilizável) │
└────────┬────────┘
         │
┌────────▼────────────────────────────────────────┐
│               Helm Deploy no K8s                 │
│  (usa chart genérico + values gerados pelo CLI) │
└─────────────────────────────────────────────────┘
```

---

## Modelo de dados (o mais importante — defina isso primeiro)

O MongoDB armazena um documento por serviço. Abaixo está o **schema real** observado em produção num IDP bancário — duas entradas reais para referência:

```json
// Serviço .NET (worker/consumer)
{
  "_id":              "afra-events-alteracao-cadastral-consumer",
  "nome":             "afra-events-alteracao-cadastral-consumer",
  "id_aplicacao":     "afra",      // sigla do time/squad
  "id_capacidade":    "onr",       // domínio de negócio
  "type":             "dotnet",
  "dotnet_version":   "8",
  "dotnet_template":  "Bmg.Template.Net.ConsumerService",  // template de projeto
  "path_solution":    "Bmg.EventsAlteracaoCadastral.sln",
  "path_project":     "Adapters/Driving/Services/Bmg.EventsAlteracaoCadastral.ConsumerService/",
  "variables": {
    "quality_approvers":     "True",
    "quality_approvers_hml": "True"
  }
}

// Serviço Frontend
{
  "_id":           "cnib-shared-ib-front",
  "nome":          "cnib-shared-ib-front",
  "id_aplicacao":  "cnib",
  "id_capacidade": "dir",
  "type":          "front",
  "version":       "20",           // versão do Node
  "variables": {
    "quality_approvers":     "True",
    "quality_approvers_hml": "True"
  }
}
```

### São 3 coleções no MongoDB — e cada uma tem um dono diferente

```
┌─────────────────────────────────────────────────────────────────────────┐
│  collection: aplicacoes          (cadastrado pela equipe de plataforma) │
│                                                                         │
│  { _id: "acaf",                                                         │
│    id_capacidade: "aca",                                                │
│    nome: "Fator Autenticação Interface Otp" }                           │
│                                                                         │
│  → mapeia sigla curta → nome do squad/aplicação                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  collection: configuracoes       (cadastrado pela equipe de infra/cloud)│
│                                                                         │
│  { _id: "prb",                                                          │
│    ambientes: {                                                         │
│      hml: { aws_account: "120586588729",                                │
│             aws_region:  "us-east-2",                                   │
│             eks_cluster: "bmg-prb-eks-hml" },                          │
│      uat: { aws_account: "804811132013",                                │
│             aws_region:  "us-east-2",                                   │
│             eks_cluster: "bmg-prb-eks-uat" },                          │
│      prd: { aws_account: "272578032931",                                │
│             aws_region:  "sa-east-1",                                   │
│             eks_cluster: "bmg-prb-eks-prd" }                           │
│    }                                                                    │
│  }                                                                      │
│                                                                         │
│  → mapeia id_capacidade + ambiente → AWS account + region + EKS        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  collection: servicos            (cadastrado pelo dev / tech lead)      │
│                                                                         │
│  { _id: "afra-events-alteracao-cadastral-consumer",                     │
│    id_aplicacao:  "afra",   ──→ lookup em aplicacoes                   │
│    id_capacidade: "onr",    ──→ lookup em configuracoes                 │
│    type:          "dotnet",                                             │
│    ... }                                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### A ordem de criação (quem cria o quê e quando)

```
ETAPA 1 — Acontece UMA VEZ por domínio (feito pela equipe de Cloud/Infra)
  │
  ├─ Cria as contas AWS (hml / uat / prd) → processo manual ou IaC
  ├─ Provisiona o cluster EKS em cada conta
  └─ Roda o pipeline  azure_pipeline_add_configuracao
         catalog configuracoes add "prb" hml "1205..." "us-east-2" "bmg-prb-eks-hml"
         catalog configuracoes add "prb" uat "8048..." "us-east-2" "bmg-prb-eks-uat"
         catalog configuracoes add "prb" prd "2725..." "sa-east-1" "bmg-prb-eks-prd"
         → registra no MongoDB: id_capacidade + ambientes


ETAPA 2 — Acontece UMA VEZ por squad (feito pela plataforma no onboarding)
  │
  └─ Roda o pipeline  azure_pipeline_add_servico (ou equivalente)
         catalog aplicacoes add "acaf" "aca" "Fator Autenticação Interface Otp"
         → registra no MongoDB: id_aplicacao → nome


ETAPA 3 — Acontece CADA VEZ que um novo serviço nasce (feito pelo dev/tech lead)
  │
  ├─ Cria o repo no Azure DevOps / GitHub (via Terraform)
  └─ Roda o pipeline  azure_pipeline_add_servico
         catalog servicos add "meu-servico" "acaf" "dotnet" ...
         → registra no MongoDB: serviço → id_aplicacao + id_capacidade


ETAPA 4 — Acontece em CADA COMMIT (automático, zero intervenção humana)
  │
  └─ Pipeline lê o MongoDB:
       servico["id_capacidade"] = "prb"
                 ↓  lookup
       configuracoes["prb"]["prd"] = { account: "2725...", eks: "bmg-prb-eks-prd" }
                 ↓
       helm upgrade ... --set image.tag=v1.2.3
```

### Por que esse modelo é elegante

| Campo | O que resolve |
|---|---|
| `id_aplicacao` | Determina qual AWS service connection usar (por squad) |
| `id_capacidade` | Chave de lookup nas `configuracoes` → traz account/region/EKS |
| `type` | Determina qual pipeline template rodar (`dotnet`, `front`, `python-fastapi`...) |
| `dotnet_version` / `version` | Determina qual agent pool usar (ex: pool com .NET 10 separado) |
| `dotnet_template` | O template de projeto que foi usado — útil para validação e scaffolding |
| `path_solution` / `path_project` | O pipeline não precisa de parâmetro — ele lê daqui |
| `variables` | Feature flags e configs por serviço (ex: exige quality approvers ou não) |

**O grande benefício da separação em 3 coleções:** se o cluster EKS da capacidade `prb` migrar de `us-east-2` para `sa-east-1`, você atualiza **um documento** na coleção `configuracoes` e todos os ~N serviços daquela capacidade pegam o update automaticamente. Sem tocar em pipeline nenhum.

> **Por que MongoDB?** Schema flexível — cada `type` pode ter campos extras sem migração. `dotnet` tem `dotnet_template`, `front` tem `version` Node, `python` teria `python_version`. SQL exigiria ALTER TABLE para cada variação.

---

## Estrutura de repositórios

```
github.com/seu-usuario/
├── catalog-cli/              ← CLI Python (o coração)
├── platform-charts/          ← Helm charts genéricos
├── platform-workflows/       ← GitHub Actions reutilizáveis
├── platform-infra/           ← Terraform
│
└── (repos das aplicações)
    ├── meu-servico-api/      ← só tem .github/workflows/deploy.yml (3 linhas)
    └── outro-servico/
```

---

## Roadmap de implementação

### Fase 1 — Fundação (Semana 1-2)

- [ ] Subir MongoDB Atlas (free tier: https://cloud.mongodb.com)
- [ ] Criar repo `catalog-cli` e estrutura Python básica
- [ ] Implementar `catalog get` e `catalog add` (CRUD no Mongo)
- [ ] Publicar no GitHub Packages como pacote pip privado
- [ ] Testar localmente: `pip install catalog-cli` + `catalog add meu-servico`

### Fase 2 — Pipeline (Semana 3-4)

- [ ] Criar repo `platform-workflows`
- [ ] Implementar `reusable-deploy.yml` básico (build Docker + push + deploy k8s)
- [ ] Criar uma aplicação de teste que use o workflow reutilizável
- [ ] Validar que o deploy acontece só com `git push`

### Fase 3 — Helm (Semana 5-6)

- [ ] Criar repo `platform-charts` com chart genérico para apps web
- [ ] CLI gera `values.yaml` dinamicamente a partir do catálogo
- [ ] Pipeline passa `values.yaml` gerado para o `helm upgrade`

### Fase 4 — Qualidade de vida (Mês 2+)

- [ ] Gate de aprovação manual para production (GitHub Environments)
- [ ] Rollback automático em caso de falha no deploy
- [ ] Notificação no Slack/Discord
- [ ] `catalog list` — listar todos os serviços cadastrados
- [ ] `catalog validate` — validar repo antes do deploy (estrutura, Dockerfile, etc.)
- [ ] CLI vira um container Docker (não precisa instalar Python no agente)

---

## Setup local (para desenvolver a CLI)

### Pré-requisitos

```bash
# ferramentas necessárias
brew install python@3.11 helm kubectl k3d

# subir k8s local com k3d (3 nodes, simula staging + production)
k3d cluster create idp-local \
  --servers 1 \
  --agents 2 \
  --port "8080:80@loadbalancer"

kubectl get nodes  # deve mostrar 3 nodes
```

### Clonar e rodar a CLI localmente

```bash
git clone https://github.com/seu-usuario/catalog-cli
cd catalog-cli

python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install -e ".[dev]"     # instala em modo editable

# configurar conexão com MongoDB
export CATALOG_MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/catalog"

# testar
catalog --help
catalog add meu-servico meu-time python-fastapi
catalog get meu-servico
```

---

## Implementação da CLI (catalog-cli)

### Estrutura do projeto

```
catalog-cli/
├── src/
│   └── catalog/
│       ├── __init__.py
│       ├── cli.py              ← entry point do Click
│       ├── commands/
│       │   ├── catalog.py      ← catalog add / get / list
│       │   ├── chart.py        ← chart values (gera Helm values.yaml)
│       │   └── validator.py    ← validate (valida repo + exporta vars)
│       ├── db/
│       │   └── mongodb.py      ← conexão e queries
│       └── models/
│           └── service.py      ← dataclass do serviço
├── tests/
├── pyproject.toml
└── Dockerfile
```

### `pyproject.toml`

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "catalog-cli"
version = "0.1.0"
dependencies = [
    "click>=8.0",
    "pymongo[srv]>=4.0",
    "pyyaml>=6.0",
    "boto3>=1.26",        # se usar AWS
    "rich>=13.0",         # output bonito no terminal
]

[project.optional-dependencies]
dev = ["pytest", "pytest-mock", "mongomock"]

[project.scripts]
catalog = "catalog.cli:cli"
```

### `src/catalog/cli.py`

```python
import click
from catalog.commands import catalog, chart, validator

@click.group()
@click.version_option()
def cli():
    """IDP Catalog CLI — gerencia serviços e gera configs de deploy."""
    pass

cli.add_command(catalog.catalog_group, name="catalog")
cli.add_command(chart.chart_group,   name="chart")
cli.add_command(validator.validate,  name="validate")
```

### `src/catalog/commands/catalog.py`

```python
import click
import json
from catalog.db.mongodb import get_db

@click.group("catalog")
def catalog_group():
    """Gerencia o catálogo de serviços."""
    pass

@catalog_group.command("add")
@click.argument("name")
@click.argument("project")
@click.argument("type", type=click.Choice(["python-fastapi", "dotnet", "java", "node"]))
@click.option("--version", default="latest")
def add(name, project, type, version):
    """Cadastra ou atualiza um serviço no catálogo."""
    db = get_db()
    db.services.update_one(
        {"name": name},
        {"$set": {"name": name, "project": project, "type": type, "version": version}},
        upsert=True
    )
    click.echo(f"✅ Serviço '{name}' cadastrado com sucesso.")

@catalog_group.command("get")
@click.argument("name")
@click.option("--output-vars", is_flag=True, help="Exporta variáveis para o pipeline")
def get(name, output_vars):
    """Lê dados de um serviço do catálogo."""
    db = get_db()
    svc = db.services.find_one({"name": name}, {"_id": 0})
    if not svc:
        raise click.ClickException(f"Serviço '{name}' não encontrado no catálogo.")

    if output_vars:
        # GitHub Actions: escreve no $GITHUB_OUTPUT
        # Azure DevOps:   usa ##vso[task.setvariable ...]
        _export_vars(svc)
    else:
        click.echo(json.dumps(svc, indent=2, default=str))

def _export_vars(data: dict, prefix="CATALOG"):
    """Flatten dict e exporta como variáveis de ambiente do pipeline."""
    import os
    github_output = os.environ.get("GITHUB_OUTPUT")

    for key, value in _flatten(data).items():
        var_name = f"{prefix}_{key}".upper().replace(".", "_").replace("-", "_")
        if github_output:
            with open(github_output, "a") as f:
                f.write(f"{var_name}={value}\n")
        else:
            # fallback: Azure DevOps
            print(f"##vso[task.setvariable variable={var_name};isoutput=true]{value}")

def _flatten(d: dict, parent_key="", sep="_") -> dict:
    items = {}
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.update(_flatten(v, new_key, sep=sep))
        else:
            items[new_key] = v
    return items
```

### `src/catalog/commands/chart.py`

```python
import click
import yaml
from catalog.db.mongodb import get_db

@click.group("chart")
def chart_group():
    """Gera configurações de Helm a partir do catálogo."""
    pass

@chart_group.command("values")
@click.argument("service_name")
@click.option("--env", default=None, help="Ambiente (staging, production)")
def values(service_name, env):
    """Gera values.yaml do Helm para o serviço."""
    db = get_db()
    svc = db.services.find_one({"name": service_name}, {"_id": 0})
    if not svc:
        raise click.ClickException(f"Serviço '{service_name}' não encontrado.")

    result = {}
    
    # valores globais do serviço
    result.update(svc.get("helm_values", {}))
    
    # override por ambiente
    if env:
        env_config = svc.get("environments", {}).get(env, {})
        result["replicas"]  = env_config.get("replicas", 1)
        result["namespace"] = env_config.get("namespace", svc["project"])
        
        env_values = svc.get("helm_values_override", {}).get(env, {})
        result.update(env_values)

    click.echo(yaml.dump(result, default_flow_style=False))
```

### `src/catalog/db/mongodb.py`

```python
import os
import pymongo
from functools import lru_cache

@lru_cache(maxsize=1)
def get_db():
    uri = os.environ.get("CATALOG_MONGO_URI")
    if not uri:
        raise RuntimeError("CATALOG_MONGO_URI não configurada.")
    client = pymongo.MongoClient(uri)
    return client["catalog"]
```

---

## Platform Workflows (GitHub Actions reutilizáveis)

### `platform-workflows/.github/workflows/reusable-deploy.yml`

```yaml
# Workflow reutilizável — fica num repo central
# Aplicações chamam com: uses: seu-usuario/platform-workflows/.github/workflows/reusable-deploy.yml@main

on:
  workflow_call:
    inputs:
      service_name:
        description: "Nome do serviço no catálogo"
        required: false
        type: string
        default: ${{ github.event.repository.name }}
    secrets:
      CATALOG_MONGO_URI:
        required: true
      K8S_CONFIG:
        required: true

jobs:
  # ─── ETAPA 1: Lê o catálogo e determina o ambiente ───────────────────────
  validate:
    runs-on: ubuntu-latest
    outputs:
      environment:  ${{ steps.catalog.outputs.CATALOG_ENVIRONMENT }}
      k8s_cluster:  ${{ steps.catalog.outputs.CATALOG_ENVIRONMENTS_K8S_CLUSTER }}
      namespace:    ${{ steps.catalog.outputs.CATALOG_ENVIRONMENTS_NAMESPACE }}
      service_type: ${{ steps.catalog.outputs.CATALOG_TYPE }}
    steps:
      - name: Install catalog-cli
        run: pip install catalog-cli --index-url ${{ vars.PYPI_URL || 'https://pypi.org/simple' }}

      - name: Read catalog
        id: catalog
        env:
          CATALOG_MONGO_URI: ${{ secrets.CATALOG_MONGO_URI }}
        run: |
          # Define o ambiente pela branch
          if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
            ENV=production
          else
            ENV=staging
          fi
          echo "CATALOG_ENVIRONMENT=$ENV" >> $GITHUB_OUTPUT
          
          # Lê o serviço do catálogo e exporta todas as variáveis
          catalog catalog get ${{ inputs.service_name }} \
            --output-vars

  # ─── ETAPA 2: Build e push da imagem Docker ───────────────────────────────
  build:
    needs: validate
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=,format=short
            type=ref,event=branch

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  # ─── ETAPA 3: Deploy (com gate de aprovação para production) ─────────────
  deploy:
    needs: [validate, build]
    runs-on: ubuntu-latest
    # environments no GitHub = gate de aprovação manual para production
    environment: ${{ needs.validate.outputs.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: Generate Helm values
        env:
          CATALOG_MONGO_URI: ${{ secrets.CATALOG_MONGO_URI }}
        run: |
          catalog chart values ${{ inputs.service_name }} > values.yaml
          catalog chart values ${{ inputs.service_name }} \
            --env ${{ needs.validate.outputs.environment }} >> values.yaml
          
          echo "=== values.yaml gerado ==="
          cat values.yaml

      - name: Configure kubectl
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.K8S_CONFIG }}" | base64 -d > ~/.kube/config

      - name: Helm deploy
        run: |
          IMAGE_TAG=$(echo "${{ needs.build.outputs.image_tag }}" | head -1)
          
          helm upgrade --install \
            ${{ inputs.service_name }} \
            ./platform-charts/${{ needs.validate.outputs.service_type }}-chart \
            --namespace ${{ needs.validate.outputs.namespace }} \
            --create-namespace \
            --set image.repository=ghcr.io/${{ github.repository }} \
            --set image.tag=${IMAGE_TAG##*:} \
            --values values.yaml \
            --wait \
            --timeout 5m

      - name: Verify deploy
        run: |
          kubectl rollout status deployment/${{ inputs.service_name }} \
            -n ${{ needs.validate.outputs.namespace }} \
            --timeout=5m
```

### Como uma aplicação usa o workflow (3 linhas)

```yaml
# meu-servico-api/.github/workflows/deploy.yml

on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    uses: seu-usuario/platform-workflows/.github/workflows/reusable-deploy.yml@main
    secrets:
      CATALOG_MONGO_URI: ${{ secrets.CATALOG_MONGO_URI }}
      K8S_CONFIG: ${{ secrets.K8S_CONFIG }}
```

---

## Helm Chart genérico (platform-charts)

### `platform-charts/python-fastapi-chart/values.yaml`

```yaml
# valores padrão — sobrescritos pelo catalog-cli
replicaCount: 1

image:
  repository: ""
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8000

ingress:
  enabled: true
  className: "nginx"
  host: ""     # preenchido pelo catalog-cli

resources:
  limits:
    memory: "256Mi"
    cpu: "250m"
  requests:
    memory: "128Mi"
    cpu: "100m"

env: []   # variáveis de ambiente injetadas pelo catalog-cli
```

---

## Testando localmente

```bash
# 1. Subir k8s local
k3d cluster create idp-dev --port "8080:80@loadbalancer"

# 2. Instalar nginx ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/k3d/deploy.yaml

# 3. Cadastrar um serviço no catálogo
export CATALOG_MONGO_URI="mongodb+srv://..."
catalog catalog add minha-api meu-time python-fastapi --version 3.11
catalog catalog get minha-api

# 4. Gerar values.yaml
catalog chart values minha-api --env staging
# → vai imprimir o YAML que seria passado pro Helm

# 5. Deploy manual para testar
catalog chart values minha-api --env staging > /tmp/values.yaml
helm upgrade --install minha-api ./platform-charts/python-fastapi-chart \
  --namespace meu-time-staging \
  --create-namespace \
  --set image.repository=nginx \
  --set image.tag=latest \
  --values /tmp/values.yaml

kubectl get pods -n meu-time-staging
```

---

## Referências

- [Backstage](https://backstage.io) — o IDP open source do Spotify (onde o ASRE se inspira)
- [DORA Metrics](https://dora.dev) — como medir a maturidade do seu platform engineering
- [Platform Engineering](https://platformengineering.org) — comunidade e recursos
- [Click docs](https://click.palletsprojects.com) — biblioteca Python para CLIs
- [Helm docs](https://helm.sh/docs) — Kubernetes package manager
- [k3d](https://k3d.io) — K8s local leve para desenvolvimento
- [MongoDB Atlas](https://cloud.mongodb.com) — free tier permanente (512MB)

---

## Contexto / Inspiração

Este projeto é inspirado num padrão real de plataforma interna de engenharia observado em produção, onde uma CLI Python conectada a um catálogo MongoDB centraliza toda a inteligência de deploy — permitindo que times entreguem em múltiplos ambientes (hml/uat/prd) sem conhecer nada sobre a infraestrutura subjacente.

O padrão é o mesmo do Backstage (Spotify), Runway (Yelp), e plataformas similares:
**"o pipeline é burro, a CLI é inteligente."**
