@minLength(1)
@maxLength(90)
param vnetResourceGroupName string

@minLength(2)
@maxLength(64)
param vnetName string

param privateDnsZoneNames array = [
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.azurewebsites.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.monitor.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: privateDnsZoneName
  location: 'global'
}]

resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNames: {
  name: replace('vnet-link-${privateDnsZoneName}', '.', '-')
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
