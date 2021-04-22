using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Text;

namespace VBrick.ConsoleApp
{
    /// <summary>
    /// Class used with <see cref="IOptions{TOptions}"/> to extract
    /// settings from an appsettings.json file.
    /// </summary>
    public class AppOptions
    {
        /// <summary>
        /// Base address for the VBrick server
        /// </summary>
        public string ApiBaseAddress { get; set; }
        /// <summary>
        /// VBrick account to use against API
        /// </summary>
        public string ApiUsername { get; set; }
        /// <summary>
        /// VBrick password. 
        /// This should be passed by console argument.
        /// For Visual Studio, this can be added by right-clicking the Console Project,
        /// Properties > Debug tab then adding the string -pw "YOUR_PASSWORD" to the arguments.
        /// </summary>
        public string ApiPassword { get; set; }
        /// <summary>
        /// HttpClient timeout, in seconds
        /// </summary>
        public int ApiClientTimeout { get; set; }
        /// <summary>
        /// When hooked up to a database, the limit to which to add records
        /// before flushing to the database. 
        /// 
        /// For example, Entity Framework Core 
        /// can add records via a DbSet Add, then call SaveAsync() to flush the
        /// results to the database.
        /// </summary>
        public int BulkLimit { get; set; }
        /// <summary>
        /// When hooked up to a database, informs the console application 
        /// not to write to the database but write instead to the logger.
        /// </summary>
        public bool? GenerateReportOnly { get; set; }
    }
}
