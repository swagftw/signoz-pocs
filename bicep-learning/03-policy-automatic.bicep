// ============================================================================
// LESSON 3: Azure Policy - The Automatic Way
// ============================================================================
// This creates a POLICY that automatically configures ANY VM that gets created
// Think of it like: "If someone creates a VM, automatically set up diagnostics"

// IMPORTANT: This deploys at SUBSCRIPTION level (not resource group)
targetScope = 'subscription'

// ----------------------------------------------------------------------------
// PARAMETERS
// ----------------------------------------------------------------------------

@description('The Event Hub auth rule ID where metrics should go')
param eventHubAuthRuleId string

@description('Name of the Event Hub')
param eventHubName string = 'vm-metrics'

// ----------------------------------------------------------------------------
// PART 1: CREATE THE POLICY DEFINITION
// This defines the RULE/LOGIC
// ----------------------------------------------------------------------------

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'auto-configure-vm-diagnostics'
  properties: {
    displayName: 'Auto-configure VM Diagnostic Settings'
    description: 'Automatically sets up diagnostic settings for any VM'
    policyType: 'Custom'           // Custom = we created it (not built-in Azure policy)
    mode: 'All'                    // Check all resources

    // PARAMETERS that the policy accepts
    parameters: {
      eventHubAuthRuleId: {
        type: 'String'
        metadata: {
          displayName: 'Event Hub Authorization Rule ID'
          description: 'Where to send the metrics'
        }
      }
      eventHubName: {
        type: 'String'
        metadata: {
          displayName: 'Event Hub Name'
        }
      }
    }

    // THE ACTUAL RULE/LOGIC
    policyRule: {
      // IF CONDITION: When does this policy apply?
      if: {
        field: 'type'
        equals: 'Microsoft.Compute/virtualMachines'   // Only for VMs
      }

      // THEN ACTION: What should happen?
      then: {
        effect: 'DeployIfNotExists'   // Deploy diagnostic settings if they don't exist

        details: {
          type: 'Microsoft.Insights/diagnosticSettings'

          // PERMISSIONS: The policy needs these roles to deploy resources
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'  // Contributor
          ]

          // CHECK: Does the diagnostic setting already exist with correct config?
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Insights/diagnosticSettings/eventHubAuthorizationRuleId'
                equals: '[parameters(\'eventHubAuthRuleId\')]'
              }
              {
                count: {
                  field: 'Microsoft.Insights/diagnosticSettings/metrics[*]'
                  where: {
                    allOf: [
                      {
                        field: 'Microsoft.Insights/diagnosticSettings/metrics[*].enabled'
                        equals: 'true'
                      }
                      {
                        field: 'Microsoft.Insights/diagnosticSettings/metrics[*].category'
                        equals: 'AllMetrics'
                      }
                    ]
                  }
                }
                greaterOrEquals: 1
              }
            ]
          }

          // DEPLOYMENT: What to create if it doesn't exist
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: { type: 'string' }
                  location: { type: 'string' }
                  eventHubAuthRuleId: { type: 'string' }
                  eventHubName: { type: 'string' }
                }
                resources: [
                  {
                    // This is what gets deployed (same as Lesson 2, but automatic!)
                    type: 'Microsoft.Compute/virtualMachines/providers/diagnosticSettings'
                    apiVersion: '2021-05-01-preview'
                    name: '[concat(parameters(\'vmName\'), \'/Microsoft.Insights/send-to-eventhub\')]'
                    location: '[parameters(\'location\')]'
                    properties: {
                      eventHubAuthorizationRuleId: '[parameters(\'eventHubAuthRuleId\')]'
                      eventHubName: '[parameters(\'eventHubName\')]'
                      metrics: [
                        {
                          category: 'AllMetrics'
                          enabled: true
                        }
                      ]
                    }
                  }
                ]
              }
              // VALUES to pass to the deployment template above
              parameters: {
                vmName: { value: '[field(\'name\')]' }
                location: { value: '[field(\'location\')]' }
                eventHubAuthRuleId: { value: '[parameters(\'eventHubAuthRuleId\')]' }
                eventHubName: { value: '[parameters(\'eventHubName\')]' }
              }
            }
          }
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------
// PART 2: ASSIGN THE POLICY
// This ACTIVATES the policy for your subscription
// ----------------------------------------------------------------------------

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'assign-vm-diagnostics-policy'
  properties: {
    displayName: 'Auto VM Diagnostics to Event Hub'
    description: 'Automatically configure diagnostic settings for all VMs'
    policyDefinitionId: policyDefinition.id

    // VALUES for the policy parameters
    parameters: {
      eventHubAuthRuleId: {
        value: eventHubAuthRuleId
      }
      eventHubName: {
        value: eventHubName
      }
    }
  }

  // MANAGED IDENTITY: The policy needs an identity to deploy resources
  identity: {
    type: 'SystemAssigned'
  }
  location: deployment().location
}

// ----------------------------------------------------------------------------
// PART 3: GIVE THE POLICY PERMISSIONS
// The policy's managed identity needs Contributor role
// ----------------------------------------------------------------------------

// NOTE: Using policyAssignment.name instead of .id to generate GUID
// This ensures a new GUID is created each time the assignment name changes
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyAssignment.name, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ----------------------------------------------------------------------------
// OUTPUTS
// ----------------------------------------------------------------------------

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.id

// ============================================================================
// HOW THIS WORKS - SIMPLE EXPLANATION:
//
// 1. You deploy this policy ONCE at subscription level
// 2. From now on, whenever ANYONE creates a VM:
//    - Azure Policy detects it
//    - Automatically deploys diagnostic settings to that VM
//    - VM metrics start flowing to Event Hub
// 3. No manual work needed!
//
// ============================================================================
// ANALOGY:
//
// Without Policy (Manual - Lesson 2):
//   - Every time someone moves into an apartment, you manually connect their WiFi
//   - Lots of work if you have 100 apartments
//
// With Policy (Automatic - This lesson):
//   - You set up a rule: "Any new tenant automatically gets WiFi"
//   - Building manager (Azure Policy) does it automatically
//   - You just set the rule once!
//
// ============================================================================
// HOW TO DEPLOY:
//
// az deployment sub create \
//   --location eastus \
//   --template-file 03-policy-automatic.bicep \
//   --parameters eventHubAuthRuleId="/subscriptions/.../authorizationRules/SendListenKey" \
//                eventHubName=vm-metrics
//
// ============================================================================
// AFTER DEPLOYMENT:
//
// FOR NEW VMs:
// 1. Create a test VM:
//    az vm create --resource-group rg-test --name testvm --image Ubuntu2204
//
// 2. Wait 10-15 minutes (policy evaluation cycle)
//
// 3. Check if diagnostic settings were created automatically:
//    az monitor diagnostic-settings list --resource <VM_ID>
//
// You should see diagnostic settings without manually creating them!
//
// ============================================================================
// IMPORTANT: FOR EXISTING VMs (Already created before policy deployment)
// ============================================================================
//
// Azure Policy with "DeployIfNotExists" does NOT automatically fix existing
// resources. You must create a REMEDIATION TASK to apply the policy to them.
//
// STEP 1: Check which VMs are non-compliant:
//   az policy state list \
//     --filter "policyAssignmentName eq 'assign-vm-diagnostics-policy'" \
//     --query "[].{resource:resourceId, compliance:complianceState}" -o table
//
// STEP 2: Create a remediation task to fix existing VMs:
//   az policy remediation create \
//     --name remediate-vm-diagnostics-$(date +%s) \
//     --policy-assignment assign-vm-diagnostics-policy \
//     --resource-discovery-mode ExistingNonCompliant
//
// STEP 3: Monitor remediation progress:
//   az policy remediation list --query "[].{name:name, state:provisioningState}" -o table
//
// STEP 4: Check specific remediation details:
//   az policy remediation show --name <remediation-name>
//
// The remediation task will deploy diagnostic settings to all existing VMs
// that don't have them. This usually takes 5-15 minutes.
//
// ============================================================================

