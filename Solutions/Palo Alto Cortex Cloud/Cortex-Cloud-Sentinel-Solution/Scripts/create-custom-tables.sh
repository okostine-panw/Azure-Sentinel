#!/bin/bash
# Script to create custom tables in Log Analytics for Cortex Cloud DCR
# Run this BEFORE deploying the DCR

# Variables - UPDATE THESE
WORKSPACE_NAME="your-workspace-name"
RESOURCE_GROUP="rg-sentinel-cortexcloud"

echo "Creating custom tables in Log Analytics workspace: $WORKSPACE_NAME"

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query customerId -o tsv)

echo "Workspace ID: $WORKSPACE_ID"

# Function to create a custom table
create_custom_table() {
  local TABLE_NAME=$1
  shift
  local COLUMNS="$@"
  
  echo "Creating table: ${TABLE_NAME}..."
  
  az monitor log-analytics workspace table create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --name "${TABLE_NAME}" \
    --columns $COLUMNS \
    --retention-time 90
}

# 1. Create CortexCloudIssues_CL table
echo ""
echo "=== Creating CortexCloudIssues_CL ==="
create_custom_table "CortexCloudIssues_CL" \
  TimeGenerated=DateTime \
  IssueId=String \
  Title=String \
  Description=String \
  Severity=String \
  Status=String \
  Category=String \
  AffectedAssets=Dynamic \
  CreatedTime=DateTime \
  ModifiedTime=DateTime \
  Tags=Dynamic \
  RawData=String

# 2. Create CortexCloudCases_CL table
echo ""
echo "=== Creating CortexCloudCases_CL ==="
create_custom_table "CortexCloudCases_CL" \
  TimeGenerated=DateTime \
  CaseId=String \
  CaseNumber=String \
  Title=String \
  Description=String \
  Priority=String \
  Status=String \
  AssignedTo=String \
  RelatedIssues=Dynamic \
  CreatedTime=DateTime \
  UpdatedTime=DateTime \
  ClosedTime=DateTime \
  Tags=Dynamic \
  RawData=String

# 3. Create CortexCloudEndpoints_CL table
echo ""
echo "=== Creating CortexCloudEndpoints_CL ==="
create_custom_table "CortexCloudEndpoints_CL" \
  TimeGenerated=DateTime \
  EndpointId=String \
  EndpointName=String \
  EndpointType=String \
  OS=String \
  OSVersion=String \
  IPAddress=String \
  MACAddress=String \
  Status=String \
  LastSeenTime=DateTime \
  AgentVersion=String \
  Domain=String \
  Tags=Dynamic \
  RawData=String

# 4. Create CortexCloudAuditLogs_CL table
echo ""
echo "=== Creating CortexCloudAuditLogs_CL ==="
create_custom_table "CortexCloudAuditLogs_CL" \
  TimeGenerated=DateTime \
  EventId=String \
  EventType=String \
  User=String \
  Action=String \
  Resource=String \
  Result=String \
  SourceIP=String \
  RawData=String

echo ""
echo "=== All tables created successfully! ==="
echo ""
echo "Wait 2-3 minutes for tables to fully provision, then deploy the DCR."
echo ""
