param appServicePlanName string
param location string = resourceGroup().location
param skuName string = 'S1'

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'

  properties: {
    perSiteScaling: false
    reserved: true
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }

  sku: {
    name: skuName
  }
}

@description('The resource ID of the App Service plan.')
output appServicePlanId string = appServicePlan.id
