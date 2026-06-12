# Production SKU Enforcement
#
# Prevents non-production SKUs being used in live and staging.
# SKU values are passed as parameters to nested deployments in the
# environment root stacks, so we read deployment.properties.parameters
# rather than the resource sku directly (which would be an ARM expression).
#
# This is a Rego-specific check — Azure Policy can restrict allowed SKUs
# but the context of "this is a production environment" is better expressed
# here where we know the environment from pipeline metadata.

package azure.infrastructure.skus

import data.azure.helpers

# SKUs that indicate non-production sizing
non_production_app_service_skus := {"F1", "D1", "B1", "B2", "B3"}
non_production_sql_skus := {"Basic", "S0", "S1"}

# Deployments that provision App Service resources
appservice_deployments[deployment] {
  deployment := helpers.nested_deployments[_]
  resource := deployment.properties.template.resources[_]
  resource.type == "Microsoft.Web/serverfarms"
}

# Deployments that provision SQL databases
sql_deployments[deployment] {
  deployment := helpers.nested_deployments[_]
  resource := deployment.properties.template.resources[_]
  resource.type == "Microsoft.Sql/servers/databases"
}

deny[msg] {
  helpers.is_production
  deployment := appservice_deployments[_]
  sku := deployment.properties.parameters.appServiceSku.value
  sku in non_production_app_service_skus
  msg := sprintf(
    "App Service SKU '%v' is not permitted in production. Use P1v3, P2v3, or P3v3.",
    [sku]
  )
}

deny[msg] {
  helpers.is_production
  deployment := sql_deployments[_]
  sku := deployment.properties.parameters.databaseSku.value
  sku in non_production_sql_skus
  msg := sprintf(
    "SQL Database SKU '%v' is not permitted in production. Use S2, S3, or a Premium tier.",
    [sku]
  )
}

# Warn (non-blocking) if dev/test is using a paid tier unnecessarily
warn[msg] {
  not helpers.is_production
  deployment := appservice_deployments[_]
  sku := deployment.properties.parameters.appServiceSku.value
  sku in {"P1v3", "P2v3", "P3v3"}
  msg := sprintf(
    "App Service SKU '%v' is a Premium tier in a non-production environment. Consider using B1 to reduce cost.",
    [sku]
  )
}
