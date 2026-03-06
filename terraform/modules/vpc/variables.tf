variable "cidr_block_vpc" {
    description = "give a valid range for private"
}

variable "env" {
    description = "specify the env type"
}

variable "public_cidr" {
     description = "This is the CIDR block range for public subnet."
}

variable "private_cidr" {
     description = "This is the CIDR block range for private subnet."
}

