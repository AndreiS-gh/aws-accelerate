### Updated AWS CLI Deployment Guide

```markdown
# AWS CLI Deployment Guide

Welcome to the AWS CLI Deployment Guide. This guide walks you through the process of setting up and deploying infrastructure on AWS using AWS CLI. We cover everything from pre-requisites to deploying a VPC with public and private subnets. Let's get started.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- An AWS account along with your access key and secret.
- AWS CLI configured on your machine.
- Ubuntu environment to run the CLI commands.
- AWS CLI configured with default credentials and region.

## B. Configure AWS CLI

1. **Set up AWS CLI Credentials**: Run `aws configure` and set your default region (e.g., `eu-central-1`), providing your access key and secret when prompted.

2. **Set Environment Variable**: Set the `NAME` environment variable to ensure unique resource names:

    ```bash
    export NAME=your_unique_identifier
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

1. **Launch an EC2 Instance in the Private Subnet**:

    ```bash
    KEY_NAME="${NAME}-keypair"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "Created and set permissions for key pair: ${KEY_NAME}"
    AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "Images[0].ImageId" --output text)
    echo "AMI ID: $AMI_ID"
    INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name ${NAME}-keypair --subnet-id $PRIVATE_SUBNET_ID_1 --query 'Instances[0].InstanceId' --output text)
    aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=${NAME}-ec2
    echo "EC2 Instance ID: $INSTANCE_ID"
    ```

## E. Set Up Load Balancer and Route 53

1. **Create an Application Load Balancer**:

    - **Create Security Group for Load Balancer**:

        ```bash
        SG_LB_ID=$(aws ec2 create-security-group --group-name ${NAME}-lb-sg --description "Security group for load balancer" --vpc-id $VPC_ID --query 'GroupId' --output text)
        aws ec2 authorize-security-group-ingress --group-id $SG_LB_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
        echo "Security Group ID for Load Balancer: $SG_LB_ID"
        ```

    - **Create Load Balancer**:

        ```bash
        LB_ARN=$(aws elbv2 create-load-balancer --name ${NAME}-lb --subnets $PUBLIC_SUBNET_ID_1 $PUBLIC_SUBNET_ID_2 --security-groups $SG_LB_ID --query 'LoadBalancers[0].LoadBalancerArn' --output text)
        echo "Load Balancer ARN: $LB_ARN"
        ```

    - **Create Target Group**:

        ```bash
        TG_ARN=$(aws elbv2 create-target-group --name ${NAME}-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --query 'TargetGroups[0].TargetGroupArn' --output text)
        echo "Target Group ARN: $TG_ARN"
        ```

    - **Register Targets**:

        ```bash
        aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID
        ```

    - **Create Listener**:

        ```bash
        aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN
        ```

2. **Create a Route 53 Record Set**:

    - **Get Hosted Zone ID**:

        ```bash
        DOMAIN_NAME="atostrainighub.net"
        HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name=='$DOMAIN_NAME.'].Id" --output text)
        echo "Hosted Zone ID: $HOSTED_ZONE_ID"
        ```

    - **Create Record Set**:

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

## F. Set Up CloudFront

1. **Create a CloudFront Distribution**:

    To set up a CloudFront distribution to use your Application Load Balancer as the origin, you will need to configure the distribution with your Load Balancer's DNS name and appropriate settings.

    ```bash
    aws cloudfront create-distribution --origin-domain-name $(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)
    ```

Congratulations! You have successfully deployed your infrastructure on AWS using the AWS CLI. Your VPC, EC2 instance, Load Balancer, Route 53 record, and CloudFront distribution are now set up and ready to use.

Remember to clean up your resources when they are no longer needed to avoid unnecessary charges.
```


## G. Expose Website

1. **SSH into EC2 Instance and Set Up Web Server**:

    ```bash
    EC2_PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicDnsName' --output text)

    ssh -i ${NAME}-keypair.pem ec2-user@$EC2_PUBLIC_DNS << 'EOF'
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "<html><body><h1>Hello World</h1></body></html>" | sudo tee /var/www/html/index.html
    exit
    EOF
    ```

2. **Verify the Website**:

    - Open your browser and navigate to `http://${NAME}-webapp.${DOMAIN_NAME}`. You should see the "Hello World" page.

## H. Clean Up (Optional)

If you wish to delete the resources created, run your cleanup script only if the `CLEANUP_LAB` environment variable is set to `true`:

```bash
#!/bin/bash

if [ "$CLEANUP_LAB" == "true" ]; then
    # Cleanup steps
    ./cleanup.sh
else
    echo "CLEANUP_LAB is not set to true. Skipping cleanup."
fi