@minLength(3)
@maxLength(24)
@description('Storage account to add the file services to')
param storageAccountName string

@minLength(3)
@maxLength(63)
param fileShareName string

@minValue(100)
@maxValue(102400)
param shareQuota int = 128

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' = {
  name: 'default'
  parent: storageAccount

  properties: {
    protocolSettings: {
      smb: {
        multichannel: {
          enabled: true
        }
      }
    }

    shareDeleteRetentionPolicy: {
      allowPermanentDelete: false
      days: 7
      enabled: true
    }
  }
}

resource fileServicesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  name: fileShareName
  parent: fileServices

  properties: {
    accessTier: 'Premium'
    enabledProtocols: 'SMB'
    shareQuota: shareQuota
  }
}
