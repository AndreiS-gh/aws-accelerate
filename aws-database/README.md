# AWS Database Lab Guide

Welcome to the AWS Database Lab Guide.
This guide provides step-by-step instructions for deploying and configuring AWS DynamoDB, RDS (Relational Database Service) Instances and Aurora using the AWS Console.

By following this guide, you will gain hands-on experience with creating and using DynamoDB tables, creating a RDS database cluster with read replica and changing an instance type and creating an Aurora DB.


## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- Ubuntu environment to run the CLI commands. (preferred)
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)
- [AWS CLI configured on your machine](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An AWS account along with your access key and secret. Once you have your credentials, [login](https://console.aws.amazon.com/) to the console, then [generate a new Access KEY](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) and save it securely as a CSV.
- Existing VPC and subnets.


## B. Configure AWS CLI and Set Environment Variables

1. **Set up AWS CLI Credentials** Run `aws configure` and set your default region (e.g., `eu-central-1`), default output format (e.g., `text`) providing your access key and secret when prompted.


## C. DynamoDB

1. **Create a standard topic**
- Go to DynamoDB > Tables > Click `Create table`
- Entter a `Table name` e.g. firstname-lastname-dynamodb
- Unde `Table settings` select `Customize settings`
- Under `Read/write capacity settings` select `Provisioned` Capacity mode
- For `Read capacity` disable `Auto scaling` and chabge `Provisioned capacity units` to `
- For `Write capacity` disable `Auto scaling` and chabge `Provisioned capacity units` to `
- Under `Secondary indexes` click `Create local index` with the below properties
```	
    Sort key: Rating, Number
	Index name: Rating-index
	Attribute projections: All
```    
- Under `Secondary indexes` click `Create global index` with the below properties
```	
    Partition key: Trend, String
	Sort key: SongTitle, String
	Index name: Trend-SongTitle-index
    Attribute projections: Only keys
```    
- Click `Create table`

2. **Create 5 items**
- Go to `DynamoDB` > `Explore items`  > Select your table
- Click `Create item`
- Add 3 items
e.g.

| Artist | Song | Rating | Trend |
| --- | --- | --- | --- |
| Shaboozey | A Bar Song | 1 | Up |
| Sabrina Carpenter | Espresso | 2 | Stable |
| Sabrina Carpenter | Taste | 3 | Down |


3. **Scan and query**
- Go to `DynamoDB` > `Explore items` and select your table
- Expand `Scan or query items`
- Run a `Scan` on the table
- Now run a `Query`. See how the `Partition key` needs to be an exact match
- Run a scan on the `Trend-SongTitle-index` index


## D. RDS Aurora

1. **Test CloudWatch Schedule**
- Go to Amazon RDS > Databases > Click `Create databse`
- Standard create
- Select `Aurora (MySQL Compatible)`
- Under Templates select `Free tier`
- DB instance identifier: `firstname-lastname-aurora`
- Under `Credentials management` select `Self managed` and click `Auto generate password`
- Under `Instance configuration` select `Serverless v2`
- Enter 0.5 for `Minimum capacity (ACUs)`
- Leave the rest to default values and click `Create database`
- Click `View connection details` to view the credentials

2. **Create read replica**
- Go to Amazon RDS > Databases
- Select your database
- Click `Actions` > `Add reader`
- Add a DB instance identifier. e.g. `firstname-lastname-aurora-2`
- Click `Add reader`

4. **Failover**
- Go to Amazon RDS > Databases
- Select your database writer instance. e.g. `firstname-lastname-aurora`
- Click `Actions` > `Failover`

## E. RDS Instances

1. **Create standard queue**
- Go to Amazon RDS > Databases > Click `Create databse`
- Standard create
- Select `MySQL`
- Under Templates select `Dev/Test`
- DB instance identifier: `firstname-lastname-rds`
- Under `Credentials management` select `Self managed` and click `Auto generate password`
- Leave the rest to default values and click `Create database`
- Click `View connection details` and save the credentials

2. **Connect to DB**
- Go to Amazon RDS > Databases
- Click on your database name and copy the endpoint from `Connectivity & security` tab
- Connect to the Bastion EC2 using Session manager
- Connect to the database using the below command:
```
mysql -u USERNAME -h HOSTNAMEORIP DATABASENAME -p
```

3. **Create read replica**
- Go to Amazon RDS > Databases
- Select your database
- Click `Actions` > `Create read replica`
- Add a DB instance identifier. e.g. `firstname-lastname-replica`
- Under `Availability` make sure `Multi-AZ DB instance` is selected
- Click `Create read replica`

4. **Promote replica**
- Go to Amazon RDS > Databases
- Select your database
- Click `Actions` > `Promote`

5. **Create multi AZ cluster from standard DB**
- Go to Amazon RDS > Databases
- Select your database
- Click `Actions` > `Convert to Multi AZ deployment`

- Go to Amazon RDS > Subnet groups
- Create a new DB subnetgroup
- Select all AZs
- Select all private subnets
- Click `Create`

- Go to Amazon RDS > Parameter groups
- Click `Create`
- Select `MySQL Community` for Engine type and `mysql8.0` for group family
- Click `Create`
- Click your parameter group and then click `Edit` in the top right
- Modify `gtid-mode` and `enforce_gtid_consistency` to `ON`

- Go to Amazon RDS > Databases
- Select your database
- Click `Modify`
- Expand `Additional configuration`
- From `DB parameter group` select your parameter group and click `Continue`
- Select `Apply immediately` and click `Modify DB instance`
- Select your database > click `Actions` > `Reboot` > `Confirm`

- Go to Amazon RDS > Databases
- Select your database
- Click `Actions` > `Create read replica`
- Add a DB instance identifier. e.g. `firstname-lastname-cluster`
- Under `Availability` select `Multi-AZ DB Cluster`
- Choose your new subnet group under `DB subnet group`
- Click `Create read replica`


## F. Delete resources

- DynamoDB tables
- Databases
- DB subnet groups
- DB parameter groups


## Useful links
- Managing DynamoDB indexes: 
```https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html```
- install mysql on Amazon Linux
```
wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
dnf install mysql80-community-release-el9-1.noarch.rpm -y
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
dnf install mysql-community-client -y # client
dnf install mysql-community-server -y # server
```