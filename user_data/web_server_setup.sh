#!/bin/bash
# ============================================================
# Web Server Setup Script
# Runs automatically when the EC2 instance first boots.
# Installs Apache and creates a simple webpage.
# ============================================================

# Exit immediately if any command fails
set -e

# Log all output to a file for debugging
exec > /var/log/user_data.log 2>&1
echo "=== Web Server Setup Started: $(date) ==="

# Update all installed packages to latest versions
yum update -y

# Install Apache web server (called "httpd" on Amazon Linux)
yum install -y httpd

# Enable Apache to start automatically when instance reboots
systemctl enable httpd

# Start Apache right now
systemctl start httpd

# Allow password-based SSH login (so Bastion can connect)
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Get the private IP address of this instance from AWS metadata service
# (The metadata service at 169.254.169.254 is a special AWS endpoint
#  available to all EC2 instances — it gives info about the instance itself)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a simple HTML webpage showing instance details
# This helps us confirm which server is responding behind the load balancer
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp Web Server</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 16px;
            padding: 40px;
            max-width: 500px;
            width: 90%;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }
        .logo { font-size: 48px; margin-bottom: 16px; }
        h1 { font-size: 28px; margin-bottom: 8px; color: #e94560; }
        h2 { font-size: 16px; font-weight: 400; color: #a8b2d8; margin-bottom: 32px; }
        .info-grid { display: grid; gap: 12px; }
        .info-item {
            background: rgba(0,0,0,0.2);
            border-radius: 8px;
            padding: 12px 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .label { color: #a8b2d8; font-size: 13px; }
        .value { color: #ccd6f6; font-weight: 600; font-size: 14px; }
        .status {
            display: inline-block;
            background: #00d68f;
            color: #003322;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 700;
            margin-top: 24px;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">🚀</div>
        <h1>TechCorp Web Server</h1>
        <h2>Serving your request successfully</h2>
        <div class="info-grid">
            <div class="info-item">
                <span class="label">Instance ID</span>
                <span class="value">$INSTANCE_ID</span>
            </div>
            <div class="info-item">
                <span class="label">Private IP</span>
                <span class="value">$PRIVATE_IP</span>
            </div>
            <div class="info-item">
                <span class="label">Availability Zone</span>
                <span class="value">$AZ</span>
            </div>
            <div class="info-item">
                <span class="label">Web Server</span>
                <span class="value">Apache HTTP Server</span>
            </div>
        </div>
        <span class="status">✓ HEALTHY</span>
    </div>
</body>
</html>
HTML

echo "=== Web Server Setup Completed: $(date) ==="
