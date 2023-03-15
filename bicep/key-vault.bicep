@minLength(3)
@maxLength(24)
param keyVaultName string

param location string = resourceGroup().location

param enablePurgeProtection bool = true
param enableSoftDelete bool = true
param softDeleteRetentionInDays int = 14
param vnetEnabled bool

@maxLength(90)
param vnetResourceGroupName string

@maxLength(64)
param vnetName string

@maxLength(80)
param subnetName string

@allowed([
  'new'
  'existing'
])
@description('Indicates whether or not to create a new Key Vault resource.')
param newOrExisting string = 'new'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = if (vnetEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = if (newOrExisting == 'new') {
  name: keyVaultName
  location: location

  properties: {
    createMode: 'default'
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: (vnetEnabled) ? 'Deny' : 'Allow'
      ipRules: []

      virtualNetworkRules: (vnetEnabled) ? [
        {
          id: '${virtualNetwork.id}/subnets/${subnetName}'
          ignoreMissingVnetServiceEndpoint: false
        }
      ] : []
    }

    sku: {
      family: 'A'
      name: 'standard'
    }

    softDeleteRetentionInDays: softDeleteRetentionInDays
    tenantId: subscription().tenantId
  }
}

module privateEndpoint './private-endpoint.bicep' = if (vnetEnabled) {
  name: '${keyVaultName}PrivateEndpoint'

  params: {
    serviceName: keyVaultName
    serviceId: keyVault.id
    location: location
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    subnetName: subnetName
    groupId: 'vault'
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
  }
}
