targetScope = 'subscription'

param location string = deployment().location

param rgName string
param acrPrivateEndpointName string
param privateDNSZoneACRName string = 'privatelink${environment().suffixes.acrLoginServer}'
param acrName string = 'eslzacr${uniqueString('acrvws', utcNow('u'))}'

param vnetName string
param serviceSubnetName string
param postgressSubnetName string
param netAppSubnetName string



param frexibleServerName string 
param skuPostgres string
param tierPostgres string
param dataBaseName string
@secure()
param adminPasswordPostgres string
@secure()
param adminUsernamePostgres string

param netAppAccountName string
param netAppAccountPoolName string
param netAppVolumeName string

param availabilityZones array
param protocolTypes array
param networkFeatures string
param netappSize int
param netAppServiceLevel string

param tags object = {}

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags: tags
  }
}

module acr 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: acrName
  params: {
    location: location
    acrName: acrName
    acrSkuName: 'Premium'
    tags : tags
  }
}

resource servicesSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${serviceSubnetName}'
}

resource postgresSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${postgressSubnetName}'
}

resource netAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${netAppSubnetName}'
}


module privateEndpointAcr 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: acrPrivateEndpointName
  params: {
    location: location
    groupIds: [
      'registry'
    ]
    privateEndpointName: acrPrivateEndpointName
    privatelinkConnName: '${acrPrivateEndpointName}-conn'
    resourceId: acr.outputs.acrid
    subnetid: servicesSubnet.id
    tags:tags
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  scope: resourceGroup(rg.name)
  name: vnetName
}

resource privateDNSZoneACR 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneACRName
}

module privateEndpointACRDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acr-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneACR.id
    privateEndpointName: privateEndpointAcr.name
  }
}

module privatednsPostgresZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsPostgresZone'
  params: {
    privateDNSZoneName: '${frexibleServerName}.private.postgres.database.azure.com'
    tags: tags
  }
}

module privateDNSLinkSA 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkPostgres'
  params: {
    privateDnsZoneName: privatednsPostgresZone.outputs.privateDNSZoneName
    vnetId: vnet.id
    tags: tags
  }
}

module flexibleServer 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.3.1' = {
  scope: resourceGroup(rg.name)
  name: 'flexibleServerDeployment'
  params: {
    // Required parameters
    name: frexibleServerName
    skuName: skuPostgres
    tier: tierPostgres
    // Non-required parameters
    administratorLogin: adminUsernamePostgres
    administratorLoginPassword: adminPasswordPostgres
    databases: [
      {
        name: dataBaseName
      }
    ]
    delegatedSubnetResourceId: postgresSubnet.id
    location: location
    privateDnsZoneArmResourceId: privatednsPostgresZone.outputs.privateDNSZoneId
    tags:tags
  }
  dependsOn: [
    privatednsPostgresZone
    postgresSubnet
  ]
}

module netAppAccount 'br/public:avm/res/net-app/net-app-account:0.3.1' = {
  scope: resourceGroup(rg.name)
  name: 'netAppAccountDeployment'
  params: {
    // Required parameters
    name: netAppAccountName
    // Non-required parameters
    capacityPools: [
      {
        name: netAppAccountPoolName
        serviceLevel: netAppServiceLevel
        size: netappSize
        volumes: [
          {
            exportPolicyRules: [
              {
                allowedClients: '0.0.0.0/0'
                nfsv3: false
                nfsv41: true
                ruleIndex: 1
                unixReadOnly: false
                unixReadWrite: true
              }
            ]
            name: netAppVolumeName
            networkFeatures: networkFeatures
            protocolTypes: protocolTypes
            subnetResourceId: netAppSubnet.id
            zones: availabilityZones
            usageThreshold: 107374182400
          }
        ]
      }
    ]
    location: location
    tags:tags
       
  }
  dependsOn: [ 
    netAppSubnet
  ]
}


module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksIdentity'
  params: {
    location: location
    identityName: 'aksIdentity'
    tags: tags
  }
}

output acrName string = acr.name
