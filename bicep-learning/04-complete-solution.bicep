// ============================================================================
// LESSON 4: COMPLETE SOLUTION - Everything Together
// ============================================================================
// This combines Lessons 1-3 into ONE deployment
// Deploy this and you're done - automatic VM diagnostics for all future VMs!

targetScope = 'subscription'

// ----------------------------------------------------------------------------
// PARAMETERS
// ----------------------------------------------------------------------------

@description('Name for the resource group that will hold Event Hub')
param resourceGroupName string = 'rg-vm-diagnostics'

@description('Name for the Event Hub Namespace')
param eventHubNamespaceName string

@description('Azure region')
param location string = 'eastus'

// ----------------------------------------------------------------------------
// STEP 1: Create a Resource Group
// Resource Group = A folder to organize related resources
// ----------------------------------------------------------------------------

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// ----------------------------------------------------------------------------
// STEP 2: Deploy Event Hub (using Module from Lesson 1)
// Module = Reusable Bicep template (like calling a function)
// ----------------------------------------------------------------------------

module eventHubModule '01-simple-eventhub.bicep' = {
  name: 'deploy-eventhub'
  scope: resourceGroup              // Deploy into the resource group above
  params: {
    namespaceName: eventHubNamespaceName
    location: location
  }
}

// ----------------------------------------------------------------------------
// STEP 3: Deploy Policy (using Module from Lesson 3)
// ----------------------------------------------------------------------------

module policyModule '03-policy-automatic.bicep' = {
  name: 'deploy-policy'
  params: {
    eventHubAuthRuleId: eventHubModule.outputs.authRuleId  // Use output from step 2
    eventHubName: eventHubModule.outputs.eventHubName
  }
  dependsOn: [
    eventHubModule                  // Wait for Event Hub to be created first
  ]
}

// ----------------------------------------------------------------------------
// OUTPUTS - Everything you need to know
// ----------------------------------------------------------------------------

output eventHubNamespace string = eventHubModule.outputs.eventHubNamespaceId
output policyAssignmentId string = policyModule.outputs.policyAssignmentId
output message string = 'Deployment complete! All new VMs will automatically send metrics to Event Hub.'

// ============================================================================
// ONE-COMMAND DEPLOYMENT:
//
// az deployment sub create \
//   --location eastus \
//   --template-file 04-complete-solution.bicep \
//   --parameters eventHubNamespaceName=myeventhub
//
// That's it! After this runs:
// ✅ Event Hub is created and ready to receive data
// ✅ Policy is active and watching for new VMs
// ✅ Any new VM → automatically configured → metrics flow to Event Hub
//
// ============================================================================
// WHAT GETS CREATED:
//
// Subscription Level:
//   └── Azure Policy (watching for new VMs)
//   └── Resource Group: rg-vm-diagnostics
//         └── Event Hub Namespace
//               └── Event Hub: vm-metrics
//                     └── Authorization Rule: SendListenKey
//
// ============================================================================
// ============================================================================
// LESSON 2: Enabling Diagnostic Settings for ONE VM (Manual)
// ============================================================================
// This shows how to manually configure one VM to send metrics to Event Hub
// This is NOT automatic - you run this for each VM

// ----------------------------------------------------------------------------
// PARAMETERS: Inputs needed
// ----------------------------------------------------------------------------

@description('Name of the VM that already exists')
param vmName string

@description('The ID of the Event Hub auth rule (from Lesson 1 output)')
param eventHubAuthRuleId string

@description('Name of the Event Hub to send data to')
param eventHubName string = 'vm-metrics'

// ----------------------------------------------------------------------------
// EXISTING RESOURCES: Reference to things that already exist
// ----------------------------------------------------------------------------

// This VM already exists - we're just referencing it
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' existing = {
  name: vmName
}

// ----------------------------------------------------------------------------
// NEW RESOURCES: What we're creating
// ----------------------------------------------------------------------------

// Create diagnostic settings for the VM
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-eventhub'         // Name of this diagnostic setting
  scope: vm                        // Apply to the VM referenced above
  properties: {
    // WHERE to send the data
    eventHubAuthorizationRuleId: eventHubAuthRuleId
    eventHubName: eventHubName

    // WHAT data to send
    metrics: [
      {
        category: 'AllMetrics'     // Send all available metrics
        enabled: true              // Turn it on
        retentionPolicy: {
          enabled: false           // Don't keep a copy locally
          days: 0
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// OUTPUTS
// ----------------------------------------------------------------------------

output diagnosticSettingName string = diagnosticSettings.name
output vmId string = vm.id

// ============================================================================
// WHAT DOES THIS DO?
//
// Imagine you have:
// - A thermometer (VM producing metrics like CPU%, Memory%)
// - A data logger (Event Hub that stores the readings)
//
// This template connects the thermometer to the data logger so readings
// automatically flow from VM → Event Hub
//
// ============================================================================
// HOW TO USE THIS:
//
// First, you need:
// 1. An Event Hub (create with 01-simple-eventhub.bicep)
// 2. A VM that already exists
//
// Then deploy:
//    az deployment group create \
//      --resource-group rg-learning \
//      --template-file 02-manual-vm-diagnostics.bicep \
//      --parameters vmName=myvm \
//                   eventHubAuthRuleId="/subscriptions/.../authorizationRules/SendListenKey" \
//                   eventHubName=vm-metrics
//
// ============================================================================
// THE PROBLEM WITH THIS APPROACH:
//
// ❌ You have to run this MANUALLY for every single VM
// ❌ If someone creates a new VM, it won't automatically get configured
// ❌ Not scalable if you have 100s of VMs
//
// SOLUTION: Use Azure Policy (Lesson 3) to make this AUTOMATIC!
// ============================================================================

