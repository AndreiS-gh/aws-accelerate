# AWS Networking Lab Deployment Guide

Welcome to the AWS Networking Lab Deployment Guide. This guide provides step-by-step instructions for deploying and configuring AWS networking components using the AWS Command Line Interface (CLI). This lab is designed to help you understand and implement essential AWS networking services, including Virtual Private Cloud (VPC), subnets, internet gateways, route tables, and more.

By following this guide, you will gain hands-on experience with setting up VPCs, subnets, and routing, and you will also learn how to deploy and manage EC2 instances within your network. We’ll also cover setting up load balancers and configuring DNS with Route 53 to ensure your application running inside the EC2 is accessible from the internet.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- An AWS account along with your access key and secret.
- AWS CLI configured on your machine.
- Ubuntu environment to run the CLI commands.
- AWS CLI configured with default credentials and region.
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)

## B. Configure AWS CLI

1. **Set up AWS CLI Credentials**: Run `aws configure` and set your default region (e.g., `eu-central-1`), providing your access key and secret when prompted.

2. **Set Environment Variable**: Set the `NAME` environment variable to ensure unique resource names:

    ```bash
    export NAME=your_unique_identifier
    export DOMAIN_NAME=your_dns_domain_name
    ```

    Replace `your_unique_identifier` with a unique string for each user.

3. **Optional: Export Variables if Previously Created**: If you have previously created and saved variables in a script file, you can load them into your environment. Run the following command to source your `export-vars.sh` file:

    ```bash
    source export-vars.sh
    ```

## C. Deploy a VPC

1. **Create a VPC**:

    ```bash
    VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=${NAME}-vpc
    echo "VPC ID: $VPC_ID"
    ```

2. **Create Subnets**:

    - **Public Subnet 1**:

        ```bash
        PUBLIC_SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text) --query 'Subnet.SubnetId' --output text)
        aws ec2 create-tags --resources $PUBLIC_SUBNET_ID_1 --tags Key=Name,Value=${NAME}-public-subnet-1
        echo "Public Subnet 1 ID: $PUBLIC_SUBNET_ID_1"
        ```

    - **Public Subnet 2**:

        ```bash
        PUBLIC_SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text) --query 'Subnet.SubnetId' --output text)
        aws ec2 create-tags --resources $PUBLIC_SUBNET_ID_2 --tags Key=Name,Value=${NAME}-public-subnet-2
        echo "Public Subnet 2 ID: $PUBLIC_SUBNET_ID_2"
        ```

    - **Private Subnet 1**:

        ```bash
        PRIVATE_SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text) --query 'Subnet.SubnetId' --output text)
        aws ec2 create-tags --resources $PRIVATE_SUBNET_ID_1 --tags Key=Name,Value=${NAME}-private-subnet-1
        echo "Private Subnet 1 ID: $PRIVATE_SUBNET_ID_1"
        ```

    - **Private Subnet 2**:

        ```bash
        PRIVATE_SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text) --query 'Subnet.SubnetId' --output text)
        aws ec2 create-tags --resources $PRIVATE_SUBNET_ID_2 --tags Key=Name,Value=${NAME}-private-subnet-2
        echo "Private Subnet 2 ID: $PRIVATE_SUBNET_ID_2"
        ```

3. **Create an Internet Gateway and Attach to VPC**:

    ```bash
    IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
    aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=${NAME}-igw
    echo "Internet Gateway ID: $IGW_ID"
    ```

4. **Create Route Tables and Associate with Subnets**:

    - **Public Route Table**:

        ```bash
        PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
        aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=Name,Value=${NAME}-public-rt
        aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
        aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID_1 --route-table-id $PUBLIC_ROUTE_TABLE_ID
        aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID_2 --route-table-id $PUBLIC_ROUTE_TABLE_ID
        echo "Public Route Table ID: $PUBLIC_ROUTE_TABLE_ID"
        ```

    - **Private Route Table**:

        ```bash
        PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
        aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID --tags Key=Name,Value=${NAME}-private-rt
        aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID_1 --route-table-id $PRIVATE_ROUTE_TABLE_ID
        aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID_2 --route-table-id $PRIVATE_ROUTE_TABLE_ID
        echo "Private Route Table ID: $PRIVATE_ROUTE_TABLE_ID"
        ```

5. **Create a NAT Gateway for the Private Subnets**:

    - **Elastic IP for NAT Gateway**:

        ```bash
        EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
        echo "Elastic IP Allocation ID: $EIP_ALLOC_ID"
        ```

    - **NAT Gateway**:

        ```bash
        NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID_1 --allocation-id $EIP_ALLOC_ID --query 'NatGateway.NatGatewayId' --output text)
        aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value=${NAME}-nat-gw
        echo "NAT Gateway ID: $NAT_GW_ID"
        ```

    - **Route for Private Subnets**:

        ```bash
        aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
        ```

## D. Deploy an EC2 Instance

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

    - **Create Instance Profile and Add Role to the Profile**:

        ```bash
        INSTANCE_PROFILE_NAME=${NAME}-InstanceProfile
        aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
        aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name EC2SSMRole-${NAME}
        ```

2. **Launch an EC2 Instance in the Private Subnet**:

    ```bash
    KEY_NAME="${NAME}-keypair"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "Created and set permissions for key pair: ${KEY_NAME}"
    AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "Images[0].ImageId" --output text)
    echo "AMI ID: $AMI_ID"
    INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --key-name $KEY_NAME --iam-instance-profile Name=$INSTANCE_PROFILE_NAME --subnet-id $PRIVATE_SUBNET_ID_1 --query 'Instances[0].InstanceId' --output text)
    aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=${NAME}-ec2
    echo "EC2 Instance ID: $INSTANCE_ID"
    ```

## E. Set Up Load Balancer and Route 53

1. **Create an Application Load Balancer**:

    - **Create Security Group for Load Balancer**:

        ```bash
        SG_LB_ID=$(aws ec2 create-security-group --group-name ${NAME}-lb-sg --description "Security group for load balancer" --vpc-id $VPC_ID --query 'GroupId' --output text)
        aws ec2 create-tags --resources $SG_LB_ID --tags Key=Name,Value=${NAME}-lb-sg
        aws ec2 authorize-security-group-ingress --group-id $SG_LB_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
        echo "Load Balancer Security Group ID: $SG_LB_ID"
        ```

    - **Create the Load Balancer**:

        ```bash
        LB_ARN=$(aws elbv2 create-load-balancer --name ${NAME}-lb --subnets $PUBLIC_SUBNET_ID_1 $PUBLIC_SUBNET_ID_2 --security-groups $SG_LB_ID --query 'LoadBalancers[0].LoadBalancerArn' --output text)
        echo "Load Balancer ARN: $LB_ARN"
        ```

2. **Create a Target Group and Register the EC2 Instance**:

    ```bash
    TG_ARN=$(aws elbv2 create-target-group --name ${NAME}-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --query 'TargetGroups[0].TargetGroupArn' --output text)
    echo "Target Group ARN: $TG_ARN"
    aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID
    ```

3. **Create a Listener for the Load Balancer**:

    ```bash
    aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN
    ```

## F. Configure Route 53

1. **Export the Hosted Zone ID**:

    ```bash
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name == '${DOMAIN_NAME}.'].Id | [0]" --output text | cut -d'/' -f3)
    echo "Hosted Zone ID: $HOSTED_ZONE_ID"
    ```

2. **Create DNS Record for Load Balancer**:

    ```bash
    aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "'${NAME}'-webapp.'${DOMAIN_NAME}'",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "'$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)'",
                    "DNSName": "'$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)'",
                    "EvaluateTargetHealth": false
                }
            }
        }]
    }'
    ```

## G. Expose Website

1. **Install Web Server on EC2 Instance Using SSM**:

    ```bash
    # VALIDATE INSTANCE IS REGISTERED IN SSM 
    aws ssm describe-instance-information --query 'InstanceInformationList[?InstanceId==`'$INSTANCE_ID'`]'

    # Install Apache HTTP Server
    # Create a temporary JSON file for the parameters
    cat <<EoF > ssm-command.json
    {
      "InstanceIds": ["$INSTANCE_ID"],
      "DocumentName": "AWS-RunShellScript",
      "Comment": "Install Apache",
      "Parameters": {
        "commands": [
          "sudo yum update -y",
          "sudo yum install -y httpd",
          "sudo systemctl start httpd",
          "sudo systemctl enable httpd",
          "echo '<html><body><h1>Hello World</h1></body></html>' | sudo tee /var/www/html/index.html"
        ]
      }
    }
    EoF

    # Execute the SSM command using the JSON file
    aws ssm send-command --cli-input-json file://ssm-command.json
    ```

2. **Ensure Security Group Configurations**:

    ```bash
    # Replace with your security group IDs
    EC2_SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
    LB_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${NAME}-lb-sg --query 'SecurityGroups[0].GroupId' --output text)

    # Allow HTTP traffic from the Load Balancer's security group to the EC2 instance
    aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $LB_SG_ID
    ```

3. **Verify Load Balancer Setup**:

    ```bash
    # Confirm the target group is correctly set up
    aws elbv2 describe-target-groups --target-group-arns $TG_ARN

    # Confirm the Load Balancer listener is correctly set up to forward to the target group
    aws elbv2 describe-listeners --load-balancer-arn $LB_ARN
    ```

### Accessing the Website

After completing these steps, your website should be accessible via the DNS name set up in Route 53. Navigate to `http://${NAME}-webapp.${DOMAIN_NAME}` in your browser to see the "Hello World" page or ..

    ```bash
    curl http://${NAME}-webapp.${DOMAIN_NAME}
    ```
