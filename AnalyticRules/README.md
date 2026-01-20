# Analytics Rules

This folder contains the detection rules for Cortex Cloud threats and case management issues.

## Files

### YAML Files (Source Definitions)
- **CortexCloud-CriticalIssue.yaml** - Detects critical severity issues requiring immediate attention
- **CortexCloud-CaseSLABreach.yaml** - Alerts on cases that have breached SLA timeframes
- **CortexCloud-MultipleIssuesOnAsset.yaml** - Identifies assets with multiple concurrent issues

These YAML files contain the rule logic and metadata in a human-readable format.

### ARM Template (Deployment)
- **analytics-rules-arm-template.json** - ARM template to deploy all 3 rules at once
- **analytics-rules-arm-parameters.json** - Parameters file for the ARM template

## Deployment Options

### Option 1: Azure Portal (Manual)
Use the YAML files as reference and create rules manually through the Sentinel UI.

See **../ANALYTICS_RULES_DEPLOYMENT.md** for detailed step-by-step instructions.

### Option 2: ARM Template (Automated)

**Step 1: Update parameters file**
Edit `analytics-rules-arm-parameters.json`:
```json
{
  "parameters": {
    "workspaceName": {
      "value": "your-sentinel-workspace-name"
    },
    "location": {
      "value": "eastus"
    }
  }
}
```

**Step 2: Deploy the template**
```bash
# Deploy all 3 rules at once
az deployment group create \
  --resource-group rg-sentinel-cortexcloud \
  --template-file analytics-rules-arm-template.json \
  --parameters @analytics-rules-arm-parameters.json
```

**Step 3: Verify deployment**
```bash
# Check if rules were created
az rest --method GET \
  --url "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}/providers/Microsoft.SecurityInsights/alertRules?api-version=2023-02-01-preview" \
  | jq '.value[] | select(.properties.displayName | contains("Cortex Cloud"))'
```

### Option 3: Azure CLI with REST API (Individual Rules)

Deploy rules one at a time using REST API:

```bash
# Deploy Critical Issue rule
az rest --method PUT \
  --url "${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules/CortexCloud-CriticalIssue?api-version=2023-02-01-preview" \
  --body @rule-critical-issue.json
```

See **../ANALYTICS_RULES_DEPLOYMENT.md** for complete JSON examples.

## Prerequisites

Before deploying these rules, ensure:
- ✅ Custom tables are created (`CortexCloudIssues_CL`, `CortexCloudCases_CL`)
- ✅ Parser functions are installed (`CortexCloudIssues`, `CortexCloudCases`)
- ✅ Data is being ingested (wait 15-30 minutes after DCR deployment)
- ✅ Parser functions return results when tested

## What Each Rule Does

### 1. Critical Issue Detection
**Trigger**: Critical severity issues that are not closed/resolved
- **Severity**: High
- **Frequency**: Every 5 minutes
- **MITRE ATT&CK**: Initial Access, Execution, Persistence, Privilege Escalation, etc.
- **Entity**: Alert (mapped to IssueId and Title)
- **Incident**: Creates incidents, groups by Alert entity and IssueCategory

### 2. Case SLA Breach
**Trigger**: Open cases that exceed SLA timeframes
- Critical: > 4 hours
- High: > 24 hours
- Medium: > 72 hours
- Low: > 168 hours

**Configuration**:
- **Severity**: Medium
- **Frequency**: Every 15 minutes
- **Entity**: Alert (mapped to CaseId and Title)
- **Incident**: Creates incidents, groups by Alert entity and CasePriority

### 3. Multiple Issues on Asset
**Trigger**: 3+ open issues on a single asset
- **Severity**: Medium (dynamically set to MaxSeverity)
- **Frequency**: Every 15 minutes
- **Lookback**: 1 hour
- **Entity**: Host (mapped to AssetName)
- **Incident**: Creates incidents, groups by Host entity

## Customization

You can modify the rules by:

1. **Edit YAML files** - Change queries, thresholds, frequencies
2. **Update ARM template** - Modify the JSON directly
3. **Clone and customize** - Create new rules based on these templates

Common customizations:
- Change query frequency (default: 5-15 minutes)
- Adjust thresholds (e.g., multiple issues threshold from 3 to 5)
- Modify SLA timeframes for case breaches
- Add additional MITRE ATT&CK techniques
- Change incident grouping logic
- Add more custom details fields

## Testing

After deployment, test each rule:

```kql
// Test Critical Issue rule query
CortexCloudIssues_CL
| where Severity == "critical" or Severity == "Critical"
| where Status != "closed" and Status != "Closed"
| take 10

// Test Case SLA Breach query
CortexCloudCases_CL
| where Status in ("new", "open", "in_progress")
| extend AgeInHours = datetime_diff('hour', now(), todatetime(CreatedTime))
| where AgeInHours > 4
| take 10

// Test Multiple Issues on Asset query
CortexCloudIssues_CL
| where Status != "closed"
| extend AffectedAssetsArray = parse_json(AffectedAssets)
| mv-expand Asset = AffectedAssetsArray
| summarize IssueCount = count() by tostring(Asset)
| where IssueCount >= 3
```

## Troubleshooting

### Rules not triggering
1. Verify data exists in custom tables
2. Check parser functions are working
3. Confirm query returns results when run manually
4. Review rule frequency and lookback period

### Deployment fails
1. Check workspace name is correct
2. Verify you have Sentinel Contributor permissions
3. Ensure custom tables exist before deploying
4. Review error message for specific issue

### Too many alerts
1. Adjust query thresholds
2. Increase suppression duration
3. Modify grouping configuration
4. Add additional filters to queries

## ARM Template Benefits

Using the ARM template provides:
- ✅ **Deploy all rules at once** - Single command instead of 3 manual steps
- ✅ **Version control** - Track changes in Git
- ✅ **Repeatable** - Deploy to multiple workspaces/environments
- ✅ **Consistent** - Ensures all rules have same configuration
- ✅ **Automated** - Integrate into CI/CD pipelines
- ✅ **Rollback** - Easy to redeploy previous versions

## Next Steps

After deploying rules:
1. Monitor the Analytics → Active rules page
2. Check for generated incidents
3. Tune thresholds based on alert volume
4. Create additional custom rules for your environment
5. Integrate with notification channels (email, Teams, etc.)

## Support

For issues or questions:
- Review **../ANALYTICS_RULES_DEPLOYMENT.md** for detailed deployment guide
- Check **../DEPLOYMENT_GUIDE.md** for overall solution deployment
- See **../DCR_DEPLOYMENT_FIX.md** if data ingestion issues occur
