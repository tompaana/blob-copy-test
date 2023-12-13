@minLength(1)
@maxLength(90)
param vnetResourceGroupName string = resourceGroup().name

@minLength(2)
@maxLength(64)
param vnetName string

// See https://learn.microsoft.com/azure/private-link/private-endpoint-dns
param privateDnsZoneNames array = [
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.azurewebsites.net'
  'privatelink.blob.${environment().suffixes.storage}' // environment().suffixes.storage returns 'core.windows.net'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.monitor.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.vaultcore.azure.net'
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [for privateDnsZoneName in privateDnsZoneNames : {
  name: privateDnsZoneName
}]

resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNames : {
  name: 'link-${vnetName}'
  location: 'global'
  parent: privateDnsZones[i]

  properties: {
    registrationEnabled: false

    virtualNetwork: {
      id: virtualNetwork.id
    }
  }

  dependsOn: [
    privateDnsZones
  ]
}]
