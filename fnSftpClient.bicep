@description('Suffix added to default parameters for names for resources. This must be globally unique for some resources.')
param nameSuffix string = '${resourceGroup().name}${uniqueString(resourceGroup().id)}'

@description('Location should be the same as the RG')
param location string = resourceGroup().location

@description('Name for VNet')
param vnetName string = 'vnetSftpClient'

@description('Address space for VNet')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Name for SubNet for Function App')
param subnetName string = 'subnetSftpClient'

@description('Address prefix for subnet')
param subnetAddressPrefix string = '10.10.1.0/24'

@description('Name for NAT Gateway')
param natgwName string = 'natSftpClient'

@description('Name for outbound Public IP for NAT Gateway')
param pipName string = 'pipSftpClient'

@description('Name for Storage Account')
param strgName string = substring(toLower(replace('strg${nameSuffix}', '-', '')),0,24)

@description('SKU for Storage Account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageSKU string = 'Standard_LRS'

@description('Name for Function App')
param fnNameSftp string = 'fn${nameSuffix}'

@description('Name for App Service Plan')
param aspName string = 'aspSftpClient'

@description('SKU for App Service Plan')
@allowed([
  'Standard'
  'ElasticPremium'
])
param fnSKU string = 'ElasticPremium'

var aspSkuOptions = {
  Standard: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  ElasticPremium: {
    name: 'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
    family: 'EP'
    capacity: 1
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: strgName
  location: location
  sku: {
    name: storageSKU
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          keyType:'Account'
          enabled: true
        }
      }
    }
    largeFileSharesState: 'Disabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: aspName
  location: location
  sku: aspSkuOptions[fnSKU]
  kind: 'elastic'
}

@description('Function App for SFTP client')
resource funcAppSftp 'Microsoft.Web/sites@2021-03-01' = {
  name: fnNameSftp
  location: location
  kind: 'functionapp'
  properties:{
    enabled: true
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: '${vnet.id}/subnets/${subnetName}'
  }

  resource funcAppConfig 'config@2021-03-01' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage: 'AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value};DefaultEndpointsProtocol=https;EndpointSuffix=${environment().suffixes.storage};'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'dotnet'
      WEBSITE_ENABLE_SYNC_UPDATE_SITE: 'true'
      WEBSITE_RUN_FROM_PACKAGE: '1'
      WEBSITE_VNET_ROUTE_ALL: '1'
    }
  }
}

resource vnet 'Microsoft.Network/virtualnetworks@2020-11-01' = {
    name: vnetName
    location: location
    properties: {
        addressSpace: {
            addressPrefixes:[
              vnetAddressPrefix
            ]
        }
        subnets: [
            {
                name: subnetName
                properties: {
                    addressPrefix: subnetAddressPrefix
                    natGateway: {
                      id: natgw.id
                    }
                    delegations: [
                          {
                              name: 'Microsoft.Web.serverFarms'
                              properties: {
                                  serviceName: 'Microsoft.Web/serverFarms'
                              }
                          }
                    ]
                }
                
            }
        ]  
    }
}

resource natgw 'Microsoft.Network/natGateways@2021-05-01' = {
  name: natgwName
  location: location
  sku: {
     name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: pip.id
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pipName
  location: location
  sku: {
      name: 'Standard'
      tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

output funcUrlSftp string = funcAppSftp.properties.defaultHostName
output outboundPublicIp string = pip.properties.ipAddress
