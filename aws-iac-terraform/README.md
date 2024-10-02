# Terraform AWS Deployment Guide

Welcome to the Terraform AWS Deployment Guide. This guide walks you through the process of setting up and deploying infrastructure on AWS using Terraform. We cover everything from pre-requisites, to configuring Terraform with AWS, deploying a VPC, subnets and an EC2 instance. We'll also cover setting up load balancers and configuring DNS with Route 53 and expose a simple running application from the EC2. Let's get started. Feel free to visualize in AWS Console resources being created after each step or terraform state file being populated.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- An AWS account along with your access key and secret.
- AWS CLI configured on your machine.
- Terraform CLI installed and configured.
- Access to your S3 bucket for state storage.

## B. Configure Terraform with Default Region to Frankfurt

1. **Set up AWS CLI Credentials**: Run `aws configure` and set `eu-central-1` as the default region, providing your access key and secret when prompted.

2. **Create `import.tf` File**: Inside a new folder named `s3-bucket`, create an `import.tf` file with the following content:

    ```hcl
    resource "aws_s3_bucket" "my-state-bucket" {
      bucket = "bkt-awsacc-w3-euc1-${var.user_name}"

      tags = {
        Owner       = var.user_name
        Environment = "awsacc-labs"
        Account     = "Workload3"
      }
    }
    ```

3. **Create `variables.tf` File**:

    ```hcl
    variable "user_name" {
      type = string
    }

    variable "domain_name" {
      type = string
    }
    ```

4. **Create `providers.tf` File**:

    ```hcl
    provider "aws" {
      region = "eu-central-1"
    }
    ```

5. **Create `terraform.tfvars.json` File**: Populate this file with your user shortname.

    ```json
    {
        "user_name": "your_user_name",
        "domain_name": "your_domain_name"
    }
    ```

6. **Import S3 Bucket in Terraform**:

    - Initialize Terraform: `terraform init`
    - Plan your deployment (showing the auto tfvars part): `terraform plan --var-file=terraform.tfvars.json`
    - Import the S3 bucket: `terraform import aws_s3_bucket.my-state-bucket bkt-awsacc-w3-euc1-<change_me_add_your_username>`
    - Apply changes (visualize enforcement of tags): `terraform apply --var-file=terraform.tfvars.json`

## C. Deploy a VPC

1. **Prepare Configuration**: Copy `providers.tf`, `variables.tf`, and `terraform.tfvars.json` files into the new root folder.

2. **Create `backend.tf` File**: This file points to your S3 bucket for state storage.

    ```hcl
    terraform {
      backend "s3" {
        bucket = "bkt-awsacc-w3-euc1-<CHANGE_ME_YOUR_USER_NAME>"
        key    = "terraform/state"
        region = "eu-central-1"
      }
    }
    ```

3. **Create and Configure `main.tf` File**:

    - **Add a data block for available zones**:

        ```hcl
        data "aws_availability_zones" "available" {
          state = "available"
        }
        ```

    - **Define locals for VPC name and tags**:

        ```hcl
        locals {
          vpc_name = "vpc-${var.user_name}"
          tags = {
            Owner       = var.user_name
            Environment = "awsacc-labs"
            Account     = "Workload3"
          }
        }
        ```

    - **Add the VPC module block**:

        ```hcl
        module "vpc" {
          source  = "terraform-aws-modules/vpc/aws"
          version = "~> 5.13"
        
          name            = local.vpc_name
          cidr            = "10.0.0.0/16"
          azs             = data.aws_availability_zones.available.names
          public_subnets  = ["10.0.1.0/24", "10.0.3.0/24"]
          private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
        
          enable_nat_gateway = true
          single_nat_gateway = true
          create_vpc         = true
          create_igw         = true
        
          tags = local.tags
        }
        ```

4. **Run Terraform Commands**:

    - Initialize: `terraform init --upgrade`
    - Plan: `terraform plan --var-file=terraform.tfvars.json`
    - Apply: `terraform apply --var-file=terraform.tfvars.json`

## D. Deploy an EC2 Instance

1. **Update Locals**: Add `ec2_name` inside locals.

    ```hcl
    locals {
      vpc_name = "vpc-${var.user_name}"
      ec2_name = "ec2-${var.user_name}"
      tags = {
        Owner       = var.user_name
        Environment = "awsacc-labs"
        Account     = "Workload3"
      }
    }
    ```


2. **Add IAM Role and Instance Profile for SSM**:

    ```hcl
    resource "aws_iam_role" "ssm_role" {
      name = "EC2SSMRole-${var.user_name}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }]
      })
      tags = local.tags
    }

    resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
      role       = aws_iam_role.ssm_role.name
      policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    resource "aws_iam_instance_profile" "instance_profile" {
      name = "InstanceProfile-${var.user_name}"
      role = aws_iam_role.ssm_role.name
      tags = local.tags
    }
    ```

3. **Create EC2 Security Group**.

    ```hcl
    module "security_group_instance" {
      source  = "terraform-aws-modules/security-group/aws"
      version = "~> 5.2"

      name        = "${local.ec2_name}-ec2"
      description = "Security Group for EC2 Instance Egress"

      vpc_id = module.vpc.vpc_id

      ingress_cidr_blocks = ["0.0.0.0/0"]
      egress_rules        = ["https-443-tcp"]
      ingress_rules       = ["http-80-tcp"]

      tags = local.tags
    }
    ```

4. **Add EC2 Instance Module**.

    ```hcl
    module "ec2_instance" {
      source                      = "terraform-aws-modules/ec2-instance/aws"
      version                     = "~> 5.7"
      name                        = local.ec2_name
      instance_type               = "t2.micro"
      subnet_id                   = module.vpc.private_subnets[0]
      vpc_security_group_ids      = [module.security_group_instance.security_group_id]
      associate_public_ip_address = false
      iam_instance_profile        = aws_iam_instance_profile.instance_profile.name

      tags = local.tags
    }
    ```

5. **Run Terraform Commands**:

    - Initialize: `terraform init --upgrade`
    - Plan: `terraform plan --var-file=terraform.tfvars.json`
    - Apply: `terraform apply --var-file=terraform.tfvars.json`

## E. Set Up Load Balancer and Route 53

1. **Create Load Balancer and Security Group**:

    ```hcl
    resource "aws_security_group" "lb_sg" {
      name        = "${var.user_name}-lb-sg"
      description = "Security group for load balancer"
      vpc_id      = module.vpc.vpc_id

      ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
      egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

      tags = local.tags
    }

    resource "aws_lb" "load_balancer" {
      name               = "${var.user_name}-lb"
      internal           = false
      load_balancer_type = "application"
      security_groups    = [aws_security_group.lb_sg.id]
      subnets            = module.vpc.public_subnets

      tags = local.tags
    }
    ```

2. **Create Target Group and Register EC2 Instance**:

    ```hcl
    resource "aws_lb_target_group" "target_group" {
      name     = "${var.user_name}-tg"
      port     = 80
      protocol = "HTTP"
      vpc_id   = module.vpc.vpc_id

      tags = local.tags
    }

    resource "aws_lb_target_group_attachment" "tg_attachment" {
      target_group_arn = aws_lb_target_group.target_group.arn
      target_id        = module.ec2_instance.id
      port             = 80
    }
    ```

3. **Create Load Balancer Listener**:

    ```hcl
    resource "aws_lb_listener" "listener" {
      load_balancer_arn = aws_lb.load_balancer.arn
      port              = 80
      protocol          = "HTTP"

      default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.target_group.arn
      }
    }
    ```

4. **Create Route 53 DNS Record**:

    ```hcl
    data "aws_route53_zone" "selected" {
      name         = var.domain_name
      private_zone = false
    }

    resource "aws_route53_record" "webapp" {
      zone_id = data.aws_route53_zone.selected.zone_id
      name    = "${var.user_name}-webapp.${var.domain_name}"
      type    = "A"

      alias {
        name                   = aws_lb.load_balancer.dns_name
        zone_id                = aws_lb.load_balancer.zone_id
        evaluate_target_health = false
      }
    }
    ```

5. **Run Terraform Commands**:

    - Initialize: `terraform init --upgrade`
    - Plan: `terraform plan --var-file=terraform.tfvars.json`
    - Apply: `terraform apply --var-file=terraform.tfvars.json`    

## F. Expose Website

1. **Install Web Server on EC2 Instance Using SSM**:

    ```hcl
    resource "null_resource" "install_web_server" {
      provisioner "local-exec" {
        command = <<EOT
          #sleep 120 &&
          aws ssm send-command --document-name "AWS-RunShellScript" --targets "Key=instanceIds,   Values=${module.ec2_instance.id}" --parameters '{"commands":["sudo yum update -y", "sudo    yum install -y httpd", "sudo systemctl start httpd", "sudo systemctl enable httpd", "echo    \"<html><body><h1>Hello World</h1></body></html>\" | sudo tee /var/www/html/index.html"]}'   --region eu-central-1
        EOT
      }

      depends_on = [aws_lb.load_balancer]
    }
    ```
2. **Run Terraform Commands**:

    - Initialize: `terraform init --upgrade`
    - Plan: `terraform plan --var-file=terraform.tfvars.json`
    - Apply: `terraform apply --var-file=terraform.tfvars.json`

## G. Test and Validation
1. **Accessing & validating the Website**

After completing these steps, your website should be accessible via the DNS name set up in Route 53. Navigate to `http://${NAME}-webapp.${DOMAIN_NAME}` in your browser to see the "Hello World" page or ...

    ```bash
    curl http://${NAME}-webapp.${DOMAIN_NAME}
    ```

2. **Review Execution**:

    - Check resource availability inside the AWS Console.
    - Review the state file contents in your S3 bucket.

## H. Destroy All Resources

1. **Run Terraform Commands**:

    - Destroy the resources: `terraform destroy --var-file=terraform.tfvars.json`
    - [OPTIONAL] Redeploy resources from one go: `terraform apply --var-file=terraform.tfvars.json`
    - [OPTIONAL] Destroy the resources: `terraform destroy --var-file=terraform.tfvars.json`

2. **Review Execution**:

    - Check resource availability inside the AWS Console.
    - Review the state file contents in your S3 bucket.    

## I. Format and Document

- Format your Terraform code: `terraform fmt --recursive`
- Generate documentation using `terraform-docs` as described in the initial message.

By following these steps, you'll have a solid foundation for managing AWS resources with Terraform. Always refer to the official Terraform and AWS documentation for more detailed information and best practices.