# PowerShell Script to create custom tables in Log Analytics for Cortex Cloud DCR
# Run this BEFORE deploying the DCR

# Variables - UPDATE THESE
$WorkspaceName = "your-workspace-name"
$ResourceGroup = "rg-sentinel-cortexcloud"

Write-Host "Creating custom tables in Log Analytics workspace: $WorkspaceName" -ForegroundColor Green

# Get workspace ID
$WorkspaceId = (az monitor log-analytics workspace show `
  --resource-group $ResourceGroup `
  --workspace-name $WorkspaceName `
  --query customerId -o tsv)

Write-Host "Workspace ID: $WorkspaceId" -ForegroundColor Cyan

# Function to create a custom table
function Create-CustomTable {
    param(
        [string]$TableName,
        [string[]]$Columns
    )
    
    Write-Host "`nCreating table: $TableName..." -ForegroundColor Yellow
    
    $columnsString = $Columns -join " "
    
    az monitor log-analytics workspace table create `
        --resource-group $ResourceGroup `
        --workspace-name $WorkspaceName `
        --name $TableName `
        --columns $columnsString `
        --retention-time 90
}

# 1. Create CortexCloudIssues_CL table
Write-Host "`n=== Creating CortexCloudIssues_CL ===" -ForegroundColor Magenta
Create-CustomTable -TableName "CortexCloudIssues_CL" -Columns @(
    "TimeGenerated=DateTime",
    "IssueId=String",
    "Title=String",
    "Description=String",
    "Severity=String",
    "Status=String",
    "Category=String",
    "AffectedAssets=Dynamic",
    "CreatedTime=DateTime",
    "ModifiedTime=DateTime",
    "Tags=Dynamic",
    "RawData=String"
)

# 2. Create CortexCloudCases_CL table
Write-Host "`n=== Creating CortexCloudCases_CL ===" -ForegroundColor Magenta
Create-CustomTable -TableName "CortexCloudCases_CL" -Columns @(
    "TimeGenerated=DateTime",
    "CaseId=String",
    "CaseNumber=String",
    "Title=String",
    "Description=String",
    "Priority=String",
    "Status=String",
    "AssignedTo=String",
    "RelatedIssues=Dynamic",
    "CreatedTime=DateTime",
    "UpdatedTime=DateTime",
    "ClosedTime=DateTime",
    "Tags=Dynamic",
    "RawData=String"
)

# 3. Create CortexCloudEndpoints_CL table
Write-Host "`n=== Creating CortexCloudEndpoints_CL ===" -ForegroundColor Magenta
Create-CustomTable -TableName "CortexCloudEndpoints_CL" -Columns @(
    "TimeGenerated=DateTime",
    "EndpointId=String",
    "EndpointName=String",
    "EndpointType=String",
    "OS=String",
    "OSVersion=String",
    "IPAddress=String",
    "MACAddress=String",
    "Status=String",
    "LastSeenTime=DateTime",
    "AgentVersion=String",
    "Domain=String",
    "Tags=Dynamic",
    "RawData=String"
)

# 4. Create CortexCloudAuditLogs_CL table
Write-Host "`n=== Creating CortexCloudAuditLogs_CL ===" -ForegroundColor Magenta
Create-CustomTable -TableName "CortexCloudAuditLogs_CL" -Columns @(
    "TimeGenerated=DateTime",
    "EventId=String",
    "EventType=String",
    "User=String",
    "Action=String",
    "Resource=String",
    "Result=String",
    "SourceIP=String",
    "RawData=String"
)

Write-Host "`n=== All tables created successfully! ===" -ForegroundColor Green
Write-Host "`nWait 2-3 minutes for tables to fully provision, then deploy the DCR." -ForegroundColor Yellow
