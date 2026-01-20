# Cortex Cloud API Endpoint Corrections

## Summary
Updated all DCR data sources to use **correct Cortex Cloud/XDR public APIs** with proper authentication.

## Corrected Endpoints

### 1. Issues (Alerts)
- **Correct API**: `POST /public_api/v1/issue/search`
- **Authentication**: `x-xdr-auth-id` + `Authorization` headers
- **Response Path**: `$.reply.data[*]`
- **Field Mapping**:
  - `issue_id` → IssueId
  - `title` → Title
  - `severity` → Severity
  - `status` → Status
  - `created_time` → CreatedTime

### 2. Cases (Incidents)
- **Correct API**: `POST /public_api/v1/case/search`
- **Authentication**: `x-xdr-auth-id` + `Authorization` headers
- **Response Path**: `$.reply.data[*]`
- **Field Mapping**:
  - `case_id` → CaseId
  - `case_number` → CaseNumber
  - `priority` → Priority
  - `assigned_to` → AssignedTo

### 3. Endpoints (Assets)
- **Correct API**: `POST /public_api/v1/endpoints/get_endpoints`
- **Authentication**: `x-xdr-auth-id` + `Authorization` headers
- **Response Path**: `$.reply.endpoints[*]`
- **Field Mapping**:
  - `endpoint_id` → EndpointId
  - `endpoint_name` → EndpointName
  - `endpoint_status` → Status
  - `last_seen` → LastSeenTime

### 4. Audit Logs
- **Correct API**: `POST /public_api/v1/audits/management_logs`
- **Authentication**: `x-xdr-auth-id` + `Authorization` headers
- **Response Path**: `$.reply.data[*]`
- **Field Mapping**:
  - `id` → EventId
  - `type` → EventType
  - `sub` → User
  - `result` → Result

## Authentication Format
All APIs require:
```json
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {API_KEY}
  Content-Type: application/json
```

## Request Body Format
All search APIs use consistent POST body:
```json
{
  "request_data": {
    "filters": [],
    "search_from": 0,
    "search_to": 100,
    "sort": {
      "field": "created_time",
      "order": "desc"
    }
  }
}
```

## Parameters Required
- `cortexCloudApiKey`: The API Key (goes in Authorization header)
- `cortexCloudApiKeyId`: The API Key ID (goes in x-xdr-auth-id header)
- `cortexCloudFqdn`: Tenant FQDN (e.g., `tenant.xdr.us.paloaltonetworks.com`)

## Status
✅ Issues API - **CORRECTED**
✅ Cases API - **CORRECTED**
✅ Endpoints API - **CORRECTED**
✅ Audit Logs API - **CORRECTED**
⚠️ Additional Data - **REMOVED** (no standard API exists)

## Note
The "Additional Data" stream was removed as there is no standard Cortex Cloud/XDR API for generic additional data. The solution now includes **4 core data streams** instead of 5, which aligns with standard Cortex XDR CCP implementations.
