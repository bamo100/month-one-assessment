# TechCorp AWS Infrastructure — Terraform Deployment Guide

This project provisions TechCorp's complete AWS infrastructure using Terraform, including a VPC, public/private subnets, EC2 instances, an Application Load Balancer, and a PostgreSQL database server.

---

## Table of Contents

1. [Glossary — What Do These Terms Mean?](#glossary)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Accessing Your Servers](#accessing-your-servers)
6. [Verifying Everything Works](#verifying-everything-works)
7. [Destroying the Infrastructure](#destroying-the-infrastructure)
8. [Troubleshooting](#troubleshooting)

---

## Glossary — What Do These Terms Mean?

Before we start, here's a plain-English explanation of every abbreviation used in this project:

| Term | Full Form | What It Means (Plain English) |
|------|-----------|-------------------------------|
| **VPC** | Virtual Private Cloud | Your own private, isolated section of AWS. Think of it like renting a private office floor in a building — you share the building (AWS), but your floor is yours. |
| **CIDR** | Classless Inter-Domain Routing | A way of writing a range of IP addresses. `10.0.0.0/16` means "all IP addresses from 10.0.0.0 to 10.0.255.255". The `/16` is the "size" of the range. A `/24` is smaller (256 addresses); a `/16` is bigger (65,536 addresses). |
| **Subnet** | Sub-network | A smaller network carved out of a VPC. Like dividing your office floor into individual rooms. Public subnets face the internet; private subnets are hidden inside. |
| **IGW** | Internet Gateway | The "front door" between your VPC and the internet. Without it, nothing inside can talk to the outside world. |
| **NAT** | Network Address Translation | A NAT Gateway lets servers in private subnets reach the internet (e.g. to download updates) without being directly reachable from the internet themselves. Like a receptionist who makes calls on your behalf. |
| **EC2** | Elastic Compute Cloud | AWS's virtual server service. An EC2 instance is simply a virtual computer (a server) running in AWS. |
| **AMI** | Amazon Machine Image | A pre-built template/snapshot of an operating system. When you launch an EC2 instance, you pick an AMI as the starting image — similar to choosing an OS when installing software. |
| **SG** | Security Group | A virtual firewall around an EC2 instance. You define rules for what traffic is allowed in (ingress) and out (egress). |
| **ALB** | Application Load Balancer | Sits in front of multiple web servers and distributes incoming web traffic between them so no single server gets overwhelmed. |
| **EIP** | Elastic IP | A fixed, permanent public IP address in AWS. Unlike regular public IPs that change when you restart an instance, an EIP stays the same. |
| **AZ** | Availability Zone | A physically separate data center within an AWS Region. Using multiple AZs means if one data center has a problem, your app stays up in another. |
| **SSH** | Secure Shell | A secure protocol for remotely logging into a server via the command line. Like remote desktop, but text-only and very secure. |
| **IAM** | Identity and Access Management | AWS's system for controlling who can do what. You create users, groups, and policies to manage permissions. |
| **S3** | Simple Storage Service | AWS's file/object storage service. We use it to store our Terraform state file remotely. |
| **RDS** | Relational Database Service | AWS's managed database service (not used here — we install PostgreSQL manually on EC2 instead). |
| **HTTP/HTTPS** | HyperText Transfer Protocol (Secure) | The protocol web browsers use to communicate with web servers. HTTP is port 80 (unencrypted); HTTPS is port 443 (encrypted). |
| **DNS** | Domain Name System | Translates human-readable names (like `google.com`) into IP addresses. Like a phonebook for the internet. |
| **Terraform** | (not an abbreviation) | An infrastructure-as-code tool. Instead of clicking in the AWS Console, you write configuration files and Terraform creates/manages everything for you. |
| **tfvars** | Terraform Variables | A file where you store your specific values (like your IP address, passwords) separately from the main configuration. |
| **ALB TG** | ALB Target Group | The list of servers the ALB should send traffic to. The ALB checks whether each target is healthy before sending it traffic. |

---

## Architecture Overview

```
Internet
    │
    ▼
[Internet Gateway]
    │
    ├─── Public Subnet 1 (AZ1)          ├─── Public Subnet 2 (AZ2)
    │    ├── Bastion Host (EIP)          │    ├── NAT Gateway 2
    │    ├── NAT Gateway 1               │    └── ALB node
    │    └── ALB node                    │
    │                                    │
    ├─── Private Subnet 1 (AZ1)         ├─── Private Subnet 2 (AZ2)
    │    ├── Web Server 1                │    └── Web Server 2
    │    └── DB Server                   │
    │                                    │
    └─────────── VPC (10.0.0.0/16) ─────┘
```

**Traffic Flow:**
- Users → ALB (public) → Web Servers (private)
- Admins → Bastion (public, your IP only) → Web/DB Servers (private)
- Web/DB servers → NAT Gateway → Internet (for updates)

---

## Prerequisites

Before you begin, make sure you have the following:

### 1. Tools Installed
- **Terraform** (v1.3+): Install guide in the main README
- **AWS CLI** (v2): Install guide in the main README
- **Git**: `sudo yum install git` or `sudo apt-get install git`

### 2. AWS Account Setup
- An AWS account with IAM user credentials configured
- Your IAM user needs at minimum: `AdministratorAccess` (or specific EC2, VPC, S3 permissions)
- AWS CLI configured: run `aws configure`

### 3. Find Your Public IP Address
You'll need this to restrict Bastion SSH access to only you:
```bash
curl https://checkip.amazonaws.com
# Example output: 105.112.45.67
# You'll enter this as: 105.112.45.67/32
```

---

## Step-by-Step Deployment

### Step 1: Create the S3 Bucket for Remote State

Terraform needs somewhere to store its state file. We use S3 for this.
The bucket name must be **globally unique** across all of AWS.

```bash
# Replace "techcorp-terraform-state-yourname" with your unique bucket name
aws s3api create-bucket \
  --bucket techcorp-terraform-state-yourname \
  --region af-south-1 \
  --create-bucket-configuration LocationConstraint=af-south-1

# Enable versioning (so you can recover old state files if something goes wrong)
aws s3api put-bucket-versioning \
  --bucket techcorp-terraform-state-yourname \
  --versioning-configuration Status=Enabled

# Block all public access to the bucket (state files can contain secrets!)
aws s3api put-public-access-block \
  --bucket techcorp-terraform-state-yourname \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Step 2: Clone or Download This Project

```bash
git clone <your-repo-url>
cd terraform-assessment
```

### Step 3: Create Your Variables File

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Open it and fill in your values
nano terraform.tfvars
```

Fill in these values:
```hcl
aws_region          = "af-south-1"
my_ip_address       = "YOUR_IP/32"         # From Step above
s3_bucket_name      = "techcorp-terraform-state-yourname"
web_server_password = "YourSecurePassword1!"
db_server_password  = "YourSecurePassword2!"
postgres_password   = "YourSecurePassword3!"
```

> ⚠️ **IMPORTANT**: Never commit `terraform.tfvars` to Git. Add it to `.gitignore`.

### Step 4: Update the Backend Configuration

Open `main.tf` and update the backend block with your bucket name:

```hcl
backend "s3" {
  bucket = "techcorp-terraform-state-yourname"   # ← Your bucket name here
  key    = "techcorp/terraform.tfstate"
  region = "af-south-1"
}
```

### Step 5: Initialize Terraform

This downloads the AWS provider plugin and connects to your S3 backend.

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 6: Validate Your Configuration

Check for syntax errors:
```bash
terraform validate
```

Expected output: `Success! The configuration is valid.`

### Step 7: Preview What Will Be Created

This shows you EXACTLY what Terraform will create — without actually creating anything yet.

```bash
terraform plan
```

Read through the output. Look for lines like:
- `# aws_vpc.techcorp_vpc will be created`
- `# aws_instance.bastion will be created`

Take a **screenshot** of this output for your submission.

### Step 8: Apply the Configuration

This actually creates all the resources. It will take about **5–10 minutes**.

```bash
terraform apply
```

Terraform will ask you to confirm:
```
Do you want to perform these actions? (yes/no): yes
```

Type `yes` and press Enter.

When complete, you'll see the outputs:
```
Outputs:
  bastion_public_ip      = "13.245.xxx.xxx"
  load_balancer_dns_name = "techcorp-alb-xxx.af-south-1.elb.amazonaws.com"
  vpc_id                 = "vpc-0abc123def456"
  web_app_url            = "http://techcorp-alb-xxx.af-south-1.elb.amazonaws.com"
```

Take a **screenshot** of this output for your submission.

---

## Accessing Your Servers

### SSH into the Bastion Host

```bash
# Using a key pair
ssh -i your-key.pem ec2-user@<bastion_public_ip>

# OR using password (if no key pair was set)
ssh ec2-user@<bastion_public_ip>
# Enter the web_server_password you set in terraform.tfvars
```

### SSH from Bastion to Web Servers

Once inside the Bastion, SSH to the web servers using their private IPs:

```bash
# Get the private IP from terraform output
terraform output web_server_1_private_ip

# From inside the Bastion:
ssh ec2-user@<web_server_1_private_ip>
# Password: the web_server_password you set
```

### SSH from Bastion to DB Server

```bash
# From inside the Bastion:
ssh ec2-user@<db_server_private_ip>
# Password: the db_server_password you set
```

### Connect to PostgreSQL

Once inside the DB server:

```bash
# Connect as the postgres superuser
psql -U postgres -d techcorp_app
# Enter the postgres_password you set

# Or connect from web server to DB server (tests network connectivity):
psql -h <db_server_private_ip> -U postgres -d techcorp_app
```

Useful PostgreSQL commands once connected:
```sql
-- List all databases
\l

-- List all users
\du

-- Show current database
SELECT current_database();

-- Exit
\q
```

---

## Verifying Everything Works

### 1. Check the Web Application

Open a browser and go to the URL from the output:
```
http://<load_balancer_dns_name>
```

You should see the TechCorp web page showing the Instance ID and Private IP.

Refresh a few times — you may see different Instance IDs as the ALB routes to different servers.

Take a **screenshot** showing the ALB URL in the browser address bar.

### 2. Verify Both Web Servers are Healthy

```bash
# In AWS Console: EC2 → Load Balancers → techcorp-alb
# → Target Groups → techcorp-web-tg → Targets
# Both instances should show "healthy"
```

### 3. Check Apache is Running on Web Servers

```bash
# SSH into a web server via Bastion, then:
sudo systemctl status httpd
# Should show: Active: active (running)
```

### 4. Check PostgreSQL is Running on DB Server

```bash
# SSH into DB server via Bastion, then:
sudo systemctl status postgresql
# Should show: Active: active (running)
```

---

## Destroying the Infrastructure

When you're done with the assessment, clean up all resources to avoid AWS charges:

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

Type `yes` when prompted.

> ⚠️ **Note**: The S3 bucket for remote state will NOT be destroyed automatically. Delete it manually in the AWS Console or with:
> ```bash
> aws s3 rb s3://techcorp-terraform-state-yourname --force
> ```

---

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|---------|
| `terraform init` fails | Wrong bucket name or region in backend config | Double-check bucket name in `main.tf` and that bucket exists |
| SSH connection refused to Bastion | Your IP changed | Update `my_ip_address` in `terraform.tfvars` and run `terraform apply` |
| Web page doesn't load | Instances still starting up | Wait 2-3 minutes after `apply` for user_data scripts to finish |
| ALB shows targets as unhealthy | Apache not started yet | SSH to web server and run `sudo systemctl status httpd` |
| Can't SSH from Bastion to web servers | Wrong password | Check the password you set in `terraform.tfvars` |
| PostgreSQL connection refused | pg_hba.conf not updated | Check `/var/log/user_data.log` on the DB server for errors |
