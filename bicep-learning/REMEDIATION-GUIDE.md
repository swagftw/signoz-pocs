# Azure Policy Remediation - Quick Reference

## ⚠️ The Problem You Encountered

You deployed an Azure Policy with `DeployIfNotExists` effect, but it didn't automatically fix your existing VM. **This is expected behavior!**

## 🔍 Why This Happens

Azure Policy's `DeployIfNotExists` effect works in two modes:

1. **For NEW resources** - Automatically applied when resources are created
2. **For EXISTING resources** - Requires a manual **Remediation Task**

## ✅ Solution: Remediation Tasks

### Step 1: Check Compliance Status
```bash
az policy state list \
  --filter "policyAssignmentName eq 'assign-vm-diagnostics-policy'" \
  --query "[].{resource:resourceId, compliance:complianceState}" -o table
```

### Step 2: Create Remediation Task
```bash
az policy remediation create \
  --name remediate-vm-diagnostics-$(date +%s) \
  --policy-assignment assign-vm-diagnostics-policy \
  --resource-discovery-mode ExistingNonCompliant
```

### Step 3: Monitor Progress
**Option A - Use the monitoring script:**
```bash
./bicep-learning/check-remediation.sh
```

**Option B - Manual checks:**
```bash
# List all remediation tasks
az policy remediation list \
  --query "[].{name:name, state:provisioningState}" -o table

# Check specific remediation
az policy remediation show --name <remediation-name>
```

### Step 4: Verify Diagnostic Settings
After remediation completes (usually 5-15 minutes):
```bash
# Check compliance again
az policy state list \
  --filter "policyAssignmentName eq 'assign-vm-diagnostics-policy'" \
  --query "[].{resource:resourceId, compliance:complianceState}" -o table

# List diagnostic settings on your VM
az monitor diagnostic-settings list --resource <VM_RESOURCE_ID>
```

## 🔄 Current Remediation Status

A remediation task has been created: `remediate-vm-diagnostics-1763550025`

Current status: **Running**
- Total Deployments: 1 (your VM)
- This will take 5-15 minutes to complete

## 📊 Timeline

```
Time 0:00  - Policy Deployed
           ⬇️
Time 0:00+ - VM exists but policy doesn't automatically remediate
           ⬇️
Time X:XX  - You manually delete diagnostic settings
           ⬇️
Time X:XX+ - Policy detects non-compliance but doesn't auto-fix
           ⬇️ 
Time NOW   - You create remediation task ✅
           ⬇️
Time +5-15min - Diagnostic settings automatically deployed
           ⬇️
Time +20min - VM shows as "Compliant"
```

## 🎯 Key Takeaways

1. **Policies don't auto-fix existing resources** - Only new ones
2. **Use remediation tasks** - To fix existing non-compliant resources
3. **Be patient** - Remediation takes 5-15 minutes
4. **Compliance evaluation** - Runs every ~30 minutes, but remediation triggers immediate deployment

## 📝 Common Commands Reference

```bash
# List all policy assignments
az policy assignment list -o table

# Check policy compliance
az policy state summarize --filter "policyAssignmentName eq 'assign-vm-diagnostics-policy'"

# List remediation tasks
az policy remediation list -o table

# Delete a remediation task
az policy remediation delete --name <remediation-name>

# Force policy re-evaluation (trigger on-demand scan)
az policy state trigger-scan --no-wait
```

## 🚀 For Future Reference

When you create new VMs after deploying this policy:
- Diagnostic settings will be **automatically** created within 10-15 minutes
- No remediation task needed for new resources
- This is the power of Azure Policy automation! 🎉

