param privateEndpointName string
param subnetid string
param groupIds array
param resourceId string
param privatelinkConnName string
param location string = resourceGroup().location
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: privateEndpointName
  location: location
  tags:tags
  properties: {
    subnet: {
      id: subnetid
    }
    privateLinkServiceConnections: [
      {
        name: privatelinkConnName
        properties: {
          groupIds: groupIds
          privateLinkServiceId: resourceId
        }
      }
    ]
  }
}

output privateEndpointName string = privateEndpoint.name
