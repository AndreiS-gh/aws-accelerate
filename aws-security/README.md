# AWS Security Essentials: Hands-On Workshop

## Overview

This workshop provides hands-on experience with securing AWS resources, focusing on network architecture, instance security, monitoring, auditing, and encryption. Each step builds upon the previous one, ensuring a cohesive learning experience.

---

## Prerequisites

- **AWS Account:** An active AWS account with sufficient permissions to create and manage resources.
- **AWS CLI:** Installed on your local machine. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
- **IAM User:** Ensure your IAM user has administrator permissions or equivalent to perform all tasks.
- **Basic Knowledge:** Familiarity with AWS services like EC2, VPC, S3, and IAM.

---

## Workshop Agenda

1. [Building a Secure Network Architecture](#1-building-a-secure-network-architecture)
2. [Securing EC2 Instances](#2-securing-ec2-instances)
3. [Monitoring with CloudWatch](#3-monitoring-with-cloudwatch)
4. [Auditing with CloudTrail](#4-auditing-with-cloudtrail)
5. [Data Protection and Encryption with AWS KMS](#5-data-protection-and-encryption-with-aws-kms)

---

## 1. Building a Secure Network Architecture

### Creating a Custom VPC
- **Objective:** Create a custom Virtual Private Cloud (VPC) to isolate resources and manage network traffic.
  
- **Steps:**
  1. **VPC Creation:**
     - Open the VPC Dashboard and click `Create VPC`.
     - Choose `VPC only` and configure the following:
       - Name: `SecureVPC"yourname"`
       - IPv4 CIDR block: `10.0.0.0/16`
       - Tenancy: Default
     - Click `Create VPC`.

  2. **Subnet Configuration:**
     - **Public Subnet:**
       - Name: `PublicSubnet"yourname"`
       - IPv4 CIDR block: `10.0.1.0/24`
       - Availability Zone: Choose any available.
       - Auto-assign public IPv4: Enable.
     - **Private Subnet:**
       - Name: `PrivateSubnet"yourname"`
       - IPv4 CIDR block: `10.0.2.0/24`
       - Availability Zone: Same as the public subnet.
     - Create both subnets within `SecureVPC"yourname"`.

  3. **Internet Gateway:**
     - Create an Internet Gateway (IGW) and attach it to `SecureVPC"yourname"`.
     - Update the route table for `PublicSubnet"yourname"`:
       - Destination: `0.0.0.0/0`
       - Target: `IGW-ID`

  4. **NAT Gateway:**
     - Create an Elastic IP for the NAT Gateway.
     - Create a NAT Gateway in `PublicSubnet"yourname"`, associating it with the Elastic IP.
     - Update the route table for `PrivateSubnet"yourname"`:
       - Destination: `0.0.0.0/0`
       - Target: `NAT-Gateway-ID`

  5. **Security Groups:**
     - Create a security group named `PublicSG"yourname"` for `SecureVPC"yourname"`:
       - Inbound Rules: Allow SSH (Port 22) from your IP.
       - Outbound Rules: Allow all traffic.
     - Create another security group named `PrivateSG"yourname"` for instances in `PrivateSubnet"yourname"`:
       - Inbound Rules: Allow traffic from `PublicSG"yourname"` only.
       - Outbound Rules: Allow all traffic.

---

## 2. Securing EC2 Instances

### Launching Secure EC2 Instances
- **Objective:** Securely launch EC2 instances within the custom VPC created earlier.
  
- **Steps:**
  1. **Launch an Instance in Public Subnet:**
     - AMI: Amazon Linux 2.
     - Instance Type: `t2.micro`.
     - Network: `SecureVPC"yourname"`, Subnet: `PublicSubnet"yourname"`.
     - Security Group: `PublicSG"yourname"`.
     - Enable EBS encryption using a default KMS key or a custom key created in a later step.
     - Launch the instance.

  2. **Launch an Instance in Private Subnet:**
     - AMI: Amazon Linux 2.
     - Instance Type: `t2.micro`.
     - Network: `SecureVPC"yourname"`, Subnet: `PrivateSubnet"yourname"`.
     - Security Group: `PrivateSG"yourname"`.
     - Enable EBS encryption as above.
     - Launch the instance.

- **Test:**
  - Verify that the instance in `PublicSubnet"yourname"` can be accessed via SSH from your IP.
  - Confirm that the instance in `PrivateSubnet"yourname"` cannot be accessed directly from the internet. Attempt SSH access from the `PublicSubnet"yourname"` instance.

---

## 3. Monitoring with CloudWatch

### Setting Up CloudWatch Alarms and Custom Metrics

- **Objective:** Monitor AWS resources using CloudWatch, including setting up custom metrics and alarms via the AWS CLI.

- **Steps:**

  1. **Enable Detailed Monitoring:**
     - Navigate to the EC2 Dashboard, select both instances, click `Actions > Monitor and troubleshoot > Enable detailed monitoring`.
  
  2. **Publishing Custom Metrics (Using AWS CLI):**
     - Install the necessary CloudWatch agent on your instances.
     - Use the AWS CLI to push custom metrics (e.g., memory usage):
       ```
       aws cloudwatch put-metric-data --metric-name MemoryUsage"yourname" --namespace "CustomMetrics" --unit Percent --value 70.5
       ```
     - Repeat for any other custom metrics you wish to monitor.

  3. **Create a CloudWatch Alarm (Using AWS CLI):**
     - Example: Create an alarm for high CPU utilization:
       ```
       aws cloudwatch put-metric-alarm --alarm-name "HighCPUAlarm"yourname"" --metric-name CPUUtilization --namespace AWS/EC2 \
       --statistic Average --period 300 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold \
       --dimensions Name=InstanceId,Value=<Instance-ID> --evaluation-periods 1 --alarm-actions <SNS-Topic-ARN>
       ```
     - Replace `<Instance-ID>` with your EC2 instance ID and `<SNS-Topic-ARN>` with your SNS topic ARN.

  4. **Creating a CloudWatch Dashboard:**
     - In the CloudWatch Console, create a new dashboard with `"yourname"`.
     - Add widgets to monitor CPU utilization, network traffic, and your custom metrics.
  
- **Test:**
  - Simulate high CPU load on the public EC2 instance:
    ```
    yes > /dev/null &
    ```
  - Verify that the `HighCPUAlarm` triggers and sends a notification via SNS.
  - Check that the custom metrics appear on the CloudWatch dashboard.

---

## 4. Auditing with CloudTrail

### Configuring CloudTrail for Comprehensive Auditing

- **Objective:** Enable AWS CloudTrail to log all API calls and account activities, ensuring security and compliance.
  
- **Steps:**

  1. **Create a CloudTrail Trail:**
     - Open the CloudTrail Dashboard, click `Create trail`.
     - Name: `SecureTrail"yourname"`.
     - Apply to all regions: Yes.
     - In paralele Create dedicated bucket for Cloudtrail - Name:`CloudTrail"yourname"`
     - Specify previous S3 bucket for log storage (enable encryption with KMS) 
     - Enable log file validation and CloudWatch logs integration.

  3. **Setup SNS Notifications:**
     - Create an SNS topic for security alerts with "yourname" in the namie of the topic.
     - Subscribe your email to the SNS topic.
     - Configure the CloudTrail trail to send notifications to this SNS topic for specific events (e.g., unauthorized access attempts).

  4. **Analyze CloudTrail Logs:**
     - Use the AWS Management Console or Athena to query and analyze logs.
     - Example query to find all IAM-related activities:
       ```sql
       SELECT eventTime, eventName, userIdentity.userName, sourceIPAddress
       FROM cloudtrail_logs
       WHERE eventSource = 'iam.amazonaws.com'
       ```

- **Test:**
  - Perform actions such as creating/deleting resources. Check CloudTrail logs to verify these activities are recorded.
  - Review SNS notifications to ensure they trigger correctly on specific events.

---

## 5. Data Protection and Encryption with AWS KMS

### Implementing Advanced Encryption Techniques with AWS KMS

- **Objective:** Protect sensitive data using AWS KMS for encryption across various AWS services.

- **Steps:**

  1. **Create a Customer Managed Key (CMK):**
     - Go to the KMS Dashboard and create a new CMK.
     - Configure key policies, restricting usage to necessary IAM users and roles.
     - Enable automatic key rotation.

  2. **Encrypt S3 Buckets:**
     - Create an S3 bucket for sensitive data and enable server-side encryption using your CMK.
     - Update bucket policies to enforce encryption and restrict access.

  3. **Cross-Service Encryption:**
     - **EBS Volumes:** Ensure that new EBS volumes are encrypted using the CMK.
     - **RDS Databases:** Encrypt RDS databases using the CMK during creation.
     - **Lambda Functions:** Encrypt environment variables in Lambda functions using the CMK.
  
  4. **Monitor Key Usage:**
     - Enable CloudTrail to log all KMS activities.
     - Set up CloudWatch Alarms for unusual key usage patterns.

- **Test:**
  - Upload sensitive data to the S3 bucket and verify it is encrypted with the CMK.
  - Check CloudTrail logs for key usage activities and validate that they are recorded.
  - Create a CloudWatch alarm that triggers on unauthorized key access attempts.

---

## Best Practices

- **IAM Policies:** Follow the principle of least privilege.
- **Monitoring:** Regularly review CloudWatch metrics and CloudTrail logs.
- **Encryption:** Encrypt sensitive data at rest and in transit using KMS.
- **Resource Cleanup:** Terminate resources created during the workshop to avoid unnecessary costs.

---

## Cleanup Instructions

1. **Terminate EC2 Instances:** Terminate all EC2 instances created.
2. **Delete Security Groups and ACLs:** Remove any custom Security Groups and Network ACLs.
3. **Remove CloudWatch Alarms:** Delete all CloudWatch alarms.
4. **Delete CloudTrail Trails:** Delete CloudTrail trails and associated S3 buckets.
5. **Revoke IAM Permissions:** Revoke temporary IAM permissions.
6. **KMS Key Deletion:** Schedule deletion of any CMKs if they are not needed.

---
