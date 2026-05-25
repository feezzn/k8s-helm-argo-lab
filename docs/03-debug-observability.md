# Debug e Observabilidade

Este arquivo e a cola para entender o que o KEDA esta fazendo por baixo.

## Ver o ScaledObject

```bash
kubectl describe scaledobject orders-consumer -n keda-lab
```

Procure por:

- `Ready`
- `Active`
- `Fallback`
- eventos de erro de conexao com Kafka
- metrica externa criada

## Ver o HPA criado pelo KEDA

```bash
kubectl get hpa -n keda-lab
kubectl describe hpa keda-hpa-orders-consumer -n keda-lab
```

O nome costuma seguir o padrao `keda-hpa-<scaledobject>`.

## Ver metricas externas

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/keda-lab" | jq
```

Se `jq` nao estiver instalado:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/keda-lab"
```

## Ver logs do operator KEDA

```bash
kubectl logs -n keda deploy/keda-operator
```

## Ver logs do metrics adapter

```bash
kubectl logs -n keda deploy/keda-operator-metrics-apiserver
```

## Ver pods do consumer

```bash
kubectl get pods -n keda-lab -w
```

Logs:

```bash
kubectl logs -n keda-lab deploy/orders-consumer -f
```

## Ver lag do consumer group

```bash
kubectl run kafka-debug \
  --namespace kafka \
  --image=apache/kafka:3.7.2 \
  --restart=Never \
  --rm \
  --stdin \
  --tty \
  -- /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server kafka.kafka.svc.cluster.local:9092 \
    --describe \
    --group orders-consumer
```

## Falhas comuns

### Deployment nao sai de zero

Cheque:

```bash
kubectl describe scaledobject orders-consumer -n keda-lab
kubectl logs -n keda deploy/keda-operator
```

Causas comuns:

- Kafka nao esta acessivel pelo KEDA.
- Topico nao existe.
- Consumer group ainda nao tem offset e a politica nao esta como esperado.
- `activationLagThreshold` esta alto demais.

### Replica sobe mas consumer falha

Cheque:

```bash
kubectl logs -n keda-lab deploy/orders-consumer
kubectl describe pod -n keda-lab -l app.kubernetes.io/name=consumer-keda
```

Causas comuns:

- Imagem nao carregada no Kind.
- `imagePullPolicy` errado.
- Bootstrap server errado.
- Kafka ainda iniciando.

### HPA existe mas nao escala como esperado

Cheque:

```bash
kubectl describe hpa keda-hpa-orders-consumer -n keda-lab
```

Lembre:

- O HPA tem janelas e estabilizacao.
- KEDA consulta a fonte em `pollingInterval`.
- Kafka limita consumo pelo numero de particoes.

## Comando mental

Quando algo parecer estranho, siga esta ordem:

```text
Kafka tem mensagem?
  -> consumer group tem lag?
    -> KEDA consegue ler esse lag?
      -> external metric aparece?
        -> HPA calculou replicas?
          -> Deployment criou pods?
            -> consumer processou e commitou?
```
