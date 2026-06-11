// Azure SQL Module
// Provisions a SQL Server (AAD-only auth) and a database.
// No SQL authentication — all access is via Azure AD.
// Connection strings use managed identity; secrets live in Key Vault.

@description('SQL Server logical server name')
param sqlServerName string

@description('Database name')
param databaseName string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags applied to all resources')
param tags object = {}

@description('Database SKU. dev/test=Basic, uat/staging=S2, live=S3')
@allowed(['Basic', 'S0', 'S1', 'S2', 'S3', 'P1', 'P2'])
param databaseSku string = 'Basic'

@description('Azure AD group or user object ID for the SQL server admin')
param aadAdminObjectId string

@description('Azure AD admin login name (UPN or group display name)')
param aadAdminLoginName string

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: aadAdminLoginName
      sid: aadAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true  // Disables SQL auth entirely
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'    // Requires private endpoint or service endpoint
    version: '12.0'
  }
}

// Allow Azure services to reach the server (required for App Service without VNet integration)
resource allowAzureServicesRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: databaseSku
    tier: databaseSku == 'Basic'
      ? 'Basic'
      : startsWith(databaseSku, 'S') ? 'Standard' : 'Premium'
  }
  properties: {
    zoneRedundant: databaseSku == 'P1' || databaseSku == 'P2'  // Premium only
    requestedBackupStorageRedundancy: 'Local'  // Change to 'Geo' in live
  }
}

output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseId string = sqlDatabase.id
output databaseName string = sqlDatabase.name
