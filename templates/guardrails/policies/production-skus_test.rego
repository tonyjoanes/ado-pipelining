package azure.infrastructure.skus

# Test input builders
appservice_deployment(sku) := {
  "type": "Microsoft.Resources/deployments",
  "name": "appservice-my-api",
  "properties": {
    "parameters": {"appServiceSku": {"value": sku}},
    "template": {"resources": [{
      "type": "Microsoft.Web/serverfarms",
      "name": "asp-my-api",
      "sku": {"name": "[parameters('appServiceSku')]"}
    }]}
  }
}

sql_deployment(sku) := {
  "type": "Microsoft.Resources/deployments",
  "name": "sql-my-api",
  "properties": {
    "parameters": {"databaseSku": {"value": sku}},
    "template": {"resources": [{
      "type": "Microsoft.Sql/servers/databases",
      "name": "my-api",
      "sku": {"name": "[parameters('databaseSku')]"}
    }]}
  }
}

live_data := {"metadata": {"environment": "live"}}
staging_data := {"metadata": {"environment": "staging"}}
dev_data := {"metadata": {"environment": "dev"}}

# ── App Service — production passing cases ─────────────────────────────────

test_pass_p1v3_in_live {
  count(deny) == 0
    with input as {"resources": [appservice_deployment("P1v3")]}
    with data as live_data
}

test_pass_p2v3_in_live {
  count(deny) == 0
    with input as {"resources": [appservice_deployment("P2v3")]}
    with data as live_data
}

test_pass_p3v3_in_live {
  count(deny) == 0
    with input as {"resources": [appservice_deployment("P3v3")]}
    with data as live_data
}

# ── App Service — production failing cases ─────────────────────────────────

test_deny_b1_in_live {
  count(deny) == 1
    with input as {"resources": [appservice_deployment("B1")]}
    with data as live_data
}

test_deny_b2_in_live {
  count(deny) == 1
    with input as {"resources": [appservice_deployment("B2")]}
    with data as live_data
}

test_deny_b1_in_staging {
  count(deny) == 1
    with input as {"resources": [appservice_deployment("B1")]}
    with data as staging_data
}

test_deny_message_contains_sku_name {
  deny_msgs := deny
    with input as {"resources": [appservice_deployment("B1")]}
    with data as live_data
  some msg in deny_msgs
  contains(msg, "B1")
  contains(msg, "P1v3")
}

# ── App Service — non-production ───────────────────────────────────────────

test_pass_b1_in_dev {
  count(deny) == 0
    with input as {"resources": [appservice_deployment("B1")]}
    with data as dev_data
}

test_warn_premium_in_dev {
  count(warn) == 1
    with input as {"resources": [appservice_deployment("P2v3")]}
    with data as dev_data
}

# ── SQL — production passing cases ────────────────────────────────────────

test_pass_s2_in_live {
  count(deny) == 0
    with input as {"resources": [sql_deployment("S2")]}
    with data as live_data
}

test_pass_s3_in_live {
  count(deny) == 0
    with input as {"resources": [sql_deployment("S3")]}
    with data as live_data
}

# ── SQL — production failing cases ────────────────────────────────────────

test_deny_basic_in_live {
  count(deny) == 1
    with input as {"resources": [sql_deployment("Basic")]}
    with data as live_data
}

test_deny_s1_in_live {
  count(deny) == 1
    with input as {"resources": [sql_deployment("S1")]}
    with data as live_data
}

test_deny_s0_in_staging {
  count(deny) == 1
    with input as {"resources": [sql_deployment("S0")]}
    with data as staging_data
}

# ── SQL — non-production ──────────────────────────────────────────────────

test_pass_basic_in_dev {
  count(deny) == 0
    with input as {"resources": [sql_deployment("Basic")]}
    with data as dev_data
}
