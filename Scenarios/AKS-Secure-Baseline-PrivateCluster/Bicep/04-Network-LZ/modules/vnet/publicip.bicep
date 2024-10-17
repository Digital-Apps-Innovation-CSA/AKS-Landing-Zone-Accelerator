param publicipName string
param publicipsku object
param publicipproperties object
param location string = resourceGroup().location
param availabilityZones array
param tags object = {}

resource publicip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: publicipName
  location: location
  sku: publicipsku
  zones: !empty(availabilityZones) ? availabilityZones : null
  properties: publicipproperties
  tags: tags
}
output publicipId string = publicip.id
