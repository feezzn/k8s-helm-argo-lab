variable "aws_region" {
  description = "AWS region where MSK Serverless will be created."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "MSK Serverless cluster name."
  type        = string
  default     = "keda-lab-msk-serverless"
}

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs. MSK Serverless expects subnets in multiple AZs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnets."
  }
}

variable "client_security_group_ids" {
  description = "Security Groups allowed to connect to MSK Serverless."
  type        = list(string)
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
