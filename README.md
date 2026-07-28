Highly Available Three‑Tier VPC on AWS
Architecture Diagram
                          Internet
                              │
                       Internet Gateway
                              │
                Application Load Balancer (public subnets)
                              │
              ┌───────────────┴───────────────┐
              │                               │
        Public Subnet A                 Public Subnet B
        (us-east-1a)                    (us-east-1b)
              │                               │
         NAT Gateway A                   NAT Gateway B
              │                               │
   ───────────────────── Private App Layer ─────────────────────
              │                               │
      EC2 (Auto Scaling Group)        EC2 (Auto Scaling Group)
              │                               │
   ───────────────────── Private DB Layer ──────────────────────
              │                               │
              └──────────── RDS PostgreSQL (Multi-AZ) ───────────┘


---
Objectives
Build a realistic three‑tier architecture on AWS: a public load balancer, a private application tier, and a fully isolated database tier.
Only the ALB is exposed to the internet; everything else is private and reachable only from the layer above it.
---
AWS Services Used
Service	Purpose
VPC	Network isolation boundary
Public / Private Subnets	Tier separation across 2 AZs
Internet Gateway	Internet access for public subnets
NAT Gateway (x2)	Outbound‑only internet for private app subnets
Route Tables	Routing rules per tier
Application Load Balancer	Entry point + traffic distribution
Auto Scaling Group	Self‑healing, scalable app tier
Launch Template	EC2 configuration + IMDSv2 enforcement
Security Groups	Tier‑to‑tier access control
RDS PostgreSQL (Multi‑AZ)	Highly available database tier
IAM Role + SSM	Secure EC2 access without SSH
KMS	Encryption at rest for RDS
---
Networking Design
Public subnets host the ALB and NAT Gateways. Their route tables send 0.0.0.0/0 to the Internet Gateway.
Private app subnets host EC2 instances. Each subnet routes outbound traffic to its own NAT Gateway, avoiding cross‑AZ dependencies.
Private DB subnets host RDS. These subnets have no internet route, keeping the database fully isolated.
Security groups follow a simple chain:
ALB SG → App SG → DB SG
Only the ALB accepts internet traffic.
---
Security Considerations
EC2 access is via SSM Session Manager, not SSH. No port 22 is open anywhere.
IMDSv2 is required on all instances.
RDS is encrypted at rest; credentials are passed through variables, not hardcoded.
Each tier only accepts traffic from the tier directly above it.
---
High Availability & Resilience
All components run across two Availability Zones.
RDS is Multi‑AZ for automatic failover.
The ASG spans both private subnets and replaces unhealthy instances.
If one AZ fails, the architecture continues running in the other.
---
Deployment Steps
cd three-tier-vpc
cp terraform.tfvars.example terraform.tfvars
# Set a real db_password in terraform.tfvars

terraform init
terraform plan
terraform apply

Get the ALB DNS name:
terraform output alb_dns_name

Give the ALB a couple of minutes for health checks, then open the DNS name in a browser.
To remove everything (recommended to avoid NAT/RDS charges):
terraform destroy

---
Testing the Architecture
1. ALB Health Checks
Go to EC2 → Target Groups
Confirm both EC2 instances show healthy
2. SSM Session Manager
EC2 → Instance → Connect → Session Manager
Verify you can access the instance without SSH keys or port 22
3. RDS Connectivity (from EC2)
From an SSM session:
psql -h <rds-endpoint> -U postgres -d postgres

This confirms the DB is reachable only from the app tier.
4. Subnet Isolation
DB subnets should show no route to the Internet Gateway
App subnets should route 0.0.0.0/0 to their own NAT Gateway
Public subnets route 0.0.0.0/0 to the IGW
---
Screenshots
Recommended screenshots (add to /screenshots):
VPC Resource Map
Subnets list (showing AZ spread)
Route tables (public / private‑app / private‑db)
ALB target group (healthy instances)
RDS Multi‑AZ status
ASG activity history
SSM Session Manager connection
CloudWatch metrics (optional)
---
Cost Management
This environment was deployed for demonstration only.
Main cost drivers:
NAT Gateways (per‑AZ)
RDS Multi‑AZ
ALB
Everything was destroyed after validation to avoid ongoing charges.
---
Future Enhancements
Add AWS WAF in front of the ALB
Add CloudFront + S3 for static content
Add Route 53 + ACM for a custom domain
Add VPC Flow Logs + GuardDuty for deeper visibility
Add Parameter Store / Secrets Manager for DB credentials
Add RDS read replicas for read‑heavy workloads
Add CI/CD pipeline (GitHub Actions → Terraform Cloud)
Add ECS or EKS as an alternative compute layer
---
Lessons Learned
Per‑AZ NAT Gateways
A single NAT Gateway is cheaper but creates a single point of failure.
Using one NAT per AZ costs more but keeps the design truly Multi‑AZ.
SSM Instead of SSH
SSM removes the need for SSH keys, bastion hosts, or open ports.
It keeps instances private and gives IAM‑controlled, auditable access.
DB Subnet Isolation
If the DB subnet had a route to the Internet Gateway, the database could become reachable from outside the VPC.
The DB layer should only route inside the VPC.
App SG Should Not Allow `0.0.0.0/0`
Allowing the app tier to accept traffic from the whole internet would expose EC2 directly and bypass the ALB.
Restricting inbound traffic to the ALB SG keeps the app tier private and forces all traffic through the load balancer.
