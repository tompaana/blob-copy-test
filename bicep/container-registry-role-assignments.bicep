@minLength(5)
@maxLength(50)
param containerRegistryName string

@minLength(36)
@maxLength(36)
@description('The object ID of the identity to assign roles to')
param principalObjectId string

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

// See https://learn.microsoft.com/azure/key-vault/general/rbac-guide?tabs=azure-cli#azure-built-in-roles-for-key-vault-data-plane-operations
@allowed([
  'c2f4ef07-c644-48eb-af81-4b1b4947fb11' // AcrDelete
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
  '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush
])
param roles array = [
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
]

resource registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = [for role in roles : {
  name: role
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, i) in roles : {
  name: guid(registry.id, principalObjectId, roleDefinition[i].id)
  scope: registry

  properties: {
    roleDefinitionId: roleDefinition[i].id
    principalId: principalObjectId
    principalType: principalType
  }
}]
