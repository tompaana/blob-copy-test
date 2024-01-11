@minLength(3)
@maxLength(24)
param storageAccountName string

@minLength(3)
@maxLength(63)
param storageBlobContainerName string

param enableSoftDelete bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'

  properties: {
    cors: {
      corsRules: []
    }

    deleteRetentionPolicy: {
      enabled: enableSoftDelete
      days: 7
    }

    containerDeleteRetentionPolicy: {
      enabled: enableSoftDelete
      days: 7
    }
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  parent: blobService
  name: storageBlobContainerName

  properties: {
    publicAccess: 'None'
  }
}
