
# Create a security group for the EC2 instances running httpd
resource "aws_security_group" "belong_sg" {
  name_prefix = "belong_sg-${var.stage}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = module.vpc.public_subnets_cidr_blocks
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch an EC2 instance in the private subnet with an HTTP server
resource "aws_launch_template" "belong_lt" {
  name_prefix            = "belong_lc-${var.stage}"
  image_id               = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.belong_sg.id]
  user_data              = filebase64("${path.module}/scripts/user_data.sh")
  # Add IAM role to the EC2 instances
  iam_instance_profile {
    name = aws_iam_instance_profile.s3_access_ssm.name
  }
}

resource "aws_autoscaling_group" "belong_asg" {
  name             = "belong-asg-${var.stage}"
  max_size         = var.max_size
  min_size         = var.min_size
  desired_capacity = var.desired_capacity

  # Launch Template
  launch_template {
    id      = aws_launch_template.belong_lt.id
    version = aws_launch_template.belong_lt.latest_version
  }
  health_check_type = "EC2"
  # Instance Refresh
  dynamic "instance_refresh" {
    for_each = length(var.instance_refresh) > 0 ? [var.instance_refresh] : []
    content {
      strategy = instance_refresh.value.strategy
      triggers = try(instance_refresh.value.triggers, null)

      dynamic "preferences" {
        for_each = try([instance_refresh.value.preferences], [])
        content {
          checkpoint_delay       = try(preferences.value.checkpoint_delay, null)
          checkpoint_percentages = try(preferences.value.checkpoint_percentages, null)
          instance_warmup        = try(preferences.value.instance_warmup, null)
          min_healthy_percentage = try(preferences.value.min_healthy_percentage, null)
        }
      }
    }
  }

  # Launch instances in the private subnet
  vpc_zone_identifier = module.vpc.private_subnets

  # Use ELB to distribute traffic to the EC2 instances
  target_group_arns = [aws_lb_target_group.belong_tg.arn]
}

# Autoscaling policy to trigger scaling based on average CPU Utilization 
resource "aws_autoscaling_policy" "autoscaling_policy" {
  name                      = "autoscaling_policy-${var.stage}"
  estimated_instance_warmup = 120
  policy_type               = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
  autoscaling_group_name = "belong-asg-${var.stage}"
}

# Create a target group for the ELB
resource "aws_lb_target_group" "belong_tg" {
  name_prefix = "bg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id
}

# Create an ELB to distribute traffic to the EC2 instances
resource "aws_lb" "belong_elb" {
  name               = "belong-elb-${var.stage}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.belong_elb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.belong_elb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.belong_tg.arn
    type             = "forward"
  }
}

# Create a security group for the ELB
resource "aws_security_group" "belong_elb_sg" {
  name_prefix = "belong_elb_sg"
  vpc_id      = module.vpc.vpc_id

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
}

# Create an IAM role for S3 access and enable ssm 
resource "aws_iam_role" "s3_access_ssm" {
  name = "s3-access-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach an S3 policy to the IAM role
resource "aws_iam_role_policy_attachment" "s3_access_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.s3_access_ssm.name
}

# Attach AWS managed policy to enable AWS Systems Manager service core functionality
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.s3_access_ssm.name
}

# Allow the EC2 instance to assume the IAM role
resource "aws_iam_instance_profile" "s3_access_ssm" {
  name = "s3-access-profile-${var.stage}"

  role = aws_iam_role.s3_access_ssm.name
}