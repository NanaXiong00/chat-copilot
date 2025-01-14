metadata description = 'Creates an Azure Cosmos DB for NoSQL account with a database.'
param accountName string
param databaseName string
param location string = resourceGroup().location
param tags object = {}

param containers array = [
  {
    name: 'chatmessages'
    id: 'chatmessages'
    partitionKey: '/chatId'
  }
  {
    name: 'chatsessions'
    id: 'chatsessions'
    partitionKey: '/id'
  }
  {
    name: 'chatparticipants'
    id: 'chatparticipants'
    partitionKey: '/userId'
  }
  {
    name: 'chatmemorysources'
    id: 'chatmemorysources'
    partitionKey: '/chatId'
  }
]
param keyVaultName string
param principalIds array = []

module cosmos '../core/database/cosmos/sql/cosmos-sql-account.bicep' = {
  name: 'cosmos-sql-account'
  params: {
    name: accountName
    location: location
    tags: tags
    keyVaultName: keyVaultName
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: '${accountName}/${databaseName}'
  properties: {
    resource: { id: databaseName }
  }

  resource list 'containers' = [for container in containers: {
    name: container.name
    properties: {
      resource: {
        id: container.id
        partitionKey: { paths: [ container.partitionKey ] }
      }
      options: {}
    }
  }]

  dependsOn: [
    cosmos
  ]
}

module roleDefinition '../core/database/cosmos/sql/cosmos-sql-role-def.bicep' = {
  name: 'cosmos-sql-role-definition'
  params: {
    accountName: accountName
  }
  dependsOn: [
    cosmos
    database
  ]
}

// We need batchSize(1) here because sql role assignments have to be done sequentially
@batchSize(1)
module userRole '../core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = [for principalId in principalIds: if (!empty(principalId)) {
  name: 'cosmos-sql-user-role-${uniqueString(principalId)}'
  params: {
    accountName: accountName
    roleDefinitionId: roleDefinition.outputs.id
    principalId: principalId
  }
  dependsOn: [
    cosmos
    database
  ]
}]

// var cosmosId = resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.DocumentDB/databaseAccounts', accountName)
// var connectionString = 'AccountEndpoint=${cosmos.outputs.endpoint};AccountKey=${listKeys(cosmosId, '2023-04-15').primaryMasterKey}'
// output cosmosConnectString string = connectionString
output accountId string = cosmos.outputs.id
output accountName string = cosmos.outputs.name
output connectionStringKey string = cosmos.outputs.connectionStringKey
output databaseName string = databaseName
output endpoint string = cosmos.outputs.endpoint
output roleDefinitionId string = roleDefinition.outputs.id
