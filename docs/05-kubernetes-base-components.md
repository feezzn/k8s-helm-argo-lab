# Componentes Base do Kubernetes

Este arquivo explica os pods que aparecem em `kube-system` no Kind.
Sem eles saudaveis, KEDA, Kafka e praticamente qualquer workload vao falhar de formas confusas.

## kube-apiserver

E a porta de entrada do cluster.
Todo `kubectl`, controller e componente interno conversa com a API.

Exemplos:

```bash
kubectl get pods
kubectl apply -f app.yaml
```

Ambos falam com o `kube-apiserver`.

No Kind, ele roda como static pod no control plane.

## etcd

E o banco chave-valor do Kubernetes.
Guarda o estado desejado e observado do cluster:

- Pods.
- Deployments.
- Services.
- Secrets.
- ConfigMaps.
- CRDs, como os recursos do KEDA.

Se o etcd quebra, o cluster perde a memoria operacional.

## kube-scheduler

Decide em qual node um pod deve rodar.

Ele olha coisas como:

- recursos pedidos pelo pod.
- taints e tolerations.
- node selectors.
- afinidade.
- nodes disponiveis.

Quando voce viu:

```text
0/1 nodes are available: untolerated taint node.kubernetes.io/not-ready
```

era o scheduler dizendo: "nao posso colocar esse pod em um node que ainda nao esta pronto".

## kube-controller-manager

Roda varios controllers essenciais.
Controllers sao loops que tentam aproximar o estado real do estado desejado.

Exemplos:

- Deployment controller cria ReplicaSets.
- ReplicaSet controller mantem numero de pods.
- Node controller observa saude dos nodes.
- EndpointSlice controller atualiza endpoints dos Services.

Se voce pede `replicas: 3`, algum controller fica olhando ate existirem 3 pods.

## kubelet

Agente que roda em cada node.
Ele recebe do API Server a lista de pods que devem rodar naquele node e conversa com o runtime de container.

Funcoes:

- criar containers.
- montar volumes.
- executar probes.
- reportar status do node e dos pods.

Quando aparece evento `FailedMount`, `Unhealthy`, `Started`, `BackOff`, normalmente quem esta reportando e o kubelet.

## container runtime

No Kind, geralmente e `containerd` dentro do node-container.
E quem realmente cria e executa containers.

O kubelet nao executa container diretamente; ele pede para o runtime.

## kube-proxy

Implementa a rede de Services do Kubernetes em cada node.

Quando voce cria:

```yaml
kind: Service
metadata:
  name: kafka
spec:
  ports:
    - port: 9092
```

o `kube-proxy` programa regras de rede para que o IP virtual do Service encaminhe trafego para os pods corretos.

Exemplo importante:

```text
https://10.96.0.1:443
```

Esse e o Service `kubernetes` que aponta para o API Server.
CoreDNS tenta falar com esse IP.
Se `kube-proxy` esta quebrado, esse Service IP nao funciona, e CoreDNS nao consegue sincronizar com a API.

Por isso, no nosso erro:

```text
CoreDNS: dial tcp 10.96.0.1:443: i/o timeout
kube-proxy: too many open files
```

o CoreDNS era vitima; o `kube-proxy` era a causa raiz.

## CoreDNS

E o DNS interno do cluster.

Ele resolve nomes como:

```text
kubernetes.default.svc.cluster.local
kafka.kafka.svc.cluster.local
orders-consumer.keda-lab.svc.cluster.local
```

Sem CoreDNS:

- pods nao resolvem nomes de Services.
- clients Kafka por DNS falham.
- apps com dependencias internas ficam instaveis.

CoreDNS precisa falar com o API Server para saber quais Services e Endpoints existem.
Se ele nao consegue falar com a API, ele fica `0/1` e mostra:

```text
Still waiting on: "kubernetes"
```

## kindnet

E o CNI padrao do Kind.
CNI e a camada que da rede para pods.

Ele permite que pods tenham IPs como:

```text
10.244.x.x
```

e consigam conversar entre si dentro do cluster.

## local-path-provisioner

Provisionador de volumes local do Kind.

Quando um PVC pede storage e usa a StorageClass padrao, ele cria um volume local no node.

Para este lab, o Kafka usa `emptyDir`, entao nao dependemos fortemente dele.
Mas em labs com PVC, ele vira importante.

## Como esses componentes se conectam

```text
kubectl
  -> kube-apiserver
      -> etcd
      -> controllers/scheduler
          -> kubelet no node
              -> container runtime

pod -> Service IP
      -> kube-proxy rules
          -> pod destino

pod -> nome DNS
      -> CoreDNS
          -> kube-apiserver
          -> Service/Endpoint
```

## Checklist antes de instalar add-ons

Antes de KEDA, Kafka, Ingress, Argo ou qualquer add-on:

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=120s
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

Se isso nao passa, pare e corrija o cluster base.
