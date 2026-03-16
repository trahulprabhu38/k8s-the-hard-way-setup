variable "cidr_block_vpc" {
  description = "CIDR block used for the VPC"
  type        = string
}

variable "testing" {
  description = "this will be a bool value and marked as true if i dont need vpc"
  type        = bool
  default    =  true
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "public" {
  description = "Public subnet definitions including CIDR and availability zone"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private" {
  description = "Private subnet definitions including CIDR and availability zone"
  type = map(object({
    cidr = string
    az   = string
  }))
}


# public = {
#   az1 = {
#     cidr = "10.0.1.0/24"
#     az   = "ap-south-1a"
#   }

#   az2 = {
#     cidr = "10.0.2.0/24"
#     az   = "ap-south-1b"
#   }
# }