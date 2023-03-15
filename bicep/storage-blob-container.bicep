@minLength(1)
@maxLength(1024)
param containerName string

@minLength(3)
@maxLength(24)
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: storageAccount

  properties: {
    changeFeed: {
      enabled: false
    }

    containerDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }

    cors: {
      corsRules: []
    }

    deleteRetentionPolicy: {
      allowPermanentDelete: false
      days: 7
      enabled: true
    }

    isVersioningEnabled: false

    restorePolicy: {
      enabled: false
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: containerName
  parent: blobService
  properties: {}
}
