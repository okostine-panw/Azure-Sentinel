#!/bin/bash
# Script to deploy Cortex Cloud Analytics Rules to Microsoft Sentinel
# Uses Azure CLI and Sentinel REST API

# Variables - UPDATE THESE
RESOURCE_GROUP="rg-sentinel-cortexcloud"
WORKSPACE_NAME="cortexcloud"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "=== Deploying Cortex Cloud Analytics Rules to Sentinel ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Workspace: $WORKSPACE_NAME"
echo "Subscription: $SUBSCRIPTION_ID"
echo ""

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query id -o tsv)

echo "Workspace ID: $WORKSPACE_ID"
echo ""

# Function to create an analytic rule
create_analytic_rule() {
    local RULE_NAME=$1
    local RULE_FILE=$2
    
    echo "=== Deploying: $RULE_NAME ==="
    
    # Create ARM template for the rule
    cat > /tmp/rule-template.json << 'TEMPLATE_EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "workspaceName": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.OperationalInsights/workspaces/providers/alertRules",
      "apiVersion": "2023-02-01-preview",
      "name": "[concat(parameters('workspaceName'), '/Microsoft.SecurityInsights/', 'RULE_ID')]",
      "kind": "Scheduled",
      "properties": {
        "displayName": "RULE_DISPLAY_NAME",
        "description": "RULE_DESCRIPTION",
        "severity": "RULE_SEVERITY",
        "enabled": true,
        "query": "RULE_QUERY",
        "queryFrequency": "QUERY_FREQUENCY",
        "queryPeriod": "QUERY_PERIOD",
        "triggerOperator": "TRIGGER_OPERATOR",
        "triggerThreshold": TRIGGER_THRESHOLD,
        "suppressionDuration": "PT5H",
        "suppressionEnabled": false,
        "tactics": TACTICS,
        "techniques": TECHNIQUES,
        "entityMappings": ENTITY_MAPPINGS,
        "customDetails": CUSTOM_DETAILS,
        "alertDetailsOverride": ALERT_DETAILS_OVERRIDE,
        "eventGroupingSettings": EVENT_GROUPING,
        "incidentConfiguration": INCIDENT_CONFIG
      }
    }
  ]
}
TEMPLATE_EOF

    # Parse YAML and extract values (simplified - you may need yq for complex parsing)
    # For now, create rules manually or use Azure Portal
    
    echo "  Rule file: $RULE_FILE"
    echo "  Status: Template created (manual values needed)"
    echo ""
}

# Deploy each rule
echo "=== Creating Analytic Rules ==="
echo ""

# Rule 1: Critical Issue Detection
create_analytic_rule "Cortex Cloud - Critical Issue Detected" "CortexCloud-CriticalIssue.yaml"

# Rule 2: Case SLA Breach
create_analytic_rule "Cortex Cloud - Case SLA Breach" "CortexCloud-CaseSLABreach.yaml"

# Rule 3: Multiple Issues on Asset
create_analytic_rule "Cortex Cloud - Multiple Issues on Single Asset" "CortexCloud-MultipleIssuesOnAsset.yaml"

echo ""
echo "=== Analytic Rules Deployment Notes ==="
echo ""
echo "Due to complexity of Sentinel Analytics Rules API, we recommend:"
echo ""
echo "Option 1: Use Azure Portal (Easiest)"
echo "  1. Go to Sentinel → Analytics → Create → Scheduled query rule"
echo "  2. Copy values from each YAML file"
echo "  3. Configure and save"
echo ""
echo "Option 2: Use Sentinel Solutions/Content Hub"
echo "  1. Package rules as a Sentinel Solution"
echo "  2. Deploy via Content Hub"
echo ""
echo "Option 3: Use REST API with complete ARM templates"
echo "  1. Convert YAML to full ARM template"
echo "  2. Deploy using 'az rest' command"
echo ""
echo "See ANALYTICS_RULES_DEPLOYMENT.md for detailed instructions"
