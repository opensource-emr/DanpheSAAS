using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace Danphetesting.Models
{
    public class AppSettings
    {


        private static AppSettings _appSettings;
        public string AppDbConnectionString { get; set; }
        private AppSettings()
        {        // Private constructor to prevent external instantiation
        }
        public static AppSettings Current
        {
            get
            {
                if (_appSettings == null)
                {
                    _appSettings = GetCurrentSettings();
                }
                return _appSettings;
            }
        }
        private static AppSettings GetCurrentSettings()
        {
            var builder = new ConfigurationBuilder()
                       .SetBasePath(Directory.GetCurrentDirectory()).AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                       .AddEnvironmentVariables();
            IConfigurationRoot configuration = builder.Build();
            var settings = new AppSettings
            {
                AppDbConnectionString = configuration.GetConnectionString("AppDb")
            };
            return settings;
        }
    }
}


