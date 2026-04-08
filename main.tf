# ============================================================
# TERRAFORM REMOTE STATE BACKEND (S3)
# ============================================================
# This block tells Terraform to store its state file in S3
# instead of on your local machine.
# IMPORTANT: Create the S3 bucket BEFORE running terraform init.
# Run: aws s3api create-bucket --bucket <your-bucket-name> \
#        --region af-south-1 \
#        --create-bucket-configuration LocationConstraint=af-south-1
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "techcorp-terraform-state-mutolib"   # Name of your S3 bucket
    key    = "techcorp/terraform.tfstate"  # Path inside the bucket
    region = "af-south-1"
  }
}

# ============================================================
# PROVIDER
# ============================================================
# This tells Terraform we are using AWS and which region.
provider "aws" {
  region = var.aws_region
}

# ============================================================
# DATA SOURCE: Fetch Available Availability Zones
# ============================================================
# Automatically discovers the AZs available in our chosen region
# so we don't have to hard-code names like "af-south-1a"
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================
# DATA SOURCE: Latest Amazon Linux 2 AMI
# ============================================================
# Automatically finds the most recent Amazon Linux 2 image ID
# so our config stays up-to-date without manual changes
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# 1. VPC (Virtual Private Cloud)
# ============================================================
# Think of the VPC as your own private section of AWS —
# like renting a floor in a building, isolated from others.
resource "aws_vpc" "techcorp_vpc" {
  cidr_block           = var.vpc_cidr   # IP address range for this VPC
  enable_dns_hostnames = true           # Lets instances get DNS names
  enable_dns_support   = true           # Enables DNS resolution

  tags = {
    Name        = "techcorp-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ============================================================
# 2. SUBNETS
# ============================================================
# Subnets are smaller sections carved out of the VPC.
# PUBLIC subnets: Resources here can be reached from the internet.
# PRIVATE subnets: Resources here are hidden from the internet.

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true   # Instances here get a public IP automatically

  tags = {
    Name        = "techcorp-public-subnet-1"
    Environment = var.environment
    Type        = "Public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "techcorp-public-subnet-2"
    Environment = var.environment
    Type        = "Public"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "techcorp-private-subnet-1"
    Environment = var.environment
    Type        = "Private"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "techcorp-private-subnet-2"
    Environment = var.environment
    Type        = "Private"
  }
}

# ============================================================
# 3. INTERNET GATEWAY
# ============================================================
# The Internet Gateway is the "door" between your VPC and
# the public internet. Without it, nothing inside the VPC
# can talk to the internet.
resource "aws_internet_gateway" "techcorp_igw" {
  vpc_id = aws_vpc.techcorp_vpc.id

  tags = {
    Name        = "techcorp-igw"
    Environment = var.environment
  }
}

# ============================================================
# 4. ELASTIC IPs FOR NAT GATEWAYS
# ============================================================
# An Elastic IP is a fixed public IP address.
# NAT Gateways need one to communicate with the internet.
resource "aws_eip" "nat_eip_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.techcorp_igw]

  tags = {
    Name = "techcorp-nat-eip-1"
  }
}

resource "aws_eip" "nat_eip_2" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.techcorp_igw]

  tags = {
    Name = "techcorp-nat-eip-2"
  }
}

# ============================================================
# 5. NAT GATEWAYS
# ============================================================
# A NAT Gateway lets private subnet instances REACH OUT to
# the internet (e.g. to download updates) WITHOUT being
# reachable from the internet themselves. It's like a
# one-way mirror — they can see out, but no one can see in.
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id   # NAT sits in public subnet
  depends_on    = [aws_internet_gateway.techcorp_igw]

  tags = {
    Name = "techcorp-nat-gw-1"
  }
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
  depends_on    = [aws_internet_gateway.techcorp_igw]

  tags = {
    Name = "techcorp-nat-gw-2"
  }
}

# ============================================================
# 6. ROUTE TABLES
# ============================================================
# Route tables are like GPS directions for network traffic.
# They tell traffic WHERE to go.

# --- Public Route Table ---
# Send all internet-bound traffic (0.0.0.0/0 = "anywhere")
# through the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.techcorp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techcorp_igw.id
  }

  tags = {
    Name = "techcorp-public-rt"
  }
}

# --- Private Route Tables ---
# Send outbound internet traffic through the NAT Gateway
# (one per AZ for high availability)
resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.techcorp_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }

  tags = {
    Name = "techcorp-private-rt-1"
  }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.techcorp_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }

  tags = {
    Name = "techcorp-private-rt-2"
  }
}

# --- Route Table Associations ---
# Link each subnet to its route table
resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}

# ============================================================
# 7. SECURITY GROUPS
# ============================================================
# Security Groups act as virtual firewalls around each instance.
# They control WHAT traffic is allowed IN (ingress) and OUT (egress).

# --- Bastion Security Group ---
# Only YOU can SSH into the Bastion (using your IP)
resource "aws_security_group" "bastion_sg" {
  name        = "techcorp-bastion-sg"
  description = "Security group for Bastion host - allows SSH only from admin IP"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]   # Only your IP!
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-bastion-sg"
  }
}

# --- Web Security Group ---
# Allows HTTP/HTTPS from anywhere (public web traffic)
# Allows SSH only from the Bastion host
resource "aws_security_group" "web_sg" {
  name        = "techcorp-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from Bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-web-sg"
  }
}

# --- Database Security Group ---
# Allows PostgreSQL only from the web servers
# Allows SSH only from the Bastion host
resource "aws_security_group" "db_sg" {
  name        = "techcorp-db-sg"
  description = "Security group for database server"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    description     = "PostgreSQL from web servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "SSH from Bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-db-sg"
  }
}

# --- ALB Security Group ---
# The load balancer is the public-facing entry point
resource "aws_security_group" "alb_sg" {
  name        = "techcorp-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-alb-sg"
  }
}

# ============================================================
# 8. EC2 INSTANCES
# ============================================================

# --- Bastion Host ---
# This is a "jump server" — a secure entry point into your
# private network. You SSH into this first, then hop to other servers.
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # Enable password authentication on the Bastion host
  user_data = <<-EOF
    #!/bin/bash
    # Allow password authentication for SSH
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    # Set a password for ec2-user so you can login from Bastion to other servers
    echo "ec2-user:${var.web_server_password}" | chpasswd
  EOF

  tags = {
    Name        = "techcorp-bastion"
    Environment = var.environment
    Role        = "Bastion"
  }
}

# Elastic IP for the Bastion host (a fixed public IP address)
resource "aws_eip" "bastion_eip" {
  instance   = aws_instance.bastion.id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.techcorp_igw]

  tags = {
    Name = "techcorp-bastion-eip"
  }
}

# --- Web Server 1 (Private Subnet 1) ---
resource "aws_instance" "web_server_1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = file("user_data/web_server_setup.sh")

  tags = {
    Name        = "techcorp-web-server-1"
    Environment = var.environment
    Role        = "WebServer"
  }
}

# --- Web Server 2 (Private Subnet 2) ---
resource "aws_instance" "web_server_2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = file("user_data/web_server_setup.sh")

  tags = {
    Name        = "techcorp-web-server-2"
    Environment = var.environment
    Role        = "WebServer"
  }
}

# --- Database Server (Private Subnet 1) ---
resource "aws_instance" "db_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = templatefile("user_data/db_server_setup.sh", {
    postgres_password  = var.postgres_password
    db_server_password = var.db_server_password
  })

  tags = {
    Name        = "techcorp-db-server"
    Environment = var.environment
    Role        = "Database"
  }
}

# ============================================================
# 9. APPLICATION LOAD BALANCER (ALB)
# ============================================================
# The ALB sits in front of your web servers. When users visit
# your website, they hit the ALB first. The ALB then forwards
# the request to one of your web servers (spreading the load).

resource "aws_lb" "techcorp_alb" {
  name               = "techcorp-alb"
  internal           = false          # false = public-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false  # Set to true in real production

  tags = {
    Name        = "techcorp-alb"
    Environment = var.environment
  }
}

# --- Target Group ---
# Defines WHICH servers the ALB should send traffic to,
# and how to check if they are healthy
resource "aws_lb_target_group" "web_tg" {
  name     = "techcorp-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.techcorp_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2     # Must pass 2 checks to be "healthy"
    unhealthy_threshold = 3     # Must fail 3 checks to be "unhealthy"
    timeout             = 5     # Seconds to wait for a response
    interval            = 30    # Seconds between health checks
    path                = "/"   # URL path to check
    matcher             = "200" # Expect HTTP 200 OK response
  }

  tags = {
    Name = "techcorp-web-tg"
  }
}

# --- Register Web Servers with Target Group ---
resource "aws_lb_target_group_attachment" "web_server_1_attachment" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_server_2_attachment" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}

# --- ALB Listener ---
# Listens on port 80 and forwards traffic to the target group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.techcorp_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
