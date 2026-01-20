# Cortex Cloud Azure Sentinel Solution - Summary

## Solution Overview

This Azure Sentinel solution for Palo Alto Networks Cortex Cloud provides comprehensive integration for security monitoring, incident management, and automated response. The solution is built using Microsoft's Codeless Connector Platform (CCP) for high-scale, reliable data ingestion.

## What's Included

### 📊 Data Connectors
- **CCP-based connector** for 5 data streams (100% parity with Cortex XDR CCP)
- **Data Collection Rule (DCR)** template for automated configuration
- Support for 5 data streams:
  - **Issues** (Security Alerts - equivalent to XDR Alerts)
  - **Cases** (Incidents - equivalent to XDR Incidents)
  - **Endpoints** (Asset Inventory - equivalent to XDR Endpoints)
  - **Audit Logs** (Activity Audit Trail)
  - **Additional Data** (Supplementary Telemetry)

**Note**: Cortex Cloud runs on the same platform as Cortex XDR and provides access to the same underlying data

### 🔍 Parsers (4 KQL Functions)
- **CortexCloudIssues**: Normalizes and enriches issue data with risk scoring
- **CortexCloudCases**: Normalizes and enriches case data with SLA tracking
- **CortexCloudEndpoints**: Normalizes endpoint/asset data with health scoring
- **CortexCloudAdditionalData**: Normalizes supplementary data streams

### 🚨 Analytic Rules
1. **Critical Issue Detected**: Alerts on critical severity issues
2. **Case SLA Breach**: Detects cases exceeding SLA thresholds
3. **Multiple Issues on Same Asset**: Identifies potentially compromised assets

### 📈 Workbooks
- **Cortex Cloud Overview**: Comprehensive dashboard with:
  - Issue statistics and trends
  - Case management metrics
  - Severity distribution
  - Resolution time analysis
  - Assignment tracking

### 🤖 Playbooks (4 Automated Workflows)
1. **CortexCloud-EnrichIssue**: Enriches incidents with detailed issue information from Cortex Cloud API
2. **CortexCloud-UpdateCaseStatus**: Bi-directional status synchronization between Sentinel and Cortex Cloud
3. **CortexCloud-AssignCase**: Synchronizes case assignments from Sentinel to Cortex Cloud
4. **CortexCloud-CloseCase**: Comprehensive case closure with full documentation transfer

### 🎯 Hunting Queries (8 Proactive Queries)
1. **Issue Trend Analysis**: Identifies anomalies in issue creation patterns
2. **Unassigned Critical Cases**: Finds critical/high priority cases without owners
3. **Asset Risk Assessment**: Comprehensive risk scoring based on issue patterns
4. **Stale Cases Investigation**: Identifies cases without recent updates
5. **Issue Correlation Patterns**: Discovers patterns between issue categories
6. **Analyst Workload Analysis**: Analyzes case distribution across analysts
7. **Recurring Issues Detection**: Identifies repeatedly occurring issues on same assets
8. **Stale and Offline Endpoints**: Identifies endpoints that haven't checked in recently

## Key Features

✅ **Real-time Ingestion**: 5-minute polling interval (configurable)  
✅ **Scalable**: Built on Azure's CCP platform  
✅ **Automated**: Pre-configured rules and playbooks  
✅ **Customizable**: All components can be modified  
✅ **Documented**: Comprehensive guides and examples  

## Directory Structure

```
Cortex-Cloud-Sentinel-Solution/
├── README.md                           # Main documentation
├── PROJECT_PLAN.md                     # Project planning document
├── DEPLOYMENT_GUIDE.md                 # Step-by-step deployment
├── MIGRATION_GUIDE.md                  # XDR to Cloud migration
├── CAPABILITY_COMPARISON.md            # Comparison with XDR CCP
├── SOLUTION_SUMMARY.md                 # This file
├── SolutionMetadata.json              # Solution manifest
│
├── DataConnectors/
│   ├── Palo_Alto_Cortex_Cloud_CCP.json
│   └── CortexCloud-DCR-Template.json
│
├── Parsers/
│   ├── CortexCloudIssues.kql
│   ├── CortexCloudCases.kql
│   ├── CortexCloudEndpoints.kql
│   └── CortexCloudAdditionalData.kql
│
├── AnalyticRules/
│   ├── CortexCloud-CriticalIssue.yaml
│   ├── CortexCloud-CaseSLABreach.yaml
│   └── CortexCloud-MultipleIssuesOnAsset.yaml
│
├── HuntingQueries/
│   ├── CortexCloud-IssueTrendAnalysis.yaml
│   ├── CortexCloud-UnassignedCriticalCases.yaml
│   ├── CortexCloud-AssetRiskAssessment.yaml
│   ├── CortexCloud-StaleCases.yaml
│   ├── CortexCloud-IssueCorrelationPatterns.yaml
│   ├── CortexCloud-AnalystWorkloadAnalysis.yaml
│   ├── CortexCloud-RecurringIssues.yaml
│   └── CortexCloud-StaleOfflineEndpoints.yaml
│
├── Workbooks/
│   └── CortexCloud-Overview.json
│
└── Playbooks/
    ├── CortexCloud-EnrichIssue.json
    ├── CortexCloud-UpdateCaseStatus.json
    ├── CortexCloud-AssignCase.json
    └── CortexCloud-CloseCase.json
```

## Quick Start

### Prerequisites
- Azure Subscription with Sentinel enabled
- Cortex Cloud tenant with API access
- API Key with Issues (Read), Cases (Read/Write) permissions

### Basic Deployment (5 Steps)

1. **Generate API Key** in Cortex Cloud
2. **Deploy DCR** using the provided ARM template
3. **Install Parsers** in Log Analytics
4. **Deploy Analytics Rules** in Sentinel
5. **Verify Data Flow** after 15 minutes

📖 See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed instructions.

## Data Schema

### Issues Table (CortexCloudIssues_CL)
```
TimeGenerated, IssueId, Title, Description, Severity, Status, 
Category, AffectedAssets, CreatedTime, ModifiedTime, Tags
```

### Cases Table (CortexCloudCases_CL)
```
TimeGenerated, CaseId, CaseNumber, Title, Description, Priority, 
Status, AssignedTo, RelatedIssues, CreatedTime, UpdatedTime, ClosedTime
```

## API Endpoints

### Base URL
```
https://api-{your-fqdn}/
```

### Key Endpoints
- `POST /public_api/v1/issue/search` - List issues
- `POST /public_api/v1/issue/search/{issueId}` - Get issue details
- `POST /public_api/v1/case/search` - List cases
- `POST /public_api/v1/case/update` - Create case
- `POST /public_api/v1/case/update/{caseId}` - Update case

## Terminology: XDR vs Cortex Cloud

| Cortex XDR | Cortex Cloud |
|------------|--------------|
| Alerts | **Issues** |
| Incidents | **Cases** |
| Endpoints | Assets |

## Comparison with XDR Solution

| Feature | XDR Solution | Cloud Solution |
|---------|--------------|----------------|
| Data Source | Cortex XDR | Cortex Cloud |
| Primary Entities | Alerts, Incidents | Issues, Cases |
| Authentication | Dual-header | Single x-api-key |
| API Version | v1 public_api | v1 REST |
| CCP Support | ✅ | ✅ |
| Deployment Complexity | Medium | Medium |

## Migration from XDR

The solution includes a comprehensive migration guide for organizations moving from Cortex XDR to Cortex Cloud. Key migration strategies:

1. **Side-by-Side**: Run both connectors simultaneously (recommended)
2. **Direct Migration**: Replace XDR with Cloud connector
3. **Unified View**: Create unified parsers for both sources

📖 See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

## Performance Considerations

### Data Volume Estimates
- **Issues**: ~100-1000 per day (varies by environment)
- **Cases**: ~10-100 per day (varies by environment)
- **Audit Logs**: ~500-5000 per day (if enabled)

### Costs
- **Log Analytics Ingestion**: $2.30/GB (varies by region)
- **Data Retention**: Included for first 90 days
- **Logic App Executions**: $0.000125 per action

### Optimization Tips
- Adjust polling interval based on needs (5-30 minutes)
- Filter data at source using DCR transformations
- Use appropriate data retention policies
- Monitor ingestion volumes regularly

## Security Considerations

### API Key Management
- ✅ Store API keys in Azure Key Vault
- ✅ Use managed identities for Logic Apps
- ✅ Rotate keys every 90 days
- ✅ Limit permissions to minimum required

### Network Security
- ✅ Use Azure Private Link (if available)
- ✅ Restrict API access to known IPs
- ✅ Enable diagnostic logging
- ✅ Monitor API call patterns

### Data Protection
- ✅ Enable encryption at rest (Log Analytics)
- ✅ Use RBAC for access control
- ✅ Implement data retention policies
- ✅ Regular security audits

## Troubleshooting Quick Reference

### No Data Ingesting
1. Check DCR deployment status
2. Verify API key is valid
3. Test API connectivity manually
4. Check Log Analytics for errors

### High Costs
1. Review ingestion volumes
2. Adjust polling intervals
3. Implement data filtering
4. Optimize retention policies

### Playbook Not Running
1. Verify managed identity permissions
2. Check API connections
3. Review automation rule conditions
4. Examine Logic App run history

## Support and Resources

### Documentation
- 📖 [README.md](README.md) - Main documentation
- 📖 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Deployment instructions
- 📖 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Migration from XDR
- 📖 [PROJECT_PLAN.md](PROJECT_PLAN.md) - Project details

### External Resources
- [Cortex Cloud API Docs](https://docs-cortex.paloaltonetworks.com/)
- [Microsoft Sentinel Docs](https://docs.microsoft.com/azure/sentinel/)
- [Postman Collection](https://github.com/okostine-panw/Cortex-Cloud-APIs-Postman-Collection)

### Support Contacts
- **Cortex Cloud**: support@paloaltonetworks.com
- **Azure Sentinel**: Microsoft Support Portal
- **Community**: GitHub Issues / Discussions

## Contributing

Contributions are welcome! Areas where help is needed:
- Additional analytic rules
- More hunting queries
- Enhanced workbooks
- Additional playbooks
- Documentation improvements
- Bug fixes and optimizations

## License

This solution is provided under the MIT License.

## Version History

### v1.0.0 (January 2026)
- Initial release
- CCP-based data connector
- Issues and Cases support
- 3 analytic rules
- 1 workbook
- 1 playbook
- Comprehensive documentation

## Roadmap

### v1.1 (Q1 2026)
- [ ] Additional analytic rules
- [ ] Enhanced workbook visualizations
- [ ] More playbooks for common scenarios
- [ ] Integration with SOAR platforms

### v1.2 (Q2 2026)
- [ ] Asset inventory connector
- [ ] Advanced threat hunting queries
- [ ] Machine learning analytics
- [ ] Custom connector for non-CCP scenarios

## Acknowledgments

- **Palo Alto Networks** for Cortex Cloud platform and API documentation
- **Microsoft** for Azure Sentinel and CCP platform
- **Community contributors** for feedback and improvements

## Contact

For questions, issues, or contributions:
- Open an issue on GitHub
- Email: (add contact email)
- Community forums: (add link)

---

**Last Updated**: January 7, 2026  
**Solution Version**: 1.0.0  
**Status**: Production Ready
