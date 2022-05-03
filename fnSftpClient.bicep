@description('Suffix added to default parameters for names for resources. Some resource names must be globally unique')
param nameSuffix string = '${resourceGroup().name}${uniqueString(resourceGroup().id)}'

@description('IP or FQDN for the SFTP server')
// Can be set later by updating Function App Configuration Settings
param sftpHost string = ''

@description('Username for the SFTP server')
// Can be set later by updating Function App Configuration Settings
param sftpUsername string = ''

// Can be set later by updating Function App Configuration Settings
@description('Password for the SFTP server')
@secure()
param sftpPassword string = ''

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Name for VNet')
param vnetName string = 'vnet${nameSuffix}'

@description('Address space for VNet')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Name for SubNet for Function App')
param subnetName string = 'sub${nameSuffix}'

@description('Address prefix for subnet')
param subnetAddressPrefix string = '10.10.1.0/24'

@description('Name for NAT Gateway')
param natgwName string = 'nat${nameSuffix}'

@description('Name for outbound Public IP for NAT Gateway')
param pipName string = 'pip${nameSuffix}'

@description('Name for KeyVault')
param kvName string = substring(toLower(replace('kv${nameSuffix}', '-', '')),0,24)

@description('Name for Storage Account')
// storage account names have additional restrictions
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
param aspName string = 'asp${nameSuffix}'

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

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies:[
      {
        // allow function app to get secret values
        tenantId: subscription().tenantId
        objectId: funcAppSftp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }

  resource secretAwjConn 'secrets@2021-10-01' = {
    name: 'azurewebjobs-connstr'
    properties: {
      value: 'AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage};DefaultEndpointsProtocol=https;'
      contentType: 'string'
      attributes: {
        enabled: true
      }
    }
  }

  resource secretSftpPassword 'secrets@2021-10-01' = {
    name: 'sftp-password'
    properties: {
      value: sftpPassword
      contentType: 'string'
      attributes: {
        enabled: true
      }
    }
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
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    enabled: true
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: '${vnet.id}/subnets/${subnetName}'
  }

  resource funcAppConfig 'config@2021-03-01' = {
    name: 'appsettings'
    properties: {
      SFTP_HOST: sftpHost
      SFTP_USERNAME: sftpUsername
      // reference to key vault for use in func app settings. KeyVault URIs end with / for latest version 
      SFTP_PASSWORD:       '@Microsoft.KeyVault(SecretUri=${keyvault.properties.vaultUri}/secrets/sftp-password/)'
      AzureWebJobsStorage: '@Microsoft.KeyVault(SecretUri=${keyvault.properties.vaultUri}/secrets/azurewebjobs-connstr/)'
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
