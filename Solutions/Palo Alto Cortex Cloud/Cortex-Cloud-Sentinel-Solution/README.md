# Palo Alto Cortex Cloud - Azure Sentinel Solution

**Version 2.1** - Complete integration solution for Palo Alto Networks Cortex Cloud with Microsoft Sentinel

---

## 📋 Overview

This solution provides **complete integration** between Palo Alto Networks Cortex Cloud and Microsoft Sentinel using the Codeless Connector Platform (CCP). It ingests security data directly from Cortex Cloud via the official public APIs, providing real-time visibility into issues, cases, endpoints, and audit activities.

**Key Highlights:**
- ✅ **4 Core Data Streams** from Cortex Cloud
- ✅ **Correct Cortex Cloud Public APIs** (`/public_api/v1/*`)
- ✅ **Proper Authentication** (`x-xdr-auth-id` + `Authorization` headers)
- ✅ **CCP-Based** (No VMs, auto-scaling, Microsoft-managed)
- ✅ **Bi-directional Automation** with Logic Apps playbooks
- ✅ **Enhanced Parsers** with risk scoring and SLA tracking
- ✅ **Comprehensive Hunting** queries for proactive detection

---

## 📦 What's Included

### Data Ingestion
- **Azure Functions** (Python 3.9) - Timer-triggered functions that poll Cortex Cloud APIs
- **Log Analytics Data Collector API** - Direct ingestion to custom tables
- **ARM Templates** - Automated deployment of Function App infrastructure

### Data Streams (4)

#### 1. **Issues** (Security Alerts)
- **API**: `POST /public_api/v1/issue/search`
- **Description**: Security findings and detections from Cortex Cloud
- **Equivalent to**: XDR Alerts
- **Polling**: Every 5 minutes (configurable)

#### 2. **Cases** (Incidents)
- **API**: `POST /public_api/v1/case/search`
- **Description**: Investigation and incident management data
- **Equivalent to**: XDR Incidents
- **Polling**: Every 5 minutes (configurable)

#### 3. **Endpoints** (Assets)
- **API**: `POST /public_api/v1/endpoints/get_endpoints`
- **Description**: Asset and endpoint inventory with health status
- **Equivalent to**: XDR Endpoints
- **Polling**: Every 15 minutes (configurable)

#### 4. **Audit Logs**
- **API**: `POST /public_api/v1/audits/management_logs`
- **Description**: Audit trail of activities within Cortex Cloud
- **Polling**: Every 5 minutes

**Note**: Cortex Cloud runs on the same platform as Cortex XDR and provides access to the same underlying security data with enhanced case management capabilities.

### Parsers (3 KQL Functions)
- **CortexCloudIssues.kql**: Normalizes issue data with risk scoring
- **CortexCloudCases.kql**: Normalizes case data with SLA tracking
- **CortexCloudEndpoints.kql**: Normalizes endpoint data with health scoring

### Analytics Rules (3)
- **Critical Issue Detection**: Triggers on high/critical severity issues
- **Case SLA Breach**: Alerts when cases exceed SLA thresholds
- **Multiple Issues on Asset**: Detects assets with repeated security findings

### Workbooks (1)
- **Cortex Cloud Overview**: Comprehensive operational dashboard

### Playbooks (4)
1. **CortexCloud-EnrichIssue**: Enriches issues with additional context
2. **CortexCloud-UpdateCaseStatus**: Bi-directional case status synchronization
3. **CortexCloud-AssignCase**: Synchronizes case assignments
4. **CortexCloud-CloseCase**: Comprehensive case closure with documentation

### Hunting Queries (8)
1. Issue Trend Analysis
2. Unassigned Critical Cases
3. Asset Risk Assessment
4. Stale Cases Investigation
5. Issue Correlation Patterns
6. Analyst Workload Analysis
7. Recurring Issues Detection
8. Stale and Offline Endpoints

### Documentation (6 Files)
- README.md (this file)
- SOLUTION_SUMMARY.md
- DEPLOYMENT_GUIDE.md
- MIGRATION_GUIDE.md
- PROJECT_PLAN.md
- API_ENDPOINT_CORRECTIONS.md

---

## 🔑 Prerequisites

### Cortex Cloud Requirements
1. **Cortex Cloud Tenant** with API access enabled
2. **Advanced API Key** with permissions:
   - Issues: Read
   - Cases: Read/Write
   - Endpoints: Read
   - Audit Logs: Read
3. **API Key ID** (from Cortex Cloud console)
4. **Tenant FQDN** (e.g., `your-tenant.xdr.us.paloaltonetworks.com`)

### Azure Sentinel Requirements
1. **Azure Sentinel Workspace** (Log Analytics)
2. **Contributor** role on Resource Group
3. **Data Collection Endpoint (DCE)** created
4. **Managed Identity** for Logic Apps (for playbooks)
5. **Azure Key Vault** (recommended for API key storage)

---

## 🚀 Quick Start

### Step 1: Generate Cortex Cloud API Credentials

1. Log into your Cortex Cloud tenant
2. Navigate to **Settings** → **Configurations** → **Integrations** → **API Keys**
3. Click **+ Add API Key**
4. Select **Advanced** key type
5. Configure permissions:
   - ✅ Issues: Read
   - ✅ Cases: Read/Write
   - ✅ Endpoints: Read
   - ✅ Audit Logs: Read
6. **Save** the API Key and API Key ID
7. Note your tenant FQDN (from browser URL bar)

### Step 2: Deploy Azure Functions

**Get Log Analytics Workspace Key:**

```bash
# Get workspace primary key
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group <your-rg> \
  --workspace-name <your-workspace> \
  --query primarySharedKey -o tsv)
```

**Update Parameters:**

Edit `AzureFunctions/function-app-parameters.json` with your values:
- `cortexCloudApiKey` - Your Cortex Cloud API Key
- `workspaceKey` - The workspace key from above
- `workspaceId` - Your workspace ID (GUID)

**Deploy Function App:**

```bash
# Deploy infrastructure (Function App, Storage, App Insights)
az deployment group create \
  --resource-group <your-rg> \
  --template-file AzureFunctions/function-app-arm-template.json \
  --parameters @AzureFunctions/function-app-parameters.json

# Deploy function code
cd AzureFunctions
func azure functionapp publish cortexcloud-functions --python
```

**Verify Deployment:**

```bash
# Check functions are deployed
az functionapp function list \
  --resource-group <your-rg> \
  --name cortexcloud-functions \
  --query "[].{Name:name}" \
  --output table
```

See `AzureFunctions/README.md` for detailed deployment guide.

### Step 3: Install Parsers

Navigate to Sentinel → **Logs** → **Functions** → **+ Create Function**

Install each parser:
1. `Parsers/CortexCloudIssues.kql` → Save as **CortexCloudIssues**
2. `Parsers/CortexCloudCases.kql` → Save as **CortexCloudCases**
3. `Parsers/CortexCloudEndpoints.kql` → Save as **CortexCloudEndpoints**

### Step 4: Deploy Analytics Rules

Navigate to Sentinel → **Analytics** → **+ Create** → **Scheduled query rule**

Import and enable:
1. `AnalyticRules/CortexCloud-CriticalIssue.yaml`
2. `AnalyticRules/CortexCloud-CaseSLABreach.yaml`
3. `AnalyticRules/CortexCloud-MultipleIssuesOnAsset.yaml`

### Step 5: Import Workbook

Navigate to Sentinel → **Workbooks** → **+ Add workbook** → **Advanced Editor**

Paste contents of `Workbooks/CortexCloud-Overview.json`

### Step 6: Deploy Playbooks

For each playbook:
1. Navigate to Azure Portal → **Logic Apps** → **+ Add**
2. Import JSON from `Playbooks/` directory
3. Configure managed identity
4. Configure API connections
5. Enable playbook
6. Create automation rule to trigger playbook

---

## 🔐 Authentication Configuration

### Cortex Cloud API Authentication

The solution uses **two authentication values**:

1. **API Key ID** (`x-xdr-auth-id` header)
   - This is the ID shown in the Cortex Cloud console
   - Visible in plaintext, safe to store in parameters

2. **API Key** (`Authorization` header)
   - This is the secret key generated when creating the API key
   - **Security Best Practice**: Store in Azure Key Vault
   - Reference from Key Vault in DCR deployment

### Example with Key Vault

```bash
# Store API key in Key Vault
az keyvault secret set \
  --vault-name <your-keyvault> \
  --name CortexCloudApiKey \
  --value "YOUR_API_KEY"

# Reference in DCR parameters
"cortexCloudApiKey": {
  "reference": {
    "keyVault": {
      "id": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault}"
    },
    "secretName": "CortexCloudApiKey"
  }
}
```

---

## 📊 Data Flow

```
Cortex Cloud APIs
       ↓ (Polling every 5-15 min)
CCP Connector (Microsoft-managed)
       ↓
Data Collection Rule (DCR)
       ↓ (Transformation)
Log Analytics Workspace
       ↓ (Parsed)
KQL Parsers
       ↓
Custom Tables:
  - CortexCloudIssues_CL
  - CortexCloudCases_CL
  - CortexCloudEndpoints_CL
  - CortexCloudAuditLogs_CL
       ↓
Analytics Rules → Incidents
       ↓
Logic App Playbooks → Actions
       ↓
Cortex Cloud APIs (bi-directional)
```

---

## 🎯 Use Cases

### Security Operations
- Real-time security alert ingestion
- Automated incident enrichment
- Bi-directional case management
- SLA tracking and breach alerts

### Threat Hunting
- Cross-asset issue correlation
- Behavioral anomaly detection
- Recurring vulnerability identification
- Endpoint health monitoring

### Compliance & Audit
- Complete audit trail visibility
- User activity tracking
- Change management monitoring
- Compliance reporting

### Asset Management
- Centralized endpoint inventory
- Health status monitoring
- Stale endpoint detection
- Agent version tracking

---

## 🔧 Configuration Options

### Polling Intervals

Edit in DCR template (`schedule.interval`):
- **Issues**: Default PT5M (5 minutes)
- **Cases**: Default PT5M (5 minutes)
- **Endpoints**: Default PT15M (15 minutes)
- **Audit Logs**: Default PT5M (5 minutes)

### Filtering

Add filters to `request_data.filters` in DCR:

```json
"filters": [
  {
    "field": "severity",
    "operator": "in",
    "value": ["high", "critical"]
  }
]
```

### Page Size

Default: 100 records per request
- Adjust `search_to` in request body
- Maximum: 100 (API limitation)

---

## 📈 Expected Data Volume

| Stream | Estimated Daily Volume | Monthly Volume |
|--------|----------------------|----------------|
| Issues | 100-1,000 events | 3,000-30,000 |
| Cases | 10-100 events | 300-3,000 |
| Endpoints | 100-10,000 assets | ~1 snapshot/15min |
| Audit Logs | 500-5,000 events | 15,000-150,000 |

**Total Estimated**: 1-20 GB/month (varies by environment)

**Cost Estimate**: ~$2.30/GB for Log Analytics ingestion

---

## 🐛 Troubleshooting

### No Data Ingestion

1. **Check DCR Status**
   ```bash
   az monitor data-collection rule show \
     --name CortexCloud-DCR \
     --resource-group <rg>
   ```

2. **Verify API Authentication**
   ```bash
   curl -X POST "https://api-{fqdn}/public_api/v1/issue/search" \
     -H "x-xdr-auth-id: {api-key-id}" \
     -H "Authorization: {api-key}" \
     -H "Content-Type: application/json" \
     -d '{"request_data":{"filters":[],"search_from":0,"search_to":10}}'
   ```

3. **Check Log Analytics**
   ```kql
   CortexCloudIssues_CL
   | take 10
   ```

### Authentication Errors (401)

- Verify API Key ID is correct (check Cortex Cloud console)
- Verify API Key has not expired
- Ensure API Key has required permissions
- Check FQDN format (no `https://`, no trailing `/`)

### Parsing Errors

- Verify parser functions are installed
- Check field name mappings match API response
- Review KQL syntax in parsers

### Playbook Failures

- Verify managed identity has Sentinel Contributor role
- Check API connections are authorized
- Verify Cortex Cloud API key in playbook configuration
- Review playbook run history for error details

---

## 🔄 Maintenance

### API Key Rotation

1. Generate new API key in Cortex Cloud
2. Update Key Vault secret (if using)
3. Update DCR parameters
4. Update playbook configurations
5. Test data ingestion

**Recommended Frequency**: Every 90 days

### Health Monitoring

Create a Log Analytics alert:
```kql
CortexCloudIssues_CL
| summarize LastIngestion = max(TimeGenerated)
| where LastIngestion < ago(15m)
```

---

## 📚 Additional Resources

### Cortex Cloud APIs
- **Documentation**: https://docs-cortex.paloaltonetworks.com/r/Cloud-Onboarding-Public-APIs/Get-started-with-Cortex-Cloud-APIs
- **Postman Collection**: https://github.com/okostine-panw/Cortex-Cloud-APIs-Postman-Collection
- **API Reference**: See API_ENDPOINT_CORRECTIONS.md

### Microsoft Sentinel
- **CCP Documentation**: https://learn.microsoft.com/azure/sentinel/data-connectors-reference
- **KQL Reference**: https://learn.microsoft.com/azure/data-explorer/kusto/query/
- **Logic Apps**: https://learn.microsoft.com/azure/logic-apps/

### Community
- **Palo Alto Live Community**: https://live.paloaltonetworks.com
- **Microsoft Tech Community**: https://techcommunity.microsoft.com/sentinelblog

---

## 🤝 Support

### For Cortex Cloud Issues
- Contact Palo Alto Networks Support
- Visit live.paloaltonetworks.com

### For Azure Sentinel Issues
- Open support ticket in Azure Portal
- Visit Microsoft Tech Community forums

### For This Solution
- Review included documentation files
- Check API_ENDPOINT_CORRECTIONS.md for API details
- See DEPLOYMENT_GUIDE.md for step-by-step instructions
- Review TROUBLESHOOTING section in this file

---

## 📝 Version History

### Version 2.1 (Current) - January 8, 2026
- ✅ **CRITICAL**: Fixed all API endpoints to use correct Cortex Cloud public APIs
- ✅ Changed from GET to POST for all search operations
- ✅ Updated authentication to use `x-xdr-auth-id` + `Authorization` headers
- ✅ Corrected request body format with `request_data` structure
- ✅ Fixed response JSONPath to match actual API responses
- ✅ Added `cortexCloudApiKeyId` parameter requirement
- ✅ Removed "Additional Data" stream (no standard API exists)
- ✅ Updated field mappings to match actual API responses
- ✅ Added comprehensive API documentation

### Version 2.0 - January 8, 2026
- ✅ Added Endpoints data stream
- ✅ Added Additional Data stream (later removed in 2.1)
- ✅ Added 2 new parsers
- ✅ Added 1 new hunting query
- ✅ Updated all documentation
- ✅ Achieved functional parity with XDR CCP

### Version 1.0 - January 7, 2026
- ✅ Initial release with 3 data streams
- ✅ 2 parsers, 3 rules, 1 workbook
- ✅ 4 playbooks, 7 hunting queries
- ✅ 5 documentation files

---

## ⚠️ Important Notes

### API Endpoints
This solution uses the **correct Cortex Cloud public APIs**:
- ✅ `/public_api/v1/issue/search` (not `/public_api/v1/issue/search`)
- ✅ `/public_api/v1/case/search` (not `/public_api/v1/case`)
- ✅ POST with JSON body (not GET with query parameters)

### Authentication
Requires **both** values:
- ✅ API Key ID in `x-xdr-auth-id` header
- ✅ API Key in `Authorization` header

### Data Streams
Solution includes **4 core streams**:
- ✅ Issues (Alerts)
- ✅ Cases (Incidents)
- ✅ Endpoints (Assets)
- ✅ Audit Logs

"Additional Data" stream was removed as no standard Cortex Cloud API exists for it.

---

## 📄 License

This solution is provided as-is for use with Palo Alto Networks Cortex Cloud and Microsoft Sentinel.

---

**Developed with ❤️ for the Palo Alto Networks and Microsoft Sentinel community**

**Version**: 2.1  
**Status**: Production Ready ✅  
**Last Updated**: January 8, 2026
