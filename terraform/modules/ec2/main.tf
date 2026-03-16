resource "aws_key_pair" "dev-key" {
  key_name   = "dev-key"
  public_key = file("${path.module}/dev-key.pub")
}


# ── CONTROL PLANE NODE ───────────────────────────────────────────────────────

resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.control_plane_instance_type
  subnet_id                   = var.control_plane_subnet_id
  vpc_security_group_ids      = [var.control_plane_sg_id]
  key_name                    = aws_key_pair.dev-key.key_name
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.ebs_encrypted
    delete_on_termination = true

    tags = {
      Name = "control-plane-root-${var.env}"
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name = "control-plane-${var.env}"
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
  key_name                    = aws_key_pair.dev-key.key_name
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.ebs_encrypted
    delete_on_termination = true

    tags = {
      Name = "worker-${count.index + 1}-root-${var.env}"
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name = "worker-${count.index + 1}-${var.env}"
    Role = "worker"
    Env  = var.env
  }
}
