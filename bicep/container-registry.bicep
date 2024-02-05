@minLength(5)
@maxLength(50)
param containerRegistryName string

param location string = resourceGroup().location
param skuName string = 'Basic'

@description('If given, will attempt to store the registry credentials as secrets in the Key Vault')
@maxLength(24)
param keyVaultName string = ''

param privateNetworkEnabled bool

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

resource registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location

  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: true
  }
}

module privateEndpoint './private-endpoint.bicep' = if (privateNetworkEnabled) {
  name: '${containerRegistryName}PrivateEndpoint'

  params: {
    serviceName: containerRegistryName
    serviceId: registry.id
    location: location
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    subnetName: subnetName
    groupId: 'registry'
    privateDnsZoneName: 'privatelink.azurecr.io'
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

module acrRegistryUsernameSecret './key-vault-secret.bicep' = if (!empty(keyVaultName)) {
  name: '${containerRegistryName}Username'

  params: {
    keyVaultName: keyVaultName
    secretName: '${containerRegistryName}Username'
    secretValue: registry.listCredentials().username
  }
}

module acrRegistryPasswordSecret './key-vault-secret.bicep' = if (!empty(keyVaultName)) {
  name: '${containerRegistryName}Password'

  params: {
    keyVaultName: keyVaultName
    secretName: '${containerRegistryName}Password'
    secretValue: registry.listCredentials().passwords[0].value
  }
}
