# Require Approved Bicep Modules
# Evaluated against the compiled ARM JSON of the Bicep root stack.
# Denies any nested deployment that does not originate from the
# central module library (infra/modules/).
#
# Run with: conftest test compiled-arm.json --policy policies/

package azure.bicep.modules

import future.keywords.in
import future.keywords.every

# Approved module paths in the compiled ARM output.
# Nested deployments from approved modules have a templateLink or
# are inlined with a _generator.name matching our known modules.
approved_modules := {
  "app-service",
  "azure-sql",
  "key-vault",
  "monitoring",
}

# Collect all nested deployment resources
nested_deployments[resource] {
  resource := input.resources[_]
  resource.type == "Microsoft.Resources/deployments"
}

# Extract the module name from the deployment name convention:
# deploy-{module}-{appName}-{env}
deployment_module_name(deployment_name) := module_name {
  parts := split(deployment_name, "-")
  count(parts) >= 2
  module_name := parts[1]
}

deny[msg] {
  deployment := nested_deployments[_]
  name := deployment.name
  module_name := deployment_module_name(name)
  not module_name in approved_modules
  msg := sprintf(
    "Nested deployment '%v' uses unapproved module '%v'. Approved modules: %v",
    [name, module_name, approved_modules]
  )
}

warn[msg] {
  count(nested_deployments) == 0
  msg := "No nested deployments found. Ensure your Bicep uses modules from infra/modules/."
}
