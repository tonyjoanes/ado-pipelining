# Allowed Resource Types
#
# Enforces that only resource types provisioned by the approved
# Bicep module library can appear in a compiled template.
# This is the meaningful replacement for the name-convention-based
# approach — resource types can't be faked.
#
# Azure Policy equivalent: a Deny policy on disallowed resource types.
# Rego value-add: catches it at pipeline time with a clear message,
# before the deployment attempt and before Azure Policy fires.

package azure.bicep.allowed_types

import data.azure.helpers

# The complete set of types provisioned by infra/modules/*.
# Adding a new approved module type requires updating this list
# and the corresponding Azure Policy allowed-types initiative.
allowed_types := {
  # Deployments (nested module invocations)
  "Microsoft.Resources/deployments",
  # App Service
  "Microsoft.Web/serverfarms",
  "Microsoft.Web/sites",
  # Key Vault
  "Microsoft.KeyVault/vaults",
  # RBAC (Key Vault managed identity grants)
  "Microsoft.Authorization/roleAssignments",
  # SQL
  "Microsoft.Sql/servers",
  "Microsoft.Sql/servers/databases",
  "Microsoft.Sql/servers/firewallRules",
  # Monitoring
  "Microsoft.OperationalInsights/workspaces",
  "Microsoft.Insights/components",
}

deny[msg] {
  resource := helpers.nested_resources[_]
  not resource.type in allowed_types
  msg := sprintf(
    "Resource type '%v' is not in the approved module library. Add it to infra/modules/ and the allowed_types list, or raise a platform exception.",
    [resource.type]
  )
}
