# Playbook API Corrections

## ⚠️ Current Playbooks Require Updating

The included playbooks use APIs that need correction for Cortex Cloud compatibility. A working example is provided below.

### ❌ Wrong APIs in Playbooks:

1. **CortexCloud-EnrichIssue.json**
   - Uses: `GET /issues/v1/issues/{issueId}`
   - Should use: `POST /public_api/v1/issue/search` with filter

2. **CortexCloud-AssignCase.json**
   - Uses: `PUT /cases/v1/cases/{caseId}`
   - Should use: `POST /public_api/v1/case/update`

3. **CortexCloud-UpdateCaseStatus.json**
   - Uses: `PUT /cases/v1/cases/{caseId}`
   - Should use: `POST /public_api/v1/case/update`

4. **CortexCloud-CloseCase.json**
   - Uses: `PUT /cases/v1/cases/{caseId}`
   - Should use: `POST /public_api/v1/case/update`

---

## ✅ Correct Cortex Cloud Public APIs

### Get Issue by ID
```json
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

### Update Case
```json
POST /public_api/v1/case/update
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {API_KEY}
Body:
{
  "request_data": {
    "case_id": "{caseId}",
    "update_data": {
      "status": "in_progress",
      "assigned_to": "analyst@company.com"
    }
  }
}
```

### Close Case
```json
POST /public_api/v1/case/update
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {API_KEY}
Body:
{
  "request_data": {
    "case_id": "{caseId}",
    "update_data": {
      "status": "closed",
      "resolution": "Resolved"
    }
  }
}
```

---

## 🔧 Playbook Corrections Needed

Each playbook needs these changes:

### 1. Update Authentication Headers
**Old:**
```json
"headers": {
  "x-api-key": "@{body('Get_API_Key_from_Key_Vault')?['value']}",
  "Content-Type": "application/json"
}
```

**New:**
```json
"headers": {
  "x-xdr-auth-id": "@{parameters('CortexCloudApiKeyId')}",
  "Authorization": "@{body('Get_API_Key_from_Key_Vault')?['value']}",
  "Content-Type": "application/json"
}
```

### 2. Change HTTP Method from GET/PUT to POST
All Cortex Cloud public APIs use **POST** method

### 3. Update Request Body Structure
All requests need `request_data` wrapper:
```json
{
  "request_data": {
    // actual parameters here
  }
}
```

---

## 📋 Playbook Fix Checklist

For each playbook:

- [ ] Change HTTP method to POST
- [ ] Update URL to correct `/public_api/v1/...` endpoint
- [ ] Add `x-xdr-auth-id` header
- [ ] Change `x-api-key` to `Authorization` header
- [ ] Wrap request body in `request_data` object
- [ ] Update response parsing for `$.reply.data` structure

---

## 🚧 Temporary Solution

**Option 1: Don't Deploy Playbooks Yet**
- Skip playbook deployment until corrected versions are ready
- Focus on data ingestion, parsers, analytics rules, and workbooks first
- Playbooks are optional for the solution to work

**Option 2: Deploy But Don't Use**
- Deploy as-is for reference
- Mark as "disabled" or "draft"
- Use as templates for building correct versions

**Option 3: Manual Correction**
- Use this guide to manually update each playbook JSON
- Test with Cortex Cloud Postman collection first
- Deploy corrected versions

---

## 📚 Reference

See **API_ENDPOINT_CORRECTIONS.md** for complete API reference with correct endpoints, authentication, and request/response formats.

For Postman examples: https://github.com/okostine-panw/Cortex-Cloud-APIs-Postman-Collection

---

## ⚠️ Important Note

The **DCR (Data Collection Rule)** uses the **CORRECT APIs** and will work properly for data ingestion. Only the **Playbooks** need correction for case management automation.

Core functionality (data ingestion, parsing, detection) works without playbooks.
