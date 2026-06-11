// App Service Module
// Provisions an App Service Plan and App Service for a .NET 8 Linux application.
// SKU is caller-supplied — this module has no opinion on sizing.

@description('Name of the App Service')
param appServiceName string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Azure region')
param location string = resourceGroup().location

@description('App Service Plan SKU. Callers choose the tier per environment.')
@allowed(['B1', 'B2', 'B3', 'P1v3', 'P2v3', 'P3v3'])
param appServiceSku string = 'B1'

@description('Tags applied to all resources')
param tags object = {}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServiceSku
  }
  kind: 'linux'
  properties: {
    reserved: true  // Required for Linux workers
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'  // Used for Key Vault access — no credentials needed
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: '/health'
      http20Enabled: true
      alwaysOn: !startsWith(appServiceSku, 'B')  // Always-on only on Premium tiers
    }
  }
}

// Outputs consumed by pipeline (configure-app-settings step) and key-vault module
output appServiceId string = appService.id
output appServiceName string = appService.name
output principalId string = appService.identity.principalId
output defaultHostName string = appService.properties.defaultHostName
