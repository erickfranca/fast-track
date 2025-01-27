###########################################################
#####                     VPC                        ######
###########################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.common-tags,{ Name = "main-vpc" })
}

###########################################################
#####                    SUBNETS                     ######
###########################################################

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.common-tags,{
    Name                                = "public-subnet-${count.index}"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/app-cluster" = "shared"
  })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.common-tags,{
    Name                                = "private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb"   = "1"
    "kubernetes.io/cluster/app-cluster" = "shared"
  })
}

###########################################################
#####                     IGW                        ######
###########################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.common-tags,{ Name = "main-igw" })
}

###########################################################
#####                     NGW                        ######
###########################################################

resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.main[count.index].id
  subnet_id     = aws_subnet.private[count.index].id
  tags = merge(var.common-tags,{ Name = "main-ngw-${count.index}" })
}

resource "aws_eip" "main" {
  count  = 2
  domain = "vpc"
  tags = merge(var.common-tags,{ Name = "main-eip-${count.index}" })
}

###########################################################
#####                 ROUTE-TABLES                   ######
###########################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.common-tags,{ Name = "public-route-table" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = merge(var.common-tags,{ Name = "private-route-table-${count.index}" })
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

###########################################################
#####                SECURITY GROUPS                 ######
###########################################################

resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.common-tags,{ Name = "eks-security-group" })
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Only allow traffic from within the VPC
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.common-tags,{ Name = "rds-security-group"})
}

resource "aws_security_group" "elasticache_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Only allow traffic from within the VPC
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.common-tags,{ Name = "elasticache-security-group" })
}

resource "aws_security_group" "private_ec2_sg" {
  name   = "private-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow SSH within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
 
  ingress {
    description = "Allow Vault Conn"
    from_port   = 0
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common-tags,{ Name = "private-ec2-sg"})
}
