#!/bin/bash

# Ensure NAME and DOMAIN_NAME environment variables are set
# export NAME=your_unique_identifier
export DOMAIN_NAME=atostrainighub.net

# SET THIS TO TRUE TO ENABLE CLEANUP OR EXPORT MANUALLY BEFORE RUNNING THE SCRIPT
export CLEANUP_LAB=true 

# Load environment variables from export-vars.sh if it exists
if [ -f export-vars.sh ]; then
    source export-vars.sh
fi

# Check if CLEANUP_LAB is set to true
if [ "$CLEANUP_LAB" != "true" ]; then
    echo "CLEANUP_LAB is not set to true. Exiting cleanup process."
    exit 0
fi

# Function to check if a resource exists
check_resource() {
    if [ -z "$1" ]; then
        echo "Resource does not exist or failed to retrieve."
        return 1
    else
        return 0
    fi
}

# Function to delete a resource
delete_resource() {
    eval $1
    if [ $? -ne 0 ]; then
        echo "Failed to delete resource or resource does not exist."
    else
        echo "Successfully deleted resource."
    fi
}

echo "Starting cleanup process..."

# Delete CloudFront distribution
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${NAME}-distribution'].Id" --output text)
check_resource $DISTRIBUTION_ID && delete_resource "aws cloudfront delete-distribution --id $DISTRIBUTION_ID --if-match $(aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --query 'ETag' --output text)"

# Delete Route 53 record set
delete_resource "aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
    \"Changes\": [{
        \"Action\": \"DELETE\",
        \"ResourceRecordSet\": {
            \"Name\": \"${NAME}-webapp.${DOMAIN_NAME}\",
            \"Type\": \"A\",
            \"AliasTarget\": {
                \"HostedZoneId\": \"$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)\",
                \"DNSName\": \"$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)\",
                \"EvaluateTargetHealth\": false
            }
        }
    }]
}'"

# Delete Load Balancer and its dependencies
delete_resource "aws elbv2 delete-listener --listener-arn $(aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --query 'Listeners[0].ListenerArn' --output text)"
delete_resource "aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN"
delete_resource "aws elbv2 delete-target-group --target-group-arn $TG_ARN"
delete_resource "aws ec2 delete-security-group --group-id $SG_LB_ID"

# Terminate EC2 instance
delete_resource "aws ec2 terminate-instances --instance-ids $INSTANCE_ID"

# Delete NAT Gateway
delete_resource "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID"

# Release Elastic IP
delete_resource "aws ec2 release-address --allocation-id $EIP_ALLOC_ID"

# Delete Route Tables
delete_resource "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $PUBLIC_ROUTE_TABLE_ID --query 'RouteTables[0].Associations[0].RouteTableAssociationId' --output text)"
delete_resource "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $PUBLIC_ROUTE_TABLE_ID --query 'RouteTables[0].Associations[1].RouteTableAssociationId' --output text)"
delete_resource "aws ec2 delete-route-table --route-table-id $PUBLIC_ROUTE_TABLE_ID"
delete_resource "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $PRIVATE_ROUTE_TABLE_ID --query 'RouteTables[0].Associations[0].RouteTableAssociationId' --output text)"
delete_resource "aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $PRIVATE_ROUTE_TABLE_ID --query 'RouteTables[0].Associations[1].RouteTableAssociationId' --output text)"
delete_resource "aws ec2 delete-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID"

# Delete Subnets
delete_resource "aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID_1"
delete_resource "aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID_2"
delete_resource "aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID_1"
delete_resource "aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID_2"

# Detach and delete Internet Gateway
delete_resource "aws ec2 detach-internet-gateway --internet-gateway-id
