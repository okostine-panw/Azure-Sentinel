# Parser Installation Guide

## Important Notes

### ⚠️ Install Parsers BEFORE Data Ingestion

The parsers should be **installed as functions** but **NOT tested/run** until after the DCR starts ingesting data.

**Why?** The parsers reference tables (`CortexCloudIssues_CL`, etc.) that need to have data before queries can run against them.

---

## Installation Steps

### Step 1: Create Parser Functions

For **each** of the 3 parsers:

1. Navigate to: **Microsoft Sentinel** → **Logs**
2. Click **Save** dropdown → **Save as function**
3. Fill in the form:

**For CortexCloudIssues:**
- Function Name: `CortexCloudIssues`
- Category: `Cortex Cloud`
- Function Alias: Leave blank (or same as Function Name)
- Copy the **entire contents** of `Parsers/CortexCloudIssues.kql`
- Paste into the query window
- Click **Save**

**For CortexCloudCases:**
- Function Name: `CortexCloudCases`
- Category: `Cortex Cloud`
- Function Alias: Leave blank
- Copy the **entire contents** of `Parsers/CortexCloudCases.kql`
- Paste into the query window
- Click **Save**

**For CortexCloudEndpoints:**
- Function Name: `CortexCloudEndpoints`
- Category: `Cortex Cloud`
- Function Alias: Leave blank
- Copy the **entire contents** of `Parsers/CortexCloudEndpoints.kql`
- Paste into the query window
- Click **Save**

---

## ⚠️ DO NOT Test Parsers Yet

**Do NOT click "Run" or try to test the parsers immediately after saving!**

The parsers will show errors like:
- ❌ "Invalid column name: 'NormalizedStatus'"
- ❌ "Table 'CortexCloudIssues_CL' not found"

**This is normal!** These errors occur because:
1. The tables exist but have no data yet
2. You haven't waited for DCR to start ingesting

---

## When Can I Test Parsers?

**Wait until AFTER:**
1. ✅ DCR is deployed successfully
2. ✅ Wait 15-30 minutes for first data ingestion
3. ✅ Verify raw data exists:
   ```kql
   CortexCloudIssues_CL
   | take 10
   ```

**Then you can test parsers:**
```kql
CortexCloudIssues
| take 10
```

---

## Verification After Data Arrives

### Check Raw Data First
```kql
// Check Issues
CortexCloudIssues_CL
| take 5

// Check Cases
CortexCloudCases_CL
| take 5

// Check Endpoints
CortexCloudEndpoints_CL
| take 5
```

### Then Test Parsers
```kql
// Test Issues parser
CortexCloudIssues
| where Severity == "Critical"
| take 10

// Test Cases parser
CortexCloudCases
| where Status == "Open"
| take 10

// Test Endpoints parser
CortexCloudEndpoints
| where NormalizedStatus == "Offline"
| take 10
```

---

## Troubleshooting

### Error: "Invalid column name: 'NormalizedStatus'"

**Cause:** Trying to run parser before data exists in tables

**Solution:** Wait for DCR to ingest data (15-30 minutes after deployment)

### Error: "Table 'CortexCloudIssues_CL' not found"

**Cause:** Custom tables not created yet OR no data ingested

**Solution:** 
1. Verify tables exist:
   ```bash
   az monitor log-analytics workspace table list \
     --resource-group rg-sentinel-cortexcloud \
     --workspace-name cortexcloud \
     --query "[?contains(name, 'CortexCloud')].name"
   ```
2. Wait for data ingestion (15-30 minutes)

### Error: "Query could not be parsed"

**Cause:** Missing semicolon or syntax error in parser

**Solution:** 
1. Copy parser content again from the file
2. Make sure you copied the **entire file** including:
   - Opening `let FunctionName = () {`
   - All query logic
   - Closing `};`
   - Final function call `FunctionName`

---

## Deployment Order Summary

✅ **Correct Order:**
1. Create custom tables (Scripts/create-custom-tables.sh)
2. Wait 2-3 minutes
3. Deploy DCR
4. **Install parsers as functions** (do NOT test yet)
5. Wait 15-30 minutes for data ingestion
6. Verify raw data exists
7. **NOW you can test parsers**
8. Deploy analytics rules
9. Deploy workbooks
10. Deploy playbooks

❌ **Wrong Order:**
1. Install parsers
2. **Try to test parsers immediately** ← This causes errors
3. Get confused by "NormalizedStatus" errors

---

## Parser Function Format

All parsers use this format:

```kql
// Comment
let FunctionName = () {
    TableName_CL
    | extend ...
    | project ...
};
FunctionName
```

The function wrapper allows the parser to be **saved** even when tables are empty, but it still can't be **executed** until data exists.

---

## Quick Reference

| Step | Action | Can Test Parser? |
|------|--------|------------------|
| 1 | Create tables | ❌ No |
| 2 | Deploy DCR | ❌ No |
| 3 | Save parser functions | ❌ No |
| 4 | Wait 15-30 min | ❌ No |
| 5 | Verify raw data | ✅ Almost |
| 6 | Data confirmed | ✅ **Yes!** |

---

## Need Help?

- **No data after 30 minutes?** Check DCR_DEPLOYMENT_FIX.md
- **Parser syntax errors?** Make sure you copied the entire file
- **Authentication errors?** Check API_ENDPOINT_CORRECTIONS.md
- **General issues?** See DEPLOYMENT_GUIDE.md troubleshooting section
