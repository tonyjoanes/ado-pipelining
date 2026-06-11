# Deny Skipping Security Scan
# Evaluated against the compiled pipeline YAML (as JSON).
# Denies pipelines that do not include a stage running the
# security-scan job template.
#
# Note: For Tier 3, this is enforced structurally by compliance-base.yml
# which always includes runSecurityScan: true. This policy is a belt-and-
# suspenders check run against the compiled ARM/infra output to detect
# any attempt to circumvent the security stage.

package azure.pipelines.security

import future.keywords.in

# All pipeline stages
stages[stage] {
  stage := input.stages[_]
}

# All jobs across all stages
jobs[job] {
  stage := stages[_]
  job := stage.jobs[_]
}

# Check if any job uses the security-scan template
has_security_scan {
  job := jobs[_]
  contains(job.template, "security-scan.yml")
}

# In compiled ARM context, verify the deployment includes a SecurityScan resource
has_security_resource {
  resource := input.resources[_]
  contains(lower(resource.name), "securityscan")
}

deny[msg] {
  not has_security_scan
  not has_security_resource
  msg := "Pipeline must include a stage that uses templates/jobs/security-scan.yml. Security scanning cannot be skipped."
}
