using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using VBrick.ConsoleApp.Models;

namespace VBrick.ConsoleApp
{
    class RecordsProcessor
    {
        private readonly HttpClient httpClient;
        private readonly IOptions<AppOptions> options;
        private readonly ILogger logger;

        public RecordsProcessor(HttpClient httpClient, 
                                IOptions<AppOptions> options, 
                                ILogger<RecordsProcessor> logger)
        {
            this.httpClient = httpClient;
            this.options = options;
            this.logger = logger;
        }

        internal async Task<int> ProcessRecords(string token)
        {
            if (options.Value.GenerateReportOnly.HasValue &&
                options.Value.GenerateReportOnly.Value)
            {
                var jsonString = await this.VideosReportAsync(token);
                logger?.LogInformation($"{{ \"data\": {jsonString} }}");
            }
            else
            {
                _ = await this.AddVideoReportsAsync(token);
            }
            /* TODO: try-catch and return something other than 0. */
            return 0;
        }

        /// <summary>
        /// User login code for generating a token for use with other calls.
        /// </summary>
        /// <param name="httpClient"></param>
        /// <returns></returns>
        internal async Task<string> UserLoginAsync()
        {
            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Post, "/api/v2/user/login");

            var jsonString = JsonSerializer.Serialize(new { username = options.Value.ApiUsername, password = options.Value.ApiPassword });
            request.Content = new StringContent(jsonString, Encoding.UTF8, "application/json");

            try
            {
                HttpResponseMessage response = await httpClient.SendAsync(request);
                response.EnsureSuccessStatusCode();

                var jsonResponse = await response.Content.ReadAsStringAsync();
                logger?.LogDebug("User login token received.");
                var jsonObject = JsonSerializer.Deserialize<SimpleToken>(jsonResponse);
                return jsonObject.token;
            }
            catch (HttpRequestException ex)
            {
                logger?.LogError(ex, "Error trying to login.");
                return string.Empty;
            }
            catch (UriFormatException ex)
            {
                logger?.LogError(ex, "Bad setting: ApiBaseAddress");
                return string.Empty;
            }
        }

        /// <summary>
        /// On-screen report for receiving and parsing API data.
        /// </summary>
        internal async Task<string> VideosReportAsync(string token)
        {
            var utcNow = DateTime.UtcNow;
            var thisMonth = new DateTime(utcNow.Year, utcNow.Month, 1);
            var lastMonth = thisMonth.AddMonths(-1);
            var testUri = string.Format("/api/v2/videos/report?after={0}&before={1}", lastMonth.AddDays(1).ToString("O"), lastMonth.AddDays(2).ToString("O"));
            logger?.LogTrace($"testUri: {testUri}");
            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Get, testUri);
            request.Headers.Authorization = new AuthenticationHeaderValue("VBrick", token);

            try
            {
                HttpResponseMessage response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();
                logger?.LogDebug("Response received with success status code.");

                await response.Content.LoadIntoBufferAsync();

                StringBuilder sb = new StringBuilder("[");
                using (var stream = new MemoryStream())
                {
                    await response.Content.CopyToAsync(stream);
                    foreach (var record in await JsonSerializer.DeserializeAsync<IEnumerable<VideoReport>>(stream))
                    {
                        sb.Append(JsonSerializer.Serialize(record));
                        sb.Append(",");
                        logger?.LogTrace($"record.ToString(): {record}");
                    }
                    /* Remove trailing comma, then close JSON array */
                    sb.Remove(sb.Length - 1, 1);
                }
                sb.Append("]");

                return sb.ToString();
            }
            catch (HttpRequestException ex)
            {
                logger?.LogError(ex, "Error: Possibly exceeded timeout or response size limit.");
                return string.Empty;
            }
            catch (UriFormatException ex)
            {
                logger?.LogError(ex, "Bad setting: ApiBaseAddress");
                return string.Empty;
            }
            catch (IOException ex)
            {
                logger?.LogError(ex, "Error retrieving content from response");
                return string.Empty;
            }
        }

        /// <summary>
        /// Stub for adding records to database processed from API.
        /// </summary>
        internal async Task<int> AddVideoReportsAsync(string token)
        {
            //var lastMonth = DateTime.UtcNow.AddMonths(-1);
            //var testUri = string.Format("/api/v2/videos/report?after={0}", new DateTime(lastMonth.Year, lastMonth.Month, 1).ToString("O"));
            var utcNow = DateTime.UtcNow;
            var thisMonth = new DateTime(utcNow.Year, utcNow.Month, 1);
            var lastMonth = thisMonth.AddMonths(-1);
            var testUri = string.Format("/api/v2/videos/report?after={0}&before={1}", lastMonth.ToString("O"), thisMonth.ToString("O"));
            HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Get, testUri);
            request.Headers.Authorization = new AuthenticationHeaderValue("VBrick", token);

            try
            {
                HttpResponseMessage response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var bulkLimit = options.Value.BulkLimit;
                foreach (var record in await JsonSerializer.DeserializeAsync<IEnumerable<VideoReport>>(await response.Content.ReadAsStreamAsync()))
                {
                    logger?.LogTrace($"record.ToString(): {record}");
                    /* Logic for bulk adding to database */
                }
                return 0;
            }
            catch (HttpRequestException ex)
            {
                logger?.LogError(ex, "Error trying to login.");
                return 1;
            }
            catch (UriFormatException ex)
            {
                logger?.LogError(ex, "Bad setting: ApiBaseAddress");
                return 1;
            }
        }

        private class SimpleToken
        {
            public string token { get; set; }
        }
    }
}
