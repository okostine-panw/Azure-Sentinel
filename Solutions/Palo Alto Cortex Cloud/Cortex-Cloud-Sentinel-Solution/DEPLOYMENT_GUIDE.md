# Deployment and Configuration Guide

## Table of Contents
1. [Pre-deployment Checklist](#pre-deployment-checklist)
2. [Deployment Steps](#deployment-steps)
3. [Post-deployment Configuration](#post-deployment-configuration)
4. [Validation](#validation)
5. [Troubleshooting](#troubleshooting)

## Pre-deployment Checklist

Before deploying the Cortex Cloud Sentinel solution, ensure you have:

- [ ] Azure Subscription with Microsoft Sentinel enabled
- [ ] Sufficient permissions (Contributor or Owner on the resource group)
- [ ] Cortex Cloud tenant with administrative access
- [ ] **API Key** (Standard security level) generated with required permissions
- [ ] Network connectivity from Azure to Cortex Cloud APIs
- [ ] Log Analytics workspace with adequate retention and capacity

## Deployment Steps

### Deployment Methods Overview

This solution supports multiple deployment approaches:

| Component | Azure Portal | Azure CLI | ARM Template | Recommended |
|-----------|--------------|-----------|--------------|-------------|
| **API Key** | ✅ Manual | ❌ | ❌ | Portal |
| **Resource Group** | ✅ | ✅ | ✅ | CLI/ARM |
| **Custom Tables** | ⚠️ Manual* | ✅ Script | ✅ | **CLI Script** |
| **Azure Functions** | ⚠️ Manual | ✅ | ✅ | **ARM + func CLI** |
| **Parsers** | ✅ | ❌ | ❌ | **Portal** |
| **Analytics Rules** | ✅ | ✅ REST API | ✅ | Portal (initial), ARM (prod) |
| **Workbook** | ✅ | ✅ | ✅ | Portal |
| **Playbooks** | ✅ | ✅ | ✅ | ARM Template |

**Key:**
- ✅ = Fully supported and documented
- ⚠️ = Possible but tedious
- ❌ = Not practical

**Recommendations by Use Case:**
- **Initial/Testing Deployment**: Mix of Portal (parsers, rules) + CLI scripts (tables) + ARM (Functions)
- **Production Deployment**: ARM templates for everything except parsers and API key
- **CI/CD Pipeline**: ARM templates + Azure Functions Core Tools + Azure DevOps/GitHub Actions
- **Multi-Environment**: ARM templates with parameter files per environment

---

### Step 1: Generate Cortex Cloud API Key

1. **Login to Cortex Cloud**
   - Navigate to your Cortex Cloud portal
   - URL format: `https://api-{your-tenant}.xdr.{region}.paloaltonetworks.com`

2. **Access API Key Management**
   ```
   Settings → Configurations → Integrations → API Keys → + Add API Key
   ```

3. **Select API Key Security Level**
   
   Choose **Standard** (recommended for this integration):
   - ✅ **Standard**: Uses simple authentication with `x-xdr-auth-id` + `Authorization` headers
   - Works perfectly with Azure DCR and HTTP requests
   - Easier to implement and troubleshoot
   - **Recommended for SIEM integrations like Sentinel**
   
   Advanced is optional:
   - Adds anti-replay protection with nonce + timestamp hashing
   - Requires additional code to generate authentication tokens
   - Primarily used with Cortex XSOAR or custom Python scripts
   - **Not necessary for this integration**

4. **Configure API Key**
   - **Name**: `Microsoft-Sentinel-Integration`
   - **Security Level**: `Standard`
   - **Role**: Select role with appropriate permissions
   - **Permissions** (if using Custom role):
     - ✅ Issues: Read
     - ✅ Cases: Read
     - ✅ Cases: Write
     - ✅ Endpoints: Read
     - ✅ Audit Logs: Read

5. **Save Credentials**
   ```plaintext
   API Key: ********************************
   API Key ID: 1234 (numeric, shown in ID column)
   FQDN: your-tenant.xdr.us.paloaltonetworks.com
   ```
   
   **Note**: The FQDN is visible in your browser URL bar or in the "View Examples" for your API key

6. **Test API Key**
   ```bash
   # Test with issue search (correct API)
   curl -X POST "https://api-{your-fqdn}/public_api/v1/issue/search" \
     -H "x-xdr-auth-id: {your-api-key-id}" \
     -H "Authorization: {your-api-key}" \
     -H "Content-Type: application/json" \
     -d '{
       "request_data": {
         "filters": [],
         "search_from": 0,
         "search_to": 1
       }
     }'
   
   # Expected response: 200 OK with JSON data
   ```

### Step 2: Prepare Azure Environment

1. **Create Resource Group** (if needed)
   ```bash
   az group create \
     --name rg-sentinel-cortexcloud \
     --location eastus
   ```

2. **Store API Key in Azure Key Vault** (Recommended for Playbooks)
   ```bash
   # Create Key Vault
   az keyvault create \
     --name kv-cortexcloud \
     --resource-group rg-sentinel-cortexcloud \
     --location eastus
   
   # Store API Key (for playbooks)
   az keyvault secret set \
     --vault-name kv-cortexcloud \
     --name CortexCloudApiKey \
     --value "{your-api-key}"
   ```
   
   **Note**: This Key Vault is only needed if you plan to deploy playbooks later.

### Step 3: Create Custom Tables in Log Analytics

**IMPORTANT**: Custom tables should be created before deploying Azure Functions.

#### Option A: Use the Provided Script (Recommended)

```bash
cd Scripts/

# Edit the script first
nano create-custom-tables.sh

# Update these variables:
WORKSPACE_NAME="your-workspace-name"
RESOURCE_GROUP="rg-sentinel-cortexcloud"

# Run the script
chmod +x create-custom-tables.sh
./create-custom-tables.sh
```

#### Option B: Manual Creation via Azure CLI

```bash
# Set variables
WORKSPACE_NAME="your-workspace-name"
RESOURCE_GROUP="rg-sentinel-cortexcloud"

# Create CortexCloudIssues_CL
az monitor log-analytics workspace table create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --name "CortexCloudIssues_CL" \
  --columns \
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
    RawData=String \
  --retention-time 90

# Create CortexCloudCases_CL
az monitor log-analytics workspace table create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --name "CortexCloudCases_CL" \
  --columns \
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
    RawData=String \
  --retention-time 90

# Create CortexCloudEndpoints_CL
az monitor log-analytics workspace table create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --name "CortexCloudEndpoints_CL" \
  --columns \
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
    RawData=String \
  --retention-time 90

# Create CortexCloudAuditLogs_CL
az monitor log-analytics workspace table create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --name "CortexCloudAuditLogs_CL" \
  --columns \
    TimeGenerated=DateTime \
    EventId=String \
    EventType=String \
    User=String \
    Action=String \
    Resource=String \
    Result=String \
    SourceIP=String \
    RawData=String \
  --retention-time 90
```

**IMPORTANT**: Wait 2-3 minutes after creating tables before deploying Azure Functions.

#### Verify Tables Were Created

```bash
az monitor log-analytics workspace table list \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query "[?contains(name, 'CortexCloud')].name" -o table
```

Expected output:
```
CortexCloudAuditLogs_CL
CortexCloudCases_CL
CortexCloudEndpoints_CL
CortexCloudIssues_CL
```

### Step 4: Deploy Azure Functions for Data Ingestion

Azure Functions poll Cortex Cloud APIs and send data to Log Analytics.

1. **Get Log Analytics Workspace Key**
   
   ```bash
   WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
     --resource-group rg-sentinel-cortexcloud \
     --workspace-name cortexcloud \
     --query primarySharedKey -o tsv)
   
   echo "Workspace Key: $WORKSPACE_KEY"
   # Save this key for the next step
   ```

2. **Update Parameters File**
   
   Edit `AzureFunctions/function-app-parameters.json`:
   ```json
   {
     "cortexCloudApiKey": {
       "value": "YOUR-ACTUAL-API-KEY"
     },
     "workspaceKey": {
       "value": "PASTE-WORKSPACE-KEY-FROM-STEP-1"
     },
     "workspaceId": {
       "value": "5b3cdf29-b7df-4cf5-bc92-84bbc8248c0e"
     }
   }
   ```

3. **Deploy Function App Infrastructure**
   
   ```bash
   az deployment group create \
     --resource-group rg-sentinel-cortexcloud \
     --template-file AzureFunctions/function-app-arm-template.json \
     --parameters @AzureFunctions/function-app-parameters.json
   ```
   
   This deploys:
   - Function App: `cortexcloud-functions`
   - Storage Account: `cortexcloudfunc001`
   - App Service Plan: `cortexcloud-functions-plan`
   - Application Insights: `cortexcloud-functions-insights`

4. **Deploy Function Code**
   
   ```bash
   cd AzureFunctions
   func azure functionapp publish cortexcloud-functions --python
   ```
   
   **Note**: Requires Azure Functions Core Tools installed. See AzureFunctions/README.md for alternative deployment methods.

5. **Verify Deployment**
   
   ```bash
   # List deployed functions
   az functionapp function list \
     --resource-group rg-sentinel-cortexcloud \
     --name cortexcloud-functions \
     --query "[].{Name:name, State:config.disabled}" \
     --output table
   
   # Stream function logs
   az webapp log tail \
     --resource-group rg-sentinel-cortexcloud \
     --name cortexcloud-functions
   ```
   
   You should see 4 functions:
   - CortexCloudIssuesFunction (every 5 min)
   - CortexCloudCasesFunction (every 5 min)
   - CortexCloudEndpointsFunction (every 15 min)
   - CortexCloudAuditLogsFunction (every 15 min)

6. **Wait for Data Ingestion**
   
   Wait 5-15 minutes for the first function executions, then verify:
   ```kql
   CortexCloudIssues_CL | take 10
   CortexCloudCases_CL | take 10
   CortexCloudEndpoints_CL | take 10
   CortexCloudAuditLogs_CL | take 10
   ```

**Troubleshooting**: See `AzureFunctions/README.md` for detailed deployment guide and troubleshooting.

### Step 5: Deploy Parsers

1. **Create CortexCloudIssues Parser**
   
   Navigate to Microsoft Sentinel → Logs → Save as Function:
   
   - **Function Name**: `CortexCloudIssues`
   - **Category**: `Cortex Cloud`
   - **Query**: Paste content from `Parsers/CortexCloudIssues.kql`

2. **Create CortexCloudCases Parser**
   
   - **Function Name**: `CortexCloudCases`
   - **Category**: `Cortex Cloud`
   - **Query**: Paste content from `Parsers/CortexCloudCases.kql`

3. **Create CortexCloudEndpoints Parser**
   
   - **Function Name**: `CortexCloudEndpoints`
   - **Category**: `Cortex Cloud`
   - **Query**: Paste content from `Parsers/CortexCloudEndpoints.kql`

### Step 5: Deploy Analytic Rules

Deploy the 3 detection rules that trigger alerts on suspicious activity.

**Option A: Azure Portal (Recommended for Initial Deployment)**

See **ANALYTICS_RULES_DEPLOYMENT.md** for complete step-by-step instructions.

Quick summary:
1. Navigate to **Microsoft Sentinel** → **Analytics** → **+ Create** → **Scheduled query rule**
2. For each rule, copy the query and configuration from ANALYTICS_RULES_DEPLOYMENT.md
3. Configure entity mappings, custom details, and alert overrides
4. Set incident creation and grouping settings
5. Click **Review + create**

**Option B: Azure CLI with REST API**

```bash
# See ANALYTICS_RULES_DEPLOYMENT.md for complete JSON templates
az rest --method PUT \
  --url "${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules/CortexCloud-CriticalIssue?api-version=2023-02-01-preview" \
  --body @rule-critical-issue.json
```

**Option C: ARM Template Deployment (Recommended for Production/Automation)**

Deploy all rules at once using ARM templates:

```bash
# Deploy all analytics rules via ARM template
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file AnalyticRules/analytics-rules-arm-template.json \
  --parameters workspaceName=cortexcloud
```

Benefits:
- ✅ Infrastructure as Code (IaC)
- ✅ Deploy all rules in one command
- ✅ Version controlled
- ✅ Repeatable across environments
- ✅ Easy to update and redeploy

See **ANALYTICS_RULES_DEPLOYMENT.md** for complete ARM template examples.

**Rules to Deploy:**
1. **CortexCloud-CriticalIssue.yaml** - Detects critical severity issues
2. **CortexCloud-CaseSLABreach.yaml** - Alerts on SLA breaches
3. **CortexCloud-MultipleIssuesOnAsset.yaml** - Identifies compromised assets

**Important Notes:**
- ⚠️ Rules reference parser functions - ensure parsers are installed first
- ⚠️ Rules query raw tables - ensure data is being ingested
- ✅ Test queries in Logs before creating rules
- ✅ Start with one rule, verify it works, then deploy others

**Verification:**
```bash
# Check rules are active
az rest --method GET \
  --url "${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules?api-version=2023-02-01-preview" \
  | jq '.value[] | select(.properties.displayName | contains("Cortex Cloud"))'
```

For detailed deployment instructions, see **ANALYTICS_RULES_DEPLOYMENT.md**.

### Step 6: Deploy Workbook

**Option 1: Azure Portal (Recommended for first-time)**

1. Navigate to **Microsoft Sentinel** → **Workbooks**
2. Click **+ Add workbook**
3. Click **Edit** → **Advanced Editor**
4. Paste content from `Workbooks/CortexCloud-Overview.json`
5. Click **Apply** → **Done Editing**
6. Click **Save**:
   - Title: `Cortex Cloud Overview`
   - Location: Select your workspace
7. Click **Apply**

**Option 2: Azure CLI with ARM Template**

```bash
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Workbooks/cortexcloud-workbook-arm-template.json \
  --parameters workspaceName=cortexcloud
```

**Verification:**

```bash
# List workbooks
az monitor app-insights workbook list \
  --resource-group rg-sentinel-cortexcloud \
  --query "[?name contains(@, 'Cortex')].{Name:displayName, Category:category}" \
  --output table

# OR navigate to Sentinel → Workbooks → "My workbooks" tab
# You should see "Palo Alto Cortex Cloud Overview"
```

### Step 7: Deploy Playbooks (Optional)

**Prerequisites:**
1. Create Key Vault and store API key:
   ```bash
   # Create Key Vault
   az keyvault create \
     --name kv-cortexcloud-001 \
     --resource-group rg-sentinel-cortexcloud \
     --location eastus

   # Store API Key
   az keyvault secret set \
     --vault-name kv-cortexcloud-001 \
     --name CortexCloudApiKey \
     --value "YOUR-ACTUAL-API-KEY"
   ```

2. Update parameters file for each playbook:
   Edit `Playbooks/CortexCloud-*-v2-ARM-parameters.json` files with your values.

**Deploy Playbooks:**

```bash
# Deploy all 4 playbooks
for playbook in EnrichIssue AssignCase UpdateCaseStatus CloseCase; do
  az deployment group create \
    --resource-group rg-sentinel-cortexcloud \
    --template-file Playbooks/CortexCloud-${playbook}-v2-ARM.json \
    --parameters @Playbooks/CortexCloud-${playbook}-v2-ARM-parameters.json
done
```

**OR deploy individually:**

```bash
# Deploy EnrichIssue playbook
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-EnrichIssue-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-EnrichIssue-v2-ARM-parameters.json

# Deploy AssignCase playbook
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-AssignCase-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-AssignCase-v2-ARM-parameters.json

# Deploy UpdateCaseStatus playbook
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-UpdateCaseStatus-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-UpdateCaseStatus-v2-ARM-parameters.json

# Deploy CloseCase playbook
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-CloseCase-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-CloseCase-v2-ARM-parameters.json
```

**Grant Permissions:**

Each deployed playbook needs permissions. Run for EACH playbook:

**Check Key Vault Authorization Method First:**

```bash
KEYVAULT_NAME="kv-cortexcloud-001"
RBAC_ENABLED=$(az keyvault show --name $KEYVAULT_NAME --query properties.enableRbacAuthorization -o tsv)

if [ "$RBAC_ENABLED" = "true" ]; then
  echo "✅ Key Vault uses RBAC - use Method 1"
else
  echo "✅ Key Vault uses Access Policies - use Method 2"
fi
```

**Method 1: RBAC Authorization (Recommended for modern Key Vaults)**

```bash
# Set variables
PLAYBOOK_NAME="CortexCloud-EnrichIssue-v2"  # Change for each playbook
RESOURCE_GROUP="rg-sentinel-cortexcloud"
WORKSPACE_NAME="cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get playbook's managed identity
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group $RESOURCE_GROUP \
  --name $PLAYBOOK_NAME \
  --query identity.principalId -o tsv)

echo "Playbook: $PLAYBOOK_NAME"
echo "Principal ID: $PRINCIPAL_ID"

# Grant Sentinel Responder role on the resource group
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Microsoft Sentinel Responder" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# Grant Key Vault Secrets User role (RBAC method)
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
```

**Method 2: Access Policies (Legacy Key Vaults)**

```bash
# Set variables
PLAYBOOK_NAME="CortexCloud-EnrichIssue-v2"  # Change for each playbook
RESOURCE_GROUP="rg-sentinel-cortexcloud"
WORKSPACE_NAME="cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get playbook's managed identity
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group $RESOURCE_GROUP \
  --name $PLAYBOOK_NAME \
  --query identity.principalId -o tsv)

echo "Playbook: $PLAYBOOK_NAME"
echo "Principal ID: $PRINCIPAL_ID"

# Grant Sentinel Responder role on the resource group
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Microsoft Sentinel Responder" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# Grant Key Vault access policy
az keyvault set-policy \
  --name $KEYVAULT_NAME \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

**Grant Permissions for All 4 Playbooks (RBAC Method):**

```bash
RESOURCE_GROUP="rg-sentinel-cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

for PLAYBOOK_NAME in CortexCloud-EnrichIssue-v2 CortexCloud-AssignCase-v2 CortexCloud-UpdateCaseStatus-v2 CortexCloud-CloseCase-v2; do
  echo "Processing $PLAYBOOK_NAME..."
  
  PRINCIPAL_ID=$(az logic workflow show \
    --resource-group $RESOURCE_GROUP \
    --name $PLAYBOOK_NAME \
    --query identity.principalId -o tsv)
  
  if [ -z "$PRINCIPAL_ID" ]; then
    echo "❌ Failed to get identity for $PLAYBOOK_NAME"
    continue
  fi
  
  echo "  Principal ID: $PRINCIPAL_ID"
  
  # Sentinel Responder role
  az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role "Microsoft Sentinel Responder" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
    2>/dev/null || echo "  (Sentinel role may already exist)"
  
  # Key Vault Secrets User role
  az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role "Key Vault Secrets User" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME" \
    2>/dev/null || echo "  (Key Vault role may already exist)"
  
  echo "✅ Completed $PLAYBOOK_NAME"
  echo ""
done
```

**Repeat the above permissions script for all 4 playbooks:**
- `CortexCloud-EnrichIssue-v2`
- `CortexCloud-AssignCase-v2`
- `CortexCloud-UpdateCaseStatus-v2`
- `CortexCloud-CloseCase-v2`

**Verification:**

```bash
# List all deployed playbooks
az logic workflow list \
  --resource-group rg-sentinel-cortexcloud \
  --query "[?contains(name, 'CortexCloud')].{Name:name, State:state, Location:location}" \
  --output table

# Check specific playbook status and identity
az logic workflow show \
  --resource-group rg-sentinel-cortexcloud \
  --name CortexCloud-EnrichIssue-v2 \
  --query "{Name:name, State:state, Identity:identity.principalId}" \
  --output table

# Verify role assignments for a playbook
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group rg-sentinel-cortexcloud \
  --name CortexCloud-EnrichIssue-v2 \
  --query identity.principalId -o tsv)

az role assignment list \
  --assignee $PRINCIPAL_ID \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table

# Expected roles:
# - Microsoft Sentinel Responder
# - Key Vault Secrets User (if using RBAC)
```

## Post-deployment Configuration

### Configure Automation Rules

**Important Prerequisites:**
1. Playbooks must be deployed and have proper permissions
2. **Each playbook needs "Microsoft Sentinel Automation Contributor" role on the resource group** to be selectable in automation rules:

```bash
# Grant automation contributor role (required for each playbook)
for PLAYBOOK in "CortexCloud-EnrichIssue-v2" "CortexCloud-AssignCase-v2" "CortexCloud-UpdateCaseStatus-v2" "CortexCloud-CloseCase-v2"; do
  PRINCIPAL_ID=$(az logic workflow show \
    --resource-group rg-sentinel-cortexcloud \
    --name $PLAYBOOK \
    --query identity.principalId -o tsv)
  
  az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role "Microsoft Sentinel Automation Contributor" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-sentinel-cortexcloud"
  
  echo "✅ Granted automation permissions to $PLAYBOOK"
done
```

**Create Automation Rules:**

1. Navigate to **Microsoft Sentinel** → **Automation**
2. Click **+ Create** → **Automation rule**
3. Configure:
   - **Name**: `Cortex Cloud - Auto Enrich Issues`
   - **Trigger**: When incident is created
   - **Conditions**: 
     - If **Analytic rule name** Contains `Cortex Cloud`
   - **Actions**:
     - **Run playbook** → Select `CortexCloud-EnrichIssue-v2`
   - **Order**: 1
   - **Expiration**: Never
4. Click **Apply**

**Create Additional Automation Rules (Optional):**

```
Rule 2: Auto-assign Cases
- Trigger: When incident is created  
- Condition: If analytic rule name Contains "Case SLA Breach"
- Action: Run playbook → CortexCloud-AssignCase-v2

Rule 3: Sync Status Changes
- Trigger: When incident is updated
- Condition: If incident status Changed
- Action: Run playbook → CortexCloud-UpdateCaseStatus-v2

Rule 4: Close Cases
- Trigger: When incident is updated
- Condition: If incident status Changed to Closed
- Action: Run playbook → CortexCloud-CloseCase-v2
```

**Verification:**

```bash
# List automation rules
az sentinel automation-rule list \
  --resource-group rg-sentinel-cortexcloud \
  --workspace-name cortexcloud \
  --query "[].{Name:displayName, Enabled:properties.triggeringLogic.isEnabled}" \
  --output table

# OR navigate to Sentinel → Automation → Active rules
```

### Configure Polling Intervals

Default polling intervals in Azure Functions:
- **Issues, Cases**: 5 minutes  
- **Endpoints, Audit Logs**: 15 minutes

**To Change Intervals:**

1. Edit the `function.json` file for each function:
   
   **5 minutes:** `"schedule": "0 */5 * * * *"`  
   **10 minutes:** `"schedule": "0 */10 * * * *"`  
   **15 minutes:** `"schedule": "0 */15 * * * *"`  
   **30 minutes:** `"schedule": "0 */30 * * * *"`  
   **1 hour:** `"schedule": "0 0 * * * *"`

2. Redeploy the function:
   ```bash
   cd AzureFunctions
   func azure functionapp publish cortexcloud-functions --python
   ```

**Cost vs Frequency Tradeoff:**
- More frequent polling = fresher data but more executions
- Less frequent polling = lower cost but delayed data
- Different intervals can be set per function

**Recommendation:**
- **Issues & Cases**: 5-10 minutes (security-critical)
- **Endpoints**: 15-30 minutes (less frequently changing)
- **Audit Logs**: 15-60 minutes (compliance/historical)

**Note**: Azure Functions Consumption Plan includes 1 million free executions per month. With default intervals (~23k executions/month), you'll stay in the free tier.

### Configure Data Retention

1. Navigate to **Log Analytics workspace**
2. Go to **Usage and estimated costs**
3. Select **Data Retention**
4. Set retention period (default: 90 days)

## Validation

### Validate Data Ingestion

Wait 10-15 minutes after deployment, then run:

```kql
// Check Issues ingestion
CortexCloudIssues_CL
| summarize Count = count(), 
    LastIngestion = max(TimeGenerated),
    FirstIngestion = min(TimeGenerated)

// Check Cases ingestion
CortexCloudCases_CL
| summarize Count = count(),
    LastIngestion = max(TimeGenerated),
    FirstIngestion = min(TimeGenerated)

// Check for any ingestion errors
_LogOperation_CL
| where Category == "DataCollectionRule"
| where OperationName contains "CortexCloud"
| project TimeGenerated, Level, Message
```

### Validate Parsers

```kql
// Test Issues parser
CortexCloudIssues
| take 10

// Test Cases parser
CortexCloudCases
| take 10
```

### Validate Analytic Rules

1. Navigate to **Analytics** → **Active rules**
2. Verify all Cortex Cloud rules are enabled
3. Check **Last trigger time** (should be within last 15 minutes)

### Validate Workbook

1. Navigate to **Workbooks** → **My workbooks**
2. Open **Cortex Cloud Overview**
3. Verify all visualizations display data

### Validate Playbook

1. Navigate to **Logic Apps** → `CortexCloud-EnrichIssue`
2. Check **Runs history**
3. Verify successful executions

## Troubleshooting

### Azure Functions Not Sending Data

**Symptom**: Tables exist but no data appearing in CortexCloudIssues_CL or CortexCloudCases_CL

**Possible Causes**:
1. Functions not deployed correctly
2. API key invalid or expired
3. Network connectivity issues from Functions to Cortex Cloud
4. Incorrect FQDN format
5. Wrong authentication headers
6. Workspace ID or Key incorrect

**Resolution Steps**:

1. **Verify Functions Are Running**
   ```bash
   # Check function app status
   az functionapp show \
     --name cortexcloud-functions \
     --resource-group rg-sentinel-cortexcloud \
     --query state
   
   # List functions
   az functionapp function list \
     --name cortexcloud-functions \
     --resource-group rg-sentinel-cortexcloud \
     --query "[].name"
   ```

2. **Check Function Logs**
   ```bash
   # Stream live logs
   az webapp log tail \
     --name cortexcloud-functions \
     --resource-group rg-sentinel-cortexcloud
   ```

3. **Test API Connectivity with Correct Authentication**
   ```bash
   # Test issue search API
   curl -X POST "https://api-{your-fqdn}/public_api/v1/issue/search" \
     -H "x-xdr-auth-id: {your-api-key-id}" \
     -H "Authorization: {your-api-key}" \
     -H "Content-Type: application/json" \
     -d '{
       "request_data": {
         "filters": [],
         "search_from": 0,
         "search_to": 1
       }
     }'
   
   # Expected: 200 OK with JSON response
   ```

3. **Verify FQDN Format**
   - ✅ Correct: `tenant.xdr.us.paloaltonetworks.com`
   - ❌ Wrong: `https://tenant.xdr.us.paloaltonetworks.com/`
   - ❌ Wrong: `api-tenant.xdr.us.paloaltonetworks.com`

4. **Check Function Execution History**
   
   Navigate to Azure Portal → Function App → cortexcloud-functions → Any Function → Monitor
   
   Or check Application Insights:
   ```kql
   traces
   | where cloud_RoleName == "cortexcloud-functions"
   | where severityLevel >= 2  // Warnings and errors
   | project timestamp, severityLevel, message
   | order by timestamp desc
   ```

5. **Verify Table Schema**
   ```kql
   CortexCloudIssues_CL
   | getschema
   ```

### Authentication Errors (401 Unauthorized)

**Symptom**: API calls return 401 errors

**Possible Causes**:
1. Wrong API Key or API Key ID
2. API Key expired
3. Missing required permissions
4. Using Standard key instead of Advanced key

**Resolution**:

1. **Verify API Key Type**
   - Must be **Advanced** key (not Standard)
   - Check in Cortex Cloud: Settings → Configurations → Integrations → API Keys

2. **Verify API Key ID**
   - Should be a numeric value (e.g., "1234")
   - Visible in the "ID" column in Cortex Cloud console

3. **Check API Key Permissions**
   - Issues: Read ✅
   - Cases: Read/Write ✅
   - Endpoints: Read ✅
   - Audit Logs: Read ✅

4. **Test Authentication Separately**
   ```bash
   # This should return 200 OK
   curl -X POST "https://api-{fqdn}/public_api/v1/issue/search" \
     -H "x-xdr-auth-id: {api-key-id}" \
     -H "Authorization: {api-key}" \
     -H "Content-Type: application/json" \
     -d '{"request_data":{"filters":[],"search_from":0,"search_to":1}}'
   ```

### High Data Ingestion Costs

**Symptom**: Unexpected high costs for data ingestion

**Resolution**:

1. **Check Ingestion Volume**
   ```kql
   union CortexCloudIssues_CL, CortexCloudCases_CL
   | summarize GB = sum(_BilledSize) / 1024 / 1024 / 1024 by bin(TimeGenerated, 1d)
   | render columnchart
   ```

2. **Optimize Polling Interval**
   - Increase function schedules from 5 minutes to 15 or 30 minutes
   - Edit function.json files and redeploy

3. **Filter Data in Functions**
   - Modify function code to filter by severity or status before sending to Log Analytics

### Playbook Not Triggering

**Symptom**: Logic App not executing when incidents are created

**Resolution**:

1. **Check Automation Rule**
   - Verify condition matches your incidents
   - Ensure playbook is enabled

2. **Verify Logic App Status**
   ```bash
   az logic workflow show \
     --resource-group rg-sentinel-cortexcloud \
     --name CortexCloud-EnrichIssue \
     --query state
   ```

3. **Check Permissions**
   - Verify managed identity has Microsoft Sentinel Responder role

4. **Review Run History**
   - Check for failed runs and error messages

### Parser Not Working

**Symptom**: Parser function not found or returns errors

**Resolution**:

1. **Verify Function Exists**
   ```kql
   .show functions
   | where Name == "CortexCloudIssues" or Name == "CortexCloudCases"
   ```

2. **Re-create Function**
   - Delete existing function
   - Re-create using parser KQL files

3. **Check for Syntax Errors**
   - Test parser query independently before saving as function

## Deployment Checklist

Use this checklist to track your deployment progress:

### Pre-Deployment
- [ ] Azure subscription with Sentinel enabled
- [ ] Cortex Cloud API key created (Standard security level)
- [ ] API Key ID noted
- [ ] FQDN noted
- [ ] Network connectivity verified
- [ ] Log Analytics workspace created

### Core Infrastructure
- [ ] Resource group created
- [ ] API key stored in Key Vault (optional, for playbooks)

### Data Ingestion
- [ ] Custom tables created (Step 3)
  - [ ] CortexCloudIssues_CL
  - [ ] CortexCloudCases_CL
  - [ ] CortexCloudEndpoints_CL
  - [ ] CortexCloudAuditLogs_CL
- [ ] Waited 2-3 minutes for table provisioning
- [ ] Azure Functions deployed (Step 4)
  - [ ] Function App infrastructure deployed
  - [ ] Function code deployed
  - [ ] 4 functions verified running
- [ ] Data ingestion verified (wait 15-30 minutes)
  - [ ] CortexCloudIssues_CL has data
  - [ ] CortexCloudCases_CL has data
  - [ ] CortexCloudEndpoints_CL has data
  - [ ] CortexCloudAuditLogs_CL has data

### Parsers
- [ ] CortexCloudIssues parser created
- [ ] CortexCloudCases parser created
- [ ] CortexCloudEndpoints parser created
- [ ] Parsers tested with data

### Detection & Response
- [ ] Analytic Rules deployed (see ANALYTICS_RULES_DEPLOYMENT.md)
  - [ ] CortexCloud-CriticalIssue
  - [ ] CortexCloud-CaseSLABreach
  - [ ] CortexCloud-MultipleIssuesOnAsset
- [ ] Rules verified in Analytics → Active rules
- [ ] Workbook deployed
- [ ] Workbook tested and displays data
- [ ] Playbooks deployed (optional)
  - [ ] CortexCloud-EnrichIssue
  - [ ] CortexCloud-AssignCase
  - [ ] CortexCloud-UpdateCaseStatus
  - [ ] CortexCloud-CloseCase

### Verification
- [ ] Data flowing for all 4 streams
- [ ] Parsers returning results
- [ ] Analytics rules enabled
- [ ] Test incident created
- [ ] Workbook displays metrics

### Documentation Review
Key documents to reference:
- [ ] README.md - Solution overview
- [ ] DEPLOYMENT_GUIDE.md - This guide
- [ ] AzureFunctions/README.md - Functions deployment details
- [ ] ANALYTICS_RULES_DEPLOYMENT.md - Detailed rule deployment
- [ ] PARSER_STEP_BY_STEP.md - Parser installation help
- [ ] API_ENDPOINT_CORRECTIONS.md - API reference
- [ ] API_KEY_TYPES_EXPLAINED.md - API key guidance
- [ ] PLAYBOOK_API_NOTICE.md - Playbook API limitations

## Support Contacts

- **Cortex Cloud Issues**: support@paloaltonetworks.com
- **Azure Sentinel Issues**: Microsoft Support Portal
- **Community Support**: GitHub Issues

## Next Steps

After successful deployment:

1. ✅ Review and customize analytic rules for your environment
2. ✅ Configure notification channels (email, Teams, etc.)
3. ✅ Create additional hunting queries for specific threats
4. ✅ Develop custom playbooks for your response workflows
5. ✅ Schedule regular reviews of workbook metrics
6. ✅ Integrate with other security tools (SOAR, ticketing, etc.)