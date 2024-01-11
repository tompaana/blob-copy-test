@minLength(1)
@maxLength(127)
param secretName string

@secure()
param secretValue string

@minLength(3)
@maxLength(24)
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource ketVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: secretName
  parent: keyVault

  properties: {
    attributes: {
      enabled: true
    }

    contentType: 'text/plain'
    value: secretValue
  }
}
