param name string
param location string = resourceGroup().location
param tags object = {}
param appServicePlanId string
param appInsightsInstrumentationKey string

param strorageAccount string
var strorageAccountId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.Storage/storageAccounts', strorageAccount)

@description('Location of the websearcher plugin to deploy')
#disable-next-line no-hardcoded-env-urls
param webSearcherPackageUri string = 'https://aka.ms/copilotchat/websearcher/latest'
param deployPackages bool = true

resource functionAppWebSearcherPlugin 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'functionapp'
  tags: tags
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
    }
  }
}

resource functionAppWebSearcherPluginConfig 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: functionAppWebSearcherPlugin
  name: 'web'
  properties: {
    minTlsVersion: '1.2'
    appSettings: [
      {
        name: 'FUNCTIONS_EXTENSION_VERSION'
        value: '~4'
      }
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'dotnet-isolated'
      }
      {
        name: 'AzureWebJobsStorage'
        value: 'DefaultEndpointsProtocol=https;AccountName=${strorageAccount};AccountKey=${listKeys(strorageAccountId, '2019-06-01').keys[1].value}'
      }
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: appInsightsInstrumentationKey
      }
      {
        name: 'PluginConfig:BingApiKey'
        value: bingSearchService.listKeys().key1
        // (deployWebSearcherPlugin) ? bingSearchService.listKeys().key1 : ''
      }
    ]
  }
}

resource functionAppWebSearcherDeploy 'Microsoft.Web/sites/extensions@2022-09-01' = if (deployPackages) {
  name: 'MSDeploy'
  kind: 'string'
  parent: functionAppWebSearcherPlugin
  properties: {
    packageUri: webSearcherPackageUri
  }
  dependsOn: [
    functionAppWebSearcherPluginConfig
  ]
}

resource bingSearchService 'Microsoft.Bing/accounts@2020-06-10' = {
  name: 'bingsearch'
  location: 'global'
  sku: {
    name: 'S1'
  }
  kind: 'Bing.Search.v7'
}

output defaulthost string = functionAppWebSearcherPlugin.properties.defaultHostName
output name string = functionAppWebSearcherPlugin.name
