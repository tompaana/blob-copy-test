@minLength(2)
@maxLength(60)
param appServiceName string

param existingAppSettingsConfigProperties object
param newAppSettingsConfigProperties object

resource appService 'Microsoft.Web/sites@2022-03-01' existing = {
  name: appServiceName
}

resource appSettingsConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  parent: appService
  properties: union(existingAppSettingsConfigProperties, newAppSettingsConfigProperties)
}
