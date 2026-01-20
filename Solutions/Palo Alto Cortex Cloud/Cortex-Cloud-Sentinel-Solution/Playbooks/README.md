# Playbooks

## ⚠️ Status: Playbooks Require API Corrections

### What's Included

**Legacy Playbooks (Need Updating):**
- `CortexCloud-EnrichIssue.json` - Uses old API endpoints
- `CortexCloud-AssignCase.json` - Uses old API endpoints
- `CortexCloud-UpdateCaseStatus.json` - Uses old API endpoints
- `CortexCloud-CloseCase.json` - Uses old API endpoints

**Corrected Playbooks (Working):**
- `CortexCloud-EnrichIssue-v2-ARM.json` + parameters - ✅ Enriches incidents with issue details
- `CortexCloud-AssignCase-v2-ARM.json` + parameters - ✅ Auto-assigns cases to incident owner
- `CortexCloud-UpdateCaseStatus-v2-ARM.json` + parameters - ✅ Syncs incident status to case
- `CortexCloud-CloseCase-v2-ARM.json` + parameters - ✅ Closes cases when incidents close

All use correct Cortex Cloud public APIs with proper authentication.

---

## 🔧 The Problem

The legacy playbooks use REST API endpoints that don't exist in Cortex Cloud:
- ❌ `GET /issues/v1/issues/{issueId}` - Doesn't exist
- ❌ `PUT /cases/v1/cases/{caseId}` - Doesn't exist

**Cortex Cloud public APIs work differently:**
- ✅ `POST /public_api/v1/issue/search` - Search with filters
- ✅ `POST /public_api/v1/case/update` - Update cases

---

## ✅ Working Example: EnrichIssue-v2

The corrected playbook demonstrates the proper pattern:

### Key Differences

**OLD (Broken):**
```http
GET /issues/v1/issues/{issueId}
Headers:
  x-api-key: {API_KEY}
```

**NEW (Working):**
```http
POST /public_api/v1/issue/search
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {API_KEY}
Body:
{
  "request_data": {
    "filters": [
      {
        "field": "issue_id",
        "operator": "eq",
        "value": "{issueId}"
      }
    ],
    "search_from": 0,
    "search_to": 1
  }
}
```

---

## 🚀 Deploy All 4 Playbooks

### Prerequisites (Same for All)

1. **Key Vault with API Key:**
```bash
# Create Key Vault
az keyvault create \
  --name kv-cortexcloud-001 \
  --resource-group rg-sentinel-cortexcloud

# Store API Key
az keyvault secret set \
  --vault-name kv-cortexcloud-001 \
  --name CortexCloudApiKey \
  --value "YOUR-ACTUAL-API-KEY"
```

2. **Update Parameters Files:**
Edit all 4 `*-parameters.json` files with your values:
- `CortexCloud-EnrichIssue-v2-ARM-parameters.json`
- `CortexCloud-AssignCase-v2-ARM-parameters.json`
- `CortexCloud-UpdateCaseStatus-v2-ARM-parameters.json`
- `CortexCloud-CloseCase-v2-ARM-parameters.json`

```json
{
  "parameters": {
    "CortexCloudFqdn": {
      "value": "your-tenant.xdr.us.paloaltonetworks.com"
    },
    "CortexCloudApiKeyId": {
      "value": "1234"
    },
    "KeyVaultName": {
      "value": "kv-cortexcloud-001"
    }
  }
}
```

### Deploy All Playbooks

```bash
# Deploy EnrichIssue
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-EnrichIssue-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-EnrichIssue-v2-ARM-parameters.json

# Deploy AssignCase
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-AssignCase-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-AssignCase-v2-ARM-parameters.json

# Deploy UpdateCaseStatus
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-UpdateCaseStatus-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-UpdateCaseStatus-v2-ARM-parameters.json

# Deploy CloseCase
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file Playbooks/CortexCloud-CloseCase-v2-ARM.json \
  --parameters @Playbooks/CortexCloud-CloseCase-v2-ARM-parameters.json
```

### Grant Permissions (For Each Playbook)

**Important**: Choose the correct method based on your Key Vault configuration.

**Method 1: RBAC Authorization (Recommended - if Key Vault has `--enable-rbac-authorization`)**

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_NAME="rg-sentinel-cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"

# Grant permissions to all 4 playbooks
for PLAYBOOK_NAME in CortexCloud-EnrichIssue-v2 CortexCloud-AssignCase-v2 CortexCloud-UpdateCaseStatus-v2 CortexCloud-CloseCase-v2; do
  echo "Processing $PLAYBOOK_NAME..."
  
  # Get Managed Identity Principal ID
  PRINCIPAL_ID=$(az logic workflow show \
    --resource-group $RG_NAME \
    --name $PLAYBOOK_NAME \
    --query identity.principalId -o tsv)
  
  if [ -z "$PRINCIPAL_ID" ]; then
    echo "❌ Failed to get identity for $PLAYBOOK_NAME"
    continue
  fi
  
  echo "  Principal ID: $PRINCIPAL_ID"
  
  # Grant Sentinel Responder role on resource group
  az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role "Microsoft Sentinel Responder" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" \
    2>/dev/null || echo "  (Sentinel role may already exist)"
  
  # Grant Key Vault Secrets User role (RBAC)
  az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role "Key Vault Secrets User" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME" \
    2>/dev/null || echo "  (Key Vault role may already exist)"
  
  echo "✅ Completed $PLAYBOOK_NAME"
  echo ""
done
```

**Method 2: Access Policies (if Key Vault does NOT have RBAC enabled)**

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_NAME="rg-sentinel-cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"

# Function to grant permissions
grant_playbook_permissions() {
  PLAYBOOK_NAME=$1
  
  # Get Managed Identity Principal ID
  PRINCIPAL_ID=$(az logic workflow show \
    --resource-group $RG_NAME \
    --name $PLAYBOOK_NAME \
    --query identity.principalId -o tsv)
  
  echo "Granting permissions for $PLAYBOOK_NAME (Principal ID: $PRINCIPAL_ID)"
  
  # Grant Sentinel Responder role
  az role assignment create \
    --role "Microsoft Sentinel Responder" \
    --assignee $PRINCIPAL_ID \
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME
  
  # Grant Key Vault access policy
  az keyvault set-policy \
    --name $KEYVAULT_NAME \
    --object-id $PRINCIPAL_ID \
    --secret-permissions get list
}

# Grant permissions for all 4 playbooks
grant_playbook_permissions "CortexCloud-EnrichIssue-v2"
grant_playbook_permissions "CortexCloud-AssignCase-v2"
grant_playbook_permissions "CortexCloud-UpdateCaseStatus-v2"
grant_playbook_permissions "CortexCloud-CloseCase-v2"
```

**Verify Permissions:**

```bash
# Check role assignments for a playbook
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

---

## 📋 What Each Playbook Does

### 1. EnrichIssue-v2
**Trigger**: Incident created  
**Action**: Searches Cortex Cloud for issue details and adds comment to incident
**Use Case**: Get full context from Cortex Cloud issue

### 2. AssignCase-v2
**Trigger**: Incident created  
**Action**: Assigns the case in Cortex Cloud to the Sentinel incident owner
**Use Case**: Keep case assignments synced between systems

### 3. UpdateCaseStatus-v2
**Trigger**: Incident created  
**Action**: Updates case status in Cortex Cloud based on Sentinel incident status
**Status Mapping**:
- Sentinel "Active" → Cortex "in_progress"
- Sentinel "Closed" → Cortex "closed"
- Sentinel "New" → Cortex "new"

### 4. CloseCase-v2
**Trigger**: Incident status changed  
**Action**: When Sentinel incident is closed, closes the case in Cortex Cloud with close reason
**Close Reason Mapping**:
- "TruePositive" → "True Positive"
- "FalsePositive" → "False Positive"
- Other → "Other"

---

## 🚀 Deploy the Working Playbook

### Prerequisites

1. **Key Vault with API Key:**
```bash
# Create Key Vault
az keyvault create \
  --name kv-cortexcloud-001 \
  --resource-group rg-sentinel-cortexcloud

# Store API Key
az keyvault secret set \
  --vault-name kv-cortexcloud-001 \
  --name CortexCloudApiKey \
  --value "YOUR-ACTUAL-API-KEY"
```

2. **Update Parameters File:**
Edit `CortexCloud-EnrichIssue-v2-ARM-parameters.json`:
```json
{
  "parameters": {
    "CortexCloudFqdn": {
      "value": "your-tenant.xdr.us.paloaltonetworks.com"
    },
    "CortexCloudApiKeyId": {
      "value": "1234"
    },
    "KeyVaultName": {
      "value": "kv-cortexcloud-001"
    }
  }
}
```

### Deploy

```bash
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file CortexCloud-EnrichIssue-v2-ARM.json \
  --parameters @CortexCloud-EnrichIssue-v2-ARM-parameters.json
```

### Grant Permissions

Each deployed playbook needs permissions. Run for EACH playbook:

**Note**: If your Key Vault uses RBAC authorization (check with `az keyvault show --name {vault} --query properties.enableRbacAuthorization`), use the RBAC method below. Otherwise use access policies.

**Method 1: RBAC Authorization (Recommended)**

```bash
# Set variables
PLAYBOOK_NAME="CortexCloud-EnrichIssue-v2"  # Change for each playbook
RESOURCE_GROUP="rg-sentinel-cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get the Managed Identity Principal ID
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group $RESOURCE_GROUP \
  --name $PLAYBOOK_NAME \
  --query identity.principalId -o tsv)

echo "Playbook: $PLAYBOOK_NAME"
echo "Principal ID: $PRINCIPAL_ID"

# Grant Sentinel Responder role on resource group
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Microsoft Sentinel Responder" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# Grant Key Vault Secrets User role (RBAC)
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
```

**Method 2: Access Policies (Legacy Key Vaults)**

```bash
# Set variables
PLAYBOOK_NAME="CortexCloud-EnrichIssue-v2"
RESOURCE_GROUP="rg-sentinel-cortexcloud"
KEYVAULT_NAME="kv-cortexcloud-001"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get the Managed Identity Principal ID
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group $RESOURCE_GROUP \
  --name $PLAYBOOK_NAME \
  --query identity.principalId -o tsv)

# Grant Sentinel Responder role
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

**Grant Permissions for All 4 Playbooks at Once (RBAC):**

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

---

## 📋 How the Working Playbook Functions

1. **Trigger**: Sentinel incident created
2. **Get API Key**: Retrieve from Key Vault
3. **Parse Custom Details**: Extract IssueId from alert
4. **Search Issue**: Use `/public_api/v1/issue/search` with filter
5. **Parse Response**: Extract issue details from `reply.data[]`
6. **Add Comment**: Post enrichment to incident

---

## 🔨 TODO: Fix Other Playbooks

The other 3 playbooks need similar updates:

### AssignCase
**Current (Broken):**
```http
PUT /cases/v1/cases/{caseId}
Body: { "assigned_to": "analyst@company.com" }
```

**Needs (Working):**
```http
POST /public_api/v1/case/update
Body:
{
  "request_data": {
    "case_id": "{caseId}",
    "update_data": {
      "assigned_to": "analyst@company.com"
    }
  }
}
```

### UpdateCaseStatus
**Current (Broken):**
```http
PUT /cases/v1/cases/{caseId}
Body: { "status": "in_progress" }
```

**Needs (Working):**
```http
POST /public_api/v1/case/update
Body:
{
  "request_data": {
    "case_id": "{caseId}",
    "update_data": {
      "status": "in_progress"
    }
  }
}
```

### CloseCase
Similar pattern to UpdateCaseStatus but with `"status": "closed"`.

---

## 📚 API Reference

See **PLAYBOOK_API_NOTICE.md** for complete API correction details.

For Cortex Cloud API documentation:
- https://cortex-panw.stoplight.io/docs/cortex-cloud
- https://github.com/okostine-panw/Cortex-Cloud-APIs-Postman-Collection

---

## ⚡ Quick Start

**If you just want Issue enrichment:**
1. Deploy the working EnrichIssue-v2 playbook (see above)
2. Ignore the legacy playbooks

**If you need case management automation:**
1. Use EnrichIssue-v2 as a template
2. Modify for case update operations
3. Test with Postman first

---

## 🧪 Testing

After deployment, trigger a test:

1. Create a test incident in Sentinel with IssueId custom detail
2. Check playbook run history in Azure Portal
3. Verify comment added to incident
4. Check for errors in Logic App runs

---

## ✅ Verify Permissions

**Check role assignments for a playbook:**

```bash
PRINCIPAL_ID=$(az logic workflow show \
  --resource-group rg-sentinel-cortexcloud \
  --name CortexCloud-EnrichIssue-v2 \
  --query identity.principalId -o tsv)

az role assignment list \
  --assignee $PRINCIPAL_ID \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table
```

**Expected output:**
```
Role                          Scope
----------------------------  -----------------------------------------------------
Microsoft Sentinel Responder  /subscriptions/.../resourceGroups/rg-sentinel-cortexcloud
Key Vault Secrets User        /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/kv-cortexcloud-001
```

**Check if Key Vault uses RBAC:**

```bash
az keyvault show \
  --name kv-cortexcloud-001 \
  --query properties.enableRbacAuthorization \
  --output tsv
```

If output is `true`, use RBAC method. If `false`, use access policies method.

---

## 💡 Why Search Instead of Get-By-ID?

Cortex Cloud public APIs use a **search-based pattern** for all operations:
- More flexible (supports complex filters)
- Consistent across all endpoints
- Enables bulk operations
- Aligns with modern API design

**Pattern:**
```
POST /public_api/v1/{resource}/search
POST /public_api/v1/{resource}/update
POST /public_api/v1/{resource}/create
```

---

## ✅ Summary

| Playbook | Status | Can Deploy? | Notes |
|----------|--------|-------------|-------|
| EnrichIssue (legacy) | ❌ Broken | No | Wrong APIs |
| **EnrichIssue-v2** | ✅ **Working** | **Yes** | **Issue enrichment** |
| AssignCase (legacy) | ❌ Broken | No | Wrong APIs |
| **AssignCase-v2** | ✅ **Working** | **Yes** | **Auto-assign cases** |
| UpdateCaseStatus (legacy) | ❌ Broken | No | Wrong APIs |
| **UpdateCaseStatus-v2** | ✅ **Working** | **Yes** | **Sync case status** |
| CloseCase (legacy) | ❌ Broken | No | Wrong APIs |
| **CloseCase-v2** | ✅ **Working** | **Yes** | **Auto-close cases** |

**All 4 corrected playbooks are ready to deploy!**
