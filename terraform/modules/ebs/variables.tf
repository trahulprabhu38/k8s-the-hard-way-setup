variable "env" {
  description = "Environment name"
  type        = string
}

variable "control_plane_instance_id" {
  description = "Instance ID of the control plane node"
  type        = string
}

variable "control_plane_az" {
  description = "Availability zone of the control plane node"
  type        = string
}

variable "worker_instance_ids" {
  description = "List of worker instance IDs"
  type        = list(string)
}

variable "worker_azs" {
  description = "List of availability zones for worker nodes"
  type        = list(string)
}

variable "etcd_volume_size" {
  description = "EBS volume size for etcd data (control plane) in GB"
  type        = number
  default     = 20
}

variable "worker_data_volume_size" {
  description = "EBS volume size for container data (workers) in GB"
  type        = number
  default     = 50
}

variable "volume_type" {
  description = "EBS volume type (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

variable "encrypted" {
  description = "Whether to encrypt EBS volumes"
  type        = bool
  default     = true
}

variable "iops" {
  description = "Provisioned IOPS for gp3/io1 volumes (ignored for gp2)"
  type        = number
  default     = 3000
}
