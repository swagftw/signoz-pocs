// ============================================================================
// LESSON 1: Creating a Simple Event Hub
// ============================================================================
// This is the SIMPLEST possible Bicep template to create an Event Hub
// Event Hub = A place where data/events are sent (like a mailbox for data)

// ----------------------------------------------------------------------------
// PARAMETERS: These are inputs you provide when deploying
// Think of them like function arguments
// ----------------------------------------------------------------------------

@description('What do you want to name your Event Hub Namespace?')
param namespaceName string

@description('Where should we create this? (e.g., eastus, westus)')
param location string = resourceGroup().location

// ----------------------------------------------------------------------------
// RESOURCES: These are the actual Azure things we're creating
// ----------------------------------------------------------------------------

// STEP 1: Create an Event Hub Namespace (like a container/folder)
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: namespaceName              // The name you provide
  location: location               // Where to create it
  sku: {
    name: 'Standard'              // Pricing tier (Basic/Standard/Premium)
    tier: 'Standard'
    capacity: 1                   // How powerful (1-20)
  }
}

// STEP 2: Create an Event Hub inside the namespace (the actual queue/stream)
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace        // This belongs to the namespace above
  name: 'vm-metrics'               // Name of the event hub
  properties: {
    messageRetentionInDays: 7      // Keep messages for 7 days
    partitionCount: 2              // How many "lanes" for parallel processing
  }
}

// STEP 3: Create a key/password to access the Event Hub
resource authRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-11-01' = {
  parent: eventHub                 // This belongs to the event hub above
  name: 'SendListenKey'            // Name of this access key
  properties: {
    rights: [
      'Send'                       // Can send data
      'Listen'                     // Can read data
    ]
  }
}

// ----------------------------------------------------------------------------
// OUTPUTS: These are values you can use after deployment
// Like return values from a function
// ----------------------------------------------------------------------------

output eventHubNamespaceId string = eventHubNamespace.id
output eventHubName string = eventHub.name
output authRuleId string = authRule.id

// ============================================================================
// HOW TO DEPLOY THIS:
//
// 1. Create a resource group:
//    az group create --name rg-learning --location eastus
//
// 2. Deploy this template:
//    az deployment group create \
//      --resource-group rg-learning \
//      --template-file 01-simple-eventhub.bicep \
//      --parameters namespaceName=my-first-eventhub
//
// 3. Check what was created:
//    az eventhub namespace list --resource-group rg-learning
// ============================================================================

