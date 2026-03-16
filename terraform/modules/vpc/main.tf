# VPC

resource "aws_vpc" "vpc" {
  count = var.testing ? 0 : 1

  cidr_block           = var.cidr_block_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.env}"
  }
}


# PUBLIC SUBNETS

resource "aws_subnet" "public" {
  for_each = var.testing ? {} : var.public

  vpc_id                  = aws_vpc.vpc[0].id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${each.key}-${var.env}"
  }
}


# PRIVATE SUBNETS

resource "aws_subnet" "private" {
  for_each = var.testing ? {} : var.private

  vpc_id            = aws_vpc.vpc[0].id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "private-${each.key}-${var.env}"
  }
}


# INTERNET GATEWAY

resource "aws_internet_gateway" "igw" {
  count = var.testing ? 0 : 1

  vpc_id = aws_vpc.vpc[0].id

  tags = {
    Name = "igw-${var.env}"
  }
}


# PUBLIC ROUTE TABLE

resource "aws_route_table" "public" {
  count = var.testing ? 0 : 1

  vpc_id = aws_vpc.vpc[0].id

  tags = {
    Name = "public-rt-${var.env}"
  }
}

resource "aws_route" "public_internet" {
  count = var.testing ? 0 : 1

  route_table_id         = aws_route_table.public[0].id
  gateway_id             = aws_internet_gateway.igw[0].id
  destination_cidr_block = "0.0.0.0/0"
}


# PUBLIC ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "public" {
  for_each = var.testing ? {} : aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}


# ELASTIC IP FOR NAT

resource "aws_eip" "nat" {
  for_each = var.testing ? {} : var.private

  domain = "vpc"

  tags = {
    Name = "nat-eip-${each.key}-${var.env}"
  }
}

# NAT GATEWAY (ONE PER AZ)

resource "aws_nat_gateway" "nat" {
  for_each = var.testing ? {} : var.private

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "nat-${each.key}-${var.env}"
  }

  depends_on = [aws_internet_gateway.igw]
}


# PRIVATE ROUTE TABLE

resource "aws_route_table" "private" {
  for_each = var.testing ? {} : var.private

  vpc_id = aws_vpc.vpc[0].id

  tags = {
    Name = "private-rt-${each.key}-${var.env}"
  }
}


# PRIVATE ROUTE TO NAT

resource "aws_route" "private_nat" {
  for_each = var.testing ? {} : var.private

  route_table_id         = aws_route_table.private[each.key].id
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
  destination_cidr_block = "0.0.0.0/0"
}


# PRIVATE ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "private" {
  for_each = var.testing ? {} : aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
