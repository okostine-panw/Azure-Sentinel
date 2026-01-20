# Cortex XDR vs Cortex Cloud - Migration Guide

## Overview

This document provides a comprehensive comparison between the Cortex XDR and Cortex Cloud Sentinel solutions, helping organizations understand the differences and plan their migration or integration strategy.

## Key Differences

### Terminology Mapping

| Component | Cortex XDR | Cortex Cloud |
|-----------|------------|--------------|
| Security Findings | **Alerts** | **Issues** |
| Investigation Records | **Incidents** | **Cases** |
| API Endpoint Base | `/public_api/v1/` | `/issues/v1/`, `/cases/v1/` |
| Authentication Header | `x-xdr-auth-id`, `Authorization` | `x-api-key` |

### Data Tables

| XDR Table | Cortex Cloud Table | Content |
|-----------|-------------------|---------|
| `CortexXDRAlerts_CL` | `CortexCloudIssues_CL` | Security alerts/findings |
| `CortexXDRIncidents_CL` | `CortexCloudCases_CL` | Incident/case management |
| `CortexXDREndpoints_CL` | `CortexCloudAssets_CL` | Asset inventory (if applicable) |

## API Comparison

### Authentication

**Cortex XDR:**
```bash
curl -X POST "https://api-{region}.xdr.{fqdn}/public_api/v1/alerts/get_alerts" \
  -H "x-xdr-auth-id: {api-key-id}" \
  -H "Authorization: {api-key}" \
  -H "Content-Type: application/json"
```

**Cortex Cloud:**
```bash
curl -X GET "https://api-{fqdn}/public_api/v1/issue/search" \
  -H "x-api-key: {api-key}" \
  -H "Content-Type: application/json"
```

### Alerts/Issues API

**Cortex XDR - Get Alerts:**
```http
POST /public_api/v1/alerts/get_alerts
Body:
{
  "request_data": {
    "filters": [
      {
        "field": "severity",
        "operator": "in",
        "value": ["high", "critical"]
      }
    ]
  }
}
```

**Cortex Cloud - Get Issues:**
```http
POST /public_api/v1/issue/search?severity=high,critical&limit=100
```

### Incidents/Cases API

**Cortex XDR - Get Incidents:**
```http
POST /public_api/v1/incidents/get_incidents
Body:
{
  "request_data": {
    "filters": [
      {
        "field": "status",
        "operator": "in",
        "value": ["new", "under_investigation"]
      }
    ]
  }
}
```

**Cortex Cloud - Get Cases:**
```http
POST /public_api/v1/case/search?status=open,in_progress&limit=100
```

## Schema Mapping

### Alert/Issue Fields

| XDR Field | Cortex Cloud Field | Notes |
|-----------|-------------------|-------|
| `alert_id` | `issueId` | Unique identifier |
| `name` | `title` | Alert/Issue name |
| `description` | `description` | Detailed information |
| `severity` | `severity` | Both use: critical, high, medium, low |
| `host_ip` | `affectedAssets[].ipAddress` | Asset information |
| `host_name` | `affectedAssets[].name` | Asset name |
| `detection_timestamp` | `createdTime` | Creation time |
| `action_local_ip` | N/A | XDR specific |
| `action_remote_ip` | N/A | XDR specific |
| `category` | `category` | Classification |

### Incident/Case Fields

| XDR Field | Cortex Cloud Field | Notes |
|-----------|-------------------|-------|
| `incident_id` | `caseId` | Unique identifier |
| `incident_name` | `title` | Incident/Case name |
| `description` | `description` | Details |
| `severity` | `priority` | Note: XDR uses severity, Cloud uses priority |
| `status` | `status` | Lifecycle state |
| `assigned_user_mail` | `assignedTo` | Assignment |
| `alert_count` | `relatedIssues.length` | Number of alerts/issues |
| `creation_time` | `createdTime` | Creation timestamp |
| `modification_time` | `updatedTime` | Last update |
| `resolve_time` | `closedTime` | Resolution time |

## Query Migration

### Example 1: Get Critical Alerts/Issues

**XDR Query:**
```kql
CortexXDRAlerts_CL
| where severity == "high" or severity == "critical"
| where status != "closed"
| project TimeGenerated, alert_id, name, severity, host_name
| order by TimeGenerated desc
```

**Cortex Cloud Query:**
```kql
CortexCloudIssues_CL
| where Severity in ("High", "Critical")
| where Status != "Closed"
| project TimeGenerated, IssueId, Title, Severity, AffectedAssets
| order by TimeGenerated desc
```

### Example 2: Get Open Incidents/Cases

**XDR Query:**
```kql
CortexXDRIncidents_CL
| where status in ("new", "under_investigation")
| summarize count() by severity, assigned_user_mail
```

**Cortex Cloud Query:**
```kql
CortexCloudCases_CL
| where Status in ("Open", "InProgress")
| summarize count() by Priority, AssignedTo
```

## Migration Strategies

### Strategy 1: Side-by-Side (Recommended)

Run both XDR and Cortex Cloud connectors simultaneously during transition.

**Advantages:**
- No disruption to existing operations
- Time to validate Cortex Cloud data
- Easy rollback if issues arise

**Implementation:**
1. Deploy Cortex Cloud solution
2. Run both connectors for 30-90 days
3. Validate data quality and completeness
4. Migrate analytics rules
5. Update workbooks to support both sources
6. Gradually shift operations to Cortex Cloud
7. Decommission XDR connector

### Strategy 2: Direct Migration

Replace XDR connector with Cortex Cloud connector.

**Advantages:**
- Clean cut-over
- Simplified architecture
- Reduced costs (single connector)

**Implementation:**
1. Document all XDR queries and rules
2. Deploy Cortex Cloud solution
3. Disable XDR connector
4. Update all queries, rules, and workbooks
5. Validate functionality
6. Monitor for 2 weeks
7. Remove XDR components

### Strategy 3: Unified View

Create unified parsers that work with both data sources.

**Implementation:**

Create a unified parser:

```kql
// Unified Security Findings Parser
let CortexFindings = union 
    // XDR Alerts
    (CortexXDRAlerts_CL
    | extend 
        Source = "XDR",
        FindingId = alert_id,
        FindingTitle = name,
        FindingSeverity = severity,
        FindingStatus = status,
        AffectedAsset = host_name,
        FindingTime = detection_timestamp
    ),
    // Cortex Cloud Issues
    (CortexCloudIssues_CL
    | extend 
        Source = "Cloud",
        FindingId = IssueId,
        FindingTitle = Title,
        FindingSeverity = Severity,
        FindingStatus = Status,
        AffectedAsset = tostring(AffectedAssets[0].name),
        FindingTime = CreatedTime
    )
| project 
    TimeGenerated,
    Source,
    FindingId,
    FindingTitle,
    FindingSeverity,
    FindingStatus,
    AffectedAsset,
    FindingTime;
CortexFindings
```

## Analytics Rule Migration

### XDR Critical Alert Rule

**Original (XDR):**
```yaml
query: |
  CortexXDRAlerts_CL
  | where severity == "critical"
  | where status != "closed"
  | project TimeGenerated, alert_id, name, severity, host_name
```

**Migrated (Cortex Cloud):**
```yaml
query: |
  CortexCloudIssues_CL
  | where Severity == "Critical"
  | where Status != "Closed"
  | project TimeGenerated, IssueId, Title, Severity, AffectedAssets
```

## Workbook Migration

### XDR Workbook Query

**Original:**
```kql
CortexXDRAlerts_CL
| summarize Count = count() by severity
| render piechart
```

**Migrated:**
```kql
CortexCloudIssues_CL
| summarize Count = count() by Severity
| render piechart
```

## Playbook Migration

### Key Changes

1. **API Endpoints**: Update from XDR endpoints to Cortex Cloud endpoints
2. **Authentication**: Change from dual-header to single `x-api-key` header
3. **JSON Schema**: Update request/response parsing
4. **Field Names**: Map XDR fields to Cortex Cloud fields

### Example: Enrich Alert/Issue Playbook

**XDR Version:**
```json
{
  "method": "POST",
  "uri": "https://api-region.xdr.fqdn/public_api/v1/alerts/get_alert_by_id",
  "headers": {
    "x-xdr-auth-id": "@parameters('apiKeyId')",
    "Authorization": "@parameters('apiKey')"
  },
  "body": {
    "request_data": {
      "alert_id": "@variables('alertId')"
    }
  }
}
```

**Cortex Cloud Version:**
```json
{
  "method": "GET",
  "uri": "https://api-@{parameters('fqdn')}/public_api/v1/issue/search/@{variables('issueId')}",
  "headers": {
    "x-api-key": "@parameters('apiKey')"
  }
}
```

## Feature Comparison

| Feature | Cortex XDR | Cortex Cloud | Notes |
|---------|------------|--------------|-------|
| Alert/Issue Ingestion | ✅ | ✅ | Different field names |
| Incident/Case Management | ✅ | ✅ | Similar functionality |
| Asset Inventory | ✅ | ⚠️ | May require additional configuration |
| Audit Logs | ✅ | ✅ | Different endpoints |
| Real-time Streaming | ❌ | ❌ | Both use polling |
| Webhook Support | ⚠️ | ⚠️ | Limited |
| API Rate Limits | 60/min | Varies | Check documentation |
| Authentication Method | Dual-header | Single header | Cortex Cloud simpler |
| Regional Endpoints | ✅ | ✅ | Both support |

## Best Practices

### During Migration

1. **Maintain Parallel Operations**
   - Run both connectors simultaneously
   - Compare data quality
   - Validate completeness

2. **Update Documentation**
   - Document field mappings
   - Update runbooks
   - Train SOC team

3. **Test Thoroughly**
   - Validate all queries
   - Test analytics rules
   - Verify playbook execution

4. **Monitor Closely**
   - Check data ingestion rates
   - Monitor API call volumes
   - Track costs

### Post-Migration

1. **Clean Up**
   - Remove old XDR components
   - Archive historical data if needed
   - Update access controls

2. **Optimize**
   - Tune polling intervals
   - Refine analytics rules
   - Optimize query performance

3. **Document**
   - Update SOPs
   - Create knowledge base articles
   - Share lessons learned

## Common Issues and Solutions

### Issue 1: Missing Fields

**Problem**: Cortex Cloud doesn't have exact equivalent for XDR field

**Solution**: 
- Use alternative fields
- Enrich data with additional API calls
- Accept data model differences

### Issue 2: Different Severity Scales

**Problem**: XDR and Cortex Cloud may use different severity values

**Solution**:
```kql
| extend NormalizedSeverity = case(
    tolower(Severity) in ("critical", "high"), "High",
    tolower(Severity) in ("medium", "med"), "Medium",
    tolower(Severity) in ("low", "info", "informational"), "Low",
    "Unknown"
)
```

### Issue 3: Performance Differences

**Problem**: Query performance differs between XDR and Cortex Cloud tables

**Solution**:
- Optimize queries with summarize operations
- Use time-based filters
- Consider data retention policies

## Rollback Plan

If migration encounters critical issues:

1. **Immediate Actions**
   - Re-enable XDR connector
   - Disable Cortex Cloud connector
   - Notify stakeholders

2. **Investigation**
   - Document issues encountered
   - Gather logs and error messages
   - Consult with Palo Alto support

3. **Resolution**
   - Address identified issues
   - Re-test in isolated environment
   - Create detailed migration plan v2

## Support Resources

- **Cortex XDR Documentation**: https://docs.paloaltonetworks.com/cortex/cortex-xdr
- **Cortex Cloud Documentation**: https://docs-cortex.paloaltonetworks.com/
- **Palo Alto Support**: https://support.paloaltonetworks.com
- **Microsoft Sentinel**: https://docs.microsoft.com/azure/sentinel

## Conclusion

Migrating from Cortex XDR to Cortex Cloud requires careful planning and execution. Using the side-by-side strategy minimizes risk while allowing thorough validation. Remember to:

- ✅ Test thoroughly before switching
- ✅ Maintain documentation
- ✅ Train your team
- ✅ Monitor closely after migration
- ✅ Have a rollback plan ready
