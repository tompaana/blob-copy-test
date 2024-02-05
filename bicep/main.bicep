@allowed([
  'dev'
  'test'
  'prod'
])
param environmentAbbreviated string = 'dev'

@minLength(2)
@maxLength(2)
param resourceNameMeronym string

@minLength(36)
@maxLength(36)
@description('The object ID of the user or ops service principal deploying this template. Will be used for role assignments.')
param opsObjectId string

@allowed([
  'ServicePrincipal'
  'User'
])
param opsObjectIdType string = 'User'


@allowed([
  'privateEndpoint'
  'serviceEndpoint'
])
param storageAccountPrivateConnectivityMethod string = 'privateEndpoint'

param primaryLocation string = 'westeurope'
param secondaryLocation string = 'swedencentral'

@description('If given, a container registry will be provisioned and the web app will attempt to automatically pull the image from there.')
param appContainerImageName string = ''

var appContainerImageTag = 'latest'

var locations = [
  primaryLocation
  secondaryLocation
]

var privateDnsZoneNames = [
  'privatelink.azurecr.io'
  'privatelink.azurewebsites.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
]

var coreLocation = locations[0]
var vnetNames = [for location in locations: 'vnet-copytest${resourceNameMeronym}-${environmentAbbreviated}-${location}']
var coreVnetName = 'vnet-copytest${resourceNameMeronym}-${environmentAbbreviated}-${coreLocation}'
var sharedSubnetNamePrefix = 'snet-copytest${resourceNameMeronym}-shared-${environmentAbbreviated}'
var appsSubnetName = 'snet-copytest${resourceNameMeronym}-apps-${environmentAbbreviated}-${coreLocation}'
var coreSharedSubnetName = '${sharedSubnetNamePrefix}-${coreLocation}'
var coreResourceNameSuffix = 'copytest${resourceNameMeronym}-${environmentAbbreviated}-${coreLocation}'
var keyVaultName = 'kv-copytest${resourceNameMeronym}-${environmentAbbreviated}'
var blobStorageAccountNamePrefix = 'stctb${resourceNameMeronym}${environmentAbbreviated}'
var blobContainerName = 'copytest'
var fileShareStorageAccountNamePrefix = 'stctf${resourceNameMeronym}${environmentAbbreviated}'
var fileShareName = blobContainerName
var containerRegistryName = 'cr${resourceNameMeronym}${environmentAbbreviated}'
var containerImage = empty(appContainerImageName) ? '' : '${containerRegistryName}.azurecr.io/${appContainerImageName}:${appContainerImageTag}'
var appServicePlanName = 'asp-${coreResourceNameSuffix}'
var appServiceName = 'app-${coreResourceNameSuffix}'

module privateDnsZones './private-dns-zones.bicep' = {
  name: 'privateDnsZones'

  params: {
    privateDnsZoneNames: privateDnsZoneNames
  }
}

module virtualNetworks './virtual-network.bicep' = [for (location, i) in locations: {
  name: 'virtualNetwork-${location}'

  params: {
    vnetName: vnetNames[i]
    location: location
    addressPrefixes: (i == 0) ? [ '10.0.0.0/22' ] : [ '10.0.4.0/22' ]

    subnets: (i == 0) ? [
      {
        name: 'AzureBastionSubnet'

        properties: {
          addressPrefix: '10.0.0.0/26'
        }
      }
      {
        name: '${sharedSubnetNamePrefix}-${location}'

        properties: {
          addressPrefix: '10.0.1.0/24'

          serviceEndpoints: (storageAccountPrivateConnectivityMethod == 'privateEndpoint') ? [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
          ] : [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
            {
              locations: [ location ]
              service: 'Microsoft.Storage.Global'
            }
          ]

          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: appsSubnetName

        properties: {
          addressPrefix: '10.0.2.0/24'

          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'

              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }

              type: '"Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]

          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ] : [
      {
        name: '${sharedSubnetNamePrefix}-${location}'

        properties: {
          addressPrefix: '10.0.4.0/24'

          serviceEndpoints: (storageAccountPrivateConnectivityMethod == 'privateEndpoint') ? [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
          ] : [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
            {
              locations: [ location ]
              service: 'Microsoft.Storage.Global'
            }
          ]

          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }

  dependsOn: [ privateDnsZones ]
}]

module virtualNetworkLinks './virtual-network-links.bicep' = [for (location, i) in locations: {
  name: 'virtualNetworkLinks-${location}'

  params: {
    vnetName: vnetNames[i]
    privateDnsZoneNames: privateDnsZoneNames
  }

  dependsOn: [
    privateDnsZones
    virtualNetworks
  ]
}]

module virtualNetworkPeerings './virtual-network-peerings.bicep' = {
  name: 'virtualNetworkPeerings'

  params: {
    vnetName1: vnetNames[0]
    vnetName2: vnetNames[1]
  }

  dependsOn: [ virtualNetworks ]
}

module keyVault './key-vault.bicep' = {
  name: 'keyVault'

  params: {
    keyVaultName: keyVaultName
    location: coreLocation
    enableSoftDelete: false
    privateNetworkEnabled: true
    vnetName: coreVnetName
    subnetName: coreSharedSubnetName
  }

  dependsOn: [ virtualNetworks ]
}

module keyVaultRoleAssignmentsForOps './key-vault-role-assignments.bicep' = {
  name: 'keyVaultRoleAssignmentsForOps'

  params: {
    keyVaultName: keyVaultName
    principalObjectId: opsObjectId
    principalType: opsObjectIdType

    roles: [
      'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
    ]
  }

  dependsOn: [ keyVault ]
}

module blobStorageAccounts './storage-account.bicep' = [for (location, i) in locations: {
  name: 'blobStorageAccount-${location}'

  params: {
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    services: [ 'blob' ]
    keyVaultName: keyVaultName
    allowSharedKeyAccess: true
    privateNetworkEnabled: true
    privateConnectivityMethod: storageAccountPrivateConnectivityMethod
    vnetResourceGroupName: resourceGroup().name
    vnetName: vnetNames[i]
    subnetName: '${sharedSubnetNamePrefix}-${location}'
  }

  dependsOn: [ keyVaultRoleAssignmentsForOps ]
}]

module blobStorageAccountRoleAssignmentsForOps './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'blobStorageAccountRoleAssignmentsForOps-${location}'

  params: {
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    principalObjectId: opsObjectId
    principalType: opsObjectIdType

    roles: [
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    ]
  }

  dependsOn: [ blobStorageAccounts ]
}]

module blobContainers './storage-blob-container.bicep' = [for location in locations: {
  name: 'blobContainer-${location}'

  params: {
    storageBlobContainerName: blobContainerName
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    enableSoftDelete: false
  }

  dependsOn: [ blobStorageAccounts ]
}]

module fileShareStorageAccounts './storage-account.bicep' = [for (location, i) in locations: {
  name: 'fileShareStorageAccount-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    location: location
    skuName: 'Premium_LRS'
    kind: 'FileStorage'
    services: [ 'file' ]
    keyVaultName: keyVaultName
    allowSharedKeyAccess: true
    privateNetworkEnabled: true
    privateConnectivityMethod: storageAccountPrivateConnectivityMethod
    vnetResourceGroupName: resourceGroup().name
    vnetName: vnetNames[i]
    subnetName: '${sharedSubnetNamePrefix}-${location}'
  }

  dependsOn: [ keyVaultRoleAssignmentsForOps ]
}]

module fileShareStorageAccountRoleAssignmentsForOps './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'fileShareStorageAccountRoleAssignmentsForOps-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    principalObjectId: opsObjectId
    principalType: opsObjectIdType

    roles: [
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
    ]
  }

  dependsOn: [ fileShareStorageAccounts ]
}]

module fileShares './storage-file-share.bicep' = [for location in locations: {
  name: 'fileShare-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    fileShareName: fileShareName
  }

  dependsOn: [ fileShareStorageAccounts ]
}]

module containerRegistry './container-registry.bicep' = if (!empty(containerImage)) {
  name: 'containerRegistry'

  params: {
    containerRegistryName: containerRegistryName
    location: coreLocation
    privateNetworkEnabled: false
    vnetResourceGroupName: resourceGroup().name
    vnetName: coreVnetName
    subnetName: coreSharedSubnetName
  }
}

module containerRegistryRoleAssignmentsForOps './container-registry-role-assignments.bicep' = if (!empty(containerImage)) {
  name: 'containerRegistryRoleAssignmentsForOps'

  params: {
    containerRegistryName: containerRegistryName
    principalObjectId: opsObjectId
    principalType: opsObjectIdType

    roles: [
      'c2f4ef07-c644-48eb-af81-4b1b4947fb11' // AcrDelete
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
      '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush
    ]
  }

  dependsOn: [ containerRegistry ]
}

module appServicePlan './app-service-plan.bicep' = {
  name: 'appServicePlan'

  params: {
    appServicePlanName: appServicePlanName
    location: coreLocation
    skuName: 'B1'
  }
}

module appService './app-service.bicep' = {
  name: 'appService'

  params: {
    appServiceName: appServiceName
    serverFarmId: appServicePlan.outputs.appServicePlanId
    location: coreLocation
    kind: empty(containerImage) ? 'app,linux' : 'app,linux,container'
    allowPublicNetworkAccess: true
    privateNetworkEnabled: true

    siteConfig: {
      vnetRouteAllEnabled: true
      http20Enabled: true
    }

    vnetName: coreVnetName
    subnetName: appsSubnetName
    privateEndpointSubnetName: coreSharedSubnetName
  }

  dependsOn: [
    virtualNetworks
    appServicePlan
  ]
}

module keyVaultRoleAssignmentsForAppService './key-vault-role-assignments.bicep' = {
  name: 'keyVaultRoleAssignmentsForAppService'

  params: {
    keyVaultName: keyVaultName
    principalObjectId: appService.outputs.identityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roles: [
      '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    ]
  }

  dependsOn: [ keyVault ]
}

module blobStorageAccountRoleAssignmentsForAppService './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'blobStorageAccountRoleAssignmentsForAppService-${location}'

  params: {
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    principalObjectId: appService.outputs.identityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roles: [
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    ]
  }

  dependsOn: [ blobStorageAccounts ]
}]

module fileShareStorageAccountRoleAssignmentsForAppService './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'fileStorageAccountRoleAssignmentsForAppService-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    principalObjectId: appService.outputs.identityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roles: [
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
    ]
  }

  dependsOn: [ fileShareStorageAccounts ]
}]

module containerRegistryRoleAssignmentsForAppService './container-registry-role-assignments.bicep' = if (!empty(containerImage)) {
  name: 'containerRegistryRoleAssignmentsAppService'

  params: {
    containerRegistryName: containerRegistryName
    principalObjectId: appService.outputs.identityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roles: [
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    ]
  }

  dependsOn: [ containerRegistry ]
}

module appServiceSettings './app-service-settings.bicep' = {
  name: 'appServiceSettings'

  params: {
    appServiceName: appServiceName

    appSettingsProperties: {
      ASPNETCORE_ENVIRONMENT: 'Development'
      WEBSITE_NODE_DEFAULT_VERSION: '6.9.1'
      PRIMARY_LOCATION: primaryLocation
      SECONDARY_LOCATION: secondaryLocation
      KEY_VAULT_NAME: keyVaultName
      BLOB_STORAGE_ACCOUNT_NAME_PREFIX: blobStorageAccountNamePrefix
      FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX: fileShareStorageAccountNamePrefix
      PRIVATE_CONNECTIVITY_METHOD: storageAccountPrivateConnectivityMethod
    }

    siteConfigProperties: empty(containerImage) ? {
      linuxFxVersion: 'DOTNETCORE|6.0'
    } : {
      acrUseManagedIdentityCreds: true
      linuxFxVersion: 'DOCKER|${containerImage}'
    }
  }

  dependsOn: [ appService ]
}
