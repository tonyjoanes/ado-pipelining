// Key Vault Module
// Provisions a Key Vault with RBAC authorization.
// Grants secret read access to supplied managed identity object IDs.
// No raw secret values are stored here — secrets are written post-deploy
// by the pipeline's configure-app-settings step.

@description('Name of the Key Vault')
param keyVaultName string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags applied to all resources')
param tags object = {}

@description('Soft-delete retention in days. 7 for non-prod, 90 for live.')
param softDeleteRetentionDays int = 7

@description('Enable purge protection. Always true in live, false in non-prod.')
param enablePurgeProtection bool = false

@description('Object IDs granted Key Vault Secrets User role (e.g. App Service managed identities)')
param secretReaderObjectIds array = []

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true      // RBAC only — no legacy access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: 'Enabled'     // Restrict to VNet in production via network rules
  }
}

// Grant each managed identity the built-in Key Vault Secrets User role
resource secretReaderAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (objectId, i) in secretReaderObjectIds: {
    name: guid(keyVault.id, objectId, '4633458b-17de-408a-b874-0445c86b69e6')
    scope: keyVault
    properties: {
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User
      )
      principalId: objectId
      principalType: 'ServicePrincipal'
    }
  }
]

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
