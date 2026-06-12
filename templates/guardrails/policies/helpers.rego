# Shared helpers imported by all policy packages.
# When Bicep compiles to ARM JSON, each module becomes a
# Microsoft.Resources/deployments nested deployment. Actual
# resources (Web/sites, KeyVault/vaults, etc.) live inside
# deployment.properties.template.resources.

package azure.helpers

# All resources from within nested deployments
nested_resources[resource] {
  deployment := input.resources[_]
  deployment.type == "Microsoft.Resources/deployments"
  resource := deployment.properties.template.resources[_]
}

# All nested deployments
nested_deployments[deployment] {
  deployment := input.resources[_]
  deployment.type == "Microsoft.Resources/deployments"
}

# Environments where production-grade configuration is required.
# Passed to Conftest via --data '{"metadata":{"environment":"live"}}'
is_production {
  data.metadata.environment == "live"
}

is_production {
  data.metadata.environment == "staging"
}
