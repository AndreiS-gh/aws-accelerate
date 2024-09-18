# AWS Compute Lab Guide

Welcome to the AWS App Integration Lab Guide.
This guide provides step-by-step instructions for deploying and configuring AWS compute services using the AWS Command Line Interface (CLI) or Console.
This lab is designed to help you understand and implement essential AWS services like SQS, SNS and CloudWatch.

By following this guide, you will gain hands-on experience with creating a SQS and how to send/view messages, creating a SNS and how to add subscriptions, use CloudWatch to search logs, expose EC2 metrics and create dashboards.


## A. Pre-Requisites

Before you begin, ensure you have the following ready:

- Ubuntu environment to run the CLI commands. (preferred)
- `jq` is installed (for Ubuntu run: `sudo apt-get update && sudo apt install jq`)
- [AWS CLI configured on your machine](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An AWS account along with your access key and secret. Once you have your credentials, [login](https://console.aws.amazon.com/) to the console, then [generate a new Access KEY](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) and save it securely as a CSV.
- Existing VPC and subnets.


## B. Configure AWS CLI and Set Environment Variables

1. **Set up AWS CLI Credentials** Run `aws configure` and set your default region (e.g., `eu-central-1`), default output format (e.g., `text`) providing your access key and secret when prompted.


## C. Simple Notification Service (SNS)

1. **Create a standard topic**
- Go to Amazon SNS > Topics > Click `Create topic`
- Select Standard type
- Add a name for your e.g. "lastname_firstname_sns"
- Make sure Encryption is not set
- Click `Create topic`

2. **Create subscription**
- Go to Amazon SNS > Subscriptions > Click `Create subscription`
- Select your topic ARN
- Select Email or Email-JSON for protocol 
- Add your email as an endpoint
- Click `Create subscription`

3. **Confirm subscription in your email**

4. **Test topic**
- Go to Amazon SNS > Topics > Click your topic
- Click `Publish message`
- Add a Subject and a Message and click `Publish message`
- In a short time, you should receive an email with the message you just typed


## D. Simple Queue Service (SQS)

1. **Create standard queue**
- Go to Amazon SQS > Queues > Click `Create queue`
- Select Standard type
- Add a name e.g. "lastname_firstname_sqs"
- Click `Create queue`

2. **Test SQS**
- Go to Amazon SQS > Queues > Clik your queue
- Click `Send and receive messages`
- Add a message and click `Send message`
- Scroll down to the `Receive messages` section and click `Poll for messages`
- Your message should appear on the bottom of the screen. You can check the message content

3. **Subscribe to SNS**
- Go to Amazon SQS > Queues > Clik your queue
- Scroll down to `SNS subscriptions` and click `Subscribe to Amazon SNS topic`
- Select you SNS topic and click `Save`

4. **Test SNS subscription**
- Go to Amazon SNS > Topics > Click your topic
- Click `Publish message`
- Add a Subject and a Message and click `Publish message`
- Go to Amazon SQS > Queues > Clik your queue
- Click `Send and receive messages`
- Scroll down to the `Receive messages` section and click `Poll for messages`
- View the latest message


## E. CloudWatch

1. **Test CloudWatch Schedule**
- Go to CloudWatch > Event Buses > Schedules
- Clikc `Create schedule`
- Enter a name and description
- Select an occurence in a the 5 minutes
- Set flexible window to `Off`
- On the next window, select `Amazon SNS Publish` template
- Scroll down and select your topic
- Enter a message and click `Next`
- Select DELETE under `Action after schedule completion`
- Click `Next` and then `Create schedule`
- Go back to schedules and verify that your schdule exists
- Wait for the time to reach the scheduled time. You should receive an email with the message you typed
- Refresh the Schedules. Your schedule should be gone.
- The same message you received in your email should be in the SQS now. 
-  Go to your queue and `Poll for messages`

2. **Create Log group**
- Go to CloudWatch > Log groups
- Click `Create log group`
- Under `Log group name` add a name in the following format `/aws-accelerate/lastname_firstname_log`
- Set retention to 1 week
- Click `Create`

3. **Create an EC2 instance**
- Go to EC2 > Instances
- Click `Launch instaces`
- Add a name e.g. "lastname_firstname_ec2"
- Under `Key pair` select `Proceed without a key pair`
- Under `Network settings` select the `default` security group
- Under `Advanced details` select `accelerate-labs-InstanceProfile` instance profile
- `Launch instance`

4. **Configure CloudWatch agent**
- Connect to your EC2 instance usign Session Manager and switch to `root` user 
```
sudo su -
```
- Install Amazon CloudWatch agent
```
sudo yum install amazon-cloudwatch-agent
```
- `CloudWatchAgentServerPolicy` and `AmazonSSMManagedInstanceCore` policies have already been attached to accelerate-labs-InstanceProfile
- Copy content of file `config.json` to `/opt/aws/amazon-cloudwatch-agent/bin/config.json` on your EC2
- Start and enable cloudwatch agent
```
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
```
- Check that agent is running
```
amazon-cloudwatch-agent-ctl -m ec2 -a status
```
- In AWS Console, go to EC2 > Instances and click on your instance
- Go to `Monitoring` tab and look at the new metrics (mem_used_percent and disk_used_percent)
(Include metrics in the CWAgent namespace must be toggled on)

5. **CloudWatch Dashboard**
- Go to CloudWatch > Dashboards
- Click `Create dashboard`
- Add a name and click `Create dashboard`
- Choose a Line widget type and click `Next`
- From CWAgent namespace, ImageId, InstanceId, InstanceType, select the mem_used_percent for your EC2 instance
- Click `Create widget`
- Click on the + sign on the top right to create another widget
- Choose a `bar` type widget and click `Next`
- From CWAgent namespace, ImageId, InstanceId, InstanceType, device, fstype, path, filter by your instance ID and select all metrics
- Click `Create widget`

## F. Delete resources

- cw dashboard
- ec2 instance
- cw log group
- sqs
- sns subscriptions and topics
