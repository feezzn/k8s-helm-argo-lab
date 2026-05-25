# MSK Serverless Terraform Skeleton

Este Terraform e opcional.
Ele cria um MSK Serverless dentro de uma VPC existente.

Ele nao cria EKS, VPC, NAT Gateway nem bastion.
Essa decisao e intencional para evitar custo escondido no lab.

## Variaveis obrigatorias

- `vpc_id`: VPC onde o MSK sera criado.
- `private_subnet_ids`: pelo menos duas subnets privadas.
- `client_security_group_ids`: Security Groups autorizados a conectar no MSK pela porta IAM/SASL.

## Comandos

```bash
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

## Limpeza

```bash
terraform destroy \
  -var='vpc_id=vpc-xxxxxxxx' \
  -var='private_subnet_ids=["subnet-aaa","subnet-bbb"]' \
  -var='client_security_group_ids=["sg-xxxxxxxx"]'
```
