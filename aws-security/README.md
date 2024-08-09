# AWS Security Essentials: Hands-On Workshop

## Overview

This workshop is designed to provide hands-on experience with securing AWS resources. Participants will learn how to implement security best practices, configure monitoring and logging, and apply data protection measures using AWS services.

---

## Prerequisites

- **AWS Account:** Ensure you have an active AWS account with sufficient permissions to create and manage resources.
- **AWS CLI (Optional):** Install the AWS CLI on your local machine for command-line interactions.
- **Basic Knowledge:** Familiarity with basic AWS services such as EC2, S3, and VPC is recommended.

---

## Securing AWS Resources

### 1. Building a Secure Network Architecture

#### Creating a Custom VPC
- **Objective:** Set up a custom Virtual Private Cloud (VPC) to isolate resources and control network traffic.
- **Steps:**
  1. **VPC Creation:**
     - Navigate to the VPC Dashboard and select `Create VPC`.
     - Choose an IPv4 CIDR block (e.g., `10.0.0.0/16`) and name your VPC.
     - Enable DNS hostnames and DNS resolution if necessary.
  2. **Subnet Configuration:**
     - Create public and private subnets within the VPC.
     - Assign appropriate CIDR blocks to each subnet (e.g., `10.0.1.0/24` for public and `10.0.2.0/24` for private).
     - Associate each subnet with a route table.
  3. **Internet Gateway:**
     - Attach an Internet Gateway (IGW) to your VPC.
     - Update the route table for the public subnet to route traffic to the IGW.
  4. **NAT Gateway:**
     - Create a NAT Gateway in the public subnet to allow instances in the private subnet to access the internet securely.
     - Update the private subnet's route table to route traffic through the NAT Gateway.

#### Configuring Security Groups and Network ACLs
- **Objective:** Control inbound and outbound traffic using Security Groups and Network ACLs.
- **Steps:**
  1. **Security Groups:**
     - Create a Security Group for your VPC, defining inbound rules that allow necessary traffic (e.g., SSH on port 22 from your IP).
     - Set outbound rules to allow all traffic, or restrict based on your security requirements.
     - Apply the Security Group to your EC2 instances when launching them.
  2. **Network ACLs:**
     - Navigate to the VPC Dashboard and select `Network ACLs`.
     - Create custom Network ACLs for your public and private subnets.
     - Implement stateless rules to allow and deny traffic based on your security needs.
  
- **Test:**
  - Attempt to SSH into an EC2 instance launched in the public subnet using the Security Group and ensure that access is only permitted from allowed IPs.
  - Verify that instances in the private subnet can access the internet via the NAT Gateway but are not directly accessible from outside.

### 2. Securing EC2 Instances

#### Launching Secure EC2 Instances
- **Objective:** Securely launch EC2 instances within the custom VPC.
- **Steps:**
  1. **Instance Launch:**
     - Navigate to the EC2 Dashboard and click `Launch Instance`.
     - Select an Amazon Machine Image (AMI) and choose an instance type (e.g., `t2.micro`).
     - Place the instance in the custom VPC and select the appropriate subnet (public or private).
     - Assign the Security Group created in the previous step to the instance.
  2. **Storage Encryption:**
     - Enable encryption for the instance's EBS volumes using an AWS KMS key.
     - Review and launch the instance, ensuring that the configuration follows security best practices.
  
- **Test:**
  - Connect to the EC2 instance in the public subnet using SSH and verify that the security group rules are functioning correctly.
  - Ensure that the EC2 instance in the private subnet can only be accessed from the public subnet (if applicable) or through a bastion host.

### 3. Monitoring with CloudWatch

#### Setting Up CloudWatch Alarms and Metrics
- **Objective:** Implement comprehensive monitoring of AWS resources using CloudWatch.
- **Steps:**
  1. **Custom Metrics:**
     - Use the AWS CLI or SDK to publish custom metrics (e.g., memory usage, disk I/O) from your EC2 instances to CloudWatch.
     - Enable detailed monitoring for your EC2 instances to capture more granular data.
  2. **Alarms:**
     - Create CloudWatch alarms that trigger on specific conditions (e.g., CPU usage exceeds 80%).
     - Configure SNS topics to send notifications to your email or phone when alarms are triggered.
  3. **Dashboards:**
     - Build a CloudWatch dashboard to visualize key metrics, including CPU utilization, network traffic, and custom metrics.
  
- **Test:**
  - Simulate high CPU usage on the EC2 instance and verify that the CloudWatch alarm is triggered and notifications are received.
  - Review the CloudWatch dashboard to ensure that metrics are correctly displayed and updated in real-time.

### 4. Auditing with CloudTrail

#### Configuring CloudTrail for Comprehensive Auditing
- **Objective:** Enable and configure AWS CloudTrail to log all API calls and account activity.
- **Steps:**
  1. **Create a CloudTrail Trail:**
     - Navigate to the CloudTrail Dashboard and select `Create Trail`.
     - Name the trail, enable it for all regions, and specify an S3 bucket for storing logs.
  2. **Enable Log File Validation:**
     - Turn on log file validation to ensure that logs are not tampered with.
  3. **Set Up SNS Notifications:**
     - Configure SNS notifications for specific API activities, such as IAM policy changes or unauthorized access attempts.
  4. **Analyze Logs:**
     - Use the CloudTrail Event History or export logs to S3 for analysis using Athena or third-party tools.

- **Test:**
  - Perform activities in your AWS account (e.g., creating/deleting resources) and verify that these actions are logged in CloudTrail.
  - Check the S3 bucket for the presence of CloudTrail logs and validate their integrity.

### 5. Data Protection and Encryption with AWS KMS

#### Implementing Advanced Encryption Techniques with AWS KMS
- **Objective:** Protect sensitive data using AWS Key Management Service (KMS) for encryption at rest and in transit.
- **Steps:**
  1. **Create a Customer Managed Key (CMK):**
     - Navigate to the KMS Dashboard and create a new CMK with appropriate access controls.
     - Define key usage policies and enable key rotation.
  2. **Encrypt S3 Buckets:**
     - Apply server-side encryption using the CMK to an S3 bucket.
     - Enable bucket logging to monitor access to the encrypted data.
  3. **Cross-Service Encryption:**
     - Use the CMK to encrypt other AWS services such as RDS, EBS, and Lambda.
     - Ensure that data is encrypted at rest and in transit.
  4. **Monitoring Key Usage:**
     - Set up CloudWatch alarms for key usage and monitor CloudTrail logs for any unauthorized access to your CMKs.
  
- **Test:**
  - Upload data to the encrypted S3 bucket and verify that it is correctly encrypted using the CMK.
  - Review CloudTrail logs to ensure that all key usage and management actions are logged and monitored.

---

## Best Practices

- **Security:** Follow the principle of least privilege when assigning IAM roles and policies.
- **Monitoring:** Regularly review CloudWatch metrics and CloudTrail logs to detect and respond to security incidents.
- **Encryption:** Always encrypt sensitive data at rest and in transit using AWS KMS and other encryption mechanisms.
- **Cost Management:** Ensure all resources created during the workshop are properly terminated or cleaned up to avoid unnecessary charges.

---

## Cleanup Instructions

1. **Terminate EC2 Instances:** Ensure that all EC2 instances launched during the workshop are terminated.
2. **Delete Security Groups and ACLs:** Remove any custom Security Groups and Network ACLs created.
3. **Remove CloudWatch Alarms:** Delete any CloudWatch alarms that were set up during the exercises.
4. **Delete CloudTrail Trails:** Remove any CloudTrail trails and associated S3 buckets if no longer needed.
5. **Revoke IAM Permissions:** Revoke any temporary IAM permissions granted for the workshop.
6. **KMS Key Deletion:** Schedule the deletion of any CMKs created for the workshop, if they are not needed.

---
