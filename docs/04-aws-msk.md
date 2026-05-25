# Trilha Opcional: AWS MSK

Esta parte e propositalmente separada do lab local.
MSK e util para treinar cloud, mas adiciona temas que nao sao KEDA:

- VPC privada.
- Subnets em mais de uma AZ.
- Security Groups.
- IAM.
- Acesso do Kubernetes ao Kafka.
- Custo por hora enquanto o cluster existir.

## Recomendacao de caminho

Para aprender KEDA primeiro:

1. Faca o lab local.
2. Entenda `ScaledObject`, HPA e lag.
3. Depois leve o mesmo conceito para AWS.

Para AWS, o desenho mais limpo e:

```text
EKS na mesma VPC
   |
KEDA + consumer
   |
MSK Serverless privado
```

Rodar Kind local falando com MSK Serverless nao e o melhor primeiro passo, porque MSK fica dentro da VPC.
Voce precisaria de VPN, tunnel, bastion ou algum caminho privado ate a VPC.

## Custo

MSK Serverless costuma ser melhor para teste curto do que um cluster provisionado.
Mesmo assim, nao deixe ligado esquecido.

Antes de aplicar Terraform:

```bash
terraform plan
```

Depois do teste:

```bash
terraform destroy
```

## Terraform deste repo

O diretorio `aws/terraform-msk-serverless` contem um esqueleto para criar:

- MSK Serverless.
- Security Group do MSK.
- Regras de entrada para Security Groups clientes.

Ele assume que voce ja tem uma VPC e subnets privadas.
Isso evita criar NAT Gateway, EKS e VPC inteira sem querer.

Fluxo:

```bash
cd aws/terraform-msk-serverless
terraform init
terraform plan \
  -var='vpc_id=vpc-xxxxxxxx' \
  -var='private_subnet_ids=["subnet-aaa","subnet-bbb"]' \
  -var='client_security_group_ids=["sg-xxxxxxxx"]'
terraform apply \
  -var='vpc_id=vpc-xxxxxxxx' \
  -var='private_subnet_ids=["subnet-aaa","subnet-bbb"]' \
  -var='client_security_group_ids=["sg-xxxxxxxx"]'
```

Saida esperada:

```bash
terraform output bootstrap_brokers_sasl_iam
```

## KEDA com MSK IAM

Em EKS, o caminho recomendado e usar IRSA/Pod Identity para o KEDA acessar o MSK.
O `ScaledObject` muda principalmente em:

- `bootstrapServers`: brokers SASL/IAM do MSK.
- `sasl`: `aws_msk_iam`.
- `tls`: habilitado.
- `awsRegion`: regiao do cluster.
- `TriggerAuthentication`: identidade AWS do pod.

Exemplo conceitual:

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: orders-consumer-msk-auth
  namespace: keda-lab
spec:
  podIdentity:
    provider: aws-eks
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: orders-consumer
  namespace: keda-lab
spec:
  scaleTargetRef:
    name: orders-consumer
  minReplicaCount: 0
  maxReplicaCount: 6
  triggers:
    - type: kafka
      authenticationRef:
        name: orders-consumer-msk-auth
      metadata:
        bootstrapServers: "b-xxxx:9098"
        consumerGroup: orders-consumer
        topic: orders
        lagThreshold: "10"
        activationLagThreshold: "5"
        sasl: aws_msk_iam
        tls: enable
        awsRegion: us-east-1
```

Antes de transformar isso em producao, valide a sintaxe exata contra a versao do KEDA instalada.

## Permissoes IAM

O KEDA e o consumer precisam conseguir autenticar no MSK.
Em um setup IAM, revise permissoes como:

- conectar no cluster.
- descrever cluster/topicos.
- ler topico.
- ler consumer group.

O detalhe de policy depende do ARN do cluster e do padrao de topicos/groups.

## Quando usar AWS neste treino

Use MSK quando voce quiser treinar:

- Conectividade privada entre EKS e MSK.
- IAM auth para Kafka.
- `TriggerAuthentication` com identidade de cloud.
- Observabilidade em um ambiente mais parecido com producao.

Nao use MSK agora se o objetivo ainda e entender KEDA.
Nesse caso, o Kafka local ja mostra o comportamento principal.
