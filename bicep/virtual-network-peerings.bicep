@minLength(2)
@maxLength(64)
param vnetName1 string

@minLength(2)
@maxLength(64)
param vnetName2 string

resource virtualNetwork1 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName1
}

resource virtualNetwork2 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName2
}

resource virtualNetworkPeering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'peer-${vnetName1}-${vnetName2}'
  parent: virtualNetwork1

  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true

    remoteVirtualNetwork: {
      id: virtualNetwork2.id
    }

    useRemoteGateways: false
  }
}

resource virtualNetworkPeering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'peer-${vnetName2}-${vnetName1}'
  parent: virtualNetwork2

  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true

    remoteVirtualNetwork: {
      id: virtualNetwork1.id
    }

    useRemoteGateways: false
  }
}
