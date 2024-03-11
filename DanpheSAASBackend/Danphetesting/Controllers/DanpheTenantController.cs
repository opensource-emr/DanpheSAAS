using Danphetesting.Context;
using Danphetesting.Models;
using Danphetesting.Utility;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace Danphetesting.Controllers
{

    [EnableCors("AllowOrigin")]
    [Route("api/[controller]")]
    [ApiController]

    public class DanpheTenantController : ControllerBase
    {
        private readonly TenantDbContext _context;



        public DanpheTenantController(TenantDbContext context)
        {
            _context = context;
        }

        private static readonly object _lockObject = new object();

   

        [HttpPost("addInfo")]
        public IActionResult AddInfo(Tenant formData)
        {
            try
            {
                TenantUtility util = new TenantUtility(_context);

                bool domainexist = util.IsCorporateEmail(formData.Email);
                if (domainexist == false)
                {
                    return BadRequest("Please Enter Corporate Email");
                }
                bool result = util.DomainAlreadyExist(formData.Email);
                if (result == false)
                {
                    return BadRequest("Email already exists");
                }

                // Generate TenantId by concatenating Id and HospitalShortName
                string tenantId = util.GenerateTenanatId(formData.HospitalShortName);
                formData.TenantId = tenantId;
                formData.CreatedOn = DateTime.Now;
                formData.IsPaid = false;
                _context.Tenants.Add(formData);
                _context.SaveChanges();

                Task powershellTask = Task.Run(() => ExecutePowerShellScript(formData.TenantId));


                return Ok();
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred while processing your request: {ex.Message}");
            }

        }
        private void ExecutePowerShellScript(string tenantId)
        {

            lock (_lockObject)
             {
                Console.WriteLine("thread working.");

                try
                {
                    var connectionstring = AppSettings.Current.AppDbConnectionString;


                    var optionsBuilder = new DbContextOptionsBuilder<TenantDbContext>();
                    optionsBuilder.UseSqlServer(connectionstring);


                    TenantDbContext _context = new TenantDbContext(optionsBuilder.Options);


                    string websiteName = tenantId;

                        var sourcePathConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-sourcePath");
                        var destinationPathConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-destinationPath");
                        var danpheDbPathConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-danpheDbPath");
                        var danpheAdminScriptPathConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-danpheAdminScriptPath");
                        var powerShellScriptPathConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-powerShellScriptPath");
                        var serverNameConfig = _context.configurations.FirstOrDefault(c => c.ParameterName == "-serverName");

                        if (sourcePathConfig == null || destinationPathConfig == null || danpheDbPathConfig == null || danpheAdminScriptPathConfig == null || powerShellScriptPathConfig == null || serverNameConfig == null)
                        {
                            Console.WriteLine("One or more parameters not found in the Configuration table.");
                            return;
                        }

                        string sourcePath = sourcePathConfig.ParameterValue;
                        string destinationPath = destinationPathConfig.ParameterValue;
                        string danpheDbPath = danpheDbPathConfig.ParameterValue;
                        string danpheAdminScriptPath = danpheAdminScriptPathConfig.ParameterValue;
                        string powerShellScriptPath = powerShellScriptPathConfig.ParameterValue;
                        string serverName = serverNameConfig.ParameterValue;


                        string arguments = $"-ExecutionPolicy Bypass -Command  \"{powerShellScriptPath} " +
                                           $"-websiteName '{websiteName}' " +
                                           $"-sourcePath '{sourcePath}' " +
                                           $"-destinationPath '{destinationPath}' " +
                                           $"-danpheDbPath '{danpheDbPath}' " +
                                           $"-danpheAdminScriptPath '{danpheAdminScriptPath}'" +
                                           $"-serverName '{serverName}'\"";


                        Console.WriteLine(arguments);
                        // Start a new process for running PowerShell
                        ProcessStartInfo psi = new ProcessStartInfo
                        {
                            FileName = "powershell.exe",
                            Arguments = arguments,
                            Verb = "runas", // Run as administrator
                            RedirectStandardError = false,
                            RedirectStandardOutput = false,
                            UseShellExecute = true,
                            CreateNoWindow = true,
                            //UserName = username,
                        };

                        try
                        {
                            using (Process process = Process.Start(psi))
                            {
                                

                                process.WaitForExit();

                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error executing PowerShell script: {ex.Message}");
                        }
                    }
                
                catch (Exception ex)
                {
                    Console.WriteLine($"Error running PowerShell script: {ex.Message}");

                }
                }
            
      
       }
       
    }

}
    

