@minLength(3)
@maxLength(24)
param keyVaultName string

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
  '00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
  'a4417e6f-fecd-4de8-b567-7b0420556985' // Key Vault Certificates Officer
  '14b46e9e-c2b7-41b4-b07b-48a6ebf60603' // Key Vault Crypto Officer
  'e147488a-f6f5-4113-8e2d-b22465e65bf6' // Key Vault Crypto Service Encryption User
  '12338af0-0e69-4776-bea7-57ae8d297424' // Key Vault Crypto User
  '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
  '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
])
param roles array = [
  '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
]

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = [for role in roles : {
  name: role
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, i) in roles : {
  name: guid(keyVault.id, principalObjectId, roleDefinition[i].id)
  scope: keyVault

  properties: {
    roleDefinitionId: roleDefinition[i].id
    principalId: principalObjectId
    principalType: principalType
  }
}]
