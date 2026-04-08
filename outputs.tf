# ============================================================
# OUTPUTS
# ============================================================
# Outputs are values Terraform prints after a successful
# "terraform apply". They're useful for quickly seeing
# important info about your infrastructure.

output "vpc_id" {
  description = "The ID of the TechCorp VPC"
  value       = aws_vpc.techcorp_vpc.id
}

output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer. Use this URL to access the web app."
  value       = aws_lb.techcorp_alb.dns_name
}

output "bastion_public_ip" {
  description = "The public Elastic IP address of the Bastion host. Use this to SSH in."
  value       = aws_eip.bastion_eip.public_ip
}

output "web_server_1_private_ip" {
  description = "Private IP of Web Server 1 (access via Bastion)"
  value       = aws_instance.web_server_1.private_ip
}

output "web_server_2_private_ip" {
  description = "Private IP of Web Server 2 (access via Bastion)"
  value       = aws_instance.web_server_2.private_ip
}

output "db_server_private_ip" {
  description = "Private IP of the Database Server (access via Bastion)"
  value       = aws_instance.db_server.private_ip
}

output "public_subnet_1_id" {
  description = "ID of Public Subnet 1"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  description = "ID of Public Subnet 2"
  value       = aws_subnet.public_subnet_2.id
}

output "ssh_bastion_command" {
  description = "Command to SSH into the Bastion host"
  value       = "ssh ec2-user@${aws_eip.bastion_eip.public_ip}"
}

output "web_app_url" {
  description = "Full URL to access the web application via the Load Balancer"
  value       = "http://${aws_lb.techcorp_alb.dns_name}"
}
