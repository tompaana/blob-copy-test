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
@maxLength(38)
@description('The object ID of the user deploying this template. Will be used for role assignments.')
param userObjectId string

var locations = [
  'westeurope'
  'swedencentral'
]

var coreLocation = locations[0]
var vnetResourceGroupName = resourceGroup().name
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
var appServicePlanName = 'plan-${coreResourceNameSuffix}'
var appServiceName = 'app-${coreResourceNameSuffix}'

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

          serviceEndpoints: [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
            {
              locations: [ location ]
              service: 'Microsoft.Storage'
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

          serviceEndpoints: [
            {
              locations: [ location ]
              service: 'Microsoft.KeyVault'
            }
            {
              locations: [ location ]
              service: 'Microsoft.Storage'
            }
          ]

          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}]

module virtualNetworkPeerings './virtual-network-peerings.bicep' = {
  name: 'virtualNetworkPeerings'

  params: {
    vnetName1: vnetNames[0]
    vnetName2: vnetNames[1]
  }

  dependsOn: [ virtualNetworks ]
}

module privateDnsZones './private-dns-zones.bicep' = {
  name: 'privateDnsZones'

  params: {
    vnetResourceGroupName: resourceGroup().name
    vnetName: coreVnetName
  }

  dependsOn: [ virtualNetworks ]
}

module keyVault './key-vault.bicep' = {
  name: 'keyVault'

  params: {
    keyVaultName: keyVaultName
    location: coreLocation
    vnetEnabled: true
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: coreVnetName
    subnetName: coreSharedSubnetName
  }

  dependsOn: [ privateDnsZones ]
}

module keyVaultRoleAssignmentsForUser './key-vault-role-assignments.bicep' = {
  name: 'keyVaultRoleAssignmentsForUser'

  params: {
    keyVaultName: keyVaultName
    principalObjectId: userObjectId
    principalType: 'User'
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
    keyVaultName: keyVaultName
    allowSharedKeyAccess: true
    vnetEnabled: true
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetNames[i]
    subnetName: '${sharedSubnetNamePrefix}-${location}'

    groupIds: [
      'blob'
    ]
  }

  dependsOn: [ keyVaultRoleAssignmentsForUser ]
}]

module blobStorageAccountRoleAssignmentsForUser './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'blobStorageAccountRoleAssignmentsForUser-${location}'

  params: {
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    principalObjectId: userObjectId
    principalType: 'User'

    roleDefinitionIds: [
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    ]
  }

  dependsOn: [ blobStorageAccounts ]
}]

module blobContainers './storage-blob-container.bicep' = [for location in locations: {
  name: 'blobContainer-${location}'

  params: {
    containerName: blobContainerName
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
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
    keyVaultName: keyVaultName
    allowSharedKeyAccess: true
    vnetEnabled: true
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetNames[i]
    subnetName: '${sharedSubnetNamePrefix}-${location}'

    groupIds: [
      'file'
    ]
  }

  dependsOn: [ keyVaultRoleAssignmentsForUser ]
}]

module fileShareStorageAccountRoleAssignmentsForUser './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'fileShareStorageAccountRoleAssignmentsForUser-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    principalObjectId: userObjectId
    principalType: 'User'

    roleDefinitionIds: [
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
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    location: coreLocation
    allowPublicNetworkAccess: true
    vnetEnabled: true

    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
      vnetRouteAllEnabled: true
      http20Enabled: true
    }

    vnetResourceGroupName: resourceGroup().name
    vnetName: coreVnetName
    subnetName: appsSubnetName
    privateEndpointSubnetName: coreSharedSubnetName
  }

  dependsOn: [
    appServicePlan
    privateDnsZones
  ]
}

module keyVaultRoleAssignmentsForAppService './key-vault-role-assignments.bicep' = {
  name: 'keyVaultRoleAssignmentsForAppService'

  params: {
    keyVaultName: keyVaultName
    principalObjectId: appService.outputs.appServiceIdentityPrincipalObjectId
    principalType: 'ServicePrincipal'
  }

  dependsOn: [
    appService
    keyVault
  ]
}

module blobStorageAccountRoleAssignmentsForAppService './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'blobStorageAccountRoleAssignmentsForAppService-${location}'

  params: {
    storageAccountName: '${blobStorageAccountNamePrefix}${location}'
    principalObjectId: appService.outputs.appServiceIdentityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roleDefinitionIds: [
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    ]
  }

  dependsOn: [
    appService
    blobStorageAccounts
  ]
}]

module fileShareStorageAccountRoleAssignmentsForAppService './storage-account-role-assignments.bicep' = [for location in locations: {
  name: 'fileStorageAccountRoleAssignmentsForAppService-${location}'

  params: {
    storageAccountName: '${fileShareStorageAccountNamePrefix}${location}'
    principalObjectId: appService.outputs.appServiceIdentityPrincipalObjectId
    principalType: 'ServicePrincipal'

    roleDefinitionIds: [
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
    ]
  }

  dependsOn: [
    appService
    fileShareStorageAccounts
  ]
}]

module appServiceSettings './app-service-settings.bicep' = {
  name: 'appServiceSettings'

  params: {
    appServiceName: appServiceName

    newAppSettingsConfigProperties: {
      ASPNETCORE_ENVIRONMENT: 'Development'
      WEBSITE_NODE_DEFAULT_VERSION: '6.9.1'
      KEY_VAULT_NAME: keyVaultName
      BLOB_STORAGE_ACCOUNT_NAME_PREFIX: blobStorageAccountNamePrefix
      FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX: fileShareStorageAccountNamePrefix
    }

    existingAppSettingsConfigProperties: {}
  }

  dependsOn: [
    appService
  ]
}
