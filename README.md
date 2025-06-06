# Terraform Configuration for Web Application

## Overview
This Terraform configuration automates the deployment of a secure and scalable web application infrastructure in AWS. It includes private networking, NAT Gateway, Application Load Balancer (ALB), Web Application Firewall (WAF), and EC2 instances running a Dockerized application.

## Key Features
- **Private Networking**: Instances are deployed in a private subnet with no public IPs.
- **NAT Gateway**: Enables secure outbound traffic from the private subnet.
- **Application Load Balancer (ALB)**: Provides HTTPS access to the application and redirects HTTP traffic to HTTPS.
- **Web Application Firewall (WAF)**: Protects the application from common threats like SQL Injection.
- **Dockerized Application**: EC2 instances run a Docker container hosting the application.
- **Security Groups**: Controls inbound and outbound traffic for both EC2 instances and ALB.

## Files
- **webapp.tf**: Main Terraform configuration defining resources such as EC2 instances, subnets, ALB, NAT Gateway, etc.
- **.gitignore**: Ensures sensitive or unnecessary files (like `.terraform/`) are not tracked in Git.
- **README.md**: Documentation file explaining the functionality of the configuration.

## Steps to Deploy
1. **Initialize Terraform**:
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform appy
2. **Destroy Terraform**:
   ```bash
   terraform destroy
2. **SSH ACCESS TO WEBAPP**
    - There is need to use private key file (.pem) - if needed please kindy contact with author