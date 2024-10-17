param subnetId string
param location string = resourceGroup().location
param tags object = {}

resource jbnic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'jbnic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

output nicName string = jbnic.name
output nicId string = jbnic.id
