# Azure Functions Deployment Guide

This guide covers deploying Azure Functions to poll Cortex Cloud APIs and send data to Log Analytics.

## Overview

**4 Timer-Triggered Functions:**
1. **CortexCloudIssuesFunction** - Polls Issues API every 5 minutes
2. **CortexCloudCasesFunction** - Polls Cases API every 5 minutes
3. **CortexCloudEndpointsFunction** - Polls Endpoints API every 15 minutes
4. **CortexCloudAuditLogsFunction** - Polls Audit Logs API every 15 minutes

**Data Flow:**
```
Cortex Cloud APIs → Azure Functions → Log Analytics → Microsoft Sentinel
```

---

## Prerequisites

1. **Azure Subscription** with permissions to create resources
2. **Cortex Cloud API Key** (Advanced API Key)
3. **Log Analytics Workspace** already created
4. **Azure CLI** or **Azure PowerShell** installed
5. **Python 3.9+** for local testing (optional)

---

## Deployment Steps

### Step 1: Get Log Analytics Workspace Key

```bash
# Get Workspace ID (you already have this)
WORKSPACE_ID="5b3cdf29-b7df-4cf5-bc92-84bbc8248c0e"

# Get Workspace Primary Key
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group rg-sentinel-cortexcloud \
  --workspace-name cortexcloud \
  --query primarySharedKey -o tsv)

echo "Workspace Key: $WORKSPACE_KEY"
```

### Step 2: Update Parameters File

Edit `function-app-parameters.json`:

```json
{
  "cortexCloudApiKey": {
    "value": "YOUR-ACTUAL-API-KEY"  // Replace this
  },
  "workspaceKey": {
    "value": "PASTE-WORKSPACE-KEY-HERE"  // Replace this
  }
}
```

### Step 3: Deploy Function App Infrastructure

```bash
# Deploy Function App, Storage, and App Insights
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file function-app-arm-template.json \
  --parameters @function-app-parameters.json

# This creates:
# - Function App: cortexcloud-functions
# - Storage Account: cortexcloudfunc001
# - App Service Plan: cortexcloud-functions-plan
# - Application Insights: cortexcloud-functions-insights
```

### Step 4: Deploy Function Code

**Option A: Using Azure Functions Core Tools (Recommended)**

```bash
# Install Azure Functions Core Tools if not installed
# https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local

# Navigate to functions directory
cd AzureFunctions

# Deploy all functions
func azure functionapp publish cortexcloud-functions --python
```

**Option B: Using Azure CLI (ZIP Deployment)**

```bash
# Create deployment package
cd AzureFunctions
zip -r ../functions.zip . -x "*.git*" -x "*__pycache__*" -x "*.venv*"

# Deploy
az functionapp deployment source config-zip \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --src ../functions.zip
```

**Option C: Using Visual Studio Code**

1. Install Azure Functions extension
2. Open AzureFunctions folder in VS Code
3. Press F1 → "Azure Functions: Deploy to Function App"
4. Select cortexcloud-functions

### Step 5: Verify Deployment

```bash
# Check function app status
az functionapp show \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --query "{State:state, DefaultHostName:defaultHostName}" \
  --output table

# List deployed functions
az functionapp function list \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --query "[].{Name:name}" \
  --output table
```

You should see:
- CortexCloudIssuesFunction
- CortexCloudCasesFunction  
- CortexCloudEndpointsFunction
- CortexCloudAuditLogsFunction

### Step 6: Monitor Function Execution

**View Logs in Real-Time:**

```bash
# Stream logs
az webapp log tail \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions
```

**View in Azure Portal:**

1. Navigate to Function App → cortexcloud-functions
2. Click on any function
3. Click "Monitor" tab
4. View execution history and logs

**View in Application Insights:**

1. Navigate to Application Insights → cortexcloud-functions-insights
2. Go to "Logs" or "Live Metrics"
3. Query function telemetry

---

## Verify Data Ingestion

Wait 5-15 minutes after deployment, then check Log Analytics:

```kql
// Check Issues data
CortexCloudIssues_CL
| take 10

// Check Cases data
CortexCloudCases_CL
| take 10

// Check Endpoints data
CortexCloudEndpoints_CL
| take 10

// Check Audit Logs data
CortexCloudAuditLogs_CL
| take 10
```

---

## Configuration

### Change Polling Intervals

Edit `function.json` files:

**5 minutes:** `"schedule": "0 */5 * * * *"`
**10 minutes:** `"schedule": "0 */10 * * * *"`
**15 minutes:** `"schedule": "0 */15 * * * *"`
**30 minutes:** `"schedule": "0 */30 * * * *"`
**1 hour:** `"schedule": "0 0 * * * *"`

After changing, redeploy:

```bash
func azure functionapp publish cortexcloud-functions --python
```

### Update API Credentials

```bash
# Update Cortex Cloud API Key
az functionapp config appsettings set \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --settings CortexCloudApiKey="NEW-API-KEY"

# Update Workspace Key
az functionapp config appsettings set \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --settings WorkspaceKey="NEW-WORKSPACE-KEY"
```

---

## Troubleshooting

### Functions Not Running

```bash
# Check function app status
az functionapp show \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --query state

# Restart function app
az functionapp restart \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions
```

### No Data in Log Analytics

1. **Check function logs** for errors
2. **Verify API credentials** are correct
3. **Check Cortex Cloud FQDN** is correct
4. **Verify Workspace ID and Key** are correct
5. **Check firewall rules** - Functions need outbound HTTPS access

### API Rate Limiting

If you hit rate limits, increase polling intervals:
- Issues/Cases: 10-15 minutes
- Endpoints: 30 minutes
- Audit Logs: 30-60 minutes

### Test Individual Function

```bash
# Trigger function manually
az functionapp function invoke \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions \
  --function-name CortexCloudIssuesFunction
```

---

## Cost Optimization

**Consumption Plan Pricing:**
- First 1 million executions: Free
- After that: $0.20 per million executions
- Execution time: $0.000016/GB-s

**Monthly Cost Estimate (Default Config):**
- Issues: 8,640 executions/month (every 5 min)
- Cases: 8,640 executions/month (every 5 min)
- Endpoints: 2,880 executions/month (every 15 min)
- Audit Logs: 2,880 executions/month (every 15 min)
- **Total: ~23,000 executions = FREE**

**To Reduce Costs Further:**
- Increase polling intervals
- Filter data in functions before sending
- Use smaller page sizes in API calls

---

## Local Development & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Copy local.settings.json.template to local.settings.json
cp local.settings.json.template local.settings.json

# Edit local.settings.json with your credentials

# Run functions locally
func start
```

Test individual function:
```bash
curl http://localhost:7071/admin/functions/CortexCloudIssuesFunction
```

---

## Cleanup

```bash
# Delete Function App (keeps data)
az functionapp delete \
  --resource-group rg-sentinel-cortexcloud \
  --name cortexcloud-functions

# Delete all resources
az deployment group delete \
  --resource-group rg-sentinel-cortexcloud \
  --name function-app-arm-template
```

---

## Next Steps

After successful deployment:

1. ✅ Deploy Analytics Rules (see AnalyticRules/README.md)
2. ✅ Deploy Workbook (see Workbooks/)
3. ✅ Deploy Playbooks (see Playbooks/README.md)
4. ✅ Configure Automation Rules (see DEPLOYMENT_GUIDE.md)
