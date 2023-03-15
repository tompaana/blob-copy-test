@minLength(2)
@maxLength(60)
param appServiceName string

param location string = resourceGroup().location

@description('The resource ID of the App Service plan to host the app in.')
param appServicePlanId string

// For more information on App Service kind, see https://github.com/Azure/app-service-linux-docs/blob/master/Things_You_Should_Know/kind_property.md
@allowed([
  'app'
  'app,linux'
  'app,linux,container'
  'hyperV'
  'app,container,windows'
  'functionapp'
  'functionapp,linux'
])
param appServiceKind string = 'app'

param allowPublicNetworkAccess bool

param vnetEnabled bool

@maxLength(90)
param vnetResourceGroupName string

@maxLength(64)
param vnetName string

@maxLength(80)
param subnetName string

@maxLength(80)
param privateEndpointSubnetName string = subnetName

param siteConfig object = {
  vnetRouteAllEnabled: vnetEnabled ? true : null
  http20Enabled: true
}

resource appSettingsConfig 'Microsoft.Web/sites/config@2022-03-01' existing = {
  name: 'appsettings'
  parent: appService
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = if (vnetEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  kind: appServiceKind

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    enabled: true
    hostNamesDisabled: false
    httpsOnly: true
    publicNetworkAccess: allowPublicNetworkAccess ? 'Enabled' : 'Disabled'
    reserved: false
    serverFarmId: appServicePlanId
    siteConfig: siteConfig
    virtualNetworkSubnetId: vnetEnabled ? '${virtualNetwork.id}/subnets/${subnetName}' : null
  }
}

module privateEndpoint './private-endpoint.bicep' = if (vnetEnabled) {
  name: '${appServiceName}PrivateEndpoint'

  params: {
    serviceName: appServiceName
    serviceId: appService.id
    location: location
    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    groupId: 'sites'
    privateDnsZoneName: 'privatelink.azurewebsites.net'
  }
}

output appServiceResourceId string = appService.id

@description('The object ID of the system assigned service principal of the App Service.')
output appServiceIdentityPrincipalObjectId string = appService.identity.principalId

#disable-next-line outputs-should-not-contain-secrets
output appSettingConfig object = appSettingsConfig.list()
