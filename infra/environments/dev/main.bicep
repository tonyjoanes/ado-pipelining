// Dev Environment Root Stack
// Calls all platform modules with development-appropriate sizing.
// Low-cost SKUs — this environment may be torn down and re-created frequently.
// Bicep resolves deployment order from the dependency graph, not file order.

targetScope = 'resourceGroup'

@description('Application name in kebab-case, e.g. my-api')
param appName string

@description('Build ID passed by the pipeline for tagging and deployment naming')
param buildId string = 'local'

@description('Azure AD group object ID for the SQL server admin (set via pipeline variable)')
param sqlAdminObjectId string = ''

@description('Azure AD admin login name')
param sqlAdminLoginName string = ''

var environment = 'dev'
var location = resourceGroup().location

var tags = {
  application: appName
  environment: environment
  managedBy: 'bicep'
  buildId: buildId
}

// ── Monitoring ─────────────────────────────────────────────────────────────
// Deploy first — other modules may reference its outputs for diagnostic settings
module monitoring '../../modules/monitoring/main.bicep' = {
  name: 'monitoring-${appName}-${environment}'
  params: {
    appInsightsName: 'appi-${appName}-${environment}'
    workspaceName: 'log-${appName}-${environment}'
    location: location
    tags: tags
    retentionDays: 30
  }
}

// ── App Service ────────────────────────────────────────────────────────────
module appService '../../modules/app-service/main.bicep' = {
  name: 'appservice-${appName}-${environment}'
  params: {
    appServiceName: 'app-${appName}-${environment}'
    appServicePlanName: 'asp-${appName}-${environment}'
    location: location
    tags: tags
    appServiceSku: 'B1'
  }
  dependsOn: [monitoring]
}

// ── Key Vault ──────────────────────────────────────────────────────────────
// Must deploy after App Service so we have the principalId for RBAC assignment
module keyVault '../../modules/key-vault/main.bicep' = {
  name: 'keyvault-${appName}-${environment}'
  params: {
    keyVaultName: 'kv-${appName}-${environment}'
    location: location
    tags: tags
    softDeleteRetentionDays: 7
    enablePurgeProtection: false
    secretReaderObjectIds: [appService.outputs.principalId]
  }
}

// ── Azure SQL ──────────────────────────────────────────────────────────────
module sql '../../modules/azure-sql/main.bicep' = {
  name: 'sql-${appName}-${environment}'
  params: {
    sqlServerName: 'sql-${appName}-${environment}'
    databaseName: appName
    location: location
    tags: tags
    databaseSku: 'Basic'
    aadAdminObjectId: sqlAdminObjectId
    aadAdminLoginName: sqlAdminLoginName
  }
}

// ── Outputs (consumed by pipeline configure-app-settings step) ─────────────
output appServiceName string = appService.outputs.appServiceName
output appServiceHostName string = appService.outputs.defaultHostName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
