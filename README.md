# AWS CloudWatch Monitoring Demo

EC2 instance monitored with CloudWatch alarms and dashboard (Terraform project).

## What it creates

- VPC + public subnet + security group
- EC2 t3.micro instance with Apache and stress tool
- CloudWatch alarm on CPUUtilization > 70% (2 minutes)
- SNS topic for email alerts (you confirm subscription in AWS console)
- CloudWatch dashboard (CPU + network metrics)

## Architecture

EC2 (t3.micro) → CloudWatch metrics → Alarm (CPU > 70%) → SNS Topic → Email

Dashboard shows CPU and network graphs for the instance.

## How to deploy (optional)

```bash
terraform init
terraform apply
