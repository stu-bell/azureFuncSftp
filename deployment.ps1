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

    [Parameter(HelpMessage="Name for SFTP demo server resource group. Required if using -includeDemoServer")][Alias("h")]
    [string]$resourceGroupServerName,

    [Parameter(HelpMessage="Include Demo SFTP Server VM?")]
    [switch]$includeDemoServer,

    [Parameter(HelpMessage="SFTP Server Address. Not required if using -includeDemoServer")][Alias("s")]
    [string]$serverAddress,

    [Parameter(Mandatory=$true,HelpMessage="Username for SFTP server account.")][Alias("u")]
    [string]$sftpUsername,

    [Parameter(Mandatory=$true,HelpMessage="Password for SFTP server account.")][Alias("p")]
    [string]$sftpPassword
)

# Deploy the function app and network resources
az group create --name $resourceGroupName --location $location
az deployment group create --resource-group $resourceGroupName --template-file fnSftpClient.bicep --parameters fnNameSftp=$functionAppName

# Get Public IP address of NAT Gateway
$natIpAddress = $(az network public-ip show --resource-group $resourceGroupName --name pipSftpClient --query 'ipAddress')

# Optionally deploy a demo server
if ($includeDemoServer){
    az group create --name $resourceGroupServerName --location $location
    # set the username, password and pass the NAT IP address to the template parameters
    az deployment group create --resource-group $resourceGroupServerName --template-file vmSftpDemoServer.bicep --parameters adminUsername=$sftpUsername adminPasswordOrKey=$sftpPassword sourceIpAddressPrefix=$natIpAddress
    # get public IP address of the server for the function app config later
    $serverAddress=$(az network public-ip show --resource-group $resourceGroupServerName --name pipSftpDemoServer --query 'ipAddress')
}

# deploy the function app code
Set-Location FunctionApp
func azure functionapp publish $functionAppName --csharp
Set-Location ..

# Update the function settings to include the server address, username and password
az functionapp config appsettings set --name $functionAppName --resource-group $resourceGroupName --settings SFTP_HOST=$serverAddress SFTP_USERNAME=$sftpUsername SFTP_PASSWORD=$sftpPassword

# Output the function URLs, outbound IP
func azure functionapp list-functions $functionAppName --show-keys
Write-Host "NAT Gateway Outbound IP: ${$natIpAddress}"
Write-Host "Done!"
