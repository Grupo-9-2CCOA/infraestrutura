data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zone_a = data.aws_availability_zones.available.names[0]
  availability_zone_b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = local.availability_zone_a
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-a"
    Tier = "Public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = local.availability_zone_b
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-b"
    Tier = "Public"
  }
}

resource "aws_subnet" "backend_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.backend_subnet_a_cidr
  availability_zone = local.availability_zone_a

  tags = {
    Name = "${var.project_name}-backend-a"
    Tier = "Private"
  }
}

resource "aws_subnet" "backend_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.backend_subnet_b_cidr
  availability_zone = local.availability_zone_b

  tags = {
    Name = "${var.project_name}-backend-b"
    Tier = "Private"
  }
}

resource "aws_subnet" "database" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidr
  availability_zone = local.availability_zone_a

  tags = {
    Name = "${var.project_name}-database"
    Tier = "Private"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "backend_a" {
  subnet_id      = aws_subnet.backend_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "backend_b" {
  subnet_id      = aws_subnet.backend_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  subnet_id      = aws_subnet.database.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_availability_zones.available.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

