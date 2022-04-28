using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Net.Http;

// from https://docs.microsoft.com/en-us/azure/azure-functions/functions-how-to-use-nat-gateway
// Returns the outgoing IP address for the function (as returned by https://ifconfig.me)
namespace stu0292.Sftp
{
    public static class ipEcho
    {
        [FunctionName("ipEcho")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            var client = new HttpClient();
            var response = await client.GetAsync(@"https://ifconfig.me");
            var responseMessage = await response.Content.ReadAsStringAsync();

            return new OkObjectResult(responseMessage);
        }
    }
}
