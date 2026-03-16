variable "env" {
  description = "Environment name"
  type        = string
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for the control plane node"
  type        = string
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "control_plane_subnet_id" {
  description = "Subnet ID for the control plane node"
  type        = string
}

variable "worker_subnet_ids" {
  description = "List of subnet IDs for worker nodes (distributed round-robin)"
  type        = list(string)
}

variable "control_plane_sg_id" {
  description = "Security group ID for the control plane node"
  type        = string
}

variable "worker_sg_id" {
  description = "Security group ID for worker nodes"
  type        = string
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with instances"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "ebs_encrypted" {
  description = "Whether to encrypt EBS volumes"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "Custom user data script. If null, defaults to basic K8s system prep."
  type        = string
  default     = null
}
