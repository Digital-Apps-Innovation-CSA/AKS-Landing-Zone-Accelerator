
targetScope = 'subscription'

param rgName string
param vnetSubnetName string
param vnetName string

param vmSize string
param location string = deployment().location
@secure()
param adminUsername string
@secure()
param adminPassword string

param vmName string = 'jumpbox'

param diskSizeGB int = 30

param storageAccountType string = 'Premium_LRS'
param tags object = {}

resource subnetVM 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rgName)
  name: '${vnetName}/${vnetSubnetName}'
}

module jumpbox 'modules/VM/virtualmachine.bicep' = {
  scope: resourceGroup(rgName)
  name: 'jumpbox'
  params: {
    location: location
    subnetId: subnetVM.id
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    VMName: vmName
    diskSizeGB: diskSizeGB
    storageAccountType: storageAccountType
    tags: tags
  }
}
