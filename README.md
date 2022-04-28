# Azure Function SFTP client with static outbound IP address

Example of how to connect to an SFTP server that has IP restrictions from Azure Functions (C#).

Uses a [NAT Gateway](https://docs.microsoft.com/en-us/azure/azure-functions/functions-how-to-use-nat-gateway) to assign a static outbound public IP address to the function app. This requires a Premium App Service Plan for the Function App. If the target SFTP server does not restrict inbound IP addresses, the NAT Gateway is not required. 

# Setup

1. Deploy the Azure resources with `fnSftpClient.bicep`
2. Deploy the function app code in `/FunctionApp/` folder
3. Optionally deploy demo SFTP server with `vmSftpDemoServer.bicep`
4. On the target SFTP server allow the Public IP address of the NAT Gateway 
5. Call the function to test the connection to the SFTP server

See `deployment.ps1` powershell script which automates most of the deployment.
It requires:
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) 
- [Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cwindows%2Ccsharp%2Cportal%2Cbash#v2)
- [.NET 6.0 SDK](https://dotnet.microsoft.com/en-us/download)

With demo server:
```
powershell .\deployment.ps1 -resourceGroupName <RESOURCE_GROUP> -location <LOCATION> -functionAppName <FUNCTIONAPP_NAME> -includeDemoServer -resourceGroupServerName <DEMO_SERVER_RESOURCE_GROUP> -sftpUsername <USERNAME> -sftpPassword <PASSWORD>
```
Without demo server:
```
powershell .\deployment.ps1 -resourceGroupName <RESOURCE_GROUP> -location <LOCATION> -functionAppName <FUNCTIONAPP_NAME> -serverAddress <SFTP_SERVER_ADDRESS> -sftpUsername <USERNAME> -sftpPassword <PASSWORD>
```

The script has a number of steps and outputs loads of text. Wait until you see 'Done!' in the powershell script output before testing anything. 

Note the outbound IP address of the NAT Gateway. This is the address you'll need to allow traffic from on the SFTP server. You can view the IP address from the Azure Portal.

For more info see [Bicep Quickstart](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code?tabs=CLI) and 
[Functions VS Code Quickstart](https://docs.microsoft.com/en-us/azure/azure-functions/create-first-function-vs-code-csharp?tabs=in-process)

# Run the function

If you didn't use the deployment script, you'll need to set the following app settings in the function app config:

- SFTP_HOST
- SFTP_USERNAME
- SFTP_PASSWORD

> For production use, store the SFTP secrets and AzureWebJobsStorage string in Key Vault, not Function App config. 

Get the URLs for the function app from the output of the deployment templates or the Azure Portal. 

There are two functions with URLs similar to the below:

sftpListDir: https://functionAppName.azurewebsites.net/api/sftplistdir/{*directorypath}?code=slkfjsaldkfj

Delete `{*directorypath}` and optionally replace it with the path to the directory on the SFTP server you wish to list. Call this URL in your browser and you should see the directory listing if everything's working. 

To confirm the outbound IP address the function is using, test call the function ipEcho, which returns the outbound IP address of the function. This should match the outbound IP attached to the NAT gateway.

# Demo Server

If using the demo server, you can set the allowed inbound IP address in the Network Security Group. Look for the inbound rule named SSH which should have the IP address of the NAT Gateway. Select the rule name to edit the rule and change the Source IP address to allow/deny the function app accordingly for testing:  

![NSG Rules](./NetworkSecurityGroup.png)

# Clean up resources

Delete the resources for the function app client and, if you set one up, the demo server:

```
az group delete --name <RESOURCE_GROUP_NAME>
az group delete --name <DEMO_SERVER_RESOURCE_GROUP>
```
