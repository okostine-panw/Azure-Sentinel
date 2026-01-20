# PARSER INSTALLATION - STEP BY STEP

## ⚠️ CRITICAL: Install One Parser at a Time

**DO NOT paste multiple parsers into one function!**

---

## Error You're Seeing

```
A syntax error has been identified in the query. 
Query could not be parsed at 'CortexCloudCasesCortexCloudEndpoints' on line [138,21]
```

**This means:** You accidentally pasted TWO parser files together!
- Line 77 ends `CortexCloudCases` 
- Line 78 starts `let CortexCloudEndpoints = () {`
- Result: `CortexCloudCasesCortexCloudEndpoints` (no space/semicolon)

---

## 🔧 CORRECT Installation Process

### Parser 1: CortexCloudIssues

1. Open **Sentinel** → **Logs**
2. **Clear the query window completely**
3. Open file: `Parsers/CortexCloudIssues.kql` 
4. **Select ALL content** (Ctrl+A in the file)
5. Copy (Ctrl+C)
6. Paste into Sentinel query window
7. Click **Save** → **Save as function**
8. Function Name: `CortexCloudIssues`
9. Category: `Cortex Cloud`
10. Click **Save**
11. **DO NOT click Run**

### Parser 2: CortexCloudCases

1. **CLEAR THE QUERY WINDOW** (this is critical!)
2. Open file: `Parsers/CortexCloudCases.kql`
3. **Select ALL content** (Ctrl+A)
4. Copy (Ctrl+C)
5. Paste into **EMPTY** query window
6. Click **Save** → **Save as function**
7. Function Name: `CortexCloudCases`
8. Category: `Cortex Cloud`  
9. Click **Save**
10. **DO NOT click Run**

### Parser 3: CortexCloudEndpoints

1. **CLEAR THE QUERY WINDOW** (critical!)
2. Open file: `Parsers/CortexCloudEndpoints.kql`
3. **Select ALL content** (Ctrl+A)
4. Copy (Ctrl+C)
5. Paste into **EMPTY** query window
6. Click **Save** → **Save as function**
7. Function Name: `CortexCloudEndpoints`
8. Category: `Cortex Cloud`
9. Click **Save**
10. **DO NOT click Run**

---

## ✅ How to Verify You Did It Right

After saving each parser, the query window should show:

### For CortexCloudIssues:
- First line: `// Cortex Cloud Issues Parser`
- Last line: `CortexCloudIssues`
- Line count: ~71 lines
- **Should NOT contain**: `CortexCloudCases` or `CortexCloudEndpoints`

### For CortexCloudCases:
- First line: `// Cortex Cloud Cases Parser`
- Last line: `CortexCloudCases`
- Line count: ~77 lines
- **Should NOT contain**: `CortexCloudIssues` or `CortexCloudEndpoints`

### For CortexCloudEndpoints:
- First line: `// Cortex Cloud Endpoints Parser`
- Last line: `CortexCloudEndpoints`
- Line count: ~69 lines
- **Should NOT contain**: `CortexCloudIssues` or `CortexCloudCases`

---

## ❌ Common Mistakes

### Mistake 1: Not Clearing Query Window
```kql
// First parser
let CortexCloudIssues = () { ... };
CortexCloudIssues
// User pastes second parser WITHOUT clearing
let CortexCloudCases = () { ... };  ← ERROR! Two functions in one
```

### Mistake 2: Selecting Wrong Content
- ❌ Selected only part of the file
- ❌ Selected from middle of file
- ✅ Selected entire file from first comment to last line

### Mistake 3: Testing Before Data Exists
```kql
CortexCloudCases
| where Priority == "Critical"  ← This will fail with "NormalizedStatus" error
```
**Why?** Table exists but has no data, so computed columns like `NormalizedStatus` don't exist yet.

---

## 🔍 Troubleshooting Specific Errors

### Error: "CortexCloudCasesCortexCloudEndpoints"
**Cause:** Two parsers pasted together without clearing query window

**Fix:**
1. Delete the saved function
2. Clear query window completely
3. Paste ONLY ONE parser
4. Save again

### Error: "Invalid column name: 'NormalizedStatus'"
**Cause:** Trying to RUN/TEST the parser before data exists

**Fix:** 
- Don't click "Run" after saving the parser
- Wait for data ingestion (15-30 minutes)
- First verify raw data: `CortexCloudCases_CL | take 10`
- Then test parser: `CortexCloudCases | take 10`

### Error: "Query could not be parsed at..."
**Cause:** Missing part of parser (didn't copy entire file)

**Fix:**
1. Make sure you copied from **first line** (comment) to **last line** (function name)
2. Each parser should start with `//` comment
3. Each parser should end with function name only (e.g., `CortexCloudCases`)

---

## 📋 Parser File Checklist

Before pasting each parser, verify:

- [ ] Query window is completely empty
- [ ] Copied entire file (first line = comment, last line = function name)
- [ ] File contains only ONE parser (not multiple concatenated)
- [ ] Last line is just the function name (e.g., `CortexCloudIssues`)
- [ ] No syntax errors showing in file

After saving each parser:

- [ ] Function saved successfully
- [ ] Did NOT click "Run" button
- [ ] Moved to next parser (cleared window first)

---

## 📝 What Each Parser Should Look Like

### Structure:
```kql
// Comment at top
let FunctionName = () {
    TableName_CL
    | extend ...
    | extend ...
    | project ...
};
FunctionName
```

### Key Points:
1. Starts with comment (`//`)
2. Function definition with `let FunctionName = () {`
3. Query logic inside `{ }`
4. Closing `};` with semicolon
5. Function call at end (just the name)
6. **Nothing after the function name**

---

## 🎯 Installation Order

1. ✅ **Install parsers** (one at a time, don't test)
2. ⏰ **Wait 15-30 minutes** for DCR to ingest data
3. ✅ **Test raw tables** first: `CortexCloudIssues_CL | take 10`
4. ✅ **Test parsers** after data exists: `CortexCloudIssues | take 10`
5. ✅ **Deploy analytics rules** (they use the parser functions)
6. ✅ **Deploy workbooks** (they use the parser functions)

---

## Need to Start Over?

If you made a mistake:

1. Go to **Sentinel** → **Logs** → **Functions**
2. Find the incorrect function
3. Click **...** → **Delete**
4. Clear query window
5. Start fresh with correct process above

---

## Still Getting Errors?

Copy and paste the EXACT error message and I'll help you fix it!

Common questions:
- "Which file do I copy?" → Copy ONE file at a time from `Parsers/` folder
- "Where do I paste it?" → Sentinel Logs query window (must be empty first)
- "Can I test it?" → Not until data exists (15-30 min after DCR deployment)
- "How many lines?" → Issues: 71, Cases: 77, Endpoints: 69
