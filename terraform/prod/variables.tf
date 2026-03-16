variable "env" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "cidr_block_vpc" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public" {
  description = "Public subnet definitions"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    az1 = { cidr = "10.0.1.0/24", az = "ap-south-1a" }
    az2 = { cidr = "10.0.2.0/24", az = "ap-south-1b" }
  }
}

variable "private" {
  description = "Private subnet definitions"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    az1 = { cidr = "10.0.10.0/24", az = "ap-south-1a" }
    az2 = { cidr = "10.0.11.0/24", az = "ap-south-1b" }
  }
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "my-key"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (restrict to bastion/VPN in prod)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_api_cidrs" {
  description = "CIDR blocks allowed to access the Kubernetes API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_nodeport_cidrs" {
  description = "CIDR blocks allowed to access NodePort services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
