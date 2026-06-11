# Service Connection Setup

These service connections must exist in your Azure DevOps project before running any pipeline.

## Required Connections

| Name | Type | Subscription | Used By |
|------|------|-------------|---------|
| `sc-nonprod` | Azure Resource Manager | Non-production subscription | Tier 1/2 default, dev/test/uat |
| `sc-prod` | Azure Resource Manager | Production subscription | staging/live, Tier 3 |

## Creating a Service Connection

1. Go to **Project Settings** → **Service connections** → **New service connection**
2. Select **Azure Resource Manager**
3. Choose **Service principal (automatic)** or **Workload identity federation** (recommended)
4. Select the subscription and optionally scope to a resource group
5. Name it exactly as shown in the table above
6. Check **Grant access permission to all pipelines**

## Workload Identity Federation (Recommended)

Using federated credentials avoids client secret rotation:

```bash
az ad app create --display-name "ado-pipelining-nonprod"
az ad sp create --id <app-id>
az role assignment create \
  --assignee <sp-object-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>
```

Then configure the federated credential in the Azure portal under the app registration
to trust the ADO service connection issuer.

## Required Permissions per Service Connection

The service principal needs at minimum:

- `Contributor` on target resource groups (`rg-{appName}-{env}`)
- `User Access Administrator` on target resource groups (for Bicep RBAC role assignments to managed identities)
- `Key Vault Secrets Officer` on Key Vaults (for pipeline to write secrets post-provisioning)

## Required Template (Tier 3 Guardrail)

Configure the pipeline setting to require the compliance template:

1. Edit the Tier 3 pipeline in ADO
2. Go to **More actions** (⋮) → **Settings**
3. Under **Required template**, add:
   - Repository: `{org}/{templates-repo}` (or this repo if co-located)
   - Branch: `main`
   - Path: `templates/guardrails/compliance-base.yml`
