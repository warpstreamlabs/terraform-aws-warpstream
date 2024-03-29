## Get most recent AMI for an ECS-optimized Amazon Linux 2 instance
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"]
}

# resource "aws_iam_role" "ecs_node_role" {
#   name_prefix        = "demo-ecs-node-role"
#   assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
# }

# resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
#   role       = aws_iam_role.ecs_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs_node" {
#   name_prefix = "demo-ecs-node-profile"
#   path        = "/ecs/instance/"
#   role        = aws_iam_role.ecs_node_role.name
# }

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_launch_template" {
  name                   = "warpstream_EC2_LaunchTemplate"
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = var.ec2_instance_type
#   key_name               = aws_key_pair.default.key_name
  user_data = base64encode(data.template_file.user_data.rendered)
  vpc_security_group_ids = [aws_security_group.ec2.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_role_profile.arn
  }

  monitoring {
    enabled = true
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/ec2_user_data.sh")

  vars = {
    ecs_cluster_name = var.cluster_name
  }
}

## SG for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "warpstream_EC2_Instance_SecurityGroup"
  description = "Security group for EC2 instances in ECS cluster"
  vpc_id      = var.vpc_id

  #ingress {
  #  description     = "Allow ingress traffic from ALB on HTTP on ephemeral ports"
  #  from_port       = 1024
  #  to_port         = 65535
  #  protocol        = "tcp"
  #  security_groups = [aws_security_group.alb.id]
  #}

  #ingress {
  #  description     = "Allow SSH ingress traffic from bastion host"
  #  from_port       = 22
  #  to_port         = 22
  #  protocol        = "tcp"
  #  security_groups = [aws_security_group.bastion_host.id]
  #}

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
