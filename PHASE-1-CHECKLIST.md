# FASE 1: Setup Inicial (Semana 1)

> Objetivo: ter um Kubernetes funcional + MongoDB + GitHub Actions + CLI básica rodando
> Status: READY TO START
> Estimated Time: 3-4 dias de trabalho

---

## 📋 Checklist Executável

### 1.1 — Preparar Repositório Base

```
[ ] 1.1.1 - Criar novo repo: /home/felipe/Laboratorios/idp-platform
            (ou usar o k8s-helm-argo-lab)

[ ] 1.1.2 - Estrutura inicial de pastas:
            idp-platform/
            ├── .github/workflows/
            ├── catalog-cli/
            ├── helm-charts/
            ├── terraform/
            ├── samples/
            ├── docs/
            ├── scripts/
            └── README.md

[ ] 1.1.3 - Criar README.md principal

[ ] 1.1.4 - Init git, fazer primeiro commit

[ ] 1.1.5 - Criar branches: main, develop, docs
```

**Tempo estimado**: 30 min

---

### 1.2 — Kubernetes Local (Kind)

```
[ ] 1.2.1 - Instalar kind (se não tiver)
            https://kind.sigs.k8s.io/docs/user/quick-start/

            # macOS
            brew install kind
            
            # Linux
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind

            kind --version  # verificar

[ ] 1.2.2 - Criar arquivo: terraform/1-kind-cluster/kind-config.yaml
            
            kind: Cluster
            apiVersion: kind.x-k8s.io/v1alpha4
            name: idp-dev
            nodes:
            - role: control-plane
              extraPortMappings:
              - containerPort: 80
                hostPort: 80
              - containerPort: 443
                hostPort: 443
            - role: worker
            - role: worker

[ ] 1.2.3 - Criar cluster
            kind create cluster --config terraform/1-kind-cluster/kind-config.yaml

[ ] 1.2.4 - Verificar
            kubectl cluster-info
            kubectl get nodes

[ ] 1.2.5 - Setup kubeconfig (se necessário)
            kind get kubeconfig --name idp-dev > ~/.kube/idp-dev.yaml
            export KUBECONFIG=~/.kube/idp-dev.yaml

[ ] 1.2.6 - Verificar novamente
            kubectl get pods --all-namespaces
```

**Tempo estimado**: 20 min
**Recursos**:
- [kind documentation](https://kind.sigs.k8s.io/)
- [kind Multi-node Clusters](https://kind.sigs.k8s.io/docs/user/configuration/)

---

### 1.3 — MongoDB (Helm)

```
[ ] 1.3.1 - Instalar Helm (se não tiver)
            https://helm.sh/docs/intro/install/

            # macOS
            brew install helm

            # Linux
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

            helm version  # verificar

[ ] 1.3.2 - Adicionar repo Bitnami
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update

[ ] 1.3.3 - Criar arquivo: terraform/2-mongodb/values.yaml
            
            auth:
              enabled: true
              rootPassword: "idp-root-password"
              username: "idp-user"
              password: "idp-password"
              database: "idp-catalog"
            
            replicaSet:
              enabled: true
              name: "rs0"
            
            persistence:
              enabled: true
              size: 10Gi
            
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "512Mi"
                cpu: "500m"

[ ] 1.3.4 - Criar namespace
            kubectl create namespace mongodb

[ ] 1.3.5 - Deploy MongoDB
            helm install mongodb bitnami/mongodb \
              --namespace mongodb \
              -f terraform/2-mongodb/values.yaml

[ ] 1.3.6 - Verificar
            kubectl get pods -n mongodb
            kubectl get svc -n mongodb

[ ] 1.3.7 - Esperar até estar Ready (pod status "Running")
            kubectl wait --for=condition=ready pod \
              -l app.kubernetes.io/name=mongodb \
              -n mongodb \
              --timeout=300s

[ ] 1.3.8 - Conectar (obtém mongosh)
            # Port-forward
            kubectl port-forward -n mongodb svc/mongodb 27017:27017 &
            
            # Conectar (em outro terminal)
            mongosh mongodb://idp-user:idp-password@localhost:27017/idp-catalog

            # Verificar (no mongosh)
            > db.version()
            > show databases
            > db.createCollection("test")
            > db.test.insertOne({message: "it works!"})
            > db.test.find()
```

**Tempo estimado**: 30 min
**Recursos**:
- [Bitnami MongoDB Chart](https://github.com/bitnami/charts/tree/main/bitnami/mongodb)
- [MongoDB Connection String](https://www.mongodb.com/docs/manual/reference/connection-string/)

---

### 1.4 — Primeiras Coleções MongoDB

```
[ ] 1.4.1 - Criar script: scripts/setup-mongodb.sh

            #!/bin/bash
            
            MONGO_URI="mongodb://idp-user:idp-password@localhost:27017/idp-catalog"
            
            mongosh "$MONGO_URI" <<EOF
            
            // Coleção 1: Aplicações (squads/times)
            db.createCollection("aplicacoes")
            db.aplicacoes.insertMany([
              {
                "_id": "acaf",
                "id_capacidade": "aca",
                "nome": "Fator Autenticação Interface Otp",
                "squad": "Auth Squad",
                "created_at": new Date()
              },
              {
                "_id": "prb",
                "id_capacidade": "prb",
                "nome": "Payment & Billing",
                "squad": "Payments Squad",
                "created_at": new Date()
              }
            ])
            
            // Coleção 2: Configurações (infra por ambiente)
            db.createCollection("configuracoes")
            db.configuracoes.insertMany([
              {
                "_id": "prb",
                "ambientes": {
                  "dev": {
                    "aws_account": "999999999999",
                    "aws_region": "us-east-1",
                    "eks_cluster": "idp-dev-cluster",
                    "namespace": "prb-dev"
                  },
                  "staging": {
                    "aws_account": "888888888888",
                    "aws_region": "us-east-1",
                    "eks_cluster": "idp-staging-cluster",
                    "namespace": "prb-staging"
                  },
                  "prod": {
                    "aws_account": "777777777777",
                    "aws_region": "sa-east-1",
                    "eks_cluster": "idp-prod-cluster",
                    "namespace": "prb-prod"
                  }
                }
              },
              {
                "_id": "aca",
                "ambientes": {
                  "dev": {
                    "aws_account": "999999999999",
                    "aws_region": "us-east-1",
                    "eks_cluster": "idp-dev-cluster",
                    "namespace": "aca-dev"
                  }
                }
              }
            ])
            
            // Coleção 3: Serviços
            db.createCollection("servicos")
            db.servicos.insertMany([
              {
                "_id": "payment-api",
                "nome": "payment-api",
                "id_aplicacao": "prb",
                "id_capacidade": "prb",
                "type": "dotnet",
                "dotnet_version": "8",
                "path_solution": "PaymentApi.sln",
                "path_project": "src/PaymentApi/",
                "owner": "payments-squad",
                "created_at": new Date()
              }
            ])
            
            // Mostrar dados
            db.aplicacoes.find()
            db.configuracoes.find()
            db.servicos.find()
            
            EOF

[ ] 1.4.2 - Dar permissão
            chmod +x scripts/setup-mongodb.sh

[ ] 1.4.3 - Executar (com port-forward ativo)
            ./scripts/setup-mongodb.sh

[ ] 1.4.4 - Verificar dados
            mongosh mongodb://idp-user:idp-password@localhost:27017/idp-catalog
            
            # no mongosh
            > use idp-catalog
            > db.aplicacoes.find()
            > db.configuracoes.find()
            > db.servicos.find()
```

**Tempo estimado**: 20 min
**Recursos**:
- [MongoDB Query Examples](https://www.mongodb.com/docs/manual/reference/method/)

---

### 1.5 — CLI Python Base

```
[ ] 1.5.1 - Criar estrutura:
            catalog-cli/
            ├── setup.py
            ├── requirements.txt
            ├── catalog/
            │   ├── __init__.py
            │   ├── cli.py
            │   ├── mongo.py
            │   └── commands/
            │       ├── __init__.py
            │       ├── servicos.py
            │       ├── configuracoes.py
            │       └── validator.py
            ├── tests/
            │   ├── __init__.py
            │   └── test_mongo.py
            └── .gitignore

[ ] 1.5.2 - Criar requirements.txt

            click==8.1.7
            pymongo==4.5.0
            python-dotenv==1.0.0
            pytest==7.4.2
            pydantic==2.4.2

[ ] 1.5.3 - Criar setup.py

            from setuptools import setup, find_packages
            
            setup(
                name="catalog-cli",
                version="0.1.0",
                packages=find_packages(),
                install_requires=[
                    "click>=8.1.0",
                    "pymongo>=4.5.0",
                    "python-dotenv>=1.0.0",
                    "pydantic>=2.4.0",
                ],
                entry_points={
                    "console_scripts": [
                        "catalog=catalog.cli:main",
                    ],
                },
            )

[ ] 1.5.4 - Criar catalog/mongo.py

            import os
            from pymongo import MongoClient
            from pymongo.errors import ServerSelectionTimeoutError
            
            class MongoConnection:
                def __init__(self):
                    self.uri = os.getenv(
                        "MONGO_URI",
                        "mongodb://idp-user:idp-password@localhost:27017/idp-catalog"
                    )
                    self.client = None
                    self.db = None
                
                def connect(self):
                    try:
                        self.client = MongoClient(self.uri, serverSelectionTimeoutMS=5000)
                        self.db = self.client["idp-catalog"]
                        # Test connection
                        self.db.command("ping")
                        print("✓ Connected to MongoDB")
                    except ServerSelectionTimeoutError:
                        print("✗ Could not connect to MongoDB")
                        raise
                
                def close(self):
                    if self.client:
                        self.client.close()
                
                def get_db(self):
                    if not self.db:
                        self.connect()
                    return self.db

[ ] 1.5.5 - Criar catalog/commands/servicos.py

            import click
            from catalog.mongo import MongoConnection
            
            @click.group()
            def servicos():
                """Manage services (serviços)"""
                pass
            
            @servicos.command()
            @click.option('--nome', required=True)
            @click.option('--aplicacao', required=True)
            @click.option('--type', required=True)
            def add(nome, aplicacao, type):
                """Add a new service"""
                mongo = MongoConnection()
                db = mongo.get_db()
                
                service = {
                    "_id": nome,
                    "nome": nome,
                    "id_aplicacao": aplicacao,
                    "type": type,
                    "created_at": None
                }
                
                try:
                    db.servicos.insert_one(service)
                    click.echo(f"✓ Service '{nome}' added successfully")
                except Exception as e:
                    click.echo(f"✗ Error: {e}", err=True)
                finally:
                    mongo.close()
            
            @servicos.command()
            def list():
                """List all services"""
                mongo = MongoConnection()
                db = mongo.get_db()
                
                try:
                    services = list(db.servicos.find({}, {"_id": 1, "type": 1, "id_aplicacao": 1}))
                    if not services:
                        click.echo("No services found")
                    else:
                        click.echo(f"{'ID':<30} {'Type':<10} {'App':<15}")
                        click.echo("-" * 55)
                        for svc in services:
                            click.echo(f"{svc['_id']:<30} {svc.get('type', 'N/A'):<10} {svc.get('id_aplicacao', 'N/A'):<15}")
                except Exception as e:
                    click.echo(f"✗ Error: {e}", err=True)
                finally:
                    mongo.close()
            
            @servicos.command()
            @click.option('--nome', required=True)
            def get(nome):
                """Get service details"""
                mongo = MongoConnection()
                db = mongo.get_db()
                
                try:
                    service = db.servicos.find_one({"_id": nome})
                    if not service:
                        click.echo(f"Service '{nome}' not found", err=True)
                    else:
                        import json
                        # Convert ObjectId to string for JSON
                        service_json = json.dumps(service, default=str, indent=2)
                        click.echo(service_json)
                except Exception as e:
                    click.echo(f"✗ Error: {e}", err=True)
                finally:
                    mongo.close()

[ ] 1.5.6 - Criar catalog/cli.py

            import click
            from catalog.commands import servicos, configuracoes
            
            @click.group()
            def main():
                """IDP Catalog CLI"""
                pass
            
            main.add_command(servicos.servicos)
            # main.add_command(configuracoes.configuracoes)  # Fase 2
            
            if __name__ == "__main__":
                main()

[ ] 1.5.7 - Criar catalog/__init__.py (vazio)
            touch catalog/__init__.py

[ ] 1.5.8 - Criar catalog/commands/__init__.py (vazio)
            touch catalog/commands/__init__.py

[ ] 1.5.9 - Instalar CLI (dev mode)
            cd catalog-cli
            pip install -e .

[ ] 1.5.10 - Testar CLI
            # Listar serviços
            catalog servicos list
            
            # Adicionar novo serviço
            catalog servicos add --nome order-api --aplicacao prb --type go
            
            # Listar novamente
            catalog servicos list
            
            # Ver detalhes
            catalog servicos get --nome payment-api
```

**Tempo estimado**: 1h
**Recursos**:
- [Click Documentation](https://click.palletsprojects.com/)
- [PyMongo Tutorial](https://pymongo.readthedocs.io/)

---

### 1.6 — GitHub Actions Básico

```
[ ] 1.6.1 - Criar arquivo: .github/workflows/validate.yml

            name: Validate Catalog
            
            on:
              push:
                branches: [main, develop]
              pull_request:
                branches: [main, develop]
            
            jobs:
              validate-mongo:
                runs-on: ubuntu-latest
                services:
                  mongodb:
                    image: mongo:latest
                    env:
                      MONGO_INITDB_ROOT_USERNAME: root
                      MONGO_INITDB_ROOT_PASSWORD: password
                    options: >-
                      --health-cmd "mongosh -u root -p password --eval 'db.adminCommand(\"ping\")'"
                      --health-interval 10s
                      --health-timeout 5s
                      --health-retries 5
                    ports:
                      - 27017:27017
                
                steps:
                  - uses: actions/checkout@v4
                  
                  - name: Set up Python
                    uses: actions/setup-python@v4
                    with:
                      python-version: '3.11'
                  
                  - name: Install dependencies
                    run: |
                      cd catalog-cli
                      pip install -e .
                  
                  - name: Run tests
                    env:
                      MONGO_URI: mongodb://root:password@localhost:27017/test
                    run: |
                      cd catalog-cli
                      pytest tests/ -v

[ ] 1.6.2 - Criar arquivo: .github/workflows/test-cli.yml

            name: Test CLI
            
            on:
              push:
              pull_request:
            
            jobs:
              test:
                runs-on: ubuntu-latest
                
                steps:
                  - uses: actions/checkout@v4
                  
                  - name: Set up Python
                    uses: actions/setup-python@v4
                    with:
                      python-version: '3.11'
                  
                  - name: Install dependencies
                    run: |
                      cd catalog-cli
                      pip install -e .
                  
                  - name: Check CLI help
                    run: |
                      catalog --help
                      catalog servicos --help

[ ] 1.6.3 - Fazer push para GitHub
            git add .github/workflows/
            git commit -m "Add initial GitHub Actions workflows"
            git push origin main

[ ] 1.6.4 - Verificar Actions no GitHub
            Ir em: https://github.com/seu-user/seu-repo/actions
            Verificar se workflows rodaram
```

**Tempo estimado**: 20 min
**Recursos**:
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions: Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

---

### 1.7 — Documentação Inicial

```
[ ] 1.7.1 - Criar README.md principal

            # IDP Platform — Internal Developer Platform
            
            Uma plataforma interna para permitir que squads de desenvolvimento
            façam deploy automaticamente, com segurança, observabilidade e
            escalabilidade.
            
            ## O que é?
            
            Um IDP (Internal Developer Platform) é um produto interno que fornece:
            
            - **Catálogo central** de serviços (MongoDB)
            - **Golden Path** padrão para qualquer tecnologia
            - **Self-service** para criar e fazer deploy de novos serviços
            - **Observabilidade** integrada (métricas, logs, traces)
            - **Segurança** aplicada automaticamente
            
            Veja [IDP-CONCEPTS.md](IDP-CONCEPTS.md) para teoria.
            
            ## Quick Start
            
            ```bash
            # 1. Clonar
            git clone <repo> && cd idp-platform
            
            # 2. Criar cluster K8s
            kind create cluster --config terraform/1-kind-cluster/kind-config.yaml
            
            # 3. Deploy MongoDB
            helm install mongodb bitnami/mongodb --namespace mongodb --create-namespace
            
            # 4. Setup CLI
            cd catalog-cli && pip install -e . && cd ..
            
            # 5. Testar
            catalog servicos list
            ```
            
            ## Fases
            
            - [x] FASE 1: Infraestrutura Base
            - [ ] FASE 2: Golden Path
            - [ ] FASE 3: Multi-Stack Apps
            - [ ] FASE 4: Self-Service Portal
            - [ ] FASE 5: IA & Observabilidade
            
            Veja [IDP-IMPLEMENTATION-PLAN.md](IDP-IMPLEMENTATION-PLAN.md) para detalhes.
            
            ## Arquitetura
            
            ```
            dev → git push → GitHub Actions → Validator (CLI)
                                                ↓
                                            Docker Build
                                                ↓
                                          Helm Deploy
                                                ↓
                                         Kubernetes
                                                ↓
                                         Slack Notify
            ```
            
            MongoDB:
            - aplicacoes (squads/times)
            - configuracoes (infra por ambiente)
            - servicos (cada microserviço)
            
            ## Recursos
            
            - [IDP Concepts](./IDP-CONCEPTS.md)
            - [Implementation Plan](./IDP-IMPLEMENTATION-PLAN.md)
            - [Team Topologies](./TEAM_TOPOLOGIES.md)
            - [Getting Started](./docs/GETTING-STARTED.md)

[ ] 1.7.2 - Criar docs/GETTING-STARTED.md

            # Getting Started
            
            ## Pré-requisitos
            
            - Docker
            - kubectl
            - kind
            - Helm 3+
            - Python 3.9+
            - Git
            
            ## Instalações
            
            ### macOS
            ```bash
            brew install docker kubectl kind helm python@3.11
            ```
            
            ### Linux
            Veja: [kind install](https://kind.sigs.k8s.io/docs/user/quick-start/)
            
            ## Setup (passo a passo)
            
            ### 1. Kubernetes Local
            ```bash
            kind create cluster --config terraform/1-kind-cluster/kind-config.yaml
            kubectl cluster-info
            kubectl get nodes
            ```
            
            ### 2. MongoDB
            ```bash
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm install mongodb bitnami/mongodb \
              --namespace mongodb --create-namespace \
              -f terraform/2-mongodb/values.yaml
            
            # Esperar
            kubectl wait --for=condition=ready pod \
              -l app.kubernetes.io/name=mongodb \
              -n mongodb --timeout=300s
            ```
            
            ### 3. CLI Python
            ```bash
            cd catalog-cli
            pip install -e .
            cd ..
            ```
            
            ### 4. Dados Demo
            ```bash
            ./scripts/setup-mongodb.sh
            ```
            
            ### 5. Testar
            ```bash
            # Port-forward
            kubectl port-forward -n mongodb svc/mongodb 27017:27017 &
            
            # Listar serviços
            catalog servicos list
            ```
            
            ## Próximos passos
            
            - Veja [TEAM_TOPOLOGIES.md](../TEAM_TOPOLOGIES.md)
            - Veja [IDP-IMPLEMENTATION-PLAN.md](../IDP-IMPLEMENTATION-PLAN.md)

[ ] 1.7.3 - Commit documentação
            git add docs/ README.md
            git commit -m "Add initial documentation"
            git push origin main
```

**Tempo estimado**: 30 min

---

## ✅ Checklist da Fase 1 — Resumo

```
INFRAESTRUTURA:
[ ] Kind cluster criado e funcional
[ ] MongoDB deployed via Helm
[ ] Dados de demo populados (3 coleções)
[ ] Port-forward testado

CLI PYTHON:
[ ] Estrutura base criada
[ ] Comandos: servicos add/get/list
[ ] Conectando em MongoDB
[ ] Instalado (pip install -e .)

GITHUB ACTIONS:
[ ] Workflows criados
[ ] Tests rodando
[ ] CLI sendo testado

DOCUMENTAÇÃO:
[ ] README principal
[ ] Getting Started
[ ] Commit no GitHub

RESULT:
✓ Você consegue: catalog servicos list
✓ MongoDB tem dados
✓ GitHub Actions passa
✓ Pronto para Fase 2
```

---

## 🐛 Troubleshooting — Fase 1

### MongoDB não conecta

```bash
# Verificar se pod está running
kubectl get pods -n mongodb

# Ver logs
kubectl logs -n mongodb <pod-name>

# Verificar port-forward
lsof -i :27017

# Reconectar
kubectl port-forward -n mongodb svc/mongodb 27017:27017 &
```

### CLI não encontra MongoDB

```bash
# Verificar URI
echo $MONGO_URI

# Set URI
export MONGO_URI="mongodb://idp-user:idp-password@localhost:27017/idp-catalog"

# Testar
mongosh $MONGO_URI
```

### GitHub Actions falha

```
Erro típico: "Cannot connect to MongoDB"
Solução: Service MongoDB rodando em GitHub Actions
        (workflow usa image: mongo:latest com service container)
```

---

## 📖 Referências — Fase 1

- [kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [MongoDB Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/mongodb)
- [Click Python CLI](https://click.palletsprojects.com/)
- [PyMongo](https://pymongo.readthedocs.io/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

**Next**: Quando terminar a Fase 1, continue com [FASE 2: Golden Path](./PHASE-2-GOLDEN-PATH.md)

---

**Last Updated**: 21 de maio de 2026
