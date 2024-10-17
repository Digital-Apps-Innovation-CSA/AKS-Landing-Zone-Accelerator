param acrName string
param acrSkuName string
param location string = resourceGroup().location
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSkuName
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Disabled'
  }
  tags:tags
}

output acrid string = acr.id
