locals {
  default_user_data = <<-EOT
    #!/bin/bash
    set -ex

    # Disable swap (required for Kubernetes)
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Load required kernel modules
    cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    # Kernel parameters for Kubernetes networking
    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system

    # Install prerequisites
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack ipset
  EOT
}


# ── IAM ROLE: CONTROL PLANE ──────────────────────────────────────────────────

resource "aws_iam_role" "control_plane" {
  name = "k8s-control-plane-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "k8s-control-plane-role-${var.env}"
    Env  = var.env
  }
}

resource "aws_iam_role_policy" "control_plane" {
  name = "k8s-control-plane-policy-${var.env}"
  role = aws_iam_role.control_plane.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:*",
        "elasticloadbalancing:*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage",
        "iam:ListInstanceProfiles",
        "iam:ListRoles",
        "iam:GetRole",
        "iam:GetInstanceProfile",
        "kms:DescribeKey",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "control_plane_ssm" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "k8s-control-plane-profile-${var.env}"
  role = aws_iam_role.control_plane.name
}


# ── IAM ROLE: WORKERS ────────────────────────────────────────────────────────

resource "aws_iam_role" "worker" {
  name = "k8s-worker-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "k8s-worker-role-${var.env}"
    Env  = var.env
  }
}

resource "aws_iam_role_policy" "worker" {
  name = "k8s-worker-policy-${var.env}"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:Describe*",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:CreateVolume",
        "ec2:DeleteVolume",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:CreateTags",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage",
        "s3:GetObject",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_ssm" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "worker" {
  name = "k8s-worker-profile-${var.env}"
  role = aws_iam_role.worker.name
}


# ── CONTROL PLANE NODE ───────────────────────────────────────────────────────

resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.control_plane_instance_type
  subnet_id                   = var.control_plane_subnet_id
  vpc_security_group_ids      = [var.control_plane_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.control_plane.name
  user_data                   = var.user_data != null ? var.user_data : local.default_user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.ebs_encrypted
    delete_on_termination = true

    tags = {
      Name = "k8s-control-plane-root-${var.env}"
    }
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name = "k8s-control-plane-${var.env}"
    Role = "control-plane"
    Env  = var.env
  }
}


# ── WORKER NODES ─────────────────────────────────────────────────────────────

resource "aws_instance" "worker" {
  count = var.worker_count

  ami                         = var.ami_id
  instance_type               = var.worker_instance_type
  subnet_id                   = element(var.worker_subnet_ids, count.index)
  vpc_security_group_ids      = [var.worker_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.worker.name
  user_data                   = var.user_data != null ? var.user_data : local.default_user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.ebs_encrypted
    delete_on_termination = true

    tags = {
      Name = "k8s-worker-${count.index + 1}-root-${var.env}"
    }
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name = "k8s-worker-${count.index + 1}-${var.env}"
    Role = "worker"
    Env  = var.env
  }
}
