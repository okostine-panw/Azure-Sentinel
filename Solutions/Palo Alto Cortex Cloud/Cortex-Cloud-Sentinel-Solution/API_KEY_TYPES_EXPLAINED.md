# Cortex XDR/Cloud API Key Types Explained

## Overview

When creating an API key in Cortex XDR/Cloud, you can choose between two security levels:
- **Standard** (Recommended for most integrations)
- **Advanced** (For enhanced security with anti-replay protection)

---

## Standard API Keys ✅ Recommended for This Integration

### Authentication Method
```http
POST /public_api/v1/issue/search
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {API_KEY}
  Content-Type: application/json
```

### Characteristics
- ✅ **Simple authentication**: Just 2 headers (`x-xdr-auth-id` + `Authorization`)
- ✅ **Works with any HTTP client**: cURL, Postman, Azure DCR, SIEM tools
- ✅ **Easy to implement**: No hashing or token generation required
- ✅ **Access to all public APIs**: Full access to `/public_api/v1/*` endpoints
- ✅ **Perfect for SIEM integrations**: Microsoft Sentinel, Splunk, QRadar, etc.
- ✅ **Easier troubleshooting**: Simple headers make debugging straightforward

### Best For
- SIEM integrations (Microsoft Sentinel, Splunk, QRadar)
- Webhook integrations
- Azure Data Collection Rules
- Simple scripts using cURL or basic HTTP libraries
- Third-party security tools

### Security
- API key is a secret bearer token
- Should be stored securely (Azure Key Vault, AWS Secrets Manager, etc.)
- Standard HTTPS encryption protects API key in transit
- No built-in replay attack protection

---

## Advanced API Keys (Optional)

### Authentication Method
```http
POST /public_api/v1/issue/search
Headers:
  x-xdr-auth-id: {API_KEY_ID}
  Authorization: {GENERATED_TOKEN}
  x-xdr-timestamp: {CURRENT_TIMESTAMP_MS}
  x-xdr-nonce: {RANDOM_STRING}
  Content-Type: application/json
```

Where `GENERATED_TOKEN` is:
```python
import hashlib
import secrets
import time

timestamp = str(int(time.time() * 1000))
nonce = secrets.token_urlsafe(64)
auth_token = f"{API_KEY}{nonce}{timestamp}"
generated_token = hashlib.sha256(auth_token.encode()).hexdigest()
```

### Characteristics
- ✅ **Anti-replay protection**: Each request uses unique nonce + timestamp
- ✅ **Enhanced security**: Prevents replay attacks even if request is intercepted
- ✅ **Required for Cortex XSOAR**: XSOAR integrations mandate Advanced keys
- ❌ **Complex implementation**: Requires code to generate authentication tokens
- ❌ **Not supported by simple HTTP clients**: cURL requires scripting wrapper
- ❌ **Harder to troubleshoot**: Multi-step token generation adds complexity
- ⚠️ **Clock sync required**: Timestamp validation requires accurate system time

### Best For
- Cortex XSOAR (Palo Alto's SOAR platform) - **REQUIRED**
- Custom Python/Node.js applications with provided client libraries
- Environments requiring protection against replay attacks
- High-security scenarios with additional compliance requirements

### Security
- Provides protection against replay attacks
- Even if HTTPS traffic is captured, tokens can't be reused
- Timestamp validation prevents old requests from being replayed
- Still requires secure storage of base API key

---

## Comparison Table

| Feature | Standard | Advanced |
|---------|----------|----------|
| **Authentication Complexity** | Simple (2 headers) | Complex (4 headers + hashing) |
| **Works with cURL** | ✅ Yes | ❌ No (needs wrapper script) |
| **Works with Azure DCR** | ✅ Yes | ❌ No |
| **Works with SIEM tools** | ✅ Yes | ⚠️ Depends on tool |
| **Access to Public APIs** | ✅ Full access | ✅ Full access |
| **Replay Attack Protection** | ❌ No | ✅ Yes |
| **Required for XSOAR** | ❌ No | ✅ Yes |
| **Implementation Time** | < 5 minutes | 30+ minutes |
| **Troubleshooting Ease** | ✅ Easy | ❌ Complex |
| **Clock Sync Required** | No | Yes |

---

## Common Misconceptions

### ❌ Myth: "Advanced keys have more API access"
**Reality**: Both Standard and Advanced keys have **identical access** to all public APIs. The difference is only in the authentication method, not the permissions or available endpoints.

### ❌ Myth: "Standard keys can't access public APIs"
**Reality**: Standard keys have **full access** to `/public_api/v1/*` endpoints. They work perfectly for all API operations including search, update, create, and delete operations (based on role permissions).

### ❌ Myth: "Advanced keys are more secure for all use cases"
**Reality**: Advanced keys provide **anti-replay protection**, which is valuable in certain scenarios but adds unnecessary complexity for most SIEM integrations. Standard keys with proper secret management (Key Vault) are sufficient for most use cases.

### ❌ Myth: "You need Advanced for production deployments"
**Reality**: Most production SIEM integrations (including Microsoft Sentinel, Splunk, QRadar) use **Standard** keys. Advanced is primarily for XSOAR and custom applications.

---

## Decision Guide

### Use **Standard** if:
- ✅ Integrating with Microsoft Sentinel, Splunk, QRadar, or other SIEM
- ✅ Using Azure Data Collection Rules (DCR)
- ✅ Building webhook integrations
- ✅ Using cURL, Postman, or simple HTTP clients
- ✅ Want simple, maintainable implementation
- ✅ Need easy troubleshooting capability

### Use **Advanced** if:
- ✅ Integrating with Cortex XSOAR (required)
- ✅ Building custom Python/Node.js apps with provided SDKs
- ✅ Have specific compliance requirement for anti-replay protection
- ✅ Have development resources for complex authentication
- ✅ Can maintain accurate clock synchronization

---

## For This Sentinel Integration

**Recommendation: Use Standard API Key**

Reasons:
1. Azure DCR doesn't support the complex authentication required for Advanced keys
2. Standard keys provide full access to all required APIs
3. API key stored securely in Azure Key Vault
4. Simpler implementation and troubleshooting
5. Consistent with other SIEM integrations
6. No replay attack risk in server-to-server API calls

---

## Security Best Practices (Both Key Types)

### For Standard Keys:
1. **Store securely**: Use Azure Key Vault (not plain text in configuration)
2. **Rotate regularly**: Generate new keys every 90 days
3. **Limit permissions**: Use least-privilege RBAC (e.g., "Viewer" role for read-only)
4. **Monitor usage**: Track API key activity in Cortex audit logs
5. **Restrict access**: Only grant key access to necessary systems/people
6. **Use HTTPS**: Always use encrypted connections (enforced by Cortex APIs)

### Additional for Advanced Keys:
7. **Clock synchronization**: Ensure accurate system time (NTP)
8. **Nonce uniqueness**: Use cryptographically secure random number generator
9. **Token expiration**: Implement short-lived token caching
10. **Error handling**: Handle timestamp validation errors gracefully

---

## Testing Your API Key

### Standard Key Test (cURL):
```bash
curl -X POST "https://api-{your-fqdn}/public_api/v1/issue/search" \
  -H "x-xdr-auth-id: 1234" \
  -H "Authorization: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "request_data": {
      "filters": [],
      "search_from": 0,
      "search_to": 1
    }
  }'
```

Expected: `200 OK` with JSON response

### Advanced Key Test (Python):
```python
import hashlib
import secrets
import time
import requests

api_key_id = "1234"
api_key = "YOUR_API_KEY"
fqdn = "your-tenant.xdr.us.paloaltonetworks.com"

timestamp = str(int(time.time() * 1000))
nonce = secrets.token_urlsafe(64)
auth_token = f"{api_key}{nonce}{timestamp}"
generated_token = hashlib.sha256(auth_token.encode()).hexdigest()

headers = {
    "x-xdr-auth-id": api_key_id,
    "Authorization": generated_token,
    "x-xdr-timestamp": timestamp,
    "x-xdr-nonce": nonce,
    "Content-Type": "application/json"
}

response = requests.post(
    f"https://api-{fqdn}/public_api/v1/issue/search",
    headers=headers,
    json={"request_data": {"filters": [], "search_from": 0, "search_to": 1}}
)

print(response.status_code, response.json())
```

---

## References

- [Cortex XDR API Documentation](https://docs-cortex.paloaltonetworks.com/r/Cortex-XDR-REST-API/Get-Started-with-Cortex-XDR-APIs)
- [Your Cortex Cloud Postman Collection](https://github.com/okostine-panw/Cortex-Cloud-APIs-Postman-Collection)
- Azure Key Vault for secret storage
- Standard keys recommended by major SIEM vendors

---

## Summary

For the **Cortex Cloud Sentinel Integration**, use a **Standard API key**. It provides:
- ✅ Full API access
- ✅ Simple implementation  
- ✅ Easy troubleshooting
- ✅ Compatible with Azure DCR
- ✅ Industry standard for SIEM integrations

Advanced keys are valuable for specific use cases (XSOAR, custom apps) but add unnecessary complexity for Sentinel integration.
