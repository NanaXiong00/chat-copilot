param name string
param location string = resourceGroup().location
param tags object = {}
@allowed([
  'AzureOpenAI'
  'OpenAI'
])
param aiService string = 'AzureOpenAI'
param completionModel string = 'gpt-35-turbo'
param embeddingModel string = 'text-embedding-ada-002'
param plannerModel string = 'gpt-35-turbo'
param memoryStore string
param appServicePlanId string
param appInsightsConnectionString string
param azureCognitiveSearch string
param deployWebSearcherPlugin bool
param allowedOrigins array = []
param virtualNetworkId0 string
param appServiceQdrantDefaultHost string
param cosmosConnectString string
param deployCosmosDB bool

param functionAppWebSearcherPlugin string
param searcherPluginDefaultHostName string
var functionAppWebSearcherPluginId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.Web/sites', functionAppWebSearcherPlugin)

param openAIServiceName string
param openAIEndpoint string
var openAIId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.CognitiveServices/accounts', openAIServiceName)

param strorageAccount string
var strorageAccountId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.Storage/storageAccounts', strorageAccount)

param deploySpeechServices bool
param speechAccount string
var speechAccountId = resourceId(subscription().subscriptionId, resourceGroup().name,
  'Microsoft.CognitiveServices/accounts', speechAccount)

param webApiClientId string
param frontendClientId string
param azureAdTenantId string
param azureAdInstance string = environment().authentication.loginEndpoint

resource appServiceWeb 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'app'
  tags: tags
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      healthCheckPath: '/healthz'
      cors: {
        allowedOrigins: allowedOrigins
      }
    }
    virtualNetworkSubnetId: memoryStore == 'Qdrant' ? virtualNetworkId0 : null
  }
}

resource appServiceWebConfig 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: appServiceWeb
  name: 'web'
  dependsOn: [
    webSubnetConnection
  ]
  properties: {
    alwaysOn: true
    detailedErrorLoggingEnabled: true
    minTlsVersion: '1.2'
    netFrameworkVersion: 'v7.0'
    use32BitWorkerProcess: false
    vnetRouteAllEnabled: true
    webSocketsEnabled: true
    appSettings: concat([
        {
          name: 'Authentication:Type'
          value: (azureAdTenantId == '' || webApiClientId == '' || frontendClientId == '') ? 'None' : 'AzureAd'
        }
        {
          name: 'Authentication:AzureAd:Instance'
          value: azureAdInstance
        }
        {
          name: 'Authentication:AzureAd:TenantId'
          value: azureAdTenantId
        }
        {
          name: 'Authentication:AzureAd:ClientId'
          value: webApiClientId
        }
        {
          name: 'Authentication:AzureAd:Scopes'
          value: 'access_as_user'
        }
        {
          name: 'Frontend:AadClientId'
          value: frontendClientId
        }
        {
          name: 'Planner:Model'
          value: plannerModel
        }
        {
          name: 'ChatStore:Type'
          value: deployCosmosDB ? 'cosmos' : 'volatile'
        }
        {
          name: 'ChatStore:Cosmos:Database'
          value: 'CopilotChat'
        }
        {
          name: 'ChatStore:Cosmos:ChatSessionsContainer'
          value: 'chatsessions'
        }
        {
          name: 'ChatStore:Cosmos:ChatMessagesContainer'
          value: 'chatmessages'
        }
        {
          name: 'ChatStore:Cosmos:ChatMemorySourcesContainer'
          value: 'chatmemorysources'
        }
        {
          name: 'ChatStore:Cosmos:ChatParticipantsContainer'
          value: 'chatparticipants'
        }
        {
          name: 'ChatStore:Cosmos:ConnectionString'
          value: cosmosConnectString
        }
        {
          name: 'AzureSpeech:Region'
          value: location
        }
        {
          name: 'AzureSpeech:Key'
          value: deploySpeechServices ? listKeys(speechAccountId, '2023-05-01').key1 : ''
        }
        {
          name: 'AllowedOrigins'
          value: '[*]' // Defer list of allowed origins to the Azure service app's CORS configuration
        }
        {
          name: 'Kestrel:Endpoints:Https:Url'
          value: 'https://localhost:443'
        }
        // {
        //   name: 'Logging:LogLevel:Default'
        //   value: 'Warning'
        // }
        // {
        //   name: 'Logging:LogLevel:CopilotChat.WebApi'
        //   value: 'Warning'
        // }
        // {
        //   name: 'Logging:LogLevel:Microsoft.SemanticKernel'
        //   value: 'Warning'
        // }
        // {
        //   name: 'Logging:LogLevel:Microsoft.AspNetCore.Hosting'
        //   value: 'Warning'
        // }
        // {
        //   name: 'Logging:LogLevel:Microsoft.Hosting.Lifetimel'
        //   value: 'Warning'
        // }
        // {
        //   name: 'Logging:ApplicationInsights:LogLevel:Default'
        //   value: 'Warning'
        // }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'KernelMemory:ContentStorageType'
          value: 'AzureBlobs'
        }
        {
          name: 'KernelMemory:TextGeneratorType'
          value: aiService
        }
        {
          name: 'KernelMemory:DataIngestion:OrchestrationType'
          value: 'Distributed'
        }
        {
          name: 'KernelMemory:DataIngestion:DistributedOrchestration:QueueType'
          value: 'AzureQueue'
        }
        {
          name: 'KernelMemory:DataIngestion:EmbeddingGeneratorTypes:0'
          value: aiService
        }
        {
          name: 'KernelMemory:DataIngestion:VectorDbTypes:0'
          value: memoryStore
        }
        {
          name: 'KernelMemory:Retrieval:VectorDbType'
          value: memoryStore
        }
        {
          name: 'KernelMemory:Retrieval:EmbeddingGeneratorType'
          value: aiService
        }
        {
          name: 'KernelMemory:Services:AzureBlobs:Auth'
          value: 'ConnectionString'
        }
        {
          name: 'KernelMemory:Services:AzureBlobs:ConnectionString'
          value: 'DefaultEndpointsProtocol=https;AccountName=${strorageAccount};AccountKey=${listKeys(strorageAccountId, '2019-06-01').keys[1].value}'
        }
        {
          name: 'KernelMemory:Services:AzureBlobs:Container'
          value: 'chatmemory'
        }
        {
          name: 'KernelMemory:Services:AzureQueue:Auth'
          value: 'ConnectionString'
        }
        {
          name: 'KernelMemory:Services:AzureQueue:ConnectionString'
          value: 'DefaultEndpointsProtocol=https;AccountName=${strorageAccount};AccountKey=${listKeys(strorageAccountId, '2019-06-01').keys[1].value}'
        }
        {
          name: 'KernelMemory:Services:AzureCognitiveSearch:Auth'
          value: 'ApiKey'
        }
        {
          name: 'KernelMemory:Services:AzureCognitiveSearch:Endpoint'
          value: memoryStore == 'AzureCognitiveSearch' ? 'https://${azureCognitiveSearch}.search.windows.net' : ''
        }
        {
          name: 'KernelMemory:Services:AzureCognitiveSearch:APIKey'
          value: memoryStore == 'AzureCognitiveSearch' ? listAdminKeys('Microsoft.Search/searchServices/${azureCognitiveSearch}', '2021-04-01-preview').primaryKey : ''
        }
        {
          name: 'KernelMemory:Services:Qdrant:Endpoint'
          value: memoryStore == 'Qdrant' ? 'https://${appServiceQdrantDefaultHost}' : ''
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIText:Auth'
          value: 'ApiKey'
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIText:Endpoint'
          value: openAIEndpoint
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIText:APIKey'
          value: listKeys(openAIId, '2023-05-01').key1
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIText:Deployment'
          value: completionModel
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIEmbedding:Auth'
          value: 'ApiKey'
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIEmbedding:Endpoint'
          value: openAIEndpoint
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIEmbedding:APIKey'
          value: listKeys(openAIId, '2023-05-01').key1
        }
        {
          name: 'KernelMemory:Services:AzureOpenAIEmbedding:Deployment'
          value: embeddingModel
        }
        {
          name: 'KernelMemory:Services:OpenAI:TextModel'
          value: completionModel
        }
        {
          name: 'KernelMemory:Services:OpenAI:EmbeddingModel'
          value: embeddingModel
        }
        {
          name: 'KernelMemory:Services:OpenAI:APIKey'
          value: listKeys(openAIId, '2023-05-01').key1
        }
        {
          name: 'Plugins:0:Name'
          value: 'Klarna Shopping'
        }
        {
          name: 'Plugins:0:ManifestDomain'
          value: 'https://www.klarna.com'
        }
      ],
      (deployWebSearcherPlugin) ? [
        {
          name: 'Plugins:1:Name'
          value: 'WebSearcher'
        }
        {
          name: 'Plugins:1:ManifestDomain'
          value: 'https://${searcherPluginDefaultHostName}'
        }
        {
          name: 'Plugins:1:Key'
          value: listkeys('${functionAppWebSearcherPluginId}/host/default/', '2022-09-01').functionKeys.default
        }
      ] : []
    )
  }
}

resource webSubnetConnection 'Microsoft.Web/sites/virtualNetworkConnections@2022-09-01' = if (memoryStore == 'Qdrant') {
  parent: appServiceWeb
  name: 'webSubnetConnection'
  properties: {
    vnetResourceId: null
    isSwift: true
  }
}

output weburl string = 'https://${appServiceWeb.properties.defaultHostName}'
output webname string = appServiceWeb.name
