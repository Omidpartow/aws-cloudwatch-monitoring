terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Simple VPC, subnet and security group
resource "aws_vpc" "monitoring" {
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "monitoring-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "monitoring-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.monitoring.id
  tags = {
    Name = "monitoring-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.monitoring.id
  name   = "monitoring-ec2-sg"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for test page
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "monitoring-ec2-sg"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 instance with user_data that installs CloudWatch agent + stress tool
resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = file("user_data.sh")

  tags = {
    Name = "monitoring-demo-ec2"
    Owner = "Omid Partow"
  }
}

# SNS topic for alerts (you will subscribe by email)
resource "aws_sns_topic" "alerts" {
  name = "cloudwatch-monitoring-alerts"
}

# Example subscription placeholder – change email when you really deploy
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com" # <-- change when you deploy
}

# CloudWatch CPU alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "EC2-CPU-High-70"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when EC2 CPU > 70% for 2 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitor.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Simple CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "monitoring" {
  dashboard_name = "Omid-Monitoring-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0,
        y    = 0,
        width  = 12,
        height = 6,
        properties = {
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
          region = "us-west-2"
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.monitor.id ]
          ]
          stat = "Average"
        }
      },
      {
        type = "metric",
        x    = 12,
        y    = 0,
        width  = 12,
        height = 6,
        properties = {
          title  = "Network In/Out"
          view   = "timeSeries"
          region = "us-west-2"
          metrics = [
            [ "AWS/EC2", "NetworkIn",  "InstanceId", aws_instance.monitor.id ],
            [ ".",       "NetworkOut", ".",          "."                     ]
          ]
        }
      }
    ]
  })
}

output "ec2_public_ip" {
  description = "Public IP of the monitoring EC2 instance"
  value       = aws_instance.monitor.public_ip
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.monitoring.dashboard_name
}
