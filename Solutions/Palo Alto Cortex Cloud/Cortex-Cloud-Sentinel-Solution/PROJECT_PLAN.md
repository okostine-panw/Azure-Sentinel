# Azure Sentinel Solution for Cortex Cloud - Project Plan

## Overview
This project creates an Azure Sentinel solution for Palo Alto Networks Cortex Cloud, adapted from the existing Cortex XDR CCP solution.

## Key Mapping: XDR to Cortex Cloud
| XDR Term | Cortex Cloud Term |
|----------|-------------------|
| Alerts | Issues |
| Incidents | Cases |

## Solution Structure

### 1. Data Connector (CCP-based)
**File**: `Data Connectors/Palo_Alto_Cortex_Cloud_CCP.json`

#### Endpoints to Support:
1. **Issues API** (replaces Alerts)
   - Endpoint: `/public_api/v1/issue/search`
   - Polling interval: 5 minutes
   - Maps to: Issues_CL table

2. **Cases API** (replaces Incidents)
   - Endpoint: `/public_api/v1/case`
   - Polling interval: 5 minutes
   - Maps to: Cases_CL table

3. **Additional Endpoints** (if applicable):
   - Audit Logs
   - Endpoints/Assets
   - Threat Intelligence

#### Authentication:
- API Key based authentication
- Headers: `x-api-key`, `Content-Type: application/json`
- Validation endpoint: `https://api-{fqdn}/api_keys/validate/`

### 2. Workbooks
**Directory**: `Workbooks/`

Create workbooks for:
- **Cortex Cloud Overview**
  - Issues by severity
  - Case statistics
  - Time-based trends
  
- **Issues Analysis**
  - Issue types distribution
  - Top affected assets
  - Issue resolution timeline

- **Cases Management**
  - Open vs closed cases
  - Case aging analysis
  - Assignment distribution

### 3. Analytic Rules
**Directory**: `Analytic Rules/`

Create detection rules for:
- High severity issues
- Critical cases requiring immediate attention
- Multiple issues on same asset
- Cases with extended resolution time
- Abnormal issue patterns

### 4. Hunting Queries
**Directory**: `Hunting Queries/`

Create queries for:
- Issue investigation
- Case correlation
- Asset risk assessment
- Threat hunting across issues

### 5. Playbooks (Logic Apps)
**Directory**: `Playbooks/`

Create automation playbooks for:
- **CortexCloud-EnrichIssue**
  - Enrich issue with additional context
  
- **CortexCloud-CreateCase**
  - Automatically create cases from issues
  
- **CortexCloud-UpdateCase**
  - Update case status and comments
  
- **CortexCloud-AssignCase**
  - Auto-assign cases based on rules

- **CortexCloud-CloseCase**
  - Close cases with proper documentation

### 6. Parsers
**Directory**: `Parsers/`

Create KQL parsers:
- **CortexCloudIssues**
  - Normalizes issue data
  
- **CortexCloudCases**
  - Normalizes case data

### 7. Solution Package
**File**: `Solution/CortexCloud.json`

Package metadata including:
- Version information
- Dependencies
- Installation instructions
- Configuration requirements

## API Specifications

### Cortex Cloud API Base URL
```
https://api-{region}.{fqdn}/
```

### Key API Endpoints

#### 1. Issues API (replaces XDR Alerts)
```
POST /public_api/v1/issue/search
POST /public_api/v1/issue/search/{issueId}/acknowledge
POST /public_api/v1/issue/search/{issueId}/resolve
POST /public_api/v1/issue/search/{issueId}
```

#### 2. Cases API (replaces XDR Incidents)
```
POST /public_api/v1/case/search
POST /public_api/v1/case/update
POST /public_api/v1/case/update/{caseId}
POST /public_api/v1/case/search/{caseId}
POST /public_api/v1/case/update/{caseId}/comments
DELETE /public_api/v1/case/{caseId}
```

#### 3. Authentication
```
POST /api_keys/validate/
```

### Request Headers
```
x-api-key: {API_KEY}
Content-Type: application/json
Accept: application/json
```

## Data Schema

### Issues_CL Table Schema
```kql
Issues_CL
| extend 
    IssueId = tostring(properties.issueId),
    Title = tostring(properties.title),
    Severity = tostring(properties.severity),
    Status = tostring(properties.status),
    Category = tostring(properties.category),
    AffectedAssets = properties.affectedAssets,
    CreatedTime = todatetime(properties.createdTime),
    ModifiedTime = todatetime(properties.modifiedTime),
    Description = tostring(properties.description)
```

### Cases_CL Table Schema
```kql
Cases_CL
| extend 
    CaseId = tostring(properties.caseId),
    CaseNumber = tostring(properties.caseNumber),
    Title = tostring(properties.title),
    Priority = tostring(properties.priority),
    Status = tostring(properties.status),
    AssignedTo = tostring(properties.assignedTo),
    RelatedIssues = properties.relatedIssues,
    CreatedTime = todatetime(properties.createdTime),
    UpdatedTime = todatetime(properties.updatedTime),
    ClosedTime = todatetime(properties.closedTime)
```

## Configuration Requirements

### Prerequisites
1. Cortex Cloud tenant with API access
2. API Key with appropriate permissions
3. Azure Sentinel workspace
4. Log Analytics workspace with sufficient retention

### Required Permissions
API Key must have:
- Read access to Issues
- Read/Write access to Cases
- Access to validation endpoint

## Testing Plan

1. **Data Connector Testing**
   - Verify API connectivity
   - Test authentication
   - Validate data ingestion
   - Check polling intervals

2. **Workbook Testing**
   - Verify all visualizations
   - Test time range selections
   - Validate data queries

3. **Analytic Rules Testing**
   - Test rule triggering
   - Verify alert generation
   - Check false positive rates

4. **Playbook Testing**
   - Test all automation scenarios
   - Verify API calls
   - Check error handling

## Migration from XDR to Cortex Cloud

### For Existing XDR Users
1. Install Cortex Cloud solution alongside XDR
2. Configure both connectors
3. Update workbooks to support both sources
4. Gradually migrate analytics rules
5. Deprecate XDR solution after validation

## Documentation Requirements

1. **Installation Guide**
2. **Configuration Guide**
3. **User Guide**
4. **API Reference**
5. **Troubleshooting Guide**

## Timeline Estimate
- Data Connector Development: 2-3 days
- Workbooks Creation: 2 days
- Analytic Rules: 2 days
- Playbooks: 3-4 days
- Testing & Documentation: 2-3 days
- **Total**: 11-14 days

## Next Steps
1. Review and approve project plan
2. Begin data connector development
3. Create sample data for testing
4. Develop workbooks and analytics
5. Create playbooks
6. Comprehensive testing
7. Documentation
8. Package solution for deployment
