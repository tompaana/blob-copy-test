@minLength(1)
@maxLength(40)
param appServicePlanName string

param location string = resourceGroup().location
param skuName string = 'F1' // See https://learn.microsoft.com/azure/app-service/overview-hosting-plans
param capacity int = 1

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'

  properties: {
    reserved: true
  }

  sku: {
    name: skuName
    capacity: capacity
  }
}

output appServicePlanId string = appServicePlan.id
