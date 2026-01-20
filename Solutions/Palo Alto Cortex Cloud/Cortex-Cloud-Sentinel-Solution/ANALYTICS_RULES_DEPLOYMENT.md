# Analytics Rules Deployment Guide

## Overview

This guide provides multiple methods to deploy Cortex Cloud analytics rules to Microsoft Sentinel.

---

## Method 1: Azure Portal (Recommended - Easiest)

### Advantages
- ✅ Visual interface
- ✅ Validation feedback
- ✅ No scripting needed
- ✅ Works immediately

### Steps

#### Rule 1: Critical Issue Detection

1. Navigate to **Sentinel** → **Analytics** → **+ Create** → **Scheduled query rule**

2. **General** tab:
   - Name: `Cortex Cloud - Critical Issue Detected`
   - Description: `This rule detects critical severity issues in Cortex Cloud that require immediate attention.`
   - Severity: `High`
   - Status: `Enabled`
   - MITRE ATT&CK: Select all relevant (Initial Access, Execution, etc.)

3. **Set rule logic** tab:
   
   **Rule query:**
   ```kql
   CortexCloudIssues_CL
   | where Severity == "critical" or Severity == "Critical"
   | where Status != "closed" and Status != "Closed" and Status != "resolved" and Status != "Resolved"
   | extend 
       IssueId = tostring(IssueId),
       Title = tostring(Title),
       Severity = tostring(Severity),
       AffectedAssets = tostring(AffectedAssets),
       CreatedTime = todatetime(CreatedTime)
   | project 
       TimeGenerated,
       IssueId,
       Title,
       Severity,
       Status,
       Category,
       AffectedAssets,
       CreatedTime,
       Description
   ```

   **Entity mapping:**
   - Entity type: `Alert`
     - SystemAlertId: `IssueId`
     - AlertDisplayName: `Title`

   **Custom details:**
   - IssueCategory: `Category`
   - IssueStatus: `Status`
   - IssueSeverity: `Severity`
   - AffectedAssets: `AffectedAssets`

   **Alert details:**
   - Alert Name Format: `Cortex Cloud Critical Issue: {{Title}}`
   - Alert Description Format:
     ```
     A critical severity issue has been detected in Cortex Cloud.
     
     Issue ID: {{IssueId}}
     Category: {{Category}}
     Status: {{Status}}
     Description: {{Description}}
     ```
   - Alert Severity Column: `Severity`
   - Alert Dynamic Properties:
     - ProviderName: `Palo Alto Networks`

   **Query scheduling:**
   - Run query every: `5 minutes`
   - Lookup data from the last: `10 minutes`

   **Alert threshold:**
   - Generate alert when number of query results: `Is greater than` `0`

   **Event grouping:**
   - Group all events into a single alert: `Disabled` (Alert per result)

4. **Incident settings** tab:
   - Create incidents: `Enabled`
   - Alert grouping: `Enabled`
     - Group related alerts into incidents: `Enabled`
     - Limit the group to alerts created within: `1 hour`
     - Group alerts triggered by this rule into a single incident by: `Grouping alerts into a single incident if all the entities match`
     - Re-open closed matching incidents: `Disabled`
     - Group by entities: `Alert`
     - Group by alert details: `Display Name`
     - Group by custom details: `IssueCategory`

5. Click **Review + create** → **Create**

---

#### Rule 2: Case SLA Breach

1. Navigate to **Sentinel** → **Analytics** → **+ Create** → **Scheduled query rule**

2. **General** tab:
   - Name: `Cortex Cloud - Case SLA Breach`
   - Description: `Detects cases that have breached their SLA timeframes based on priority levels.`
   - Severity: `Medium`
   - Status: `Enabled`

3. **Set rule logic** tab:
   
   **Rule query:**
   ```kql
   CortexCloudCases_CL
   | where Status in ("new", "New", "open", "Open", "in_progress", "InProgress")
   | extend 
       CaseId = tostring(CaseId),
       CaseNumber = tostring(CaseNumber),
       Title = tostring(Title),
       Priority = tostring(Priority),
       AgeInHours = datetime_diff('hour', now(), todatetime(CreatedTime))
   | extend SLABreached = case(
       Priority == "Critical" and AgeInHours > 4, true,
       Priority == "High" and AgeInHours > 24, true,
       Priority == "Medium" and AgeInHours > 72, true,
       Priority == "Low" and AgeInHours > 168, true,
       false
   )
   | where SLABreached == true
   | project 
       TimeGenerated,
       CaseId,
       CaseNumber,
       Title,
       Priority,
       Status,
       AgeInHours,
       AssignedTo,
       CreatedTime
   ```

   **Entity mapping:**
   - Entity type: `Alert`
     - SystemAlertId: `CaseId`
     - AlertDisplayName: `Title`

   **Custom details:**
   - CasePriority: `Priority`
   - CaseStatus: `Status`
   - CaseAge: `AgeInHours`
   - AssignedAnalyst: `AssignedTo`

   **Alert details:**
   - Alert Name Format: `Cortex Cloud Case SLA Breach: {{Title}}`
   - Alert Description Format:
     ```
     A case has breached its SLA timeframe.
     
     Case ID: {{CaseId}}
     Case Number: {{CaseNumber}}
     Priority: {{Priority}}
     Age: {{AgeInHours}} hours
     Assigned To: {{AssignedTo}}
     ```
   - Alert Severity Column: `Priority`
   - Alert Dynamic Properties:
     - ProviderName: `Palo Alto Networks`

   **Query scheduling:**
   - Run query every: `15 minutes`
   - Lookup data from the last: `30 minutes`

   **Alert threshold:**
   - Generate alert when number of query results: `Is greater than` `0`

4. **Incident settings** tab:
   - Create incidents: `Enabled`
   - Alert grouping: `Enabled`
     - Limit the group to alerts created within: `1 hour`
     - Group by entities: `Alert`
     - Group by custom details: `CasePriority`

5. Click **Review + create** → **Create**

---

#### Rule 3: Multiple Issues on Asset

1. Navigate to **Sentinel** → **Analytics** → **+ Create** → **Scheduled query rule**

2. **General** tab:
   - Name: `Cortex Cloud - Multiple Issues on Single Asset`
   - Description: `Detects when multiple issues are reported for the same asset, indicating potential compromise.`
   - Severity: `Medium`
   - Status: `Enabled`

3. **Set rule logic** tab:
   
   **Rule query:**
   ```kql
   CortexCloudIssues_CL
   | where Status != "closed" and Status != "Closed"
   | extend AffectedAssetsArray = parse_json(AffectedAssets)
   | mv-expand Asset = AffectedAssetsArray
   | extend AssetName = tostring(Asset)
   | where isnotempty(AssetName)
   | summarize 
       IssueCount = count(),
       IssueIds = make_set(IssueId),
       IssueCategories = make_set(Category),
       MaxSeverity = max(Severity),
       LatestIssue = arg_max(CreatedTime, *)
       by AssetName
   | where IssueCount >= 3
   | project 
       TimeGenerated = LatestIssue_CreatedTime,
       AssetName,
       IssueCount,
       MaxSeverity,
       IssueCategories,
       IssueIds
   ```

   **Entity mapping:**
   - Entity type: `Host`
     - HostName: `AssetName`

   **Custom details:**
   - AssetName: `AssetName`
   - IssueCount: `IssueCount`
   - MaxSeverity: `MaxSeverity`
   - IssueCategories: `IssueCategories`

   **Alert details:**
   - Alert Name Format: `Multiple Issues Detected on Asset: {{AssetName}}`
   - Alert Description Format:
     ```
     Multiple security issues have been detected on a single asset.
     
     Asset: {{AssetName}}
     Number of Issues: {{IssueCount}}
     Highest Severity: {{MaxSeverity}}
     Categories: {{IssueCategories}}
     ```
   - Alert Severity Column: `MaxSeverity`
   - Alert Dynamic Properties:
     - ProviderName: `Palo Alto Networks`

   **Query scheduling:**
   - Run query every: `15 minutes`
   - Lookup data from the last: `1 hour`

   **Alert threshold:**
   - Generate alert when number of query results: `Is greater than` `0`

4. **Incident settings** tab:
   - Create incidents: `Enabled`
   - Alert grouping: `Enabled`
     - Limit the group to alerts created within: `1 hour`
     - Group by entities: `Host`

5. Click **Review + create** → **Create**

---

## Method 2: Azure CLI with REST API

### Prerequisites
```bash
az login
az account set --subscription "Your-Subscription-Name"
```

### Create Rule via REST API

```bash
# Variables
RESOURCE_GROUP="rg-sentinel-cortexcloud"
WORKSPACE_NAME="cortexcloud"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get workspace resource ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query id -o tsv)

# Create rule
az rest --method PUT \
  --url "${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules/CortexCloud-CriticalIssue?api-version=2023-02-01-preview" \
  --body @rule-critical-issue.json
```

**rule-critical-issue.json:**
```json
{
  "kind": "Scheduled",
  "properties": {
    "displayName": "Cortex Cloud - Critical Issue Detected",
    "description": "This rule detects critical severity issues in Cortex Cloud that require immediate attention.",
    "severity": "High",
    "enabled": true,
    "query": "CortexCloudIssues_CL\n| where Severity == \"critical\" or Severity == \"Critical\"\n| where Status != \"closed\" and Status != \"Closed\" and Status != \"resolved\" and Status != \"Resolved\"\n| extend \n    IssueId = tostring(IssueId),\n    Title = tostring(Title),\n    Severity = tostring(Severity),\n    AffectedAssets = tostring(AffectedAssets),\n    CreatedTime = todatetime(CreatedTime)\n| project \n    TimeGenerated,\n    IssueId,\n    Title,\n    Severity,\n    Status,\n    Category,\n    AffectedAssets,\n    CreatedTime,\n    Description",
    "queryFrequency": "PT5M",
    "queryPeriod": "PT10M",
    "triggerOperator": "GreaterThan",
    "triggerThreshold": 0,
    "suppressionDuration": "PT5H",
    "suppressionEnabled": false,
    "tactics": [
      "InitialAccess",
      "Execution",
      "Persistence"
    ],
    "entityMappings": [
      {
        "entityType": "Alert",
        "fieldMappings": [
          {
            "identifier": "SystemAlertId",
            "columnName": "IssueId"
          },
          {
            "identifier": "AlertDisplayName",
            "columnName": "Title"
          }
        ]
      }
    ],
    "customDetails": {
      "IssueCategory": "Category",
      "IssueStatus": "Status",
      "IssueSeverity": "Severity",
      "AffectedAssets": "AffectedAssets"
    },
    "alertDetailsOverride": {
      "alertDisplayNameFormat": "Cortex Cloud Critical Issue: {{Title}}",
      "alertDescriptionFormat": "A critical severity issue has been detected in Cortex Cloud.\n\nIssue ID: {{IssueId}}\nCategory: {{Category}}\nStatus: {{Status}}\nDescription: {{Description}}",
      "alertSeverityColumnName": "Severity",
      "alertDynamicProperties": [
        {
          "alertProperty": "ProviderName",
          "value": "Palo Alto Networks"
        }
      ]
    },
    "eventGroupingSettings": {
      "aggregationKind": "AlertPerResult"
    },
    "incidentConfiguration": {
      "createIncident": true,
      "groupingConfiguration": {
        "enabled": true,
        "reopenClosedIncident": false,
        "lookbackDuration": "PT1H",
        "matchingMethod": "AllEntities",
        "groupByEntities": ["Alert"],
        "groupByAlertDetails": ["DisplayName"],
        "groupByCustomDetails": ["IssueCategory"]
      }
    }
  }
}
```

---

## Method 3: ARM Template Deployment

Create a master ARM template that deploys all rules:

```bash
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file analytics-rules-template.json \
  --parameters workspaceName=cortexcloud
```

---

## Verification

After deploying rules, verify they're active:

### Check in Portal
1. Navigate to **Sentinel** → **Analytics** → **Active rules**
2. Search for "Cortex Cloud"
3. Verify all 3 rules are listed and enabled

### Check via CLI
```bash
az rest --method GET \
  --url "${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules?api-version=2023-02-01-preview" \
  | jq '.value[] | select(.properties.displayName | contains("Cortex Cloud")) | {name: .properties.displayName, enabled: .properties.enabled}'
```

---

## Troubleshooting

### Error: "Too many column names"
**Symptom:** "You can define up to 3 column names" when creating rule

**Cause:** Alert dynamic properties limited to 3 items

**Fix:** The YAML files have been corrected to use only 1 dynamic property (ProviderName)

### Error: "Query validation failed"
**Symptom:** Query syntax error when creating rule

**Cause:** Parser functions not created or data not ingested yet

**Fix:**
1. Verify parsers are installed: `CortexCloudIssues`, `CortexCloudCases`
2. Verify data exists: `CortexCloudIssues_CL | take 10`

### Rules Not Triggering
**Symptom:** Rules enabled but no alerts generated

**Cause:** No data matching query conditions

**Fix:**
1. Check data ingestion: `CortexCloudIssues_CL | where Severity == "Critical" | take 10`
2. Verify DCR is running and pulling data
3. Check query frequency and lookback period

---

## Best Practices

1. **Test queries first**: Run each rule query in Logs before creating the rule
2. **Start with one rule**: Deploy Critical Issue rule first, then others
3. **Monitor alert volume**: Check if rules generate too many alerts
4. **Tune thresholds**: Adjust severity, frequency as needed
5. **Review incidents**: Regularly check incident quality and false positives

---

## Summary

**Recommended Method**: Azure Portal (Method 1)
- Easiest for initial deployment
- Visual validation
- Works immediately

**For Automation**: Use Method 2 (REST API) or Method 3 (ARM templates)
- Scriptable
- Version controlled
- Repeatable deployments
