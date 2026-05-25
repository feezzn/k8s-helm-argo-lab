# Auditoria KEDA em um Cluster Existente

Use este roteiro quando voce entrar em um cluster da empresa e quiser responder:

- KEDA esta instalado?
- Como foi instalado?
- Qual versao esta rodando?
- Quais apps usam KEDA?
- Quais HPAs foram criados pelo KEDA?
- Quais fontes de evento estao controlando escala?
- Existe risco, erro ou scaler quebrado?

Todos os comandos abaixo sao de leitura.

## 1. Contexto e saude basica

```bash
kubectl config current-context
kubectl version
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

Antes de culpar KEDA, valide a base:

```bash
kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=60s
kubectl -n kube-system rollout status deployment/coredns --timeout=60s
```

## 2. KEDA existe?

```bash
kubectl get ns | grep -i keda
kubectl get crd | grep -i keda
kubectl api-resources | grep -i keda
```

Recursos esperados:

```text
scaledobjects.keda.sh
scaledjobs.keda.sh
triggerauthentications.keda.sh
clustertriggerauthentications.keda.sh
```

Se nao tem CRD, KEDA nao esta instalado nesse cluster.

## 3. Componentes do KEDA

O namespace mais comum e `keda`, mas pode variar.

```bash
kubectl get deploy,pod,svc,secret,job -n keda
kubectl get apiservice | grep -i external.metrics
kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration | grep -i keda
```

Componentes comuns:

```text
keda-operator
keda-operator-metrics-apiserver
keda-admission-webhooks
kedaorg-certs
```

O `keda-operator` reconcilia `ScaledObject` e cria HPA.
O `keda-operator-metrics-apiserver` entrega metricas externas para o HPA.
O `keda-admission-webhooks` valida/muta recursos do KEDA.

## 4. Como foi instalado?

### Helm

```bash
helm list -A | grep -i keda
helm status keda -n keda
helm get values keda -n keda
helm get manifest keda -n keda | head -n 80
```

Se o release nao se chamar `keda`, descubra pelo `helm list -A`.

### Argo CD

```bash
kubectl get applications -A | grep -i keda
kubectl get app -A | grep -i keda
```

Se existir uma Application, veja:

```bash
kubectl describe application <app-name> -n <argo-namespace>
```

### GitOps sem Argo

Procure labels/annotations:

```bash
kubectl get deploy -n keda -o yaml | grep -i -E 'helm|argocd|flux|managed-by|chart'
```

## 5. Versao instalada

```bash
kubectl get deploy -n keda -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.template.spec.containers[*].image}{"\n"}{end}'
```

Exemplo:

```text
keda-operator -> ghcr.io/kedacore/keda:2.14.0
keda-operator-metrics-apiserver -> ghcr.io/kedacore/keda-metrics-apiserver:2.14.0
keda-admission-webhooks -> ghcr.io/kedacore/keda-admission-webhooks:2.14.0
```

Compare com a versao do Kubernetes:

```bash
kubectl version
```

## 6. Quem usa KEDA?

Liste todos os `ScaledObjects`:

```bash
kubectl get scaledobject -A
kubectl get so -A
```

Detalhe um:

```bash
kubectl describe scaledobject <nome> -n <namespace>
kubectl get scaledobject <nome> -n <namespace> -o yaml
```

Liste `ScaledJobs`:

```bash
kubectl get scaledjob -A
kubectl get sj -A
```

## 7. Quais HPAs foram criados pelo KEDA?

```bash
kubectl get hpa -A | grep -i keda
```

Para cruzar tudo:

```bash
kubectl get scaledobject -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicaCount,MAX:.spec.maxReplicaCount,TRIGGERS:.spec.triggers[*].type'
```

Depois:

```bash
kubectl get hpa -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,TARGETS:.status.currentMetrics[*].external.current.averageValue,REPLICAS:.status.currentReplicas'
```

## 8. Quais triggers existem?

```bash
kubectl get scaledobject -A -o yaml | grep -E 'type:|bootstrapServers|queue|topic|serverAddress|query|consumerGroup|lagThreshold|activation'
```

Mais organizado com `yq`, se tiver:

```bash
kubectl get scaledobject -A -o yaml | yq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, target: .spec.scaleTargetRef.name, min: .spec.minReplicaCount, max: .spec.maxReplicaCount, triggers: .spec.triggers}'
```

## 9. Autenticacao dos triggers

```bash
kubectl get triggerauthentication -A
kubectl get clustertriggerauthentication
```

Detalhe sem vazar secret:

```bash
kubectl describe triggerauthentication <nome> -n <namespace>
kubectl describe clustertriggerauthentication <nome>
```

Evite:

```bash
kubectl get secret -o yaml
```

Se precisar auditar segredo, prefira metadados:

```bash
kubectl get secret -A | grep -i '<nome-ou-app>'
```

## 10. Estado de um ScaledObject

```bash
kubectl get scaledobject <nome> -n <namespace>
kubectl describe scaledobject <nome> -n <namespace>
```

Campos importantes:

`READY`
: KEDA conseguiu reconciliar o objeto e montar o scaler.

`ACTIVE`
: O trigger esta ativo agora. Em Kafka, geralmente significa lag acima do limiar de ativacao.

`FALLBACK`
: KEDA entrou em fallback porque a metrica falhou varias vezes e existe fallback configurado.

`PAUSED`
: Escala pausada por anotacao/configuracao.

## 11. Logs do KEDA

```bash
kubectl logs -n keda deploy/keda-operator --tail=200
kubectl logs -n keda deploy/keda-operator-metrics-apiserver --tail=200
kubectl logs -n keda deploy/keda-admission-webhooks --tail=200
```

Procure por:

- erro de autenticacao.
- timeout na fonte externa.
- scaler mal configurado.
- metricas nao encontradas.
- problemas no webhook.

## 12. Metric API externa

```bash
kubectl get apiservice v1beta1.external.metrics.k8s.io -o yaml
```

Se estiver saudavel, deve apontar para o service do metrics adapter do KEDA.

Para listar metricas externas de um namespace:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/<namespace>"
```

## 13. Perguntas boas para fazer na empresa

- Qual workload realmente precisa escalar por evento?
- A metrica usada representa demanda real?
- O `maxReplicaCount` conversa com throughput, quota e numero de particoes?
- Existe Cluster Autoscaler/Karpenter se as replicas nao couberem nos nodes?
- O workload trata shutdown com seguranca?
- Quem e dono do `ScaledObject`: app team ou platform team?
- Existe dashboard/alerta para scaler quebrado?
- O KEDA foi instalado via Helm, Argo CD ou outro GitOps?
- Qual processo de upgrade do KEDA?

## 14. Interpretando scale-to-zero

Quando o trabalho acabou, voce pode ver:

```text
ScaledObject ACTIVE=False
HPA TARGETS <unknown>/10
Deployment 0/0
```

Isso e normal.

O trigger nao esta ativo, o KEDA levou o workload para zero, e o HPA nao tem pod/metric atual para mostrar.
Quando novo evento chegar, o KEDA observa a fonte externa e faz `0 -> 1`.
Depois o HPA assume `1 -> N`.
