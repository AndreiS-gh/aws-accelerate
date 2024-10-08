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

1. **Set up AWS CLI Credentials** Run `aws configure` and set your default region (e.g., `us-west-2`), default output format (e.g., `json`) providing your access key and secret when prompted.

2. **Set Environment Variables** Set the following environment variables to ensure unique resource names and use existing VPC and subnets:

Replace the placeholders with your unique values.
```bash
export NAME="replace_with_your_unique_identifier"
export AWS_ACCESS_KEY_ID="replace_with_your_access_key"
export AWS_SECRET_ACCESS_KEY="replace_with_your_secret_key"
export AWS_DEFAULT_REGION="eu-central-1"

### Get VPC ID
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values= accelerate-labs-vpc" --query 'Vpcs[0].VpcId' --output text)

### Get Public Subnet ID 1
export PUBLIC_SUBNET_ID_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=accelerate-labs-public-subnet-1" --query 'Subnets[0].SubnetId' --output text)

### Get Public Subnet ID 2
export PUBLIC_SUBNET_ID_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values= accelerate-labs-public-subnet-2" --query 'Subnets[0].SubnetId' --output text)

### Get Private Subnet ID 1
export PRIVATE_SUBNET_ID_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values= accelerate-labs-private-subnet-1" --query 'Subnets[0].SubnetId' --output text)

### Get Private Subnet ID 2
export PRIVATE_SUBNET_ID_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values= accelerate-labs-private-subnet-2" --query 'Subnets[0].SubnetId' --output text)

echo "VPC ID: $VPC_ID"
echo "Public Subnet ID 1: $PUBLIC_SUBNET_ID_1"
echo "Public Subnet ID 2: $PUBLIC_SUBNET_ID_2"
echo "Private Subnet ID 1: $PRIVATE_SUBNET_ID_1"
echo "Private Subnet ID 2: $PRIVATE_SUBNET_ID_2"
```


## C. EC2 operations

01. **Create a key pair with your name**

```bash
export KEY_NAME="${NAME}-keypair"
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
chmod 400 ${KEY_NAME}.pem
```

02. **Launch an EC2 instance in the public subnet (make sure ZScaler is disabled)**
- AMI: `Amazon Linux 2023 AMI`
- Instance Type: `t2.micro`
- Key pair: the key you created
- Network: `accelerate-labs-vpc`, Subnet: `accelerate-labs-public-subnet-1`
- Auto-assign public IP: `Enable`
- Security Group: `Create security group`. Use your name for the SG name and description. `e.g. john-doe`
- Inbound Security Group Rules: select "SSH" under `Type` and "My IP" under `Source type` (again, make sure ZScaler is disabled)
- Launch the instance.

03. **View if instance is ready to connect**
- Select your instance
- Go to Actions > Monitor and troubleshoot > Get instance screenshot

04. **Try tonnect to the EC2 instance using SSM**

05. **Connect to the EC2 instance using SSH to troubleshoot SSM**
- check that SSM is installed and running at startup: systemctl status amazon-ssm-agent
- if it's not, follow this procedure to install: https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-al2.html
- attach instance profile (accelerate-labs-InstanceProfile)
- reboot instance

06. **Install Nginx and create a new AMI**
```bash
yum install nginx -y
systemctl enable nginx
systemctl start nginx
systemctl status nginx
curl localhost
```
- Stop instance
- Create AMI (Actions > Image and templates > Create image)
- Wait for the AMI to be ready
- Terminate the public instance

07. **Launch a new EC2 instance in the private subnet from the new AMI**
- AMI: previuously created AMI
- Instance Type: `t2.micro`
- Key pair: the key you created
- Network: `accelerate-labs-vpc`, Subnet: `accelerate-labs-private-subnet-1`
- Auto-assign public IP: `Disable`
- Security Group: `Select existing security group`. Use the SG you created in the previous step
- Advanced details > IAM instance profile: Select > accelerate-labs-InstanceProfile
- Advanced details > User data: 
    ```bash
    #!/bin/bash
    hostname -s > /usr/share/nginx/html/index.html
    echo "" >> /usr/share/nginx/html/index.html
    date >> /usr/share/nginx/html/index.html
    ```
- Launch the instance.

08. **Connect to the EC2 instance using SSM and test Nginx**
```
curl localhost
```

09. **Update security groups and connect to private instance using SSH**
- start public instance
- and SSH and HTTP access to VPC CIDR
- connect to public instance
- copy your SSH key to the public instance and set correct permissions
- run a curl against the IP of the private instance
- ssh from public instance to private instance

10. **Change the EC2 instance type**
- connect to the public instance and check it's memory
- stop the instance
- change instance type to small
- start the instance
- connect to the instance and check the memory again

11. **Create a static webpage using Autoscaling Groups and Load Balancers**
- Create a launch template
  * Add name and description
  * Choose my AMIs and select your newly create AMI
  * Instance Type: `t2.small`
  * Key pair: the key you created
  * Subnet: `Don't include in launch template`
  * Security Group: `Select existing security group`. Select the SG you created
  * Advanced details 
    > Select the IAM instance profile
    > User data: 
      ```bash
      #!/bin/bash
      hostname -s > /usr/share/nginx/html/index.html
      echo "---" >> /usr/share/nginx/html/index.html
      date >> /usr/share/nginx/html/index.html
      ```

- Create ASG
  * Select your template
  * Add a name and click next
  * Select the accelerate-labs-vpc
  * Select the 2 private subnets and click next
  * Attach to a new load balancer > Application Load Balancer > Internet-facing
  * Select the public subnets
  * Create target groups
  * Turn on ELB health checks
  * Health check grace period: 30 seconds
  * Enable group metrics collection within CloudWatch and click next
  * Capacity: min 1, desired 1, max 3
  * Target tracking scaling policy
  * Average CPU utilizaiton
  * Target value:30 and click Next
  * Tags: Name > Your name with `-asg at` the end and click Next
  * Create Auto Scaling group

- While the resources are creating, update your security group and give yourself access on port 80

12. **Check the webpage from the LB url.**

13. **Connect to one of the EC2 instances and increase load**
- run the yes command"
```
yes > /dev/null &
```
- check alarms

14. **Check the webpage from the LB url. Refresh multiple times to view the different launch date times**


## D. Lambda operations

1. **A python hello world lambda function from blueprints**

2. **Create a test event for the lambda function and test it**

3. **Update the code of the lambda with the code in lambda.py and deploy the new function**

4. **Update the test with the example request from request.json and test the new function**

5. **Attach the function to your load balancer and access the url of your ALB**

6. **Check the lambda logs**

## E. Delete resources

- lambda funciton
- load balancer
- target groups
- ASG
- launch template
- AMI and snapshot
- ec2 instances
- cloudwatch log groups
- security groups
- key pair