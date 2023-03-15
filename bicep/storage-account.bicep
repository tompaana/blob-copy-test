@minLength(3)
@maxLength(24)
param storageAccountName string

param location string = resourceGroup().location
param skuName string = 'Standard_LRS'

@allowed([
  'FileStorage'
  'StorageV2'
])
param kind string

param allowSharedKeyAccess bool

@maxLength(24)
@description('If given, will store the storage account key in the Key Vault.')
param keyVaultName string = ''

param vnetEnabled bool

@maxLength(90)
param vnetResourceGroupName string

@maxLength(64)
param vnetName string

@maxLength(80)
param subnetName string

@allowed([
  'blob'
  'file'
  'queue'
  'table'
])
param groupIds array

var privateDnsZoneNames = [for groupId in groupIds: 'privatelink.${groupId}.${environment().suffixes.storage}']

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = if (vnetEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location

  sku: {
    name: skuName
  }

  kind: kind

  identity: {
    type: 'None'
  }

  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: true
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: false

    encryption: {
      keySource: 'Microsoft.Storage'

      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }

        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }

    minimumTlsVersion: 'TLS1_2'

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: (vnetEnabled) ? 'Deny' : 'Allow'
      ipRules: []

      virtualNetworkRules: (vnetEnabled) ? [
        {
          id: '${virtualNetwork.id}/subnets/${subnetName}'
          action: 'Allow'
        }
      ] : []
    }

    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
}

module keyVaultSecret './key-vault-secret.bicep' =  if (!empty(keyVaultName))  {
  name: '${storageAccountName}keyVaultSecret'

  params: {
    keyVaultName: keyVaultName
    secretName: '${storageAccountName}Key'
    secretValue: storageAccount.listKeys().keys[0].value
  }
}

// Sweden Central does not support advanced threat protection settings for storage accounts as of writing this 2022-10-20
resource advancedThreatProtectionSettings 'Microsoft.Security/advancedThreatProtectionSettings@2019-01-01' = if (location != 'swedencentral') {
  name: 'current'
  scope: storageAccount

  properties: {
    isEnabled: true
  }
}

module privateEndpoints './private-endpoint.bicep' = [for (privateDnsZoneName, i) in privateDnsZoneNames: if (vnetEnabled) {
  name: '${storageAccountName}${groupIds[i]}PrivateEndpoint'

  params: {
    serviceName: storageAccountName
    serviceId: storageAccount.id
    location: location
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    subnetName: subnetName
    groupId: groupIds[i]
    privateDnsZoneName: privateDnsZoneName
  }
}]

@description('The resource ID of the storage account.')
output storageAccountResourceId string = storageAccount.id
