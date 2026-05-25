# Aula: KEDA sem Magia

## A frase curta

KEDA escala workloads Kubernetes usando eventos e metricas externas.
Ele nao substitui completamente o HPA; ele cria e alimenta um HPA com metricas que o Kubernetes normalmente nao teria sozinho.

```text
Kafka lag / fila / Prometheus / cron / cloud metric
        |
      KEDA
        |
external.metrics.k8s.io
        |
      HPA
        |
Deployment replicas
```

## O problema que o KEDA resolve

HPA tradicional escala muito bem quando a carga aparece dentro dos pods:

- CPU alta.
- Memoria alta.
- Alguma custom metric ja publicada no cluster.

Mas muitos sistemas modernos tem a demanda fora dos pods:

- Mensagens paradas em um topico Kafka.
- Itens em uma fila SQS, RabbitMQ ou Redis.
- Numero de jobs pendentes.
- Uma query Prometheus que representa backlog.
- Um horario comercial em que um worker deve existir.

Se o worker esta em `0` replicas, CPU e memoria nao existem como sinal de demanda.
KEDA consegue olhar para a fonte externa, perceber trabalho pendente, subir o primeiro pod e depois deixar o HPA continuar o calculo.

## Componentes do KEDA

### Operator

Observa recursos como `ScaledObject` e `ScaledJob`.
Quando voce cria um `ScaledObject`, o operator cria/gerencia um HPA apontando para o Deployment, StatefulSet ou outro workload escalavel.

### Metrics Adapter

Expoe metricas externas para a API `external.metrics.k8s.io`.
O HPA pergunta para essa API qual e a metrica atual, e o KEDA responde com base no trigger configurado.

### Scaler

E o plugin especifico da fonte de evento.
Exemplos: Kafka, RabbitMQ, Prometheus, AWS SQS, Azure Queue, PostgreSQL, Cron.

### ScaledObject

Recurso principal para escalar um workload existente.
Exemplo mental:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  scaleTargetRef:
    name: orders-consumer
  minReplicaCount: 0
  maxReplicaCount: 6
  triggers:
    - type: kafka
      metadata:
        topic: orders
        consumerGroup: orders-consumer
        lagThreshold: "10"
```

### TriggerAuthentication

Recurso usado quando o scaler precisa de credenciais.
Exemplos:

- Usuario e senha do Kafka.
- Certificados TLS.
- IAM no EKS.
- Token de Prometheus privado.

## HPA simples ou KEDA?

Use HPA simples quando:

- CPU/memoria representam bem a carga.
- A app sempre tem pelo menos uma replica.
- Voce nao precisa escalar por backlog, fila ou evento externo.
- Voce quer um comportamento simples e previsivel.

Use KEDA quando:

- A carga real esta em uma fila, topico, stream ou metrica externa.
- Voce precisa de `scale to zero`.
- Voce quer escalar workers/consumers por backlog.
- Voce quer ligar workload por horario com `cron`.
- A app processa trabalho assincrono e nao recebe trafego HTTP direto.

Evite KEDA quando:

- A metrica externa nao e confiavel.
- Voce nao sabe o throughput real do worker.
- A app nao trata `SIGTERM`, commit de offset e graceful shutdown.
- Ja existe outro HPA manual controlando o mesmo Deployment.
- O gargalo e node/infra, nao quantidade de pods.

## Kafka: o exemplo classico

No Kafka, o KEDA normalmente olha o lag de um consumer group.

Se o topico tem 300 mensagens pendentes e voce configura:

```yaml
lagThreshold: "50"
maxReplicaCount: 6
```

O raciocinio e:

```text
300 mensagens pendentes / 50 mensagens por replica = 6 replicas desejadas
```

Esse numero ainda e limitado por:

- `minReplicaCount`
- `maxReplicaCount`
- numero de particoes do topico
- tempo de polling do KEDA
- comportamento do HPA
- velocidade real do consumer

## Lendo o resultado do lab

Exemplo real:

```text
scaledobject/orders-consumer
READY=True ACTIVE=True MIN=0 MAX=6

hpa/keda-hpa-orders-consumer
TARGETS 10/10 (avg)
MINPODS 1
MAXPODS 6
REPLICAS 6

deployment/orders-consumer
READY 6/6
```

O que isso quer dizer:

`READY=True`
: O KEDA conseguiu reconciliar o `ScaledObject` e falar com a fonte configurada.

`ACTIVE=True`
: O trigger esta ativo. No caso do Kafka, existe lag suficiente para acionar escala.

`TARGETS 10/10 (avg)`
: O HPA recebeu do KEDA uma metrica externa e compara valor atual com alvo.
Neste lab, `lagThreshold: "10"`, entao o alvo e 10 mensagens de lag por replica.

`REPLICAS 6`
: O HPA calculou replicas desejadas e bateu no teto `maxReplicaCount: 6`.

`MINPODS 1`
: Mesmo com `minReplicaCount: 0` no KEDA, o HPA gerado geralmente mostra minimo 1 enquanto o scaler esta ativo.
O KEDA cuida da transicao especial `0 -> 1` e `1 -> 0`.

## De onde sairam os dados

Neste lab, os dados vieram deste job:

```yaml
kind: Job
metadata:
  name: orders-producer
```

Ele executa:

```bash
for i in $(seq 1 240); do
  echo "{\"order_id\":${i},\"source\":\"keda-lab\"}"
done | /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 \
  --topic orders
```

Ou seja:

- foram produzidas 240 mensagens.
- no topico `orders`.
- no Kafka acessivel por `kafka.kafka.svc.cluster.local:9092`.

O consumer Python usa:

```text
KAFKA_TOPIC=orders
KAFKA_GROUP_ID=orders-consumer
PROCESSING_SECONDS=2
```

Cada pod processa uma mensagem e dorme 2 segundos antes de commitar.
Esse atraso cria backlog de proposito.

## De onde o KEDA tirou a metrica

O `ScaledObject` do chart tem:

```yaml
triggers:
  - type: kafka
    metadata:
      bootstrapServers: "kafka.kafka.svc.cluster.local:9092"
      consumerGroup: "orders-consumer"
      topic: "orders"
      lagThreshold: "10"
      activationLagThreshold: "5"
```

O KEDA usa essas informacoes para consultar o Kafka e calcular o lag do consumer group.

Lag, simplificado:

```text
ultimo offset produzido no topico - ultimo offset commitado pelo consumer group
```

Se existem 240 mensagens produzidas e poucas commitadas, o lag e alto.
Se os consumers processam e commitam, o lag cai.

O KEDA expoe esse lag como metrica externa.
O HPA le essa metrica externa e decide quantas replicas o Deployment deve ter.

## O detalhe das particoes

Kafka nao distribui uma mesma particao para dois consumers do mesmo group ao mesmo tempo.

Se o topico tem 3 particoes, passar de 3 replicas normalmente nao aumenta o consumo.
Por isso, para este lab usamos 6 particoes e `maxReplicaCount: 6`.

## Campos importantes do ScaledObject

`pollingInterval`
: De quanto em quanto tempo o KEDA consulta a fonte externa. Ajuda a controlar tempo de reacao.

`cooldownPeriod`
: Quanto tempo esperar antes de voltar para zero depois que a demanda some.

`minReplicaCount`
: Minimo de replicas. Use `0` para scale-to-zero.

`maxReplicaCount`
: Teto de replicas. No Kafka, pense no numero de particoes.

`lagThreshold`
: No Kafka, alvo de lag por replica.

`activationLagThreshold`
: Lag minimo para ativar escala a partir de zero.

## Como pensar antes de usar em producao

Checklist:

- A metrica representa trabalho real?
- O worker consegue processar com idempotencia?
- O pod trata encerramento com seguranca?
- O tempo de boot do pod e aceitavel?
- O `maxReplicaCount` conversa com particoes/capacidade?
- O cluster tem autoscaler de nodes se precisar de mais capacidade?
- O KEDA tem credenciais seguras via `TriggerAuthentication`?

## Conclusao pratica

KEDA e excelente quando a demanda esta fora do pod.
Se a demanda esta dentro do pod e CPU/memoria ja explicam o comportamento, HPA simples continua sendo o caminho mais limpo.
