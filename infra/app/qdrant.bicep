param name string
param location string = resourceGroup().location
// @allowed([
//   'AzureCognitiveSearch'
//   'Qdrant'
// ])
// param memoryStore string
param appServicePlanQdrantId string
param virtualNetworkId0 string
param virtualNetworkId1 string
param storageFileShareName string

param strorageAccount string
var strorageAccountId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.Storage/storageAccounts', strorageAccount)

resource appServiceQdrant 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlanQdrantId
    httpsOnly: true
    reserved: true
    clientCertMode: 'Required'
    virtualNetworkSubnetId: virtualNetworkId1
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'DOCKER|qdrant/qdrant:latest'
      alwaysOn: true
      vnetRouteAllEnabled: true
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: virtualNetworkId0
          action: 'Allow'
          priority: 300
          name: 'Allow front vnet'
        }
        {
          ipAddress: 'Any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
        }
      ]
      azureStorageAccounts: {
        aciqdrantshare: {
          type: 'AzureFiles'
          accountName: strorageAccount
          shareName: storageFileShareName
          mountPath: '/qdrant/storage'
          accessKey: listKeys(strorageAccountId, '2019-06-01').keys[0].value
        }
      }
    }
  }
}

resource qdrantSubnetConnection 'Microsoft.Web/sites/virtualNetworkConnections@2022-09-01' = {
  parent: appServiceQdrant
  name: 'qdrantSubnetConnection'
  properties: {
    vnetResourceId: virtualNetworkId1
    isSwift: true
  }
}

output defaultHost string = appServiceQdrant.properties.defaultHostName
