// Staging Environment Root Stack
// Mirror of live configuration — staging is the final human gate
// before production. Configuration must match live to catch any
// environment-specific issues before they reach customers.

targetScope = 'resourceGroup'

@description('Application name in kebab-case')
param appName string

@description('Build ID passed by the pipeline')
param buildId string = 'local'

@description('Azure AD group object ID for the SQL server admin')
param sqlAdminObjectId string = ''

@description('Azure AD admin login name')
param sqlAdminLoginName string = ''

var environment = 'staging'
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
    retentionDays: 30
  }
}

module appService '../../modules/app-service/main.bicep' = {
  name: 'appservice-${appName}-${environment}'
  params: {
    appServiceName: 'app-${appName}-${environment}'
    appServicePlanName: 'asp-${appName}-${environment}'
    location: location
    tags: tags
    appServiceSku: 'P1v3'    // Same as UAT — both are pre-production gates
  }
  dependsOn: [monitoring]
}

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

module sql '../../modules/azure-sql/main.bicep' = {
  name: 'sql-${appName}-${environment}'
  params: {
    sqlServerName: 'sql-${appName}-${environment}'
    databaseName: appName
    location: location
    tags: tags
    databaseSku: 'S2'
    aadAdminObjectId: sqlAdminObjectId
    aadAdminLoginName: sqlAdminLoginName
  }
}

output appServiceName string = appService.outputs.appServiceName
output appServiceHostName string = appService.outputs.defaultHostName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
