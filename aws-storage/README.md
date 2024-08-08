# Integrated AWS Storage Lab Guide

Welcome to the Integrated AWS Storage Lab Guide. This guide provides step-by-step instructions for deploying and configuring AWS storage services using the AWS Command Line Interface (CLI). This lab is designed to help you understand and implement essential AWS storage services, including S3, EBS, and EFS, in an integrated manner.

By following this guide, you will gain hands-on experience with setting up an S3 bucket, deploying an EC2 instance with an attached EBS volume, and configuring an EFS file system for shared access.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- Ubuntu environment to run the CLI commands. (preferred)
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)
- [AWS CLI configured on your machine](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- 
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

## C. Deploy an S3 Bucket

1. **Create an S3 Bucket**:

    ```bash
    aws s3api create-bucket --bucket ${NAME}-bucket --region $(aws configure get region) --create-bucket-configuration LocationConstraint=$(aws configure get region)
    aws s3api put-bucket-tagging --bucket ${NAME}-bucket --tagging 'TagSet=[{Key=Name,Value='${NAME}'-bucket}]'
    echo "S3 Bucket Created: ${NAME}-bucket"
    ```

2. **Enable Versioning on the S3 Bucket**:

    ```bash
    aws s3api put-bucket-versioning --bucket ${NAME}-bucket --versioning-configuration Status=Enabled
    echo "Versioning Enabled on S3 Bucket: ${NAME}-bucket"
    ```

3. **Upload a Test File to the S3 Bucket**:

    ```bash
    echo "Hello, AWS S3!" > testfile.txt
    aws s3 cp testfile.txt s3://${NAME}-bucket/
    echo "Test File Uploaded to S3 Bucket: ${NAME}-bucket"
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

    - **Attach Read-Only Access Policy to the Role**:

        ```bash
        aws iam attach-role-policy --role-name EC2SSMRole-${NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
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

## E. Deploy an EBS Volume

1. **Create an EBS Volume**:

    - First, find a valid availability zone:

        ```bash
        AVAILABILITY_ZONE=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
        echo "Using Availability Zone: $AVAILABILITY_ZONE"

        # If AVAILABILITY_ZONE is empty, there's a problem with the retrieval
        if [ -z "$AVAILABILITY_ZONE" ]; then
          echo "Failed to retrieve availability zone. Please check your AWS CLI configuration and region."
          exit 1
        fi
        ```

    - Then create the EBS volume:

        ```bash
        VOLUME_ID=$(aws ec2 create-volume --size 10 --region $(aws configure get region) --availability-zone $AVAILABILITY_ZONE --volume-type gp2 --query 'VolumeId' --output text)
        echo "EBS Volume Created: $VOLUME_ID"

        # If VOLUME_ID is empty, the volume creation failed
        if [ -z "$VOLUME_ID" ]; then
          echo "Failed to create EBS volume. Please check your AWS CLI configuration and try again."
          exit 1
        fi

        # Tag the EBS volume
        aws ec2 create-tags --resources $VOLUME_ID --tags Key=Name,Value=${NAME}-ebs
        echo "EBS Volume Tagged: $VOLUME_ID"
        ```

2. **Attach the EBS Volume to an EC2 Instance**:

    ```bash
    aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/sdf
    echo "EBS Volume Attached to Instance: $INSTANCE_ID"
    ```

3. **Format and Mount the EBS Volume**:

    ```bash
    # Connect to the instance using SSM
    aws ssm start-session --target $INSTANCE_ID

    # Inside the SSM session, run the following commands:
    sudo mkfs -t ext4 /dev/xvdf
    sudo mkdir /mnt/data-ebs
    sudo mount /dev/xvdf /mnt/data-ebs
    echo "EBS Volume Mounted at /mnt/data-ebs"
    ```

## F. Deploy an EFS File System

1. **Create an EFS File System**:

    ```bash
    FILE_SYSTEM_ID=$(aws efs create-file-system --creation-token ${NAME}-efs --tags Key=Name,Value=${NAME}-efs --query 'FileSystemId' --output text)
    echo "EFS File System Created: $FILE_SYSTEM_ID"
    ```

2. **Create Mount Targets for the EFS File System**:

    ```bash
    for subnet in $(aws ec2 describe-subnets --query 'Subnets[*].SubnetId' --output text); do
        aws efs create-mount-target --file-system-id $FILE_SYSTEM_ID --subnet-id $subnet --security-groups $PRIVATE_SG_ID
    done
    echo "Mount Targets Created for EFS File System: $FILE_SYSTEM_ID"
    ```

3. **Mount the EFS File System on an EC2 Instance**:

    ```bash
    # Connect to the instance using SSM
    aws ssm start-session --target $INSTANCE_ID

    # Inside the SSM session, run the following commands:
    sudo yum install -y amazon-efs-utils
    sudo mkdir /mnt/efs
    sudo mount -t efs $FILE_SYSTEM_ID:/ /mnt/efs
    echo "EFS File System Mounted at /mnt/efs"
    ```

## G. Clean Up Resources

1. **Delete the S3 Bucket and Objects**:

    ```bash
    aws s3 rb s3://${NAME}-bucket --force
    echo "S3 Bucket Deleted: ${NAME}-bucket"
    ```

2. **Detach and Delete the EBS Volume**:

    ```bash
    aws ec2 detach-volume --volume-id $VOLUME_ID
    aws ec2 delete-volume --volume-id $VOLUME_ID
    echo "EBS Volume Deleted: $VOLUME_ID"
    ```

3. **Delete the EFS File System**:

    ```bash
    aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID
    echo "EFS File System Deleted: $FILE_SYSTEM_ID"
    ```

4. **Terminate the EC2 Instance**:

    ```bash
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    echo "EC2 Instance Terminated: $INSTANCE_ID"
    ```


## OPTIONAL Deploy an S3 Bucket with Advanced Configurations

1. **Create an S3 Bucket**:

    ```bash
    aws s3api create-bucket --bucket ${NAME}-bucket --region $(aws configure get region) --create-bucket-configuration LocationConstraint=$(aws configure get region)
    aws s3api put-bucket-tagging --bucket ${NAME}-bucket --tagging 'TagSet=[{Key=Name,Value='${NAME}'-bucket}]'
    echo "S3 Bucket Created: ${NAME}-bucket"
    ```

2. **Set up a Bucket Policy**:

    ```bash
    cat <<EoF > bucket-policy.json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": "*",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::${NAME}-bucket/*"
        }
      ]
    }
    EoF

    aws s3api put-bucket-policy --bucket ${NAME}-bucket --policy file://bucket-policy.json
    echo "Bucket Policy Applied to ${NAME}-bucket"
    ```

3. **Enable Server-Side Encryption**:

    ```bash
    aws s3api put-bucket-encryption --bucket ${NAME}-bucket --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }
      ]
    }'
    echo "Server-Side Encryption Enabled on ${NAME}-bucket"
    ```

4. **Set Up a Lifecycle Policy**:

    ```bash
    cat <<EoF > lifecycle-policy.json
    {
      "Rules": [
        {
          "ID": "Move to Standard-IA after 30 days",
          "Prefix": "",
          "Status": "Enabled",
          "Transitions": [
            {
              "Days": 30,
              "StorageClass": "STANDARD_IA"
            }
          ]
        },
        {
          "ID": "Expire after 365 days",
          "Prefix": "",
          "Status": "Enabled",
          "Expiration": {
            "Days": 365
          }
        }
      ]
    }
    EoF

    aws s3api put-bucket-lifecycle-configuration --bucket ${NAME}-bucket --lifecycle-configuration file://lifecycle-policy.json
    echo "Lifecycle Policy Applied to ${NAME}-bucket"
    ```

5. **Set Up Cross-Region Replication**:

    First, create a destination bucket in a different region.

    ```bash
    aws s3api create-bucket --bucket ${NAME}-bucket-replica --region us-east-1 --create-bucket-configuration LocationConstraint=us-east-1
    aws s3api put-bucket-tagging --bucket ${NAME}-bucket-replica --tagging 'TagSet=[{Key=Name,Value='${NAME}'-bucket-replica}]'
    echo "Replication Destination Bucket Created: ${NAME}-bucket-replica"
    ```

    Then, set up the replication configuration.

    ```bash
    cat <<EoF > replication-config.json
    {
      "Role": "arn:aws:iam::<account-id>:role/<role-name>",
      "Rules": [
        {
          "Status": "Enabled",
          "Prefix": "",
          "Destination": {
            "Bucket": "arn:aws:s3:::${NAME}-bucket-replica",
            "StorageClass": "STANDARD"
          }
        }
      ]
    }
    EoF

    aws s3api put-bucket-replication --bucket ${NAME}-bucket --replication-configuration file://replication-config.json
    echo "Cross-Region Replication Enabled from ${NAME}-bucket to ${NAME}-bucket-replica"
    ```

By following these steps, you have successfully deployed and managed an integrated set of AWS storage services. This lab provides foundational skills for working with AWS storage solutions in a cohesive environment.
