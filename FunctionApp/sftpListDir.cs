using System;
using System.Threading.Tasks;
using System.Linq;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Renci.SshNet;

// Lists files in remote directory on SFTP server
namespace stu0292.Sftp
{
    public static class sftpListDir
    {
        [FunctionName("sftpListDir")]
        public static async Task<IActionResult>
        Run(
            [
                HttpTrigger(
                    AuthorizationLevel.Function,
                    "get",
                    Route ="sftpListDir/{*directoryPath}") // * allows slashes in route param
            ]
            HttpRequest req,
            string directoryPath,
            ILogger log
        )
        {
            // route params do not start with "/". Also defaults to / in the case of no route provided
            directoryPath = "/" + directoryPath;
            log.LogInformation($"Processing for directory: {directoryPath}");

            // connect to SFTP service
            string host =
                Environment.GetEnvironmentVariable("SFTP_HOST");
            string username =
                Environment.GetEnvironmentVariable("SFTP_USERNAME");
            string sftpPasswordString =
                Environment.GetEnvironmentVariable("SFTP_PASSWORD");
            var sftp = new SftpClient(host, 22, username, sftpPasswordString);

            try
            {
                sftp.Connect();
                log.LogInformation($"SFTP Connect Success to {host}");

                var files = sftp.ListDirectory(directoryPath.ToString());

                // separate directories from files
                var dirs = files.Where(file => file.IsDirectory && file.Name != "." && file.Name != "..");
                var dirNames = dirs.Select(file => file.Name).ToArray();
                var fileNames = files.Where(file => !file.IsDirectory).Select(file => file.Name).ToArray();
                Array.Sort(fileNames);
                Array.Sort(dirNames);

                // build response message
                string n = Environment.NewLine;
                string responseMessage = host + directoryPath;
                responseMessage += n+n+ string.Join("/" + n, dirNames) + "/";
                responseMessage += n+n+ string.Join(n, fileNames);
                
                log.LogInformation($"Done");
                return new OkObjectResult(responseMessage);
            }
            catch (Exception e)
            {
                log.LogError(e.ToString());
                return new NotFoundObjectResult(e.ToString());
            }
        }
    }
}
