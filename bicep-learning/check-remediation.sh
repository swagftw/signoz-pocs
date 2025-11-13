#!/bin/bash
# Script to monitor Azure Policy remediation progress

echo "==================================================================="
echo "Azure Policy Remediation Monitor"
echo "==================================================================="
echo ""

# Get the latest remediation task
REMEDIATION_NAME=$(az policy remediation list \
  --query "sort_by([?contains(name, 'remediate-vm-diagnostics')], &createdOn)[-1].name" -o tsv)

if [ -z "$REMEDIATION_NAME" ]; then
  echo "❌ No remediation tasks found!"
  exit 1
fi

echo "📋 Monitoring: $REMEDIATION_NAME"
echo ""

# Monitor the remediation
while true; do
  RESULT=$(az policy remediation show --name "$REMEDIATION_NAME" -o json)

  STATE=$(echo "$RESULT" | jq -r '.provisioningState')
  TOTAL=$(echo "$RESULT" | jq -r '.deploymentStatus.totalDeployments')
  SUCCESS=$(echo "$RESULT" | jq -r '.deploymentStatus.successfulDeployments')
  FAILED=$(echo "$RESULT" | jq -r '.deploymentStatus.failedDeployments')

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Status: $STATE | Total: $TOTAL | Success: $SUCCESS | Failed: $FAILED"

  # Exit if completed or failed
  if [[ "$STATE" == "Succeeded" ]] || [[ "$STATE" == "Complete" ]]; then
    echo ""
    echo "✅ Remediation completed successfully!"
    echo ""
    echo "To verify diagnostic settings were created, run:"
    echo "  az policy state list --filter \"policyAssignmentName eq 'assign-vm-diagnostics-policy'\" --query \"[].{resource:resourceId, compliance:complianceState}\" -o table"
    break
  elif [[ "$STATE" == "Failed" ]]; then
    echo ""
    echo "❌ Remediation failed!"
    echo ""
    echo "View full details:"
    echo "  az policy remediation show --name $REMEDIATION_NAME"
    break
  fi

  sleep 15
done

