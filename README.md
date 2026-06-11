# Azure DevOps YAML Pipeline Reference

A reference implementation showing how to use Azure DevOps YAML pipelines with Bicep infrastructure-as-code for C# services deploying to Azure. The YAML describes *what* happens; Bicep handles *how* the infrastructure is provisioned.

## The Three Tier Model

Teams choose the tier that matches their autonomy vs. guardrails trade-off:

| | Tier 1 — Golden Path | Tier 2 — Extended | Tier 3 — Innovation |
|---|---|---|---|
| **Who** | Standard services | Services with custom steps | Platform/innovation teams |
| **What teams change** | 3–4 parameters | Stage overrides, extra steps | Full pipeline + Bicep |
| **Guardrails** | All stages managed centrally | Job/step templates enforced | `extends` + OPA policies |
| **Entry point** | `pipelines/tier1/golden-path.yml` | `pipelines/tier2/extended.yml` | `pipelines/tier3/innovation.yml` |

## Pipeline Flow

All tiers follow the same promotion chain:

```
Build → [dev] → [test] → [uat] → [staging] → [live]
         │         │         │         │          │
      InfraDeploy AppDeploy SmokeTest  (repeat per env)
```

UAT, staging, and live require approval gates configured on ADO Environments (not in YAML).

## Quick Start — Tier 1

1. Copy `pipelines/tier1/golden-path.yml` to your repository as `azure-pipelines.yml`
2. Change `appName` and `azureSubscription` parameters at the top
3. Point the pipeline at the templates repository (configure resource in ADO)
4. Configure approval gates on the ADO Environments: `{appName}-uat`, `{appName}-staging`, `{appName}-live`

## Repository Structure

```
pipelines/          # Entry points — teams copy these
  tier1/            # Golden path: minimal params, everything managed
  tier2/            # Extended: stage-level overrides possible
  tier3/            # Innovation: full custom via `extends` + guardrails

templates/          # Central template library (platform-owned)
  stages/           # Stage-level templates (Tier 1 consumes here)
  jobs/             # Job-level templates (Tier 2 overrides here)
  steps/            # Atomic step templates (Tier 3 picks from here)
  variables/        # Per-environment variable sets (SKUs, resource names)
  guardrails/       # compliance-base.yml and OPA policies

infra/
  modules/          # Approved, reusable Bicep modules (SKU-agnostic)
  environments/     # Root stacks per environment (sets SKUs, calls modules)

src/SampleApi/      # .NET 8 Minimal Web API demo application
```

## Secrets Strategy

No raw secret values appear anywhere in YAML or Bicep outputs.

- Bicep provisions Key Vault and grants the App Service managed identity `Key Vault Secrets User`
- The pipeline `configure-app-settings` step sets app settings as Key Vault references:
  `@Microsoft.KeyVault(VaultName=kv-myapp-dev;SecretName=sqlConnectionString)`
- The application reads `Configuration["ConnectionStrings:Default"]` normally

## Infrastructure SKUs by Environment

| Environment | App Service Plan | SQL Database | Log Retention |
|-------------|------------------|--------------|---------------|
| dev         | B1               | Basic        | 30 days       |
| test        | B1               | Basic        | 30 days       |
| uat         | P1v3             | S2           | 30 days       |
| staging     | P1v3             | S2           | 30 days       |
| live        | P2v3             | S3           | 90 days       |

## Tier 3 Guardrails

Four layers prevent innovation teams from breaking compliance:

1. **`extends` keyword** — ADO evaluates compliance-base.yml at parse time; mandatory stages cannot be removed
2. **OPA/Conftest** — ComplianceValidation stage runs `.rego` policies against compiled Bicep ARM JSON
3. **Branch protection** — PRs required to modify anything in `templates/guardrails/`
4. **ADO Environment approvals** — configured outside YAML; teams cannot bypass in code

## Prerequisites

- Azure DevOps organization with Pipelines enabled
- Service connections (`sc-nonprod`, `sc-prod`) configured as Azure Resource Manager connections
- Resource groups pre-created per environment: `rg-{appName}-{env}`
- ADO Environments created: `{appName}-{dev,test,uat,staging,live}`
- Approval checks configured on `{appName}-uat`, `{appName}-staging`, `{appName}-live` environments
- For Tier 3 OPA checks: Conftest available or installable on agents
