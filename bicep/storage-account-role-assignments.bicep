@minLength(3)
@maxLength(24)
param storageAccountName string

@minLength(36)
@maxLength(36)
param principalObjectId string

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

param roleDefinitionIds array = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource roleDefinitions 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = [for roleDefinitionId in roleDefinitionIds: {
  name: roleDefinitionId
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (roleDefinitionId, i) in roleDefinitionIds: {
  name: guid(storageAccount.id, principalObjectId, roleDefinitions[i].id)
  scope: storageAccount

  properties: {
    roleDefinitionId: roleDefinitions[i].id
    principalId: principalObjectId
    principalType: principalType
  }
}]
