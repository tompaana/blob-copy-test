@minLength(3)
@maxLength(24)
param keyVaultName string

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
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
]

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource roleDefinitions 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = [for roleDefinitionId in roleDefinitionIds: {
  name: roleDefinitionId
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (roleDefinitionId, i) in roleDefinitionIds: {
  name: guid(keyVault.id, principalObjectId, roleDefinitions[i].id)
  scope: keyVault

  properties: {
    roleDefinitionId: roleDefinitions[i].id
    principalId: principalObjectId
    principalType: principalType
  }
}]
