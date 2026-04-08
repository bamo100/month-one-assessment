#!/bin/bash
# ============================================================
# Database Server Setup Script
# Runs automatically when the EC2 instance first boots.
# Installs and configures PostgreSQL.
# ============================================================

set -e
exec > /var/log/user_data.log 2>&1
echo "=== DB Server Setup Started: $(date) ==="

# Update system packages
yum update -y

# Allow password-based SSH (so Bastion can connect)
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set the password for ec2-user (for SSH from Bastion)
echo "ec2-user:${db_server_password}" | chpasswd

# ============================================================
# Install PostgreSQL 14
# Amazon Linux 2 doesn't have PostgreSQL in its default repos,
# so we add the official PostgreSQL repository first.
# ============================================================

# Install the PostgreSQL repository configuration package
amazon-linux-extras enable postgresql14
yum clean metadata
yum install -y postgresql postgresql-server

# Initialize the PostgreSQL database (creates data directory & config)
postgresql-setup initdb

# Enable PostgreSQL to start on boot
systemctl enable postgresql

# Start PostgreSQL
systemctl start postgresql

# ============================================================
# Configure PostgreSQL
# ============================================================

# Set password for the default 'postgres' superuser
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${postgres_password}';"

# Create a sample application database
sudo -u postgres psql -c "CREATE DATABASE techcorp_app;"

# Create a dedicated app user (not a superuser — principle of least privilege)
sudo -u postgres psql -c "CREATE USER techcorp_user WITH PASSWORD '${postgres_password}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE techcorp_app TO techcorp_user;"

# ============================================================
# Configure PostgreSQL to accept password authentication
# and connections from the VPC (10.0.0.0/16)
# ============================================================

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
PG_CONF="/var/lib/pgsql/data/postgresql.conf"

# Allow password (md5) auth for all users from VPC CIDR
echo "host    all             all             10.0.0.0/16             md5" >> $PG_HBA

# Allow PostgreSQL to listen on all interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF

# Restart PostgreSQL to apply configuration changes
systemctl restart postgresql

echo "=== DB Server Setup Completed: $(date) ==="
echo "PostgreSQL is running. Connect with: psql -h localhost -U postgres -d techcorp_app"
