# Lab Local: Kind + Kafka + KEDA

Este roteiro cria um laboratorio local com:

- Kind Kubernetes `1.27.x`.
- KEDA instalado por Helm.
- Kafka single-node para desenvolvimento.
- Um consumer lento em Python.
- Um `ScaledObject` que escala por lag Kafka.

## 0. Aviso honesto

Os comandos abaixo puxam imagens e charts da internet quando voce os executa.
O assistente nao executa esses comandos por voce.

## 1. Conferir ferramentas

```bash
./scripts/00-check-tools.sh
```

## 2. Criar cluster Kind

```bash
./scripts/01-kind-create.sh
```

Antes de instalar KEDA, valide a base do cluster:

```bash
./scripts/01b-check-cluster-health.sh
```

Se `kube-proxy` estiver em `CrashLoopBackOff` ou CoreDNS estiver `0/1`, pare aqui e veja [docs/00-kind-troubleshooting.md](00-kind-troubleshooting.md).

Se voce quiser usar um cluster ja existente, pule este passo e confira o contexto:

```bash
kubectl config current-context
kubectl version
```

## 3. Instalar KEDA

```bash
./scripts/02-install-keda.sh
```

O script usa Helm e fixa a versao do chart:

```bash
helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --version 2.14.2
```

Validacao:

```bash
kubectl get pods -n keda
kubectl get crd | grep keda
```

Nao siga para o Kafka se:

- `kube-system` tiver `coredns` sem Ready.
- `kube-system` tiver `kube-proxy` em `CrashLoopBackOff`.
- pods do KEDA estiverem presos em `FailedMount`.
- o secret `kedaorg-certs` nao existir.

Debug rapido:

```bash
./scripts/09-debug-keda-bootstrap.sh
```

Se o problema for o secret `kedaorg-certs` ausente, olhe primeiro os jobs/hooks do chart:

```bash
kubectl get job -n keda
kubectl get secret -n keda
kubectl describe pod -n keda
helm status keda -n keda
```

Mas se `kube-proxy` e `coredns` tambem estao quebrados, trate isso como problema do cluster Kind antes de tratar como problema do KEDA.

## 4. Subir Kafka local

```bash
./scripts/03-install-kafka.sh
```

Este lab usa um Kafka single-node, sem autenticacao, so para aprendizado.
Ele nao e uma receita de producao.

Validacao:

```bash
kubectl get pods -n kafka
kubectl get svc -n kafka
kubectl logs -n kafka statefulset/kafka
```

Se o script parecer travado apos criar o StatefulSet, ele provavelmente esta aguardando o pod `kafka-0` ficar Ready.
Abra outro terminal e veja:

```bash
kubectl get pods -n kafka -o wide
kubectl describe pod kafka-0 -n kafka
kubectl logs -n kafka pod/kafka-0 --all-containers --tail=160
kubectl get events -n kafka --sort-by=.lastTimestamp
```

Se precisar interromper e ajustar:

```bash
kubectl delete -f infra/kafka/kafka-single-node.yaml
```

Se o erro for `ImagePullBackOff` com `bitnami/kafka:3.7.0`, atualize o repo e reaplique.
Este lab usa a imagem oficial `apache/kafka:3.7.2`.

## 5. Buildar e carregar o consumer no Kind

```bash
./scripts/04-build-load-consumer.sh
```

O consumer e propositalmente lento.
Ele dorme alguns segundos por mensagem para gerar lag e deixar o KEDA trabalhar.

## 6. Instalar a aplicacao com Helm

```bash
./scripts/05-install-consumer.sh
```

Validacao:

```bash
kubectl get deploy -n keda-lab
kubectl get scaledobject -n keda-lab
kubectl get hpa -n keda-lab
```

Antes de produzir mensagens, o esperado e o Deployment ficar com `0` replicas.

## 7. Produzir carga

```bash
./scripts/06-produce-load.sh
```

Depois acompanhe:

```bash
./scripts/07-watch.sh
```

Voce deve ver:

- Job produtor enviando mensagens para o topico `orders`.
- Lag subindo para o consumer group `orders-consumer`.
- HPA criado pelo KEDA aumentando replicas.
- Pods consumindo e fazendo commit.
- Replicas voltando para zero apos o lag acabar e passar o cooldown.

## 8. Experimentos bons

### Mudar o alvo de lag

Edite `charts/consumer-keda/values.yaml`:

```yaml
scaledObject:
  kafka:
    lagThreshold: "5"
```

Reaplique:

```bash
helm upgrade --install orders-consumer ./charts/consumer-keda \
  --namespace keda-lab \
  --create-namespace
```

Com `lagThreshold` menor, a tendencia e pedir mais replicas.

### Aumentar lentidao do consumer

Edite:

```yaml
consumer:
  processingSeconds: "5"
```

Reaplique o chart e produza mensagens de novo.

### Testar sem scale-to-zero

Edite:

```yaml
scaledObject:
  minReplicaCount: 1
```

Assim o worker fica sempre quente.

## 9. Limpeza

Se criou o cluster Kind somente para o lab:

```bash
kind delete cluster --name keda-lab
```

Se usou um cluster existente:

```bash
helm uninstall orders-consumer -n keda-lab
helm uninstall keda -n keda
kubectl delete ns keda-lab kafka keda
```
