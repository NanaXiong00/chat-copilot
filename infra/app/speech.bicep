param name string
param location string = resourceGroup().location

resource speechAccount 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: name
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'SpeechServices'
  identity: {
    type: 'None'
  }
  properties: {
    customSubDomainName: name
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
}

output name string = speechAccount.name
