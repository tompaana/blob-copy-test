@minLength(2)
@maxLength(64)
param vnetName string

param location string = resourceGroup().location
param addressPrefixes array = [ '10.0.0.0/22' ]
param subnets array

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location

  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }

    subnets: subnets
  }
}
