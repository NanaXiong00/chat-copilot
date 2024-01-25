param name string
param location string = resourceGroup().location
@allowed([
  'AzureCognitiveSearch'
  'Qdrant'
])
param memoryStore string
param storageFileShareName string

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name // Not using full unique name to avoid hitting 24 char limit
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
  resource fileservices 'fileServices' = if (memoryStore == 'Qdrant') {
    name: 'default'
    resource share 'shares' = {
      name: storageFileShareName
    }
  }
}

output name string = storage.name
