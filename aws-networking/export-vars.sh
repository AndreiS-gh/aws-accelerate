#!/bin/bash

# Ensure NAME environment variable is set
# export NAME=add_your_name
# Uncomment and change with your manually created domain
#export DOMAIN_NAME=changeme.net

# Function to check if a resource is in a desired state
check_resource_state() {
    local resource_type=$1
    local resource_id=$2
    local state_key=$3
    local desired_state=$4

    # Query the resource state
    current_state=$(aws $resource_type describe --$resource_id --query "$state_key" --output text 2>/dev/null)

    # Check if the current state matches the desired state
    if [ "$current_state" == "$desired_state" ]; then
        echo "Resource is in the desired state ($desired_state)."
        return 1
    else
        echo "Resource is not in the desired state. Current state: $current_state."
        return 0
    fi
}

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

# Check and export NAT Gateway ID only if not deleted
if [ "$NAT_GW_ID" != "None" ]; then
    if check_resource_state "ec2" "nat-gateways/$NAT_GW_ID" "NatGateways[0].State" "deleted"; then
        export NAT_GW_ID=None
    fi
fi

# Get Elastic IP Allocation ID for NAT Gateway
export EIP_ALLOC_ID=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=${NAME}-eip" --query 'Addresses[0].AllocationId' --output text)
echo "Elastic IP Allocation ID: $EIP_ALLOC_ID"

# Get EC2 Instance ID
export INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NAME}-ec2" --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "EC2 Instance ID: $INSTANCE_ID"

# Check and export EC2 Instance ID only if not terminated
if [ "$INSTANCE_ID" != "None" ]; then
    if check_resource_state "ec2" "instances/$INSTANCE_ID" "Reservations[0].Instances[0].State.Name" "terminated"; then
        export INSTANCE_ID=None
    fi
fi

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
