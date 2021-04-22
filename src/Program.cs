using System;

namespace src
{
    class Program
    {
        static readonly HttpClient httpClient = new HttpClient();

        public static async Task<int> Main(string[] args)
        {
            int returnValue = 0;
            using (var host = CreateHostBuilder(args).Build())
            {
                host.Services.GetService<DiagnosticTimer>().Restart();
                using (var scope = host.Services.CreateScope())
                {
                    await host.StartAsync();
                    InitializeMapping(scope);
                    /* TODO: Code Goes Here */
                    RecordsProcessor recordsProcessor = scope.ServiceProvider.GetService<RecordsProcessor>();
                    recordsProcessor.SetClientProperties(httpClient);
                    /* TODO: Retry to get token */
                    var token = await recordsProcessor.UserLoginAsync(httpClient);
                    /* TODO: Retry to get results */
                    returnValue = await recordsProcessor.ProcessRecords(httpClient, token);
                    await host.StopAsync();
                }
                await Console.Out.WriteLineAsync($"FinishTime: {host.Services.GetService<DiagnosticTimer>().FinishTime()}");
            }
            return returnValue;
        }

        internal static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((hostingContext, config) =>
                {
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
                            /*
                             * The next four code statements are equivalent to the line
                             * `services.AddHydrogenApplication<AppStartupModule<IdentityNameProvider>>();`
                             * in a Web Startup.cs file.
                             * */
                    services.Configure<MapperConfigurationExpression>(options =>
                        options.AddMaps(new[] {
                                    typeof(AppMappingModule).Assembly,
                                    typeof(OrganizationMappingModule).Assembly
                    }));

                    services.RegisterModule(module:
                        new LogicDependencyModule<AppDataInitializer,
                                                  EmailTransmitter,
                                                  IdentityProvider>()
                    );

                            /* Organization mapping and module dependencies */
                    services.RegisterModule(module:
                        new OrganizationDependencyModule<OrganizationDbContext>()
                    );

                    var configuration = hostContext.Configuration;
                    services.Configure<AppOptions>(configuration);
                    services.Configure<HydrogenOrganizationalOptions>(configuration);
                    services.Configure<HydrogenEntityFrameworkOptions>(configuration);
                    services.Configure<HydrogenEmailOptions>(configuration);
                    services.AddOptions();

                            // Register identity
                    services.AddScoped<IIdentityProvider<string>, IdentityProvider>();
                    services.AddScoped<IIdentityProvider<KeyPerson>, KeyPersonIdentityProvider>();
                    services.AddScoped<IIdentityProvider<BasicPerson>, BasicPersonIdentityProvider>();
                    services.AddScoped<IRootDirectoryProvider, RootDirectoryProvider>();

                            // Other dependencies
                    services.AddScoped<IFileManager, FileManager>();
                    services.AddScoped<IDirectoryManager, DirectoryManager>();
                    services.AddScoped<IRootDirectoryProvider>(s =>
                    {
                        return new RootDirectoryProvider()
                        {
                            Path = Directory.GetCurrentDirectory()
                        };
                    });
                    services.AddScoped<SmtpClient>();

                    services.AddScoped<DiagnosticTimer>();
                    services.AddScoped<RecordsProcessor>();

                    services.AddSingleton<DiagnosticTimer>();
                });

        internal static void InitializeMapping(IServiceScope scope)
        {
            var options = scope.ServiceProvider.GetService<IOptions<MapperConfigurationExpression>>();
            Mapper.Initialize(options.Value);
        }
    }
}
