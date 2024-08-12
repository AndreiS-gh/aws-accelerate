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
  - Install stress
    ```
    sudo yum install stress
    ```
  - Run stress test
    ```
    stress --cpu 2
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
     - In paralel Create dedicated bucket for Cloudtrail - Name:`CloudTrail"yourname"`
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
## 5. AWS KMS

### Creating and Securing Customer Managed Keys with AWS KMS

- **Steps:**
- ***Create a Single-Region Symmetrical KMS Key***
    -  Navigate to Amazon S3 using the Services menu or the unified search bar.
    -  Confirm you see a bucket that starts with the cloud-user prefix.
    -  Click on the bucket, and navigate to the Properties tab.
    -  Using the search bar, type and select Key Management Service.
    -  Under Get started now, click Create a key.
    -  Under Key type, ensure Symmetric is selected.
    -  Under key usage, ensure Encrypt and decrypt is selected.
    -  Under Advanced options, ensure Regionality is set to Single-Region key, and Key material origin is set to KMS.Click Next.
    -  Under Alias, enter `"youruser"` .Click Next.
    -  Under Key administrators, click on the checkbox next to cloud_user.
    -  Under Key deletion, ensure Allow key administrators to delete this key is selected.
    -  Click Next until you get to the Review page, then click Finish.

- ***Set Up Amazon S3 Default Encryption via KMS***
    -  Navigate to Amazon S3 using the shortcut bar or the unified search bar.
    -  Create a new  bucket, and navigate to the Properties tab.
    -  Scroll down to Default encryption, and click Edit.
    -  Under Default encryption, set the following values:
    -  Encryption key type: Select AWS Key Management Service key (SSE-KMS).
    -  AWS KMS key: Select Choose from your AWS KMS keys.
    -  Under Available AWS KMS keys, click on the dropdown menu and select `"youruser"`.
    -  Bucket Key: Select Enable.
    -  Click Save changes.
    -  Navigate to the Objects tab, and click on Upload.
    -  Choose a file you would like to upload.
    -  Click Upload.
    -  Once you see the Upload succeeded banner, click Close in the upper right corner.
    -  Click on the file you uploaded.
    -  Scroll down to Server-side encryption settings to confirm you successfully implemented the KMS key.

- ***Schedule AWS KMS Key Deletion
    -  Under Encryption key ARN, click on the key ARN.
    -  In the upper right corner, click on the key actions dropdown menu, and select Schedule key deletion.
    -  Under Waiting period, enter 7 days.
    -  Under Confirmation, select the checkbox next to Confirm that you want to schedule these keys for deletion after a 7 day waiting period.
    -  Click Schedule deletion.
      
---
## 6. AWS Security Solutions

### Use AWS Native Security Solutions

- **Objective:** Use AWS Native solutions to check on environment security according to various standards.

- **Steps:**
  1. ** In AWS Services Search bar type "Security Hub" and open it **
  2. ** Check the available standards and see how many vulnerabilities present on each of them **
  3. ** In AWS Services Search bar type "Trusted Advisor" and open it **
  4. ** Go to Recommendations" and see what issues are present that you can resolve **
  5. ** In AWS Services Search bar type "AWS Artifact" and open it **
  6. ** Check available standard reports that can be extracted **
  7. ** In AWS Services Search bar type "AWS Inspector" and open it **
  8. ** Check available menu options **
  
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
