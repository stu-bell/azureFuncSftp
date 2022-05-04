# Powershell script to deploy Function App SFTP Client
# Run this script from the same directory it's saved in so it can find the correct template files
# Script has several steps. Wait until Done! is printed.
#
# Requires Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
# Requires Azure Functions Core Tools: https://docs.microsoft.com/en-us/azure/azure-functions/create-first-function-cli-csharp?tabs=azure-cli%2Cin-process

Param(
    [Parameter(Mandatory=$true,HelpMessage="Name for SFTP Function resource group")][Alias("g")]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true,HelpMessage="Name for Function App. Must be globally unique")][Alias("f")]
    [string]$functionAppName,

    [Parameter(Mandatory=$true,HelpMessage="Location for all resources")][Alias("l")]
    [string]$location='uksouth',

    [Parameter(HelpMessage="Name for SFTP demo server resource group. Required if using -includeDemoServer")]
    [string]$resourceGroupServerName,

    [Parameter(HelpMessage="Include Demo SFTP Server VM?")]
    [switch]$includeDemoServer,

    [Parameter(HelpMessage="SFTP Server Address. Not required if using -includeDemoServer")][Alias("h")]
    [string]$sftpHost,

    [Parameter(Mandatory=$true,HelpMessage="Username for SFTP server account.")][Alias("u")]
    [string]$sftpUsername,

    [Parameter(Mandatory=$true,HelpMessage="Password for SFTP server account.")][Alias("p")]
    [string]$sftpPassword
)

$pipClient='pipSftpClient'
$pipServer='pipSftpServer'

Write-Host 'Deploying Resource Group...'
az group create --name $resourceGroupName --location $location
Write-Host 'Deploying FunctionApp and Network Resources...'
az deployment group create --resource-group $resourceGroupName --template-file fnSftpClient.bicep --parameters fnNameSftp=$functionAppName sftpHost=$sftpHost sftpUsername=$sftpUsername sftpPassword=$sftpPassword pipName=$pipClient

# Get Public IP address of NAT Gateway
$natIpAddress = $(az network public-ip show --resource-group $resourceGroupName --name $pipClient --query 'ipAddress')

# Optionally deploy a demo server
if ($includeDemoServer){
    Write-Host 'Deploying Demo Server Resource Group...'
    az group create --name $resourceGroupServerName --location $location
    Write-Host 'Deploying Demo Server Resources...'
    # set the username, password and pass the NAT IP address to the template parameters
    az deployment group create --resource-group $resourceGroupServerName --template-file vmSftpDemoServer.bicep --parameters adminUsername=$sftpUsername adminPasswordOrKey=$sftpPassword sourceIpAddressPrefix=$natIpAddress pipName=$pipServer
    # get public IP address of the server for the function app config later
    $sftpHost=$(az network public-ip show --resource-group $resourceGroupServerName --name $pipServer --query 'ipAddress')
}

# deploy the function app code
Write-Host 'Deploying Function App...'
Set-Location FunctionApp
func azure functionapp publish $functionAppName --csharp
Set-Location ..

# Update the function settings to include the server address
az functionapp config appsettings set --name $functionAppName --resource-group $resourceGroupName --settings SFTP_HOST=$sftpHost

# Output the function URLs, outbound IP
func azure functionapp list-functions $functionAppName --show-keys
Write-Host "NAT Gateway Outbound IP: ${natIpAddress}"
Write-Host "Done!"
