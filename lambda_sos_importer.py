import json
import boto3
from datetime import datetime
import uuid
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function specifically for importing SOS data from S3 to DynamoDB
    Only processes files in the 'sos/' folder
    """
    
    logger.info(f"SOS Importer - Event received: {json.dumps(event)}")
    
    try:
        # Initialize AWS clients
        s3_client = boto3.client('s3')
        dynamodb = boto3.resource('dynamodb')
        
        # Handle different event types
        if 'Records' in event:
            # S3 event with Records
            for record in event['Records']:
                if record.get('eventSource') == 'aws:s3':
                    bucket = record['s3']['bucket']['name']
                    key = record['s3']['object']['key']
                    process_sos_file(s3_client, dynamodb, bucket, key)
        
        elif 'source' in event and event['source'] == 'aws.s3':
            # EventBridge S3 event
            bucket = event['detail']['bucket']['name']
            key = event['detail']['object']['key']
            process_sos_file(s3_client, dynamodb, bucket, key)
        
        elif 'bucket' in event:
            # Manual batch import
            bucket = event['bucket']
            prefix = event.get('prefix', 'sos/')  # Default to sos/ prefix
            batch_import_sos(s3_client, dynamodb, bucket, prefix)
        
        else:
            logger.error(f"Unknown event format: {event}")
            return {'statusCode': 400, 'body': 'Unknown event format'}
        
        return {'statusCode': 200, 'body': 'SOS import completed successfully'}
        
    except Exception as e:
        logger.error(f"SOS Importer - Error: {str(e)}")
        return {'statusCode': 500, 'body': f'Error: {str(e)}'}

def process_sos_file(s3_client, dynamodb, bucket, key):
    """Process a single SOS file from S3"""
    
    try:
        # Only process files in sos/ folder
        if not key.startswith('sos/'):
            logger.info(f"Skipping file {key} - not in sos/ folder")
            return
        
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        data = json.loads(response['Body'].read())
        
        logger.info(f"Processing SOS file: {key}")
        
        # Check if SOS table exists
        table_name = 'sos'
        try:
            table = dynamodb.Table(table_name)
            table.load()  # This will raise an exception if table doesn't exist
            logger.info(f"SOS table {table_name} exists and is accessible")
        except Exception as table_error:
            logger.error(f"SOS table {table_name} does not exist or is not accessible: {str(table_error)}")
            return
        
        # Create SOS item
        item = create_sos_item(data, key)
        
        logger.info(f"Attempting to insert SOS item into {table_name} table: {json.dumps(item, default=str)}")
        
        # Insert into DynamoDB
        response = table.put_item(Item=item)
        
        logger.info(f"Successfully imported SOS {key} to {table_name} table. Response: {response}")
        
    except Exception as e:
        logger.error(f"Error processing SOS file {key}: {str(e)}")

def batch_import_sos(s3_client, dynamodb, bucket, prefix):
    """Import all SOS files with given prefix"""
    
    try:
        # Ensure prefix is for SOS files
        if not prefix.startswith('sos/'):
            prefix = 'sos/' + prefix.lstrip('/')
        
        logger.info(f"Starting batch import of SOS files with prefix: {prefix}")
        
        # List all objects with prefix
        paginator = s3_client.get_paginator('list_objects_v2')
        page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)
        
        count = 0
        for page in page_iterator:
            if 'Contents' in page:
                for obj in page['Contents']:
                    if obj['Key'].endswith('.json') and obj['Key'].startswith('sos/'):
                        process_sos_file(s3_client, dynamodb, bucket, obj['Key'])
                        count += 1
        
        logger.info(f"SOS batch import completed: {count} files processed")
        
    except Exception as e:
        logger.error(f"SOS batch import error: {str(e)}")

def create_sos_item(data, s3_key):
    """Create DynamoDB item for SOS data"""
    
    # Generate unique ID
    item_id = str(uuid.uuid4())
    
    # Convert float values to strings in originalData to avoid DynamoDB float type errors
    def convert_floats_to_strings(obj):
        """Recursively convert float values to strings in nested data structures"""
        if isinstance(obj, dict):
            return {key: convert_floats_to_strings(value) for key, value in obj.items()}
        elif isinstance(obj, list):
            return [convert_floats_to_strings(item) for item in obj]
        elif isinstance(obj, float):
            return str(obj)
        else:
            return obj
    
    # Convert floats to strings in the original data
    converted_data = convert_floats_to_strings(data)
    
    # Base item
    item = {
        'id': item_id,
        's3Key': s3_key,
        'importedAt': datetime.utcnow().isoformat(),
        'originalData': converted_data
    }
    
    # Add SOS-specific fields
    item.update({
        'userId': data.get('userId', 'unknown'),
        'category': data.get('category', 'unknown'),
        'latitude': str(data.get('latitude', '0')),  # Convert to string
        'longitude': str(data.get('longitude', '0')),  # Convert to string
        'timestamp': data.get('timestamp', datetime.utcnow().isoformat()),
        'status': data.get('status', 'active')
    })
    
    # Add optional fields if they exist
    if 'userName' in data:
        item['userName'] = data['userName']
    if 'userEmail' in data:
        item['userEmail'] = data['userEmail']
    if 'userPhone' in data:
        item['userPhone'] = data['userPhone']
    if 'userAddress' in data:
        item['userAddress'] = data['userAddress']
    if 'accuracy' in data:
        item['accuracy'] = str(data['accuracy'])
    if 'altitude' in data:
        item['altitude'] = str(data['altitude'])
    if 'speed' in data:
        item['speed'] = str(data['speed'])
    if 'heading' in data:
        item['heading'] = str(data['heading'])
    
    return item
