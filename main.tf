###########################################################
#####                     EKS                        ######
###########################################################

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  cluster_name                             = "app-cluster"
  version                                  = "~> 20.31"
  cluster_version                          = "1.32"
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # cluster_compute_config = {
  #   enabled    = true
  #   node_pools = ["general-purpose"]
  # }

  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

  eks_managed_node_groups = {
    app_spot_nodes = {
      desired_capacity    = 2
      min_size            = 1
      max_size            = 3
      instance_types      = ["t3.medium"]
      spot_instance_pools = 2
      capacity_type       = "SPOT"
    }

    app_on_demand_nodes = {
      desired_capacity = 1
      min_size         = 1
      max_size         = 2
      instance_types   = ["t3.medium"]
      capacity_type    = "ON_DEMAND"
    }
  }

  tags = var.common-tags
}

###########################################################
#####                     RDS                        ######
###########################################################

data "vault_kv_secret_v2" "rds" {
  mount = "secret"
  name  = "mysql"
}

resource "aws_db_instance" "mysql" {
  db_name              = "appdb"
  username             = "admin"
  password             = data.vault_kv_secret_v2.rds.data["password"]
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
  tags = merge(var.common-tags,{ Name = "mysql-rds" })
}

resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = merge(var.common-tags,{ Name = "db-subnet-group" })
}

###########################################################
#####                    REDIS                       ######
###########################################################

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "app-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]
  port                 = 6379
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = merge(var.common-tags,{ Name = "redis-subnet-group" })
}

###########################################################
#####                     ALB                        ######
###########################################################

resource "aws_lb" "app" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_sg.id]
  subnets            = aws_subnet.public[*].id
  tags = merge(var.common-tags,{ Name = "app-alb" })
}

###########################################################
#####                 MONITORING                     ######
###########################################################

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "app-log-group"
  retention_in_days = 7
  tags = merge(var.common-tags,{ Name = "app-logs" })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name                = "HighCPUUtilization"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EKS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 80
  alarm_actions             = []
  dimensions = {
    ClusterName = module.eks.cluster_name
  }
}

###########################################################
#####                 EC2 - VAULT                    ######
###########################################################

resource "aws_instance" "private_ec2" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.small"
  subnet_id             = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private_ec2_sg.id]

  tags = merge(var.common-tags,{ Name = "vault-server"})
}

