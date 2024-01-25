targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string
param resourceGroupName string = ''

param openAIServiceName string = ''
param openAISkuName string = 'S0'
param embeddingDeploymentName string = 'text-embedding-ada-002'
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingDeploymentCapacity int = 30
param chatGptDeploymentName string = 'gpt-35-turbo'
param chatGptDeploymentCapacity int = 30
param chatGptModelName string = 'gpt-35-turbo'
param chatGptModelVersion string = '0613'

@allowed([ 'B1', 'S1', 'S2', 'S3', 'P1V3', 'P2V3', 'I1V2', 'I2V2' ])
param webAppServiceSku string = 'B1'
param webAppName string = ''
param appServicePlanName string = ''
param applicationInsightsName string = ''
param dashboardName string = ''
param logAnalyticsName string = ''
param webApiName string = ''
param storageAccountName string = ''
param azureCognitiveSearchName string = ''
param functionAppWeb string = ''
param appMemoryPipelineName string = ''
param appServiceQdrantName string = ''
param storageFileShareName string = 'aciqdrantshare'
param cosmosDbAccountName string = ''
param speechName string = ''
param azureAdTenantId string = ''
param frontendClientId string = ''
param webApiClientId string = ''

@description('Whether to deploy the web searcher plugin, which requires a Bing resource')
param deployWebSearcherPlugin bool = true

@allowed([
  'AzureCognitiveSearch'
  'Qdrant'
])
param memoryStore string = 'Qdrant'

@description('Whether to deploy Cosmos DB for persistent chat storage')
param deployCosmosDB bool = true

@description('Whether to deploy Azure Speech Services to enable input by voice')
param deploySpeechServices bool = true

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module openAI './core/ai/cognitiveservices.bicep' = {
  name: 'opanai'
  scope: rg
  params: {
    location: location
    name: !empty(openAIServiceName) ? openAIServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    tags: tags
    sku: {
      name: openAISkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        capacity: chatGptDeploymentCapacity
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
        }
        capacity: embeddingDeploymentCapacity
      }
    ]
  }
}

module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'asp-webapi'
  scope: rg
  params: {
    location: location
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    sku: {
      name: webAppServiceSku
    }
    kind: 'app'
    reserved: false
  }
}

module api './app/api.bicep' = {
  scope: rg
  name: 'api'
  params: {
    name: !empty(webApiName) ? webApiName : '${abbrs.webSitesAppService}webapi-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'api' }, { skweb: '1' })
    appInsightsConnectionString: applicationInsights.outputs.connectionString
    appServicePlanId: appServicePlan.outputs.id
    azureCognitiveSearch: memoryStore == 'AzureCognitiveSearch' ? azureCognitiveSearch.outputs.name : ''
    openAIEndpoint: openAI.outputs.endpoint
    openAIServiceName: openAI.outputs.name
    strorageAccount: storage.outputs.name
    deployWebSearcherPlugin: deployWebSearcherPlugin
    functionAppWebSearcherPlugin: deployWebSearcherPlugin ? functionAppWebSearcherPlugin.outputs.name : ''
    searcherPluginDefaultHostName: deployWebSearcherPlugin ? functionAppWebSearcherPlugin.outputs.defaulthost : ''
    allowedOrigins: [ '*' ]
    // [ web.outputs.uri ]
    memoryStore: memoryStore
    virtualNetworkId0: memoryStore == 'Qdrant' ? virtualNetwork.outputs.id0 : ''
    appServiceQdrantDefaultHost: memoryStore == 'Qdrant' ? appServiceQdrant.outputs.defaultHost : ''
    deployCosmosDB: deployCosmosDB
    cosmosConnectString: deployCosmosDB ? cosmos.outputs.cosmosConnectString : ''
    deploySpeechServices: deploySpeechServices
    speechAccount: deploySpeechServices ? speechAccount.outputs.name : ''
    azureAdTenantId: azureAdTenantId //
    frontendClientId: frontendClientId //
    webApiClientId: webApiClientId //
  }
}

module web './core/host/staticwebapp.bicep' = {
  scope: rg
  name: 'web'
  params: {
    name: !empty(webAppName) ? webAppName : '${abbrs.webStaticSites}${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

module storage 'app/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    location: location
    memoryStore: memoryStore
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    storageFileShareName: storageFileShareName
  }
}

module azureCognitiveSearch 'core/search/search-services.bicep' = if (memoryStore == 'AzureCognitiveSearch') {
  scope: rg
  name: 'azurecognitivesearch'
  params: {
    name: !empty(azureCognitiveSearchName) ? azureCognitiveSearchName : '${abbrs.searchSearchServices}${resourceToken}'
    location: location
    replicaCount: 1
    partitionCount: 1
    sku: {
      name: 'basic'
    }
  }
}

module applicationInsights 'core/monitor/applicationinsights.bicep' = {
  name: 'applicatininsight'
  scope: rg
  params: {
    dashboardName: dashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    includeDashboard: false
  }
}

module logAnalytics 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : 'log-${resourceToken}'
    location: location
  }
}

module functionAppWebSearcherPlugin './app/searcherplugin.bicep' = if (deployWebSearcherPlugin) {
  scope: rg
  name: 'searcherplugin'
  params: {
    name: !empty(functionAppWeb) ? functionAppWeb : '${abbrs.webSitesFunctions}${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'searcherplugin' }, { skweb: '1' })
    appInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    appServicePlanId: appServicePlan.outputs.id
    strorageAccount: storage.outputs.name
  }
}

module virtualNetwork 'app/virtualnetwork.bicep' = if (memoryStore == 'Qdrant') {
  scope: rg
  name: 'virtualnetwork'
  params: {
    location: location
  }
}

module appServiceMemoryPipeline 'app/memorypipeline.bicep' = {
  scope: rg
  name: 'memorypipeline'
  params: {
    tags: union(tags, { 'azd-service-name': 'memorypipeline' }, { skweb: '1' })
    location: location
    appInsightsConnectionString: applicationInsights.outputs.connectionString
    appServicePlanId: appServicePlan.outputs.id
    appServiceQdrantDefaultHostName: memoryStore == 'Qdrant' ? appServiceQdrant.outputs.defaultHost : ''
    azureCognitiveSearch: memoryStore == 'AzureCognitiveSearch' ? azureCognitiveSearch.outputs.name : ''
    memoryStore: memoryStore
    name: !empty(appMemoryPipelineName) ? appMemoryPipelineName : '${abbrs.webSitesAppService}memory-${resourceToken}'
    openAIEndpoint: openAI.outputs.endpoint
    openAIServiceName: openAI.outputs.name
    strorageAccount: storage.outputs.name
    virtualNetworkId0: memoryStore == 'Qdrant' ? virtualNetwork.outputs.id0 : ''
  }
}

module appServicePlanQdrant 'core/host/appserviceplan.bicep' = if (memoryStore == 'Qdrant') {
  scope: rg
  name: 'asp-qdrant'
  params: {
    kind: 'linux'
    location: location
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}qdrant-${resourceToken}'
    sku: {
      name: 'P1v3'
    }
  }
}

module appServiceQdrant 'app/qdrant.bicep' = if (memoryStore == 'Qdrant') {
  scope: rg
  name: 'appserviceqdrant'
  params: {
    location: location
    appServicePlanQdrantId: memoryStore == 'Qdrant' ? appServicePlanQdrant.outputs.id : ''
    name: !empty(appServiceQdrantName) ? appServiceQdrantName : '${abbrs.webSitesAppService}qdrant-${resourceToken}'
    storageFileShareName: storageFileShareName
    strorageAccount: storage.outputs.name
    virtualNetworkId0: memoryStore == 'Qdrant' ? virtualNetwork.outputs.id0 : ''
    virtualNetworkId1: memoryStore == 'Qdrant' ? virtualNetwork.outputs.id1 : ''
  }
}

module cosmos 'app/cosmosdb.bicep' = if (deployCosmosDB) {
  scope: rg
  name: 'cosmosdb'
  params: {
    location: location
    name: !empty(cosmosDbAccountName) ? cosmosDbAccountName : 'cosmos-${resourceToken}'
  }
}

module speechAccount 'app/speech.bicep' = if (deploySpeechServices) {
  scope: rg
  name: 'speech'
  params: {
    location: location
    name: !empty(speechName) ? speechName : 'speech-${resourceToken}'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output REACT_APP_BACKEND_URI string = api.outputs.weburl
output REACT_APP_WEB_BASE_URL string = web.outputs.uri
output AZURE_AD_TENANTID string = azureAdTenantId
output FRONTEND_CLIENTID string = frontendClientId
output WEBAPI_CLIENTID string = webApiClientId

// output webapiUrl string = api.outputs.weburl
// output webapiName string = api.outputs.webname
// output memoryPipelineName string = appServiceMemoryPipeline.outputs.name
// output pluginNames array = concat(
//   [],
//   (deployWebSearcherPlugin) ? [ functionAppWebSearcherPlugin.outputs.name ] : []
// )
