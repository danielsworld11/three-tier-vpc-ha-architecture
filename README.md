# Highly Available Three‑Tier AWS Architecture

[![Terraform](https://img.shields.io/badge/Terraform-1.x-623CE4?logo=terraform)]()
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws)]()
[![Architecture](https://img.shields.io/badge/Architecture-3--Tier-blue)]()
[![IaC](https://img.shields.io/badge/Infrastructure_as_Code-Terraform-4CAF50)]()



# Highly Available Three-Tier VPC on AWS

## Architecture Diagram

```
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
```

*(Replace this ASCII block with an exported diagram image or the AWS VPC
resource map screenshot once deployed — see `screenshots/`.)*

## Objectives

Demonstrate a production-style three-tier network on AWS: a public-facing
load balancer, an auto-scaled private application tier, and an isolated
database tier — with no direct internet exposure for compute or data,
and every layer reachable only from the layer directly above it.

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC | Network isolation boundary |
| Public / Private Subnets | Tier separation across 2 AZs |
| Internet Gateway | Inbound/outbound internet for public subnets |
| NAT Gateway (x2) | Outbound-only internet for the app tier, one per AZ |
| Route Tables | Explicit routing per tier (public, app, db) |
| Application Load Balancer | Distributes traffic to the app tier |
| Auto Scaling Group + Launch Template | Self-healing, horizontally scalable app tier |
| Security Groups | Least-privilege tier-to-tier access chaining |
| RDS PostgreSQL (Multi-AZ) | Resilient, encrypted data tier |
| IAM Role + SSM | Instance access without SSH keys or open port 22 |
| KMS (via RDS encryption) | Encryption at rest |

## Networking Design

- **Public subnets** (one per AZ) hold the ALB and each AZ's NAT Gateway.
  Route table sends `0.0.0.0/0` to the Internet Gateway.
- **Private app subnets** (one per AZ) hold the EC2 instances in the ASG.
  Each AZ's route table sends `0.0.0.0/0` to *that AZ's own* NAT Gateway —
  this avoids cross-AZ NAT traffic and its cost/latency, and means losing
  one AZ's NAT Gateway doesn't affect the other AZ.
- **Private db subnets** (one per AZ) hold RDS. Their route table has
  **no internet route at all** — only local VPC traffic. RDS is also
  provisioned with `publicly_accessible = false`.
- Security groups are chained: ALB SG (open to internet) → App SG (only
  open to ALB SG) → DB SG (only open to App SG). Nothing but the ALB
  is reachable from the internet.

## Security Considerations

- No SSH key pairs and no port 22 open anywhere — EC2 instances are
  managed via **SSM Session Manager** through an IAM instance role
  (`AmazonSSMManagedInstanceCore`), following least-privilege access.
- IMDSv2 is enforced (`http_tokens = "required"`) on all instances.
- RDS storage is encrypted at rest; credentials are passed via Terraform
  variables, never hardcoded, and `terraform.tfvars` is gitignored.
- Each tier's security group only accepts traffic from the security
  group of the tier directly above it — never from a CIDR range.

## High Availability & Resilience

- All subnets, NAT Gateways, EC2 instances, and RDS are spread across
  2 Availability Zones.
- RDS is deployed **Multi-AZ**, giving an automatic failover standby.
- The Auto Scaling Group spans both private app subnets and uses ELB
  health checks, so an unhealthy instance is replaced automatically.
- Losing an entire AZ still leaves the app and db tiers running in the
  surviving AZ.

## Deployment Steps

```bash
cd three-tier-vpc
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set a real db_password

terraform init
terraform plan
terraform apply
```

After `apply`, grab the ALB URL:

```bash
terraform output alb_dns_name
```

Wait 2–3 minutes for instances to pass health checks, then load the ALB
DNS name in a browser — you should see the sample page served by one of
the ASG instances.

**To tear down** (do this promptly to avoid ongoing NAT Gateway / RDS charges):

```bash
terraform destroy
```

## Screenshots

*(Add these after deploying, before destroying)*

- [ ] VPC Resource Map
- [ ] Route tables (public / private-app / private-db)
- [ ] Subnets list showing AZ spread
- [ ] ALB target group showing healthy instances
- [ ] RDS console showing Multi-AZ status
- [ ] CloudWatch dashboard / ASG activity history

## Cost Management

This environment is deployed for demonstration purposes only. It was
validated (ALB reachable, targets healthy, RDS available), screenshotted,
then destroyed via `terraform destroy` to avoid ongoing charges. Primary
cost drivers while running: 2x NAT Gateway (hourly + data processing),
RDS Multi-AZ instance, and ALB hourly rate.

Here are clean, sharp, interview‑ready answers you can paste straight into your README.
---
Lessons Learned
Why per‑AZ NAT Gateways instead of one shared NAT Gateway?
Using one NAT Gateway creates a hidden single point of failure.
If the AZ hosting that NAT fails, all private subnets lose outbound internet, breaking:
EC2 package installs
SSM Session Manager
App updates
External API calls
Using one NAT Gateway per AZ ensures each private subnet has its own independent egress path.
Trade‑off:
Higher cost (≈ $0.045/hr per NAT + data)
Much higher resilience and true Multi‑AZ design
This is a classic AWS architecture trade‑off: cost vs availability.
---
Why SSM over SSH key pairs?
SSM Session Manager removes the need for:
SSH keys
Port 22
Bastion hosts
Public IPs
Benefits:
Zero open inbound ports → massively reduces attack surface
IAM‑based access control → no key rotation headaches
Audited sessions → CloudTrail + SSM logs
Works inside private subnets → no public exposure
This is the modern AWS best practice for EC2 access.
---
What would break if the DB subnet route table accidentally got a route to the Internet Gateway?
If the DB subnet had a route to the IGW, the database would become publicly routable, even if “Publicly Accessible = NO”.
Consequences:
Violates AWS security best practices
Breaks the principle of least privilege
Exposes RDS to the public internet
Could allow inbound traffic if SGs/NACLs were misconfigured
Fails compliance standards (PCI, SOC2, ISO27001)
A DB subnet must never have a route to the IGW.
It should only route within the VPC.
---
What’s the blast radius if the App SG allowed `0.0.0.0/0` instead of just the ALB SG?
If the App SG allowed inbound from 0.0.0.0/0, your EC2 instances would be exposed to the entire internet.
Impact:
Anyone could hit your application servers directly
ALB protections (WAF, health checks, throttling) are bypassed
Attack surface increases massively
Potential for:
Port scanning
Exploits
DDoS
Credential stuffing
Direct traffic to backend APIs
By restricting inbound traffic to only the ALB SG, you enforce:
Layer‑7 filtering
Centralized entry point
Proper load balancing
Security group chaining
Zero direct exposure of private EC2 instances
This is one of the most important security patterns in AWS.
