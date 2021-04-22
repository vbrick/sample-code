using System;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using Newtonsoft.Json;

namespace RevAPi
{
    class Program
    {
        //
        // REQUIRED FIELDS - Update for your environment
        //
        static readonly Uri _myRevServerURL = new Uri("TBD/");  // TBD = Rev URL
        static string myapiKey = "TBD";  // TBD = Rev API key name
        static string secret = "TBD";   // TBD = Rev API key secret
        static string redirecturi = "TBD";   // TBD = Rev API key redirect URI
        static string myUsername = "TBD";  // TBD = Rev username to login with
        static string myPassword = "TBD"; // TBD = Rev password to login with
        // END REQUIRED FIELDS

        static string authorization;
        static string signature;
        static string verifier;
        static string redirecturibase;
        static string timeStamp;
        static string referer;
        static string token;
        static string refreshToken;
        static string authorizationForAPI;

        static void Main(string[] args)
        {
            timeStamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss");
            verifier = (myapiKey + "::" + timeStamp);
            signature = GenerateSignature(verifier, secret);
            redirecturibase = redirecturi + "/";

            //Logon();
            Oauth_Authorization();
            Console.WriteLine("Hit ENTER to exit...");
            Console.ReadLine();
        }

        static async void Oauth_Authorization()
        {
            HttpClient client = new HttpClient();
            Uri address = new Uri(_myRevServerURL, "/oauth/authorization?apiKey=" + myapiKey 
                + "&signature=" + System.Web.HttpUtility.UrlEncode(signature) 
                + "&redirect_uri=" + System.Web.HttpUtility.UrlEncode(redirecturi) 
                + "&verifier=" + System.Web.HttpUtility.UrlEncode(verifier) 
                + "&response_type=code");
            client.DefaultRequestHeaders.Add("Referer", redirecturi);
            Console.WriteLine("SENDING AUTHORIZATION REQUEST");
            HttpResponseMessage response = await client.GetAsync(address);
            var result = await response.Content.ReadAsStringAsync();
            if (response.ReasonPhrase == "OK")
            {
                Console.WriteLine(response);
                Console.WriteLine("OK");
                Logon();
            }
            else
            {
                // failure path
                Console.WriteLine(response);
                Oauth_Authorization();
            }

        }

        /// <summary>
        /// IMPORTANT!!!
        /// This method simulates a user manually entering their credentials via UI.  An application would NOT build and send this API call - this is for simulation purposes only.
        /// </summary>
        static async void Logon()
        {
            var postData = "username=" + myUsername + "&password=" + myPassword 
                + "&redirectUri=" + _myRevServerURL + "&state=&apiKey=" + myapiKey;
            referer = _myRevServerURL + "/oauth/authorization?apikey=" + myapiKey 
                + "&signature=" + signature 
                + "&redirect_uri=" + redirecturi 
                + "&verifier=" + verifier 
                + "&response_type=code";
            string req;
            Uri address = new Uri(_myRevServerURL, "/oauth/logon");
            string _ContentType = "application/x-www-form-urlencoded";
            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("Referer", referer);
                var request = new HttpRequestMessage(HttpMethod.Post, address);
                request.Content = new StringContent(postData, Encoding.UTF8, _ContentType);
                var response = await client.PostAsync(address.ToString(), request.Content);
                Console.WriteLine("\n\nSENDING LOGIN REQUEST\n");
                var result = await response.Content.ReadAsStringAsync();
                req = response.RequestMessage.RequestUri.ToString();
                int startPoint = req.IndexOf("?auth_code=");
                authorization = req.Remove(0, startPoint + 11);
                if (response.ReasonPhrase == "OK")
                {
                    Console.WriteLine("Logon succes");
                    GetToken();
                }
                else
                {
                    Console.WriteLine("Logon failed -> " + response.ReasonPhrase);
                }
            }
        }


        static async void GetToken()
        {

            string _ContentType = "application/json";
            Uri address = new Uri(_myRevServerURL, "/oauth/token");
            var postData = JsonConvert.SerializeObject(new RevTokenRequest() { ApiKey = myapiKey, RedirectUri = redirecturi, AuthCode = authorization, GrantType = "authorization_code" });
            byte[] data = Encoding.ASCII.GetBytes(postData);
            using (var client = new HttpClient())
            {
                var request = new HttpRequestMessage(HttpMethod.Post, address);
                request.Content = new StringContent(postData, Encoding.UTF8, _ContentType);
                Console.WriteLine("\nSENDING TOKEN REQUEST\n"); 
                var response = await client.PostAsync(address.ToString(), request.Content);
                var result = await response.Content.ReadAsStringAsync();
                Console.WriteLine(result);
                var gettoken = JsonConvert.DeserializeObject<AccessToken>(result);
                token = gettoken.accessToken;
                refreshToken = gettoken.refreshToken;

                Console.WriteLine("Access Token: " + token);
                Console.WriteLine("Refresh Token: " + refreshToken);
                Console.WriteLine("Issued By: " + gettoken.issuedBy);
                Console.WriteLine("Expiration: " + gettoken.expiration);
                Console.WriteLine("UserId: " + gettoken.userId);

                authorizationForAPI = gettoken.issuedBy + " " + token;
                RefreshToken();
            }
        }

        static async void RefreshToken()
        {

            string _ContentType = "application/json";
            Uri address = new Uri(_myRevServerURL, "/oauth/token");
            var postData = JsonConvert.SerializeObject(new RevTokenRequest() { ApiKey = myapiKey, RedirectUri = redirecturi, RefreshToken = refreshToken, AuthCode = "", GrantType = "refresh_token" });
            byte[] data = Encoding.ASCII.GetBytes(postData);
            using (var client = new HttpClient())
            {
                var request = new HttpRequestMessage(HttpMethod.Post, address);
                request.Content = new StringContent(postData, Encoding.UTF8, _ContentType);
                Console.WriteLine("\nSENDING REFRESH TOKEN REQUEST\n");
                var response = await client.PostAsync(address.ToString(), request.Content);
                var result = await response.Content.ReadAsStringAsync();
                Console.WriteLine(result);
                var gettoken = JsonConvert.DeserializeObject<AccessToken>(result);
                token = gettoken.accessToken;

                Console.WriteLine("New Access Token: " + token);
                Console.WriteLine("Refresh Token: " + gettoken.refreshToken);
                Console.WriteLine("Issued By: " + gettoken.issuedBy);
                Console.WriteLine("Expiration: " + gettoken.expiration);

                authorizationForAPI = gettoken.issuedBy + " " + token;

                GetCategories();
            }
        }

        static async void GetCategories()
        {
            Console.WriteLine("\nAuth for API:: " + authorizationForAPI);

            HttpClient client = new HttpClient();
            Uri address = new Uri(_myRevServerURL, "/api/v2/categories");
            client.DefaultRequestHeaders.Add("Authorization", authorizationForAPI);
            Console.WriteLine("\n\nSENDING GetCategories API call");
            HttpResponseMessage response = await client.GetAsync(address);
            var result = await response.Content.ReadAsStringAsync();
            if (response.ReasonPhrase == "OK")
            {
                Console.WriteLine("Success");
                Console.WriteLine(result);
            }
            else
            {
                Console.WriteLine("Fail: " + response.ReasonPhrase);
            }
        }

        public class Authorization
        {
            public string authorization { get; set; }
            public string Issuer { get; set; }
        }
        public class RevTokenRequest
        {
            public string AuthCode { get; set; }
            public string GrantType { get; set; }
            public string ApiKey { get; set; }
            public string RedirectUri { get; set; }
            public string RefreshToken { get; set; }
        }
        public class AccessToken
        {
            public string accessToken { get; set; }
            public string refreshToken { get; set; }
            public string expiration { get; set; }
            public string issuedBy { get; set; }
            public string userId { get; set; }
        }
        static string GenerateSignature(string verifier, string apisecret)
        {
            var encoding = new ASCIIEncoding();
            var originalData = encoding.GetBytes(verifier);
            var keyBytes = encoding.GetBytes(apisecret);

            using (var hmacsha256 = new HMACSHA256(keyBytes))
            {
                try
                {
                    var signedBytes = hmacsha256.ComputeHash(originalData);

                    return Convert.ToBase64String(signedBytes);
                }
                catch (CryptographicException)
                {
                    throw new UnauthorizedAccessException();
                }
            }
        }
    }
}
