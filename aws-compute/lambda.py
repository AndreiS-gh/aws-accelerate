import boto3
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
  # Get host from event
  host = event['headers']['host']
  logger.info(f"Request made from host: {host}")

  return event