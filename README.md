# KEDA Kafka Lab

Laboratorio para aprender KEDA do jeito certo: primeiro o modelo mental, depois um teste local com Kafka, por fim uma trilha opcional para AWS/MSK.

Este repo foi zerado para virar um lab focado em:

- KEDA como add-on/operator no cluster.
- HPA gerado e alimentado por metricas externas.
- `ScaledObject` usando lag de consumer group no Kafka.
- Um consumer lento para deixar o autoscaling visivel.
- Uma trilha AWS opcional sem misturar custo e rede privada no primeiro exercicio.

## Regra deste lab

O assistente nao executa comandos de rede, `kubectl`, `helm` ou `terraform`.
Os comandos estao nos docs e scripts para voce rodar manualmente.

## Por onde comecar

1. Leia [docs/01-keda-aula.md](docs/01-keda-aula.md).
2. Rode o lab local seguindo [docs/02-local-kind-kafka.md](docs/02-local-kind-kafka.md).
3. Use [docs/03-debug-observability.md](docs/03-debug-observability.md) para entender o que o KEDA criou por baixo.
4. Quando quiser treinar cloud, leia [docs/04-aws-msk.md](docs/04-aws-msk.md).

## Estrutura

```text
apps/consumer/                 # Worker Python lento que consome Kafka
charts/consumer-keda/           # Helm chart da app com ScaledObject
infra/kind/                     # Config do cluster Kind
infra/kafka/                    # Kafka single-node para dev
scripts/                        # Comandos numerados para voce executar
aws/terraform-msk-serverless/   # Esqueleto opcional para MSK Serverless
docs/                           # Aula e passo a passo
```

## Versoes escolhidas

Voce mostrou:

```text
Client Version: v1.35.5
Server Version: v1.27.0
kind v0.31.0
```

Por isso este lab fixa KEDA `2.14.2`, uma escolha mais conservadora para Kubernetes `1.27`.
Se voce subir um cluster mais novo depois, podemos atualizar esse pin.

## Fluxo rapido

Abra os scripts antes de executar:

```bash
sed -n '1,200p' scripts/00-check-tools.sh
sed -n '1,200p' scripts/01-kind-create.sh
sed -n '1,200p' scripts/02-install-keda.sh
sed -n '1,200p' scripts/03-install-kafka.sh
sed -n '1,200p' scripts/04-build-load-consumer.sh
sed -n '1,200p' scripts/05-install-consumer.sh
sed -n '1,200p' scripts/06-produce-load.sh
sed -n '1,200p' scripts/07-watch.sh
```

Depois execute na ordem, se fizer sentido para o seu ambiente.

## O que voce deve observar

Antes de produzir mensagens:

- Deployment com `0` replicas.
- `ScaledObject` pronto.
- HPA criado pelo KEDA.

Depois de produzir mensagens:

- Lag do consumer group aumenta.
- KEDA entrega metrica externa para o HPA.
- HPA aumenta replicas do Deployment.
- Quando o lag zera e passa o `cooldownPeriod`, replicas voltam para `0`.
