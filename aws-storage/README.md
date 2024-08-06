# AWS Storage Lab Guide

Welcome to the AWS Storage Lab Guide. This guide provides step-by-step instructions for deploying and configuring AWS storage services using the AWS Command Line Interface (CLI). This lab is designed to help you understand and implement essential AWS storage services, including S3, EBS, and EFS.

By following this guide, you will gain hands-on experience with setting up S3 buckets, EBS volumes, and EFS file systems, and you will also learn how to manage these resources effectively.

## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- Ubuntu environment to run the CLI commands. (preferred)
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)
- [AWS CLI configured on your machine](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An AWS account along with your access key and secret. Once you have your credentials, [login](https://console.aws.amazon.com/) to the console, then [generate a new Access KEY](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) and save it securely as a CSV.

## B. Configure AWS CLI

1. **Set up AWS CLI Credentials**: Run `aws configure` and set your default region (e.g., `us-west-2`), default output format (e.g., `json`) providing your access key and secret when prompted.

2. **Set Environment Variable**: Set the `NAME` environment variable to ensure unique resource names:

    ```bash
    export NAME=your_unique_identifier
    ```

    Replace `your_unique_identifier` with a unique string for each user.

3. **Optional: Export Variables if Previously Created**: If you have previously created and saved variables in a script file, you can load them into your environment. Run the following command to source your `export-vars.sh` file:

    ```bash
    source export-vars.sh
    ```

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

1. **Create an EC2 Key Pair**:

    ```bash
    KEY_NAME="${NAME}-keypair"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "Created and set permissions for key pair: ${KEY_NAME}"
    ```

2. **Launch an EC2 Instance in a Private Subnet**:

    ```bash
    PRIVATE_SUBNET_ID_1=subnet-your-private-subnet-id-1  # Replace with your private subnet ID
    PRIVATE_SG_ID=sg-your-private-security-group-id  # Replace with your private security group ID
    
    INSTANCE_ID=$(aws ec2 run-instances --image-id $(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "Images[0].ImageId" --output text) --count 1 --instance-type t2.micro --key-name $KEY_NAME --security-group-ids $PRIVATE_SG_ID --subnet-id $PRIVATE_SUBNET_ID_1 --query 'Instances[0].InstanceId' --output text)
    aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=${NAME}-instance
    echo "EC2 Instance Created: $INSTANCE_ID"
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
        ```

2. **Attach the EBS Volume to an EC2 Instance**:

    ```bash
    aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/sdf
    echo "EBS Volume Attached to Instance: $INSTANCE_ID"
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
    ssh -i ${NAME}-keypair.pem ec2-user@$INSTANCE_PRIVATE_IP
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

