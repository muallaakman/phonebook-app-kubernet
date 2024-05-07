terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = "us-east-1"
  
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  name = "mualla"
}

resource "aws_instance" "worker" {
  ami           = "ami-080e1f13689e07408"
  instance_type = "t3a.medium"
  vpc_security_group_ids = [aws_security_group.secgrubum.id]
  key_name = "first_key"
  user_data = templatefile("worker.sh", { region = data.aws_region.current.name, master-id = aws_instance.master.id, master-private = aws_instance.master.private_ip} )
  iam_instance_profile = aws_iam_instance_profile.ec2connectprofile.name
  connection {
    host = self.public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file("~/.ssh/first_key.pem")
  }
  provisioner "file" {
    source      = "./bookstore-api.py"
    destination = "/home/ubuntu/bookstore-api.py"
    
  }
  depends_on = [aws_instance.master]

  

  tags = {
    Name = "workerdaworker"
  }
}
resource "aws_instance" "master" {
  ami           = "ami-080e1f13689e07408"
  instance_type = "t3a.medium"
  vpc_security_group_ids = [aws_security_group.secgrubum.id]
  key_name = "first_key"
  user_data = file("master.sh")
  tags = {
    Name = "mastermaster"
  }
  iam_instance_profile = aws_iam_instance_profile.ec2connectprofile.name
}

resource "aws_iam_instance_profile" "ec2connectprofile" {
  name = "ec2connectprofile-${local.name}"
  role = aws_iam_role.ec2connectcli.name
}

resource "aws_iam_role" "ec2connectcli" {
  name = "ec2connectcli-${local.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : "ec2-instance-connect:SendSSHPublicKey",
          "Resource" : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
          "Condition" : {
            "StringEquals" : {
              "ec2:osuser" : "ubuntu"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : "ec2:DescribeInstances",
          "Resource" : "*"
        }
      ]
    })
  }
}

resource "aws_security_group" "secgrubum" {
  name = "${local.name}-sec"
  tags = {
    Name = "${local.name}-sec"
  }

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    self = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "master_public_dns" {
  value = aws_instance.master.public_dns
}

output "master_private_dns" {
  value = aws_instance.master.private_dns
}

output "worker_public_dns" {
  value = aws_instance.worker.public_dns
}

output "worker_private_dns" {
  value = aws_instance.worker.private_dns
}

