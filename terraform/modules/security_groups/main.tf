# CONTROL PLANE SECURITY GROUP
# Rules are separate resources to avoid circular dependency with worker SG

resource "aws_security_group" "control_plane" {
  name        = "k8s-control-plane-${var.env}"
  description = "Security group for Kubernetes control plane nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-control-plane-sg-${var.env}"
    Role = "control-plane"
    Env  = var.env
  }
}


# WORKER SECURITY GROUP

resource "aws_security_group" "worker" {
  name        = "k8s-worker-${var.env}"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-sg-${var.env}"
    Role = "worker"
    Env  = var.env
  }
}


# ── CONTROL PLANE RULES ──────────────────────────────────────────────────────

resource "aws_security_group_rule" "cp_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
}

resource "aws_security_group_rule" "cp_api_server" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubernetes API Server"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_api_cidrs
}

resource "aws_security_group_rule" "cp_etcd" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "etcd server client API (self)"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "cp_kubelet" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubelet API"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "cp_controller_manager" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "kube-controller-manager"
  from_port         = 10257
  to_port           = 10257
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "cp_scheduler" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  description       = "kube-scheduler"
  from_port         = 10259
  to_port           = 10259
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "cp_from_workers" {
  type                     = "ingress"
  security_group_id        = aws_security_group.control_plane.id
  description              = "Allow all traffic from worker nodes"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.worker.id
}


# ── WORKER RULES ─────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "worker_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
}

resource "aws_security_group_rule" "worker_kubelet" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "Kubelet API"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "worker_nodeport" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "NodePort Services"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = var.allowed_nodeport_cidrs
}

resource "aws_security_group_rule" "worker_cni_vxlan" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "CNI VXLAN overlay (Flannel/Calico)"
  from_port         = 8472
  to_port           = 8472
  protocol          = "udp"
  self              = true
}

resource "aws_security_group_rule" "worker_cni_bgp" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "Calico BGP"
  from_port         = 179
  to_port           = 179
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "worker_from_cp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  description              = "Allow all traffic from control plane"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.control_plane.id
}
