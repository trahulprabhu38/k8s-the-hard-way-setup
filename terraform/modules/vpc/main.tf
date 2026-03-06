#vpc created 
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block_vpc
  tags = {
                  Name = "vpc-${var.env}"
    }  
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#public_subnet created
resource "aws_subnet" "public_subnet" {
 
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = var.public_cidr
  #count                = var.env == "dev"? 2 : 1

  tags = {
                  Name = "subnet-${var.env}"
  }
}

#private_subnet created
resource "aws_subnet" "private_subnet" {
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = var.private_cidr
  count                = var.env == "prod"? 1 : 0  

  tags = {
                  Name = "subnet-${var.env}"
  }
}

# ---- public setup -----

#public_route_tables
resource "aws_route_table" "public_rt"{
  vpc_id               = aws_vpc.vpc.id

  route {
    cidr_block         = "0.0.0.0/0"
    gateway_id         = aws_internet_gateway.igw.id
  }
}

#public_route_table_association created
resource "aws_route_table_association" "public_rta" {
  subnet_id            = aws_subnet.public_subnet.id
  route_table_id       = aws_route_table.public_rt.id
}

#internet_gateway created
resource "aws_internet_gateway" "igw" {
  vpc_id               = aws_vpc.vpc.id

  tags = {
                  Name = "igw-${var.env}"
  }
}

#internet_gateway_association created
resource "aws_internet_gateway_attachment" "igwa" {
  internet_gateway_id  = aws_internet_gateway.igw.id
  vpc_id               = aws_vpc.vpc.id
}

# ---- private setup -----

#public_route_tables
resource "aws_route_table" "private_rt"{
  vpc_id               = aws_vpc.vpc.id
  count                = var.env == "dev"? 0 : 1 

  route {
    cidr_block         = "0.0.0.0/0"
    nat_gateway_id     = aws_nat_gateway.nat[0].id
  }
}

#public_route_table_association created
resource "aws_route_table_association" "private_rta" {
    
  subnet_id            = aws_subnet.private_subnet[0].id
  route_table_id       = aws_route_table.private_rt[0].id
  count                = var.env == "dev"? 0 : 1 
}

#primary_nat_eip created
resource "aws_eip" "primary_nat_eip" {
  domain               = "vpc"
  count                = var.env == "dev"? 0 : 1 
}

#nat_gateway created
resource "aws_nat_gateway" "nat" {
  allocation_id        = aws_eip.primary_nat_eip[0].id
  subnet_id            = aws_subnet.public_subnet.id
  count                = var.env == "dev"? 0 : 1 

  tags = {
                  Name = "nat-${var.env}"
  }

  depends_on           = [aws_internet_gateway.igw]
}










#---- can be used to create specific routes ----
# list "aws_route" "example" {
#   provider = aws
#
#   config {
#     route_table_id = aws_route_table.example.id
#   }
# }