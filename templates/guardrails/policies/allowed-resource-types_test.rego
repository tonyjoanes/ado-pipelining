package azure.bicep.allowed_types

# Helpers for building test inputs
deployment_with_resource_type(resource_type) := {
  "resources": [{
    "type": "Microsoft.Resources/deployments",
    "name": "test-deployment",
    "properties": {
      "template": {
        "resources": [{
          "type": resource_type,
          "name": "test-resource",
          "properties": {}
        }]
      }
    }
  }]
}

test_pass_app_service {
  count(deny) == 0 with input as deployment_with_resource_type("Microsoft.Web/sites")
}

test_pass_key_vault {
  count(deny) == 0 with input as deployment_with_resource_type("Microsoft.KeyVault/vaults")
}

test_pass_sql_server {
  count(deny) == 0 with input as deployment_with_resource_type("Microsoft.Sql/servers")
}

test_pass_monitoring {
  count(deny) == 0 with input as deployment_with_resource_type("Microsoft.Insights/components")
}

test_deny_redis_cache {
  count(deny) == 1 with input as deployment_with_resource_type("Microsoft.Cache/Redis")
}

test_deny_cosmos_db {
  count(deny) == 1 with input as deployment_with_resource_type("Microsoft.DocumentDB/databaseAccounts")
}

test_deny_public_ip {
  count(deny) == 1 with input as deployment_with_resource_type("Microsoft.Network/publicIPAddresses")
}

test_deny_reports_correct_type {
  msgs := deny with input as deployment_with_resource_type("Microsoft.Cache/Redis")
  msgs["Resource type 'Microsoft.Cache/Redis' is not in the approved module library. Add it to infra/modules/ and the allowed_types list, or raise a platform exception."]
}

test_pass_no_nested_deployments {
  count(deny) == 0 with input as {"resources": []}
}
