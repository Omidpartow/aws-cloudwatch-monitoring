#!/bin/bash
yum update -y

# Install Apache just to have a web page
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>CloudWatch Monitoring Demo - Omid Partow</h1>" > /var/www/html/index.html

# Install stress-ng to generate CPU load (manual test)
yum install -y epel-release
yum install -y stress-ng || yum install -y stress

# (Optional) Run quick CPU spike for 60 seconds on boot
# stress-ng --cpu 2 --timeout 60s &
