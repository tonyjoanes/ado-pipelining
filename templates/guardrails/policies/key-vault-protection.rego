# Key Vault Protection
#
# Verifies Key Vault hardening settings. Some values are hardcoded
# in the module (enableSoftDelete, enableRbacAuthorization) and
# checked directly on the resource. Others are environment-specific
# parameters (enablePurgeProtection, softDeleteRetentionInDays) and
# are checked on the nested deployment's parameter values.
#
# Azure Policy equivalents:
#   - "Azure Key Vault should have soft delete enabled"
#   - "Key vaults should have purge protection enabled" (production)
#   - "Key Vault should use RBAC permission model"

package azure.keyvault.protection

import data.azure.helpers

key_vaults[vault] {
  vault := helpers.nested_resources[_]
  vault.type == "Microsoft.KeyVault/vaults"
}

# Deployments that provision a Key Vault (for checking parameter values)
keyvault_deployments[deployment] {
  deployment := helpers.nested_deployments[_]
  resource := deployment.properties.template.resources[_]
  resource.type == "Microsoft.KeyVault/vaults"
}

# Soft delete protects against accidental or malicious deletion.
# Hardcoded to true in the module — this verifies it hasn't been weakened.
deny[msg] {
  vault := key_vaults[_]
  not vault.properties.enableSoftDelete == true
  msg := sprintf(
    "Key Vault '%v' must have enableSoftDelete: true.",
    [vault.name]
  )
}

# RBAC authorization model is required — legacy access policies are deprecated
# and harder to audit.
deny[msg] {
  vault := key_vaults[_]
  not vault.properties.enableRbacAuthorization == true
  msg := sprintf(
    "Key Vault '%v' must use RBAC authorization (enableRbacAuthorization: true). Legacy access policies are not permitted.",
    [vault.name]
  )
}

# Purge protection prevents hard-deletion of the vault for the retention period.
# Required in production — without it a malicious actor (or accident) could
# permanently destroy secrets with no recovery window.
deny[msg] {
  helpers.is_production
  deployment := keyvault_deployments[_]
  purge_protection := deployment.properties.parameters.enablePurgeProtection.value
  not purge_protection == true
  msg := "Key Vault must have enablePurgeProtection: true in production environments."
}

# Soft delete retention must be 90 days in production for compliance.
# 7 days (the non-prod default) is insufficient for incident response.
deny[msg] {
  helpers.is_production
  deployment := keyvault_deployments[_]
  retention := deployment.properties.parameters.softDeleteRetentionDays.value
  retention < 90
  msg := sprintf(
    "Key Vault softDeleteRetentionDays is %v. Production environments require at least 90 days.",
    [retention]
  )
}
