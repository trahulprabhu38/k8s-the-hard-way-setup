variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}
