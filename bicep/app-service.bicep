@minLength(2)
@maxLength(60)
param appServiceName string

param location string = resourceGroup().location

@allowed([
  'app'
  'app,linux'
  'app,linux,container'
  'hyperV'
  'app,container,windows'
  'functionapp'
  'functionapp,linux'
])
param kind string = 'app,linux'

param serverFarmId string

@minLength(4)
@maxLength(63)
param logAnalyticsWorkspaceName string

param allowPublicNetworkAccess bool

param privateNetworkEnabled bool

param siteConfig object = {
  vnetRouteAllEnabled: privateNetworkEnabled ? true : null
  http20Enabled: true
}

@maxLength(90)
param vnetResourceGroupName string = resourceGroup().name

@maxLength(64)
param vnetName string = ''

@maxLength(80)
@description('This subnet must be delegated to Microsoft.Web/serverFarms')
param subnetName string = ''

@maxLength(80)
param privateEndpointSubnetName string = ''

@minLength(1)
@maxLength(90)
param privateDnsZoneResourceGroupName string = resourceGroup().name

var appServiceLogs = kind != 'functionapp,linux' ? [
  {
    category: 'AppServiceHTTPLogs'
    enabled: true
  }
  {
    category: 'AppServiceAppLogs'
    enabled: true
  }
  {
    category: 'AppServiceAuditLogs'
    enabled: true
  }
] : [
  {
    category: 'FunctionAppLogs'
    enabled: true
  }
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (privateNetworkEnabled) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  kind: kind

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    enabled: true
    httpsOnly: true
    publicNetworkAccess: allowPublicNetworkAccess ? 'Enabled' : 'Disabled'
    serverFarmId: serverFarmId
    siteConfig: siteConfig
    virtualNetworkSubnetId: privateNetworkEnabled ? '${virtualNetwork.id}/subnets/${subnetName}' : null
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${appServiceName}'
  scope: appService

  properties: {
    logs: appServiceLogs

    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]

    workspaceId: logAnalyticsWorkspace.id
  }
}

module privateEndpoint './private-endpoint.bicep' = if (privateNetworkEnabled) {
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
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
  }
}

output identityPrincipalObjectId string = appService.identity.principalId
