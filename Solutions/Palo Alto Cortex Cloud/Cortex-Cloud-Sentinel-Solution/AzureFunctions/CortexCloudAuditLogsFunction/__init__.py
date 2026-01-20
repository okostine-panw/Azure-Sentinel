import datetime
import logging
import json
import requests
import hashlib
import hmac
import base64
import os
import azure.functions as func

# Environment variables
CORTEX_CLOUD_FQDN = os.environ.get('CortexCloudFqdn')
CORTEX_API_KEY_ID = os.environ.get('CortexCloudApiKeyId')
CORTEX_API_KEY = os.environ.get('CortexCloudApiKey')
WORKSPACE_ID = os.environ.get('WorkspaceId')
WORKSPACE_KEY = os.environ.get('WorkspaceKey')
LOG_TYPE = 'CortexCloudAuditLogs'

def main(mytimer: func.TimerRequest) -> None:
    """
    Azure Function to poll Cortex Cloud Audit Logs API and send to Log Analytics
    Runs every 15 minutes
    """
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due:
        logging.info('The timer is past due!')

    logging.info(f'Python timer trigger function ran at {utc_timestamp}')

    try:
        # Get audit logs from Cortex Cloud
        audit_logs = get_cortex_cloud_audit_logs()
        
        if audit_logs:
            logging.info(f'Retrieved {len(audit_logs)} audit logs from Cortex Cloud')
            
            # Send to Log Analytics
            send_to_log_analytics(audit_logs, LOG_TYPE)
            logging.info(f'Successfully sent {len(audit_logs)} audit logs to Log Analytics')
        else:
            logging.info('No audit logs retrieved from Cortex Cloud')
            
    except Exception as e:
        logging.error(f'Error in function execution: {str(e)}')
        raise


def get_cortex_cloud_audit_logs():
    """
    Call Cortex Cloud Audit Logs API
    """
    url = f'https://api-{CORTEX_CLOUD_FQDN}/public_api/v1/audits/management_logs'
    
    headers = {
        'x-xdr-auth-id': CORTEX_API_KEY_ID,
        'Authorization': CORTEX_API_KEY,
        'Content-Type': 'application/json'
    }
    
    # Get logs from last 15 minutes
    timestamp_gte = int((datetime.datetime.utcnow() - datetime.timedelta(minutes=15)).timestamp() * 1000)
    
    payload = {
        "request_data": {
            "filters": [
                {
                    "field": "timestamp",
                    "operator": "gte",
                    "value": timestamp_gte
                }
            ],
            "search_from": 0,
            "search_to": 100
        }
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        
        data = response.json()
        
        # Extract audit logs from reply.data
        logs = data.get('reply', {}).get('data', [])
        
        # Transform to Log Analytics format
        transformed_logs = []
        for log in logs:
            transformed = {
                'TimeGenerated': datetime.datetime.utcnow().isoformat(),
                'EventId': str(log.get('audit_id', '')),
                'EventType': str(log.get('audit_type', '')),
                'User': str(log.get('user_name', '')),
                'Action': str(log.get('action', '')),
                'Resource': str(log.get('resource', '')),
                'Result': str(log.get('result', '')),
                'SourceIP': str(log.get('source_ip', '')),
                'RawData': json.dumps(log)
            }
            transformed_logs.append(transformed)
        
        return transformed_logs
        
    except requests.exceptions.RequestException as e:
        logging.error(f'Error calling Cortex Cloud API: {str(e)}')
        raise


def build_signature(customer_id, shared_key, date, content_length, method, content_type, resource):
    """
    Build the authorization signature for Log Analytics Data Collector API
    """
    x_headers = 'x-ms-date:' + date
    string_to_hash = method + "\n" + str(content_length) + "\n" + content_type + "\n" + x_headers + "\n" + resource
    bytes_to_hash = bytes(string_to_hash, encoding="utf-8")  
    decoded_key = base64.b64decode(shared_key)
    encoded_hash = base64.b64encode(hmac.new(decoded_key, bytes_to_hash, digestmod=hashlib.sha256).digest()).decode()
    authorization = "SharedKey {}:{}".format(customer_id, encoded_hash)
    return authorization


def send_to_log_analytics(data, log_type):
    """
    Send data to Log Analytics workspace using Data Collector API
    """
    body = json.dumps(data)
    
    method = 'POST'
    content_type = 'application/json'
    resource = '/api/logs'
    rfc1123date = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
    content_length = len(body)
    
    signature = build_signature(WORKSPACE_ID, WORKSPACE_KEY, rfc1123date, content_length, method, content_type, resource)
    
    uri = f'https://{WORKSPACE_ID}.ods.opinsights.azure.com{resource}?api-version=2016-04-01'
    
    headers = {
        'content-type': content_type,
        'Authorization': signature,
        'Log-Type': log_type,
        'x-ms-date': rfc1123date
    }
    
    try:
        response = requests.post(uri, data=body, headers=headers, timeout=30)
        response.raise_for_status()
        logging.info(f'Data successfully sent to Log Analytics. Status: {response.status_code}')
    except requests.exceptions.RequestException as e:
        logging.error(f'Error sending data to Log Analytics: {str(e)}')
        raise
