variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "af-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.0.4.0/24"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for the Web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the Database server"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair to use for EC2 instances (optional - for SSH key access)"
  type        = string
  default     = "tech_corp.pem"
}

variable "my_ip_address" {
  description = "Your current public IP address in CIDR format (e.g. 105.112.0.1/32). Used to restrict Bastion SSH access."
  type        = string
}

variable "environment" {
  description = "Environment name tag applied to all resources"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "techcorp"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform remote state (must be globally unique)"
  type        = string
}

variable "web_server_password" {
  description = "Password for the ec2-user on web servers (used for Bastion SSH password login)"
  type        = string
  sensitive   = true
}

variable "db_server_password" {
  description = "Password for the ec2-user on the DB server (used for Bastion SSH password login)"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Password for the PostgreSQL 'postgres' superuser"
  type        = string
  sensitive   = true
}
