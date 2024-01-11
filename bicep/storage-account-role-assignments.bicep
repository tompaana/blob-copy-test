@minLength(3)
@maxLength(24)
param storageAccountName string

@minLength(2)
@maxLength(60)
param principalObjectId string

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

// See "Storage" at https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
@allowed([
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
  '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
  'aba4ae5f-2193-4029-9191-0cb91df5e314' // Storage File Data SMB Share Reader
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '19e7f393-937e-4f77-808e-94535e297925' // Storage Queue Data Reader
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
  '76199698-9eea-4c19-bc75-cec21354c6b6' // Storage Table Data Reader
])
param roles array = [
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = [for role in roles : {
  name: role
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, i) in roles : {
  name: guid(storageAccount.id, principalObjectId, roleDefinition[i].id)
  scope: storageAccount

  properties: {
    roleDefinitionId: roleDefinition[i].id
    principalId: principalObjectId
    principalType: principalType
  }
}]
