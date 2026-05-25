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
