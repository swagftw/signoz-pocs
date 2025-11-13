# Bicep Learning Guide - VM Diagnostics to Event Hub

## 📚 Learning Path

I've broken down the complex Bicep templates into **4 simple lessons** that build on each other. Start with Lesson 1 and work your way up!

---

## 🎯 Lesson 1: Simple Event Hub
**File:** `01-simple-eventhub.bicep`

### What You'll Learn:
- What is an Event Hub (think: mailbox for data)
- Basic Bicep syntax: parameters, resources, outputs
- How resources relate to each other (parent-child)

### Key Concepts:
```
Event Hub Namespace (container)
    └── Event Hub (the actual queue/stream)
          └── Authorization Rule (access key/password)
```

### What It Does:
Creates a place to receive VM metrics data.

### Try It:
```bash
az group create --name rg-learning --location eastus

az deployment group create \
  --resource-group rg-learning \
  --template-file 01-simple-eventhub.bicep \
  --parameters namespaceName=my-first-eventhub
```

**Expected Result:** An Event Hub ready to receive data ✅

---

## 🎯 Lesson 2: Manual VM Diagnostics
**File:** `02-manual-vm-diagnostics.bicep`

### What You'll Learn:
- How to reference existing resources
- What diagnostic settings are
- How to connect a VM to Event Hub

### Key Concepts:
- `existing` keyword = reference something already created
- `scope` = which resource to configure
- Diagnostic settings = the connection between VM and Event Hub

### What It Does:
Manually configures ONE VM to send metrics to Event Hub.

### The Problem:
❌ You have to run this for EVERY VM manually
❌ New VMs won't automatically get configured

### Try It:
First create a VM, then:
```bash
az deployment group create \
  --resource-group rg-learning \
  --template-file 02-manual-vm-diagnostics.bicep \
  --parameters vmName=myvm \
               eventHubAuthRuleId="<from-lesson-1-output>"
```

**Expected Result:** One VM sends metrics to Event Hub ✅

---

## 🎯 Lesson 3: Azure Policy (The Magic!)
**File:** `03-policy-automatic.bicep`

### What You'll Learn:
- What is Azure Policy
- How `DeployIfNotExists` effect works
- Managed identities and permissions
- Subscription-level deployments

### Key Concepts:

**Azure Policy = Automatic Rule Enforcer**

Think of it like a building manager:
1. **Rule:** "Any new tenant gets WiFi automatically"
2. **Detection:** Policy watches for new VMs
3. **Action:** Automatically deploys diagnostic settings
4. **No manual work!**

### Policy Structure:
```
1. IF condition (when does this apply?)
   └── field type = Virtual Machine
   
2. THEN effect (what should happen?)
   └── DeployIfNotExists
       ├── Check: Does diagnostic setting exist?
       └── If not: Deploy it automatically!
```

### What It Does:
- Creates a policy definition (the rule)
- Assigns it to your subscription (activates it)
- Gives it permissions (managed identity + role)
- Watches for new VMs forever

### Try It:
```bash
az deployment sub create \
  --location eastus \
  --template-file 03-policy-automatic.bicep \
  --parameters eventHubAuthRuleId="<from-lesson-1>" \
               eventHubName=vm-metrics
```

Then create a test VM:
```bash
az vm create --resource-group rg-test --name testvm --image Ubuntu2204 --admin-username azureuser --generate-ssh-keys
```

**Expected Result:** After 10-15 minutes, diagnostic settings appear automatically! ✅

---

## 🎯 Lesson 4: Complete Solution
**File:** `04-complete-solution.bicep`

### What You'll Learn:
- How to use modules (reusable templates)
- Dependencies between resources
- Orchestrating multiple deployments

### Key Concepts:

**Module = Reusable Bicep File**
```bicep
module eventHubModule '01-simple-eventhub.bicep' = {
  name: 'deploy-eventhub'
  scope: resourceGroup
  params: { ... }
}
```

It's like calling a function in programming!

### What It Does:
Combines everything:
1. Creates Event Hub (Lesson 1)
2. Creates Policy (Lesson 3)
3. Connects them together

### Try It (ONE COMMAND!):
```bash
az deployment sub create \
  --location eastus \
  --template-file 04-complete-solution.bicep \
  --parameters eventHubNamespaceName=my-vm-diagnostics
```

**Expected Result:** Complete automatic VM diagnostics system! 🎉

---

## 🔑 Key Bicep Concepts Explained

### 1. **Parameters** (Inputs)
```bicep
@description('A helpful description')
param myParameter string = 'defaultValue'
```
Like function arguments - values you provide when deploying.

### 2. **Resources** (Things to Create)
```bicep
resource myResource 'Microsoft.Type/resourceType@version' = {
  name: 'name-of-resource'
  location: 'eastus'
  properties: { ... }
}
```
The actual Azure resources you're creating.

### 3. **Existing Resources** (Reference Only)
```bicep
resource existingVM 'Microsoft.Compute/virtualMachines@2023-09-01' existing = {
  name: 'vm-that-already-exists'
}
```
Don't create - just reference something that's already there.

### 4. **Outputs** (Return Values)
```bicep
output resourceId string = myResource.id
```
Values you want to see or use after deployment.

### 5. **Modules** (Reusable Templates)
```bicep
module myModule 'other-file.bicep' = {
  name: 'deployment-name'
  params: { ... }
}
```
Call another Bicep file (like a function).

### 6. **Target Scope**
```bicep
targetScope = 'subscription'  // Deploy at subscription level
targetScope = 'resourceGroup' // Deploy at resource group level (default)
```

---

## 🎓 Learning Progression

### Understanding Levels:

**Level 1 (Lesson 1):** 
- You understand: Creating simple Azure resources
- You can: Deploy an Event Hub

**Level 2 (Lesson 2):**
- You understand: Connecting resources together
- You can: Manually configure VM diagnostics

**Level 3 (Lesson 3):**
- You understand: Azure Policy and automation
- You can: Create automatic rules for compliance

**Level 4 (Lesson 4):**
- You understand: Orchestrating complex deployments
- You can: Build complete solutions with modules

---

## 🧪 Hands-On Exercise

**Goal:** Deploy the complete solution and verify it works

1. **Deploy:**
   ```bash
   az deployment sub create \
     --location eastus \
     --template-file 04-complete-solution.bicep \
     --parameters eventHubNamespaceName=test-$(date +%s)
   ```

2. **Wait 5 minutes** for deployment to complete

3. **Create a test VM:**
   ```bash
   az vm create \
     --resource-group rg-test \
     --name testvm \
     --image Ubuntu2204 \
     --admin-username azureuser \
     --generate-ssh-keys
   ```

4. **Wait 15 minutes** for policy to evaluate

5. **Check if it worked:**
   ```bash
   VM_ID=$(az vm show --resource-group rg-test --name testvm --query id -o tsv)
   az monitor diagnostic-settings list --resource $VM_ID
   ```

6. **Expected:** You should see diagnostic settings configured automatically! 🎉

---

## 🆚 Comparison: Manual vs Automatic

| Aspect | Manual (Lesson 2) | Automatic (Lesson 3) |
|--------|-------------------|---------------------|
| **Setup** | Deploy for each VM | Deploy policy once |
| **New VMs** | Must configure manually | Automatic |
| **Existing VMs** | Run template for each | Run remediation task once |
| **Maintenance** | High effort | Low effort |
| **Scalability** | Poor (10 VMs = 10 deployments) | Excellent (1000 VMs = 0 manual work) |
| **Best For** | Learning, testing | Production, enterprise |

---

## 🤔 Common Questions

### Q: What if I already have VMs?
**A:** Run a remediation task:
```bash
az policy remediation create \
  --name fix-existing-vms \
  --policy-assignment assign-vm-diagnostics-policy
```

### Q: How long does the policy take to apply?
**A:** 10-15 minutes after VM creation (evaluation cycle).

### Q: Can I test without waiting?
**A:** Yes! Manually trigger evaluation:
```bash
az policy state trigger-scan --no-wait
```

### Q: How do I see if VMs are compliant?
**A:** 
```bash
az policy state list \
  --filter "policyDefinitionName eq 'auto-configure-vm-diagnostics'"
```

### Q: What if I want to exclude certain VMs?
**A:** Modify the policy's `if` condition or use exclusions in the assignment.

---

## 📖 Further Reading

- **Bicep Documentation:** https://learn.microsoft.com/azure/azure-resource-manager/bicep/
- **Azure Policy:** https://learn.microsoft.com/azure/governance/policy/
- **Event Hubs:** https://learn.microsoft.com/azure/event-hubs/
- **Diagnostic Settings:** https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings

---

## 🎯 Next Steps for Your Go Program

Once you understand these Bicep templates, your Go program will:

1. **Read user configuration** (which resources to monitor)
2. **Select appropriate Bicep template** (VMs, Storage, etc.)
3. **Generate parameters** based on user input
4. **Compile Bicep to ARM JSON** (using Bicep CLI)
5. **Deploy using Azure SDK** 
6. **Monitor deployment status**
7. **Return results to user**

The Bicep templates stay simple and readable - the Go program handles the orchestration!

---

**Ready to start?** Begin with Lesson 1 and work your way through! 🚀

