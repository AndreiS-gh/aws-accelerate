# AWS Compute Lab Guide

Welcome to the AWS Compute Lab Guide.
This guide provides step-by-step instructions for deploying and configuring AWS compute services using the AWS Command Line Interface (CLI) or Console.
This lab is designed to help you understand and implement essential AWS compute services like EC2 and Lambda.

By following this guide, you will gain hands-on experience with deploying an EC2 instance, connecting to the instance in different ways, changing instance settings, using userdata scripts, creating Autoscaling groups, creating and deploying lambda functions.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- Ubuntu environment to run the CLI commands. (preferred)
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)
- [AWS CLI configured on your machine](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An AWS account along with your access key and secret. Once you have your credentials, [login](https://console.aws.amazon.com/) to the console, then [generate a new Access KEY](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) and save it securely as a CSV.
- Existing VPC and subnets.

## B. Configure AWS CLI and Set Environment Variables

1. **Set up AWS CLI Credentials**: Run `aws configure` and set your default region (e.g., `us-west-2`), default output format (e.g., `json`) providing your access key and secret when prompted.

2. **Set Environment Variables**: Set the following environment variables to ensure unique resource names and use existing VPC and subnets:

    ```bash
    export NAME=your_unique_identifier
    export VPC_ID=your_vpc_id
    export PRIVATE_SUBNET_ID_1=your_private_subnet_id_1
    export PRIVATE_SUBNET_ID_2=your_private_subnet_id_2    
    ```

    Replace the placeholders with your unique values.

## C. EC2 operations

01. **Create a key pair with your name**:

    ```bash
    export KEY_NAME="${NAME}-keypair"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    ```

02. **Launch an EC2 instance in the public subnet**:

03. **Upload a Test File to the S3 Bucket**:

04. **Try tonnect to the EC2 instance using SSM**:

05. **Connect to the EC2 instance using ssh**:

06. **Install SSM agent and create a new AMI**:

07. **Launch a new EC2 instance in the private subnet from the new AMI**:

08. **Add an instance role to the EC2 instance**:

09. **Connect to the EC2 instance using SSM**:

11. **Change the EC2 instance type**:

12. **Add a start/stop schedule for the EC2 instance**:

13. **Create a static webpage using Autoscaling Groups and Load Balancers**:

    - **Connect to the intance in the private network**:
    - **Install Nginx and create a new AMI**:
    - **Create a new ASG with 1 minimum, 2 maximum and 1 desired number of instances**:
    - **Add the current date to the the nginx default webpage and automatic start for nginx in the userdata script**:
    - **Create a Load Balancer in the public subnets that has this ASG as a target**:
    - **Connect to an EC2 instance from the ASG and increase it's CPU load**:
        ```bash
        yes&
        ```    
    - **Check webpage status from the LB url. Refresh multiple times to view the different launch date times**:


## D. Lambda operations

1. **Create IAM Role and Instance Profile for SSM**:

    - **Create IAM Role**:

        ```bash
        aws iam create-role --role-name EC2SSMRole-${NAME} --assume-role-policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "Service": "ec2.amazonaws.com"
              },
              "Action": "sts:AssumeRole"
            }
          ]
        }'
        ```

    - **Attach SSM Managed Instance Core Policy to the Role**:

        ```bash
        aws iam attach-role-policy --role-name EC2SSMRole-${NAME} --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        ```
