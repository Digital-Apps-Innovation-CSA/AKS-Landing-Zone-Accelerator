targetScope = 'subscription'

param rgName string
param clusterName string
param akslaWorkspaceName string
param vnetName string
param subnetName string
param appGatewayName string

param aksuseraccessprincipalId string
param aksadminaccessprincipalId string
param aksIdentityName string
param kubernetesVersion string

param location string = deployment().location
param availabilityZones array
param enableAutoScaling bool
param autoScalingProfile object

@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'


param acrName string //User to provide each time

param nodeAgents int = 3
param vmSize string = 'Standard_D4d_v5'
param disk int = 100
 
param tags object = {}

var privateDNSZoneAKSSuffixes = {
  AzureCloud: '.azmk8s.io'
  AzureUSGovernment: '.cx.aks.containerservice.azure.us'
  AzureChinaCloud: '.cx.prod.service.azk8s.cn'
  AzureGermanCloud: '' //TODO: what is the correct value here?
}

var privateDNSZoneAKSName = 'privatelink.${toLower(location)}${privateDNSZoneAKSSuffixes[environment().name]}'

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  scope: resourceGroup(rg.name)
  name: aksIdentityName
}

module aksPodIdentityRole 'modules/Identity/role.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksPodIdentityRole'
  params: {
    principalId: aksIdentity.properties.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //Managed Identity Operator
    
  }
}

resource pvtdnsAKSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDNSZoneAKSName
  scope: resourceGroup(rg.name)
}

module aksPolicy 'modules/policy/policy.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksPolicy'
  params: {
    location: location
  }
}

module akslaworkspace 'modules/laworkspace/la.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'akslaworkspace'
  params: {
    location: location
    workspaceName: akslaWorkspaceName
    tags:tags
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${subnetName}'
}

resource appGateway 'Microsoft.Network/applicationGateways@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: appGatewayName
}

module aksCluster 'modules/aks/privateaks.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksCluster'
  params: {
    autoScalingProfile: autoScalingProfile
    enableAutoScaling: enableAutoScaling
    availabilityZones: availabilityZones
    location: location
    aadGroupdIds: [
      aksadminaccessprincipalId
    ]
    clusterName: clusterName
    kubernetesVersion: kubernetesVersion
    networkPlugin: networkPlugin
    logworkspaceid: akslaworkspace.outputs.laworkspaceId
    privateDNSZoneId: pvtdnsAKSZone.id
    subnetId: aksSubnet.id
    identity: {
      '${aksIdentity.id}': {}
    }
    appGatewayResourceId: appGateway.id
    nodeAgents : nodeAgents
    vmSize: vmSize
    disk: disk
    tags:tags
  }
  dependsOn: [
    aksPvtDNSContrib
    aksPvtNetworkContrib
    aksPodIdentityRole
    aksPolicy
  ]
}


module acraksaccess 'modules/Identity/acrrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acraksaccess'
  params: {
    principalId: aksCluster.outputs.kubeletIdentity
    roleGuid: '7f951dda-4ed3-4680-a7ca-43fe172d538d' //AcrPull
    acrName: acrName
  }
}

module aksPvtNetworkContrib 'modules/Identity/networkcontributorrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksPvtNetworkContrib'
  params: {
    principalId: aksIdentity.properties.principalId
    roleGuid: '4d97b98b-1d4f-4787-a291-c67834d212e7' //Network Contributor
    vnetName: vnetName
  }
}

module aksPvtDNSContrib 'modules/Identity/pvtdnscontribrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksPvtDNSContrib'
  params: {
    principalId: aksIdentity.properties.principalId
    roleGuid: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f' //Private DNS Zone Contributor
    pvtdnsAKSZoneName: privateDNSZoneAKSName
  }
}

module vmContributeRole 'modules/Identity/role.bicep' = {
  scope: resourceGroup('${clusterName}-aksInfraRG')
  name: 'vmContributeRole'
  params: {
    principalId: aksIdentity.properties.principalId
    roleGuid: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' //Virtual Machine Contributor
  }
  dependsOn: [
    aksCluster
  ]
}

module aksuseraccess 'modules/Identity/role.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksuseraccess'
  params: {
    principalId: aksuseraccessprincipalId
    roleGuid: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f' //Azure Kubernetes Service Cluster User Role
  }
}

module aksadminaccess 'modules/Identity/role.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksadminaccess'
  params: {
    principalId: aksadminaccessprincipalId
    roleGuid: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8' //Azure Kubernetes Service Cluster Admin Role
  }
}

module appGatewayContributerRole 'modules/Identity/appgtwyingressroles.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'appGatewayContributerRole'
  params: {
    principalId: aksCluster.outputs.ingressIdentity
    roleGuid: 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor
    applicationGatewayName: appGateway.name
  }
}

module appGatewayReaderRole 'modules/Identity/role.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'appGatewayReaderRole'
  params: {
    principalId: aksCluster.outputs.ingressIdentity
    roleGuid: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader
  }
}


//  Telemetry Deployment
module telemetry 'modules/telemetry/telemetry.bicep' = {
  name: 'telemetry'
  params: {
    enableTelemetry: true
    location: location
  }
}

// @description('Enable usage and telemetry feedback to Microsoft.')
// param enableTelemetry bool = true
// var telemetryId = 'a4c036ff-1c94-4378-862a-8e090a88da82-${location}'
// resource telemetrydeployment 'Microsoft.Resources/deployments@2021-04-01' = if (enableTelemetry) {
//   name: telemetryId
//   location: location
//   properties: {
//     mode: 'Incremental'
//     template: {
//       '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
//       contentVersion: '1.0.0.0'
//       resources: {}
//     }
//   }
// }
