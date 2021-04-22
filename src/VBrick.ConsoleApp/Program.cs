using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;

namespace VBrick.ConsoleApp
{
    class Program
    {
        public static async Task<int> Main(string[] args)
        {
            int returnValue = 0;
            using (var host = CreateHostBuilder(args).Build())
            {
                host.Services.GetService<Stopwatch>().Start();
                using (var scope = host.Services.CreateScope())
                {
                    await host.StartAsync();
                    RecordsProcessor recordsProcessor = scope.ServiceProvider.GetService<RecordsProcessor>();
                    /* TODO: Retry to get token */
                    var token = await recordsProcessor.UserLoginAsync();
                    /* TODO: Retry to get results */
                    returnValue = await recordsProcessor.ProcessRecords(token);
                    await host.StopAsync();
                }
                host.Services.GetService<Stopwatch>().Stop();
                await Console.Out.WriteLineAsync($"Elapsed: {host.Services.GetService<Stopwatch>().ElapsedMilliseconds} ms");
            }
            return returnValue;
        }

        internal static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((hostingContext, config) =>
                {
                    /* 
                     * Switch Mapping maps command line arguments to an IOptions<T> class.
                     * */
                    var switchMapping = new Dictionary<string, string>
                    {
                        { "-g", "GenerateReportOnly" },
                        { "--generate-report-only", "GenerateReportOnly" },
                        { "-pw", "ApiPassword" },
                        { "-api-password", "ApiPassword" }
                    };

                    config.AddCommandLine(args, switchMapping);
                })
                .ConfigureServices((hostContext, services) =>
                {
                    services.Configure<AppOptions>(hostContext.Configuration)
                        .AddOptions();

                    // Other dependencies
                    services.AddScoped<RecordsProcessor>();
                    /* Reference: https://docs.microsoft.com/en-us/dotnet/architecture/microservices/implement-resilient-applications/use-httpclientfactory-to-implement-resilient-http-requests#how-to-use-typed-clients-with-ihttpclientfactory */
                    services.AddHttpClient<RecordsProcessor>(client =>
                    {
                        client.BaseAddress = new Uri(hostContext.Configuration["ApiBaseAddress"]);
                        client.Timeout = new TimeSpan(0, 0, hostContext.Configuration.GetValue<int>("ApiClientTimeout"));
                    });

                    services.AddSingleton<Stopwatch>();
                });

    }
}
