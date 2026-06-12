# App Service Security
#
# Checks that all App Service instances in the compiled template
# meet the minimum security baseline. These values are hardcoded
# in infra/modules/app-service/main.bicep — this policy verifies
# nobody has weakened the module.
#
# Azure Policy equivalents (mirror these as built-in initiatives):
#   - "App Service apps should use the latest TLS version"
#   - "App Service apps should only be accessible over HTTPS"
#   - "App Service apps should have FTPS disabled"

package azure.web.security

import data.azure.helpers

app_services[site] {
  site := helpers.nested_resources[_]
  site.type == "Microsoft.Web/sites"
}

# HTTPS must be enforced — prevents downgrade attacks
deny[msg] {
  site := app_services[_]
  not site.properties.httpsOnly == true
  msg := sprintf(
    "App Service '%v' must have httpsOnly: true. HTTP connections must be redirected to HTTPS.",
    [site.name]
  )
}

# TLS 1.0 and 1.1 are deprecated — minimum 1.2 required
deny[msg] {
  site := app_services[_]
  tls := site.properties.siteConfig.minTlsVersion
  not tls in {"1.2", "1.3"}
  msg := sprintf(
    "App Service '%v' has minTlsVersion '%v'. Must be '1.2' or '1.3'.",
    [site.name, tls]
  )
}

deny[msg] {
  site := app_services[_]
  not site.properties.siteConfig.minTlsVersion
  msg := sprintf(
    "App Service '%v' does not specify minTlsVersion. Must be '1.2' or '1.3'.",
    [site.name]
  )
}

# FTPS exposes credentials in transit — must be disabled entirely
deny[msg] {
  site := app_services[_]
  not site.properties.siteConfig.ftpsState == "Disabled"
  msg := sprintf(
    "App Service '%v' must have ftpsState: 'Disabled'. FTP and FTPS expose credentials in transit.",
    [site.name]
  )
}
