@minLength(2)
@maxLength(60)
param appServiceName string

param siteConfigProperties object = {}
param appSettingsProperties object = {}

resource appService 'Microsoft.Web/sites@2022-03-01' existing = {
  name: appServiceName
}

var existingAppSettings = empty(appService.properties.siteConfig.appSettings) ? {} : toObject(appService.properties.siteConfig.appSettings, x => x.name, x => x.value)

resource siteConfig 'Microsoft.Web/sites/config@2022-03-01' = if (!empty(siteConfigProperties)) {
  name: 'web'
  parent: appService
  properties: union(appService.properties.siteConfig, siteConfigProperties)
}

resource appSettingsConfig 'Microsoft.Web/sites/config@2022-03-01' = if (!empty(appSettingsProperties)) {
  name: 'appsettings'
  parent: appService
  properties: union(existingAppSettings, appSettingsProperties)
}
