# Use the default VPC — no custom VPC needed for dev
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# ── VPC (SKIPPED — testing = true) ───────────────────────────────────────────

module "vpc" {
  source = "../modules/vpc"

  env            = var.env
  cidr_block_vpc = "10.0.0.0/16" # unused when testing = true
  public         = {}
  private        = {}
  testing        = true
}


# ── SECURITY GROUPS ───────────────────────────────────────────────────────────

module "security_groups" {
  source = "../modules/security_groups"

  env                    = var.env
  vpc_id                 = data.aws_vpc.default.id
  allowed_ssh_cidrs      = ["0.0.0.0/0"]
  allowed_api_cidrs      = ["0.0.0.0/0"]
  allowed_nodeport_cidrs = ["0.0.0.0/0"]
}


# ── EC2 ───────────────────────────────────────────────────────────────────────

module "ec2" {
  source = "../modules/ec2"

  env                         = var.env
  ami_id                      = data.aws_ami.ubuntu_22_04.id
  control_plane_instance_type = "t3.medium"
  worker_instance_type        = "t3.medium"
  worker_count                = 3

  control_plane_subnet_id = data.aws_subnets.default.ids[0]
  worker_subnet_ids       = data.aws_subnets.default.ids

  control_plane_sg_id = module.security_groups.control_plane_sg_id
  worker_sg_id        = module.security_groups.worker_sg_id

  associate_public_ip = true
  root_volume_size    = 30
  root_volume_type    = "gp2"
  ebs_encrypted       = false
}


# ── EBS ───────────────────────────────────────────────────────────────────────

module "ebs" {
  source = "../modules/ebs"

  env                       = var.env
  control_plane_instance_id = module.ec2.control_plane_id
  control_plane_az          = module.ec2.control_plane_az
  worker_instance_ids       = module.ec2.worker_ids
  worker_azs                = module.ec2.worker_azs

  etcd_volume_size        = 10
  worker_data_volume_size = 20
  volume_type             = "gp2"
  encrypted               = false
}
