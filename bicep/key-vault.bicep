@minLength(3)
@maxLength(24)
param keyVaultName string

param location string = resourceGroup().location

param enableSoftDelete bool = true

param privateNetworkEnabled bool

@maxLength(90)
#disable-next-line BCP335
param vnetResourceGroupName string = resourceGroup().name

@maxLength(64)
param vnetName string

@maxLength(80)
param subnetName string

@minLength(1)
@maxLength(90)
param privateDnsZoneResourceGroupName string = resourceGroup().name

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (privateNetworkEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location

  properties: {
    createMode: 'default'
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privateNetworkEnabled ? 'Deny' : 'Allow'
      ipRules: []

      virtualNetworkRules: privateNetworkEnabled ? [
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

    tenantId: subscription().tenantId
  }
}

module privateEndpoint './private-endpoint.bicep' = if (privateNetworkEnabled) {
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
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

output keyVaultName string = keyVault.name
