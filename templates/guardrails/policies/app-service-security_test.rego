package azure.web.security

# Base compliant App Service resource used across tests
compliant_site := {
  "type": "Microsoft.Web/sites",
  "name": "app-my-api-dev",
  "properties": {
    "httpsOnly": true,
    "siteConfig": {
      "minTlsVersion": "1.2",
      "ftpsState": "Disabled"
    }
  }
}

input_with_site(site) := {
  "resources": [{
    "type": "Microsoft.Resources/deployments",
    "name": "appservice-my-api-dev",
    "properties": {"template": {"resources": [site]}}
  }]
}

# ── Passing cases ──────────────────────────────────────────────────────────

test_pass_fully_compliant {
  count(deny) == 0 with input as input_with_site(compliant_site)
}

test_pass_tls_13 {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/siteConfig/minTlsVersion", "value": "1.3"}])
  count(deny) == 0 with input as input_with_site(site)
}

# ── HTTPS ──────────────────────────────────────────────────────────────────

test_deny_when_https_only_false {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/httpsOnly", "value": false}])
  count(deny) == 1 with input as input_with_site(site)
}

test_deny_when_https_only_missing {
  site := {"type": "Microsoft.Web/sites", "name": "app-my-api-dev", "properties": {
    "siteConfig": {"minTlsVersion": "1.2", "ftpsState": "Disabled"}
  }}
  count(deny) == 1 with input as input_with_site(site)
}

# ── TLS ────────────────────────────────────────────────────────────────────

test_deny_when_tls_10 {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/siteConfig/minTlsVersion", "value": "1.0"}])
  count(deny) == 1 with input as input_with_site(site)
}

test_deny_when_tls_11 {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/siteConfig/minTlsVersion", "value": "1.1"}])
  count(deny) == 1 with input as input_with_site(site)
}

test_deny_when_tls_missing {
  site := {"type": "Microsoft.Web/sites", "name": "app-my-api-dev", "properties": {
    "httpsOnly": true,
    "siteConfig": {"ftpsState": "Disabled"}
  }}
  count(deny) == 1 with input as input_with_site(site)
}

# ── FTPS ───────────────────────────────────────────────────────────────────

test_deny_when_ftps_allowed {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/siteConfig/ftpsState", "value": "AllAllowed"}])
  count(deny) == 1 with input as input_with_site(site)
}

test_deny_when_ftps_only {
  site := json.patch(compliant_site, [{"op": "replace", "path": "/properties/siteConfig/ftpsState", "value": "FtpsOnly"}])
  count(deny) == 1 with input as input_with_site(site)
}

# ── Multiple violations ────────────────────────────────────────────────────

test_deny_reports_all_violations {
  site := {
    "type": "Microsoft.Web/sites",
    "name": "app-insecure",
    "properties": {
      "httpsOnly": false,
      "siteConfig": {"minTlsVersion": "1.0", "ftpsState": "AllAllowed"}
    }
  }
  count(deny) == 3 with input as input_with_site(site)
}
