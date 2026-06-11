// Live Environment Root Stack
// Production configuration. Differences from non-prod:
//   - P2v3 App Service Plan (more compute, zone-resilient)
//   - S3 SQL database
//   - 90-day log retention (compliance requirement)
//   - Purge protection enabled on Key Vault (prevents accidental deletion)
//   - Geo-redundant SQL backup storage

targetScope = 'resourceGroup'

@description('Application name in kebab-case')
param appName string

@description('Build ID passed by the pipeline')
param buildId string = 'local'

@description('Azure AD group object ID for the SQL server admin')
param sqlAdminObjectId string = ''

@description('Azure AD admin login name')
param sqlAdminLoginName string = ''

var environment = 'live'
var location = resourceGroup().location

var tags = {
  application: appName
  environment: environment
  managedBy: 'bicep'
  buildId: buildId
}

module monitoring '../../modules/monitoring/main.bicep' = {
  name: 'monitoring-${appName}-${environment}'
  params: {
    appInsightsName: 'appi-${appName}-${environment}'
    workspaceName: 'log-${appName}-${environment}'
    location: location
    tags: tags
    retentionDays: 90          // Extended for compliance
  }
}

module appService '../../modules/app-service/main.bicep' = {
  name: 'appservice-${appName}-${environment}'
  params: {
    appServiceName: 'app-${appName}-${environment}'
    appServicePlanName: 'asp-${appName}-${environment}'
    location: location
    tags: tags
    appServiceSku: 'P2v3'      // Premium v3 — production workload
  }
  dependsOn: [monitoring]
}

module keyVault '../../modules/key-vault/main.bicep' = {
  name: 'keyvault-${appName}-${environment}'
  params: {
    keyVaultName: 'kv-${appName}-${environment}'
    location: location
    tags: tags
    softDeleteRetentionDays: 90   // 90-day retention for production
    enablePurgeProtection: true   // Prevents hard deletion of Key Vault
    secretReaderObjectIds: [appService.outputs.principalId]
  }
}

module sql '../../modules/azure-sql/main.bicep' = {
  name: 'sql-${appName}-${environment}'
  params: {
    sqlServerName: 'sql-${appName}-${environment}'
    databaseName: appName
    location: location
    tags: tags
    databaseSku: 'S3'             // Standard S3 — production throughput
    aadAdminObjectId: sqlAdminObjectId
    aadAdminLoginName: sqlAdminLoginName
  }
}

output appServiceName string = appService.outputs.appServiceName
output appServiceHostName string = appService.outputs.defaultHostName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
