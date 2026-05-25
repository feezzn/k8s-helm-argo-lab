locals {
  tags = merge(
    {
      Project   = "keda-kafka-lab"
      ManagedBy = "terraform"
    },
    var.tags
  )
}

resource "aws_security_group" "msk" {
  name        = "${var.cluster_name}-sg"
  description = "Security Group for the KEDA lab MSK Serverless cluster."
  vpc_id      = var.vpc_id
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.msk.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "client_iam" {
  for_each = toset(var.client_security_group_ids)

  security_group_id            = aws_security_group.msk.id
  referenced_security_group_id = each.value
  from_port                    = 9098
  to_port                      = 9098
  ip_protocol                  = "tcp"
  description                  = "Allow MSK IAM/SASL clients."
}

resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.cluster_name

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.msk.id]
  }

  tags = local.tags
}
