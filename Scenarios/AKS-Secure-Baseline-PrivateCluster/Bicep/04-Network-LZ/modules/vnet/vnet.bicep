param vnetAddressSpace object = {
  addressPrefixes: [
    '10.0.0.0/16'
  ]
}
param vnetName string
param subnets array
param location string = resourceGroup().location
param tags object = {}


resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: vnetAddressSpace
    subnets: subnets

  }
  tags: tags
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output vnetSubnets array = vnet.properties.subnets
