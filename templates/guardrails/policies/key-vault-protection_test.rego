package azure.keyvault.protection

# A compliant non-production Key Vault deployment
nonprod_deployment := {
  "type": "Microsoft.Resources/deployments",
  "name": "keyvault-my-api-dev",
  "properties": {
    "parameters": {
      "enablePurgeProtection": {"value": false},
      "softDeleteRetentionDays": {"value": 7}
    },
    "template": {
      "resources": [{
        "type": "Microsoft.KeyVault/vaults",
        "name": "kv-my-api-dev",
        "properties": {
          "enableSoftDelete": true,
          "enableRbacAuthorization": true,
          "softDeleteRetentionInDays": 7,
          "enablePurgeProtection": false
        }
      }]
    }
  }
}

# A compliant production Key Vault deployment
prod_deployment := {
  "type": "Microsoft.Resources/deployments",
  "name": "keyvault-my-api-live",
  "properties": {
    "parameters": {
      "enablePurgeProtection": {"value": true},
      "softDeleteRetentionDays": {"value": 90}
    },
    "template": {
      "resources": [{
        "type": "Microsoft.KeyVault/vaults",
        "name": "kv-my-api-live",
        "properties": {
          "enableSoftDelete": true,
          "enableRbacAuthorization": true,
          "softDeleteRetentionInDays": 90,
          "enablePurgeProtection": true
        }
      }]
    }
  }
}

nonprod_metadata := {"metadata": {"environment": "dev"}}
prod_metadata := {"metadata": {"environment": "live"}}

# ── Passing cases ──────────────────────────────────────────────────────────

test_pass_compliant_nonprod {
  count(deny) == 0
    with input as {"resources": [nonprod_deployment]}
    with data as nonprod_metadata
}

test_pass_compliant_production {
  count(deny) == 0
    with input as {"resources": [prod_deployment]}
    with data as prod_metadata
}

test_pass_purge_protection_not_required_in_dev {
  count(deny) == 0
    with input as {"resources": [nonprod_deployment]}
    with data as nonprod_metadata
}

# ── Soft delete ────────────────────────────────────────────────────────────

test_deny_soft_delete_disabled {
  deployment := json.patch(nonprod_deployment, [{
    "op": "replace",
    "path": "/properties/template/resources/0/properties/enableSoftDelete",
    "value": false
  }])
  count(deny) == 1
    with input as {"resources": [deployment]}
    with data as nonprod_metadata
}

test_deny_soft_delete_missing {
  deployment := {
    "type": "Microsoft.Resources/deployments",
    "name": "keyvault-bad",
    "properties": {
      "parameters": {"enablePurgeProtection": {"value": false}, "softDeleteRetentionDays": {"value": 7}},
      "template": {"resources": [{
        "type": "Microsoft.KeyVault/vaults",
        "name": "kv-bad",
        "properties": {"enableRbacAuthorization": true}
      }]}
    }
  }
  count(deny) == 1
    with input as {"resources": [deployment]}
    with data as nonprod_metadata
}

# ── RBAC authorization ─────────────────────────────────────────────────────

test_deny_rbac_disabled {
  deployment := json.patch(nonprod_deployment, [{
    "op": "replace",
    "path": "/properties/template/resources/0/properties/enableRbacAuthorization",
    "value": false
  }])
  count(deny) == 1
    with input as {"resources": [deployment]}
    with data as nonprod_metadata
}

# ── Production purge protection ────────────────────────────────────────────

test_deny_purge_protection_disabled_in_live {
  deployment := json.patch(prod_deployment, [{
    "op": "replace",
    "path": "/properties/parameters/enablePurgeProtection/value",
    "value": false
  }])
  # Expect 1 deny (purge protection) — resource property check passes as
  # the vault resource itself doesn't expose enablePurgeProtection directly
  deny_msgs := deny
    with input as {"resources": [deployment]}
    with data as prod_metadata
  count(deny_msgs) >= 1
}

test_deny_short_retention_in_production {
  deployment := json.patch(prod_deployment, [{
    "op": "replace",
    "path": "/properties/parameters/softDeleteRetentionDays/value",
    "value": 7
  }])
  deny_msgs := deny
    with input as {"resources": [deployment]}
    with data as prod_metadata
  some msg in deny_msgs
  contains(msg, "90 days")
}

test_pass_staging_requires_production_settings {
  count(deny) == 0
    with input as {"resources": [prod_deployment]}
    with data as {"metadata": {"environment": "staging"}}
}

test_deny_staging_with_short_retention {
  deployment := json.patch(prod_deployment, [{
    "op": "replace",
    "path": "/properties/parameters/softDeleteRetentionDays/value",
    "value": 30
  }])
  deny_msgs := deny
    with input as {"resources": [deployment]}
    with data as {"metadata": {"environment": "staging"}}
  some msg in deny_msgs
  contains(msg, "90 days")
}
