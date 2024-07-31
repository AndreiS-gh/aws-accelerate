#!/bin/bash

# Ensure DOMAIN_NAME environment variable is set
if [ -z "$DOMAIN_NAME" ]; then
    echo "DOMAIN_NAME environment variable is not set."
    exit 1
fi

# Fetch Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name == '${DOMAIN_NAME}.'].Id | [0]" --output text | cut -d'/' -f3)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Ensure CLEANUP_LAB is set to true to enable cleanup
export CLEANUP_LAB=true 

# Load environment variables from export-vars.sh if it exists
if [ -f export-vars.sh ]; then
    source export-vars.sh
else
    echo "export-vars.sh file not found. Please make sure it exists and contains the necessary variables."
    exit 1
fi

# Check if CLEANUP_LAB is set to true
if [ "$CLEANUP_LAB" != "true" ]; then
    echo "CLEANUP_LAB is not set to true. Exiting cleanup process."
    exit 0
fi

# Function to check if a resource exists
check_resource() {
    local resource=$1
    if [ -z "$resource" ] || [ "$resource" == "None" ]; then
        echo "Resource does not exist or failed to retrieve."
        return 1
    else
        return 0
    fi
}

# Function to delete a resource
delete_resource() {
    local command=$1
    echo "Deleting resource with command: $command"
    if eval "$command"; then
        echo "Successfully deleted resource."
    else
        echo "Failed to delete resource."
    fi
}

# Function to disassociate Elastic IP addresses
unmap_public_ips() {
    local vpc_id=$1
    echo "Fetching Elastic IPs associated with VPC $vpc_id..."

    # Get all Elastic IP addresses associated with the VPC
    PUBLIC_IPS=$(aws ec2 describe-addresses --filters Name=network-interface.association.network-interface-id,Values=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --query 'InternetGateways[0].Attachments[0].VpcId' --output text) --query 'Addresses[].Association.AssociationId' --output text)
    
    if [ -z "$PUBLIC_IPS" ]; then
        echo "No public IPs found associated with VPC $vpc_id."
        return 0
    fi

    echo "Disassociating public IPs..."
    for IP in $PUBLIC_IPS; do
        echo "Disassociating IP $IP..."
        aws ec2 disassociate-address --association-id $IP
    done

    echo "All public IPs have been disassociated."
}

echo "Starting cleanup process..."

# Delete Load Balancer and its dependencies
if check_resource "$LB_ARN"; then
    LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --query 'Listeners[0].ListenerArn' --output text)
    if check_resource "$LISTENER_ARN"; then
        delete_resource "aws elbv2 delete-listener --listener-arn $LISTENER_ARN"
    fi
    delete_resource "aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN"
fi

# Delete Target Group
if check_resource "$TG_ARN"; then
    delete_resource "aws elbv2 delete-target-group --target-group-arn $TG_ARN"
fi

# Delete Route 53 record set
if check_resource "$HOSTED_ZONE_ID"; then
    ALIAS_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)
    ALIAS_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)
    if check_resource "$ALIAS_HOSTED_ZONE_ID" && check_resource "$ALIAS_DNS_NAME"; then
        delete_resource "aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
            \"Changes\": [{
                \"Action\": \"DELETE\",
                \"ResourceRecordSet\": {
                    \"Name\": \"${NAME}-webapp.${DOMAIN_NAME}\",
                    \"Type\": \"A\",
                    \"AliasTarget\": {
                        \"HostedZoneId\": \"$ALIAS_HOSTED_ZONE_ID\",
                        \"DNSName\": \"$ALIAS_DNS_NAME\",
                        \"EvaluateTargetHealth\": false
                    }
                }
            }]
        }'"
    fi
fi

# Delete EC2 Instance
if check_resource "$INSTANCE_ID"; then
    delete_resource "aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
fi

# Delete NAT Gateway
if check_resource "$NAT_GW_ID"; then
    delete_resource "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID"
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_ID
fi

# Release Elastic IP
if [ "$EIP_ALLOC_ID" != "None" ]; then
    delete_resource "aws ec2 release-address --allocation-id $EIP_ALLOC_ID"
fi

# Unmap public IPs before detaching and deleting Internet Gateway
if check_resource "$IGW_ID"; then
    unmap_public_ips $VPC_ID
fi

# Detach and Delete Internet Gateway
if check_resource "$IGW_ID"; then
    delete_resource "aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID"
    delete_resource "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID"
fi

# List all route tables associated with the VPC
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID --query 'RouteTables[*].RouteTableId' --output text)
# Fetch the main route table
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID --query 'RouteTables[?Associations[?Main==`true`]].RouteTableId' --output text)

for ROUTE_TABLE_ID in $ROUTE_TABLE_IDS; do
    if [ "$ROUTE_TABLE_ID" != "$MAIN_ROUTE_TABLE_ID" ]; then
        # Disassociate and delete non-main route tables
        ASSOCIATIONS=$(aws ec2 describe-route-tables --route-table-id $ROUTE_TABLE_ID --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text)
        
        for ASSOCIATION_ID in $ASSOCIATIONS; do
            delete_resource "aws ec2 disassociate-route-table --association-id $ASSOCIATION_ID"
        done

        delete_resource "aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID"
    fi
done

# Delete Subnets
for SUBNET_ID in "$PUBLIC_SUBNET_ID_1" "$PUBLIC_SUBNET_ID_2" "$PRIVATE_SUBNET_ID_1" "$PRIVATE_SUBNET_ID_2"; do
    if check_resource "$SUBNET_ID"; then
        delete_resource "aws ec2 delete-subnet --subnet-id $SUBNET_ID"
        # Handle possible dependencies
        if [ $? -ne 0 ]; then
            echo "Failed to delete subnet $SUBNET_ID due to dependencies. Please ensure no resources are using this subnet."
        fi
    fi
done

# Delete Security Group associated with the Load Balancer
SG_ID=$(aws ec2 describe-security-groups --filters Name=tag:Name,Values=$NAME --query 'SecurityGroups[0].GroupId' --output text)
if check_resource "$SG_ID"; then
    # Revoke inbound rules before deleting the security group
    INBOUND_RULES=$(aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --output json)
    if [ "$INBOUND_RULES" != "[]" ]; then
        for RULE in $(echo "$INBOUND_RULES" | jq -c '.[]'); do
            delete_resource "aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol $(echo $RULE | jq -r '.IpProtocol') --port $(echo $RULE | jq -r '.FromPort') --cidr $(echo $RULE | jq -r '.IpRanges[0].CidrIp')"
        done
    fi
    delete_resource "aws ec2 delete-security-group --group-id $SG_ID"
fi

# Delete VPC
if check_resource "$VPC_ID"; then
    delete_resource "aws ec2 delete-vpc --vpc-id $VPC_ID"
    aws ec2 wait vpc-deleted --vpc-ids $VPC_ID
fi

# Delete IAM Role and Instance Profile
ROLE_NAME="EC2SSMRole-${NAME}"
INSTANCE_PROFILE_NAME="${NAME}-InstanceProfile"

if check_resource "$ROLE_NAME" && check_resource "$INSTANCE_PROFILE_NAME"; then
    POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text)
    for POLICY in $POLICIES; do
        delete_resource "aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY"
    done

    delete_resource "aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $ROLE_NAME"
    delete_resource "aws iam delete-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME"
    delete_resource "aws iam delete-role --role-name $ROLE_NAME"
fi

echo "Cleanup process completed."
