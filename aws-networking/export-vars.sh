#!/bin/bash

# Ensure NAME environment variable is set
#export NAME=add_your_name
# uncomment and change with your manually created domain
export DOMAIN_NAME=changeme.net

# Get VPC ID
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME}-vpc" --query 'Vpcs[0].VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Get Public Subnet ID 1
export PUBLIC_SUBNET_ID_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${NAME}-public-subnet-1" --query 'Subnets[0].SubnetId' --output text)
echo "Public Subnet ID 1: $PUBLIC_SUBNET_ID_1"

# Get Public Subnet ID 2
export PUBLIC_SUBNET_ID_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${NAME}-public-subnet-2" --query 'Subnets[0].SubnetId' --output text)
echo "Public Subnet ID 2: $PUBLIC_SUBNET_ID_2"

# Get Private Subnet ID 1
export PRIVATE_SUBNET_ID_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${NAME}-private-subnet-1" --query 'Subnets[0].SubnetId' --output text)
echo "Private Subnet ID 1: $PRIVATE_SUBNET_ID_1"

# Get Private Subnet ID 2
export PRIVATE_SUBNET_ID_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=${NAME}-private-subnet-2" --query 'Subnets[0].SubnetId' --output text)
echo "Private Subnet ID 2: $PRIVATE_SUBNET_ID_2"

# Get Internet Gateway ID
export IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=${NAME}-igw" --query 'InternetGateways[0].InternetGatewayId' --output text)
echo "Internet Gateway ID: $IGW_ID"

# Get Public Route Table ID
export PUBLIC_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${NAME}-public-rt" --query 'RouteTables[0].RouteTableId' --output text)
echo "Public Route Table ID: $PUBLIC_ROUTE_TABLE_ID"

# Get Private Route Table ID
export PRIVATE_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${NAME}-private-rt" --query 'RouteTables[0].RouteTableId' --output text)
echo "Private Route Table ID: $PRIVATE_ROUTE_TABLE_ID"

# Get NAT Gateway ID
export NAT_GW_ID=$(aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=${NAME}-nat-gw" --query 'NatGateways[0].NatGatewayId' --output text)
echo "NAT Gateway ID: $NAT_GW_ID"

# Get Elastic IP Allocation ID for NAT Gateway
export EIP_ALLOC_ID=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=${NAME}-eip" --query 'Addresses[0].AllocationId' --output text)
echo "Elastic IP Allocation ID: $EIP_ALLOC_ID"

# Get EC2 Instance ID
export INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NAME}-ec2" --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "EC2 Instance ID: $INSTANCE_ID"

# Get Load Balancer ARN
export LB_ARN=$(aws elbv2 describe-load-balancers --names ${NAME}-lb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "Load Balancer ARN: $LB_ARN"

# Get Target Group ARN
export TG_ARN=$(aws elbv2 describe-target-groups --names ${NAME}-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "Target Group ARN: $TG_ARN"

# Get Hosted Zone ID
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --query 'HostedZones[0].Id' --output text)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Print all exported variables
echo "All environment variables have been set."
