output "cluster_arn" {
  description = "MSK Serverless cluster ARN."
  value       = aws_msk_serverless_cluster.this.arn
}

output "cluster_name" {
  description = "MSK Serverless cluster name."
  value       = aws_msk_serverless_cluster.this.cluster_name
}

output "security_group_id" {
  description = "Security Group attached to MSK Serverless."
  value       = aws_security_group.msk.id
}

output "bootstrap_brokers_sasl_iam" {
  description = "Bootstrap brokers for IAM/SASL clients."
  value       = aws_msk_serverless_cluster.this.bootstrap_brokers_sasl_iam
}
