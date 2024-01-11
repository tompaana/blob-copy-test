@minLength(3)
@maxLength(24)
param storageAccountName string

param location string = resourceGroup().location

param skuName string = 'Standard_GRS'

param kind string = 'StorageV2'

@allowed([
  'blob'
  'file'
  'queue'
  'table'
])
param services array = [ 'blob' ]

param allowSharedKeyAccess bool = false

param managementPolicyProperties object = {}

@maxLength(24)
@description('If given, will attempt to store the storage account key as a secret in the Key Vault')
param keyVaultName string = ''

param privateNetworkEnabled bool

@allowed([
  'privateEndpoint'
  'serviceEndpoint'
])
param privateConnectivityMethod string = 'privateEndpoint'

@minLength(1)
@maxLength(90)
param vnetResourceGroupName string = resourceGroup().location

@maxLength(64)
param vnetName string = ''

@maxLength(80)
param subnetName string = ''

@minLength(1)
@maxLength(90)
param privateDnsZoneResourceGroupName string = resourceGroup().name

var serviceProperties = {
  enabled: true
  keyType: 'Account'
}

var privateDnsZoneNames = [for groupId in services: 'privatelink.${groupId}.${environment().suffixes.storage}']

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (privateNetworkEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location

  sku: {
    name: skuName
  }

  kind: kind

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: allowSharedKeyAccess

    encryption: {
      keySource: 'Microsoft.Storage'

      services: {
        blob: contains(services, 'blob') ? serviceProperties : {}
        file: contains(services, 'file') ? serviceProperties : {}
        queue: contains(services, 'queue') ? serviceProperties : {}
        table: contains(services, 'table') ? serviceProperties : {}
      }
    }

    minimumTlsVersion: 'TLS1_2'

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateNetworkEnabled ? 'Deny' : 'Allow'
      ipRules: []

      virtualNetworkRules: privateNetworkEnabled && privateConnectivityMethod == 'serviceEndpoint' ? [
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

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = if (contains(services, 'blob')) {
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

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' = if (contains(services, 'queue')) {
  name: 'default'
  parent: storageAccount
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2022-09-01' = if (contains(services, 'table')) {
  name: 'default'
  parent: storageAccount
}

resource managementPolicies 'Microsoft.Storage/storageAccounts/managementPolicies@2022-09-01' = if (!empty(managementPolicyProperties)) {
  name: 'default'
  parent: storageAccount
  properties: managementPolicyProperties
}

module privateEndpoints './private-endpoint.bicep' = [for (privateDnsZoneName, i) in privateDnsZoneNames: if (privateNetworkEnabled && privateConnectivityMethod == 'privateEndpoint') {
  name: '${storageAccountName}${services[i]}PrivateEndpoint'

  params: {
    serviceName: storageAccountName
    serviceId: storageAccount.id
    location: location
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    subnetName: subnetName
    groupId: services[i]
    #disable-next-line BCP334
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}]

module storageAccountKeySecret './key-vault-secret.bicep' = if (!empty(keyVaultName)) {
  name: '${storageAccountName}StorageAccountKey'

  params: {
    keyVaultName: keyVaultName
    secretName: '${storageAccountName}StorageAccountKey'
    secretValue: storageAccount.listKeys().keys[0].value
  }
}

output storageAccountId string = storageAccount.id
