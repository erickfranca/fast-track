# AWS Infrastructure with Terraform
This repository contains a Terraform configuration that provisions a basic AWS infrastructure stack including:

- VPC with public and private subnets
- Internet Gateway (IGW) and NAT Gateways
- Route Tables for public and private subnets
- Security Groups for EKS, RDS, ElastiCache, and a private EC2 instance
- Amazon EKS cluster (with managed node groups for Spot and On-Demand instances)
- Amazon RDS (MySQL) instance
- Amazon ElastiCache (Redis) cluster
- Application Load Balancer (ALB)
- CloudWatch log group and an example metric alarm (High CPU)
- A private EC2 instance intended for Vault

By default, this configuration stores Terraform state in an S3 bucket and uses the AWS provider.


------------

## Architecture Overview
    VPC (10.0.0.0/16)
    ├─ Subnets
    │  ├─ Public (e.g., 10.0.0.0/24, 10.0.1.0/24)
    │  │  └─ ALB
    │  └─ Private (e.g., 10.0.2.0/24, 10.0.3.0/24)
    │     ├─ EKS Worker Nodes (Spot & On-Demand)
    │     ├─ RDS (MySQL)
    │     ├─ ElastiCache (Redis)
    │     └─ Private EC2 Instance (Vault)
    ├─ Internet Gateway (IGW) [Attached to the VPC]
    ├─ NAT Gateways in Private Subnets
    ├─ Security Groups for EKS, RDS, ElastiCache, Vault
    └─ CloudWatch (Logs & Alarms)

- **EKS:** Creates a Kubernetes cluster with two managed node groups (Spot and On-Demand).
- **RDS:** A MySQL database, accessible only within the VPC.
- **ElastiCache:** A Redis cluster, also accessible only within the VPC.
- **ALB:** Public-facing load balancer for the EKS cluster.
- **Vault (private EC2):** Example instance for Hashicorp Vault usage.
- **CloudWatch:** Logs and an example alarm for CPU utilization on the EKS cluster.

## Configuration
### Variables
- common-tags
A map of common tags to apply to AWS resources. Default is:
```shell
{
  environment = "test"
  owner       = "devops-team"
  client      = "fast-track"
  created_by  = "terraform"
}
```
You can customize any variable by passing -var or using a .tfvars file:
```shell
terraform apply -var='common-tags={ environment="prod", owner="my-team" }'
```
### Other Notable Settings
- AWS Provider: Region is set to us-east-1.
- Terraform Backend:
```shell
backend "s3" {
  bucket = "tfstate-184239210367"
  key    = "terraform.tfstate"
  region = "us-east-1"
}
```
Adjust if you prefer a different bucket or region.
- **EKS Module:** Using the `terraform-aws-modules/eks/aws` module (version ~> 20.31) with Kubernetes version `1.32`.
- **RDS:** MySQL 8.0, default allocated storage = 10GB, instance class = `db.t3.micro`.
- **Redis:** Single-node cluster, `cache.t3.micro`.
- **ALB:** Public ALB named `app-alb`.
- **CloudWatch:** A log group named `app-log-group` (7 days retention) and an alarm for high CPU usage in EKS.
- **Private EC2 (Vault):** An EC2 instance named `vault-server` in a private subnet to host Vault (or other private workloads).

## Project Structure
```shell
.
├── main.tf            # Main Terraform configuration (or split into multiple .tf files)
├── variables.tf      # Variables definitions (optional separate file)
├── outputs.tf        # Outputs (if defined separately)
└── README.md    # This documentation
```
## Important Notes
- **Vault Integration**
  
If you plan to use Vault in production, ensure you carefully configure the backend and its replication. Since we are in a test environment, Vault is provisioned in development mode here.

- **Costs**

The cluster was created with mixed node groups (On-Demand and Spot) to take advantage of cost savings. This approach places more critical workloads on On-Demand nodes and the rest on Spot nodes. Keep in mind this is for a test or development environment. For production, you can certainly use Spot nodes, but any applications running on them must be carefully aligned with the team to handle potential interruptions.

- **Resource Limits**

Some AWS accounts have default limits on EC2 instances, NAT Gateways, or other services. Check your AWS service limits if you encounter provisioning issues.

- **Production Hardening**

For production environments, consider enabling multi-AZ for RDS, setting up Route53 DNS for your ALB, and adding more robust monitoring/alerting.

