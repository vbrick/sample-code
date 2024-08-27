<#
.SYNOPSIS
    VBrick Rev Client
.DESCRIPTION
    VBrick Rev Client
    Built 2024-07-16
    DISCLAIMER:
        This script is not an officially supported Vbrick product, and is provided AS-IS.

    This script is intended to be imported before running scripts that call the included cmdlets.

    Once you call "New-RevClient" or "Import-RevClient" then any of the Rev commands should then use the configured settings. The [RevClient] instance will attempt to automatically extend/reconnect the Rev session as needed

    To get a list of the included CmdLets run this command (after loading script):
    
    get-command -Name "*-Rev*" | get-help | select Name,Synopsis

    ### Configure Rev Connection
    New-RevClient
    Get-RevClient
    Set-RevClient
    Import-RevClient
    Export-RevClient

    ### Manage Rev Connection
    Connect-Rev
    Disconnect-Rev
    Test-Rev
    Get-RevAccountId

    ### Make API Request
    Invoke-Rev
    
    ### Videos
    New-RevVideo
    Set-RevVideo
    Remove-RevVideo
    Search-RevVideos
    Wait-RevTranscode
    Edit-RevVideoDetails
    Edit-RevVideoMigration
    Get-RevVideoDetails

    ### Download
    Get-RevVideoFile
    Get-RevVideoTranscriptionFile
    Get-RevVideoTranscriptionFiles
    Get-RevThumbnailFile

    ### Webcasts
    Get-RevWebcast
    New-RevWebcast
    Edit-RevWebcast
    Get-RevWebcastStatus
    Search-RevWebcasts

    ### Users
    Get-RevRoles
    Get-RevUser
    New-RevUser
    Search-RevUsersGroupsChannels
    Search-RevUsers

    ### Utilities
    New-RevFormData
    New-RevFormDataField
    Set-RevRateLimit
    Get-RevRateLimit
    Wait-RevRateLimit
.NOTES
    While this library *should* work in Powershell v5, version 7 is recommended
.LINK
    https://revdocs.vbrick.com/reference/getting-started
.EXAMPLE
    . .\rev-client.ps1
    New-RevClient -Connect -Url "https://my.rev.url" -ApiKey "User API Key" -Secret "API Secret"
    Get-RevUser -Me

    This example will load this script file, create a new connection to Rev and get the details of the authenticated user
#>


class RevMetadataAttribute : Attribute
{
    # field to store constructor argument:
    [string]$PayloadName = ''
    [bool]$IsPassthru = $false
    [bool]$PreferSource = $false

    RevMetadataAttribute([string] $PayloadName, [bool] $IsPassthru, [bool] $PreferSource)
    {
        $this.PayloadName = $PayloadName;
        $this.IsPassthru = $IsPassthru;
        $this.PreferSource = $PreferSource;
    }

    RevMetadataAttribute([string] $PayloadName, [bool] $IsPassthru)
    {
        $this.PayloadName = $PayloadName;
        $this.IsPassthru = $IsPassthru;
    }

    RevMetadataAttribute([string]$PayloadName)
    {
        $this.PayloadName = $PayloadName;
    }

    RevMetadataAttribute() {}

    static [hashtable] PopulatePayload([System.Management.Automation.InvocationInfo] $Invocation, [object]$Source, [hashtable] $Payload) {
        $BoundParameters = $Invocation.BoundParameters;
        $AllParameters = $Invocation.MyCommand.Parameters;

        foreach ($key in $AllParameters.Keys)
        {
            # skip if no value
            if ($null -eq $BoundParameters.$key -and $null -eq $Source.$key) {
                continue;
            }

            $attributes = $AllParameters.$key.Attributes;
            $metaAttr = $attributes | Where-Object { $_.TypeId -eq [RevMetadataAttribute]}
            if (-not $metaAttr) {
                continue;
            }
            $metaKey = if ($metaAttr.PayloadName) { $metaAttr.PayloadName } else { $key }
            $subKey = "Body";

            if ($metaAttr.IsPassthru) {
                $subKey = $null;
            }
            # allow setting Body.value and splitting by /
            $metaKeyPair = $metaKey -split '/',2
            if ($metaKeyPair.Count -gt 1) {
                $subKey = $metaKeyPair[0]
                $metaKey = $metaKeyPair[1]
            }

            $value = $BoundParameters.$key;
            if ($null -eq $value -or ($metaAttr.PreferSource -and $null -ne $Source.$key))
            {
                $value = $Source.$key
            }
            if ($null -eq $value) {
                continue;
            }

            # convert datetime to strings
            if ($value -is [datetime]) {
                $value = [RevClient]::ISODate($value);
            }

            if (-not $subKey) {
                # Workaround for if RequestArgs and body are defined
                if ($Payload.$metaKey -is [hashtable] -and $value -is [hashtable]) {
                    $value.GetEnumerator() | foreach-object {
                        $Payload.$metaKey.($_.Key) = $_.Value;
                    }
                }
                $Payload.$metaKey = $value;
            } else {
                if ($null -eq $Payload.$subKey) {
                    $Payload.$subKey = @{}
                }
                $Payload.$subKey.$metaKey = $value;
            }
        }
        return $Payload
    }
    static [hashtable] PopulatePayload([System.Management.Automation.InvocationInfo] $Invocation, [object]$Source)
    {
        return [RevMetadataAttribute]::PopulatePayload($Invocation, $Source, @{ Body = @{} });
    }
    static [hashtable] PopulatePayload([System.Management.Automation.InvocationInfo] $Invocation)
    {
        return [RevMetadataAttribute]::PopulatePayload($Invocation, $null);
    }
}

class RevAPI {
    hidden [RevClient] $_rev;
    RevAPI([RevClient] $rev) {
        $this._rev = $rev;
    }
}
Add-Type -AssemblyName 'System.Net.Http'

class RevClient {
    [uri] $Url
    [string] $Token
    [datetime] $Expiration = (Get-Date).AddHours(-1);
    [string] $UserId
    [string] $Username
    hidden [securestring] $Password
    [string] $ApiKey
    hidden [securestring] $Secret
    [hashtable] $WebRequestArgs = @{}
    [bool] $AutoConnect = $true
    [int32] $Max429Retries = 1
    [string] $AccountId
    [Version] $Version
    [hashtable] $RateLimits = @{}
    static [hashtable] $APIs = @{}
    # [RevAdminAPI] $Admin;
    # [RevUserAPI] $User;
    # [RevDeviceAPI] $Device;
    # [RevWebcastAPI] $Webcast;
    RevClient() {
        # $this.Cache = [RevCache]::new();
        $this.Initialize();
    }
    RevClient(
        [object]$Config
    ) {
        # $this.Cache = [RevCache]::new();
        $this.Initialize($Config);
    }
    RevClient(
        [string]$Url
    ) {
        # $this.Cache = [RevCache]::new();
        $this.Initialize(@{ Url = $Url });
    }
    [bool] IsApiKeyAuth() {
        return $this.ApiKey -and $this.Secret;
    }
    hidden [bool] IsUserPassAuth() {
        return $this.Username -and $this.Password;
    }
    [bool] IsConnected() {
        return $this.Token -and ($this:Expiration - [datetime]::now).TotalMinutes -lt 1;
    }
    static [bool] IsAuthEndpoint([string] $Endpoint) {
        return $Endpoint -match '(v\d/authenticate|v\d/tokens)|extend-session|user/(login|logoff|session)';
    }
    [void] Initialize(
        [object]$Config
    ) {
        # $this.Admin = [RevAdminAPI]::new($this);
        # $this.User = [RevUserAPI]::new($this);
        # $this.Device = [RevDeviceAPI]::new($this);
        # $this.Webcast = [RevWebcastAPI]::new($this);

        foreach ($keypair in [RevClient]::APIs.GetEnumerator()) {
            if (-not $this.($keypair.Key)) {
                $this | Add-Member -NotePropertyName $keypair.Key -NotePropertyValue (($keypair.Value)::new($this));
            }
        }

        if (-not $Config) {
            return;
        }
        @('Url', 'Username', 'ApiKey', 'Password', 'Secret', 'Token', 'Expiration', 'WebRequestArgs', 'AutoConnect') | foreach-object {
            $val = $Config.$_;

            if (-not $val) {
                return;
            }
            if (($_ -eq 'Password' -or $_ -eq 'Secret') -and $val -isnot [securestring]) {
                $this.$_ = $val | ConvertTo-SecureString -AsPlainText -Force;
            } else {
                $this.$_ = $Config.$_
            }
        }
    }
    [Microsoft.PowerShell.Commands.WebResponseObject] Request(
        # Method - HTTP VERB
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,
        # Endpoint - the API endpoint, i.e. /api/v1/zones
        [string] $Endpoint,
        # Body - a hash or string for body of request (or query parameters for GET requests)
        [object] $Body,
        # hash of additional headers for request (example = User Agent)
        [hashtable] $Headers,
        # show progress bar (use only for downloads)
        [bool] $Progress,
        # hash of additional arguments for invoke-webrequest
        [hashtable] $RequestArgs
    ) {
        $isModern = $global:PSVersionTable.PSVersion.Major -gt 5;

        if ($this.AutoConnect -and -not [RevClient]::IsAuthEndpoint($Endpoint) -and -not $this.IsConnected()) {
            $this.Connect();
        }

        if ($null -eq $RequestArgs) {
            $RequestArgs = @{};
        }

        if ($null -eq $Headers) {
            $Headers = @{};
        }

        if (-not $Headers.'Content-Type') {
            $Headers.'Content-Type' = "application/json";
        }

        # add the authentication header
        if ($this.Token) {
            $Headers.Authorization = "VBrick $($this.Token)";
        }

        $request = $this.WebRequestArgs.Clone();
        $request.Method = $Method;
        $request.Uri = [uri]::new($this.Url, [uri]$Endpoint);
        $request.Headers = $Headers;

        # deal with formdata
        if ($Body -is [System.Net.Http.MultipartFormDataContent]) {
            if ($isModern) {
                $request.Headers.Remove('Content-Type');
                $request.Body = $Body;
            } else {
                foreach ($keypair in $Body.Headers ) {
                    $request.Headers.($keypair.Key) = "$($keypair.Value)";
                }
                [System.IO.Stream] $multipart = $null;
                [System.IO.StreamReader] $streamReader = $null;
                try {
                    $task = $Body.ReadAsStreamAsync();
                    # non-blocking wait
                    while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
                    $multipart = $task.GetAwaiter().GetResult();
                    $streamReader = [System.IO.StreamReader]::new($multipart, [System.Text.Encoding]::UTF8);
                    $request.Body = $streamReader.ReadToEnd();
                    $streamReader.Close();
                } catch {
                    if ($streamReader) {
                        $streamReader.Dispose();
                    } elseif ($multipart) {
                        $multipart.Dispose();
                    }
                    throw $_;
                }
            }
        } elseif ($null -ne $Body) {
            # convert to json string if needed
            if ($Body -isnot [string] -and $Method -ne [Microsoft.PowerShell.Commands.WebRequestMethod]::Get) {
                $Body = $Body | ConvertTo-Json -Depth 100;
            }
            $request.Body = $Body;
        }

        # disable progress bars because they really slow things down
        $oldProgress = $global:ProgressPreference;
        if (-not $Progress) {
            $global:ProgressPreference = 'SilentlyContinue';
        }

        # supports skiphttperror
        if ($isModern) {
            $request.SkipHttpErrorCheck = $true;
        } else {
            $request.UseBasicParsing = $True;
        }
        try {
            $response = $null;
            $attempt = 0;
            do {
                $attempt += 1;

                Write-Verbose "[Rev] Request $Method $Endpoint"
                $response = Invoke-WebRequest @request @RequestArgs;
                if ($null -eq $response) {
                    Write-Verbose "[Rev] Response $Method $Endpoint 200"
                    return $response;
                }
                $StatusCode = $response.BaseResponse.StatusCode;
                
                Write-Verbose "[Rev] Response $Method $Endpoint $([int]$StatusCode) $StatusCode)"

                if ($StatusCode -eq 429 -and $attempt -lt $this.Max429Retries) {
                    Write-Warning "[Rev] 429 Rate Limiting for $Method $Endpoint - Retry after 1 minute"
                    Start-Sleep -Seconds 60;
                } else {
                    break;
                }
            } while ($attempt -lt $this.Max429Retries);

            if ($isModern -and -not $response.BaseResponse.IsSuccessStatusCode) {
                throw [RevError]::Create($response);
            }
            return $response;
        } catch [RevError] {
            throw $_
        } catch {
            $err = if ($null -eq $_.Exception.Response) {
                [RevError]::new($_.Exception, $method, $endpoint);
            } else {
                $err = [RevError]::Create($_.Exception);
            }
            Write-Verbose "[Rev] Response $Method $Endpoint $($err.StatusCode) $($err.Detail)"

            if ($err.StatusCode -eq 401) {
                if ($this.Token -and -not $this.IsConnected()) {
                    Write-Warning "Session Token Expired - You must relogin to Rev using Connect-Rev command";
                } elseif (-not $this.Token -and -not ($Endpoint.EndsWith('user/login') -or $Endpoint.EndsWith('authenticate'))) {
                    Write-Warning "Not logged into Rev - use Connect-Rev command";
                }
            }
            throw $err;
        } finally {
            if (-not $Progress) {
                $global:ProgressPreference = $oldProgress;
            }
        }
    }
    [Microsoft.PowerShell.Commands.WebResponseObject] Request(
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method, [string] $Endpoint, [object] $Body, [hashtable] $Headers, [bool] $Progress
    ) {
        return $this.Request($Method, $Endpoint, $Body, $Headers, $Progress, @{});
    }
    [Microsoft.PowerShell.Commands.WebResponseObject] Request(
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method, [string] $Endpoint, [object] $Body
    ) {
        return $this.Request($Method, $Endpoint, $Body, @{}, $false, @{});
    }
    [Microsoft.PowerShell.Commands.WebResponseObject] Request(
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method, [string] $Endpoint
    ) {
        return $this.Request($Method, $Endpoint, $null, @{}, $false);
    }
    [object] Get([string] $Endpoint, [object] $Body) {
        $response = $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Get, $Endpoint, $Body, @{}, $false);
        return $this.DecodeResponse($response);
    }
    [object] Get([string] $Endpoint) { return $this.Get($Endpoint, $null); }
    [object] Post([string] $Endpoint, [object] $Body) {
        $response = $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Post, $Endpoint, $Body, @{}, $false);
        return $this.DecodeResponse($response);
    }
    [void] Patch([string] $Endpoint, [object] $Body) {
        $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Patch, $Endpoint, $Body, @{}, $false);
    }
    [object] Put([string] $Endpoint, [object] $Body) {
        $response = $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Put, $Endpoint, $Body, @{}, $false);
        return $this.DecodeResponse($response);
    }
    [void] Delete([string] $Endpoint) {
        $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Delete, $Endpoint, $null, @{}, $false)
    }
    [void] Head ([string] $Endpoint) {
        $this.Request([Microsoft.PowerShell.Commands.WebRequestMethod]::Head, $Endpoint, $null, @{}, $false)
    }
    hidden [object] DecodeResponse([Microsoft.PowerShell.Commands.WebResponseObject] $response) {
        $content = $response.Content;
        $contentType = $response.Headers.'Content-Type'
        $accept = $response.BaseResponse.RequestMessage.Headers.Accept;
        if ($content -isnot [string]) {
            # some responses don't have content type response
            $isNotString = ($contentType -and $contentType -notmatch 'json|text') -or ($accept -and $accept -notmatch 'json|text');
            # don't transform, pass as is
            if ($isNotString) {
                return $content;
            }
            try {
                $content = [System.Text.Encoding]::UTF8.GetString($response.Content);
            } catch {
                return $content;
            }
        }
        $isJson = $contentType -match 'json' -or $content -match '^[\[\{]';
        if ($isJson) {
            try {
                return $content | ConvertFrom-Json;
            } catch {}
        }
        return $content;
    }
    [void] Connect() {
        $key = if ($this.IsApiKeyAuth()) {
            $Endpoint = '/api/v2/authenticate';
            $Body = @{ apiKey = $this.ApiKey };
            'secret';
        } elseif ($this.IsUserPassAuth()) {
            $Endpoint = '/api/v2/user/login';
            $Body = @{ username = $this.Username; };
            'password';
        } else {
            if (-not $this.IsConnected()) {
                throw "Invalid Token / Expiration specified or session expired"
            }
            return;
        }

        # powershell 5 doesn't support convertfrom-securestring properly
        $bits = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.$key);
        $Body.$key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bits);

        $response = $null;
        $lastError = $null;
        # retry connecting a few times
        foreach ($i in (0..3)) {
            try {
                $response = $this.Post($Endpoint, $Body);
                break;
            } catch [RevError] {
                $lastError = $_;
            }
        }

        if ($response) {
            $this.Token = $response.token;
            $this.Expiration = Get-Date $response.expiration;
            $this.UserId = $response.id;
        } else {
            throw $lastError;
        }
    }
    [void] Connect(
        [object]$Config
    ) {
        $this.Initialize($Config);
        $this.Connect();
    }
    [bool] Disconnect() {
        try {
            if (-not $this.IsConnected()) {
                return $False;
            }

            if ($this.IsApiKeyAuth()) {
                $this.Delete("/api/v2/tokens/$($this.ApiKey)");
            } elseif ($this.IsUserPassAuth()) {
                $this.Post("/api/v2/user/logoff", @{ userId = $this.UserId; });
            }
            return $True;
        } catch [RevError] {
            Write-Warning $_;
            return $False;
        } finally {
            $this.Token = $null;
            $this.Expiration = Get-Date;
            $this.UserId = $null;
        }
    }
    [void] ExtendSession() {
        $response = $this.Post("/api/v2/user/extend-session", $null);
        if ($response) {
            $this.Expiration = Get-Date $response.expiration;
        }
    }
    [bool] VerifySession() {
        try {
            $this.Get("/api/v2/user/session");
            return $true;
        } catch [RevError] {
            return $false;
        }
    }
    [string] GetAccountID() {
        if ($this.accountId) {
            return $this.accountId;
        }
        $response = $this.Get('/');
        if ($response -match '"account":\{"id":"(?<accountId>[a-f0-9-]{36})"') {
            $this.accountId = $Matches.accountId;
            return $this.accountId;
        } else {
            throw [Exception]::new("Unable to determine Account ID");
        }
    }
    [string] GetVersion() {
        if ($this.version) {
            return $this.version;
        }
        $response = $this.Get('/js/version.js');
        if ($response -match 'buildNumber:\s*"(?<version>[\d.]+)') {
            $this.version = [Version]$Matches.version;
            return $this.version;
        } else {
            throw [Exception]::new("Unable to determine Version");
        }
    }
    [void] SetRateLimit([string] $key, [int32] $perMinute) {
        $this.RateLimits.$key = [pscustomobject]@{
            Limit = $perMinute;
            Start = [datetime]::Now - [timespan]::FromMinutes(1);
            Count = 0;
        }
    }
    [void] QueueRateLimit([string] $key) {
        $bucket = $this.RateLimits.$key;
        if ($null -eq $bucket) {
            return;
        }
        $delta = 60 - ([datetime]::Now - $bucket.Start).TotalSeconds;
        if ($delta -le 0) {
            $bucket.Start = [datetime]::Now;
            $bucket.Count = 0;
            return;
        }

        $bucket.Count += 1;
        if ($bucket.Count -ge $bucket.Limit) {
            Write-Verbose "[Rev] $key Rate Limited, sleeping $delta seconds"
            Start-Sleep -Seconds $delta;
            $bucket.Start = [datetime]::Now;
            $this.Current = 0;
        }
    }
    static [datetime] ConvertJSDate([string] $val) {
        $outval = [datetime]::MinValue;
        if ([datetime]::TryParse($val, [ref]$outval)) {
            return $outval;
        }

        $format = "ddd MMM dd yyyy HH:mm:ss zzz";
        if ([datetime]::TryParseExact(($val -replace 'GMT([+-]\d\d)(\d\d).*', '$1:$2'), $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$outval)) {
            return $outval
        };
        return $null;
    }
    static [string] ISODate ([datetime] $val) {
        return $val.ToUniversalTime().ToString("s", [System.Globalization.CultureInfo]::InvariantCulture) + "Z";
    }
    static [string] ISODate ([string] $val) {
        return [RevClient]::ISODate([datetime]$val);
    }
    static hidden [void] RegisterAPI([string] $name, [System.Type] $type) {
        [RevClient]::APIs.$name = $type;
    }
}
class RevError : System.InvalidOperationException
{
    [int] $StatusCode;
    [string] $Code;
    [string] $Detail;
    [string] $Endpoint;
    [string] $Method;
    hidden [object] $Response;

    RevError([System.Exception] $Exception, $method, $endpoint) : base($Exception.Message, $Exception) {
        $this.StatusCode = -1;
        $this.Endpoint = $endpoint;
        $this.Method = $method;
        $this.Code = "Unknown";
        $this.Detail = "$Exception";
    }
    RevError([string] $Message, [System.Net.WebException] $Exception, $response, $Code, $Detail) : base($Message, $Exception) {
        $this.StatusCode = $response.StatusCode;
        $this.Endpoint = $response.ResponseUri.PathAndQuery;
        $this.Method = $response.Method;
        $this.Response = $response;
        if ($Code -and $Detail) {
            $this.Code = $Code;
            $this.Detail = $Detail;
        }
    }
    RevError($Message, [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject] $response, [string] $code, [string] $detail) : base($Message) {
        $verb = $response.BaseResponse.RequestMessage.Method;
        $path = $response.BaseResponse.RequestMessage.RequestUri.PathAndQuery;

        $this.Response = $response;
        $this.Method = $verb;
        $this.Endpoint = $path;
        $this.StatusCode = $response.StatusCode;
        $this.Code = $Code;
        $this.Detail = $Detail;
    }
    RevError($Message, [Microsoft.PowerShell.Commands.WebResponseObject] $response, [string] $code, [string] $detail) : base($Message) {
        $this.StatusCode = $response.StatusCode;
        $this.Endpoint = $response.ResponseUri.PathAndQuery;
        $this.Method = $response.Method;
        $this.Response = $response;
        if ($Code -and $Detail) {
            $this.Code = $Code;
            $this.Detail = $Detail;
        }
    }
    static [System.Tuple[string,string]] GetDetail([object] $raw = "", [System.Net.HttpStatusCode] $statusCode, [string] $statusDescription = "") {
        if ($raw -is [byte[]]) {
            $raw = [system.text.encoding]::UTF8.GetString($raw);
        } elseif ($raw -isnot [string] -and $null -ne $raw) {
            Write-Verbose "Rev Error Get Detail - raw response is not string - $($raw.GetType())";
            $raw = "$raw";
        }
        if ([string]::IsNullOrWhiteSpace($raw)) { $raw = ""; }
        $codeValue = [string] ([int] $statusCode);
        $detailValue = $statusDescription;

        $body = $raw.Trim();
        if ($body.StartsWith("{"))
        {
            try
            {
                $parsed = $body | ConvertFrom-Json -ErrorAction Ignore;
                if (![string]::IsNullOrEmpty($parsed.code))
                {
                    $codeValue = $parsed.code;
                }
                if (![string]::IsNullOrEmpty($parsed.detail))
                {
                    $detailValue = $parsed.detail;
                }
            }
            catch {
                $codeValue = "Unknown";
                $detailValue = "Unable to parse error response body $_";
            }
        }
        elseif ($statusCode -eq [System.Net.HttpStatusCode]::TooManyRequests)
        {
            $detailValue = "Too Many Requests";
        }
        elseif ($statusCode -eq [System.Net.HttpStatusCode]::NotFound)
        {
            # used to ignore html body of 404s
        }
        elseif ($body.StartsWith("<!DOCTYPE") -or $body.StartsWith("<html"))
        {
            $detailValue = $body -replace "(?ms).*<body>\s*(.+)\s*</body>.*",'$1'
        }
        if ($detailValue.Length -gt 256)
        {
            $detailValue = $detailValue.Substring(0, 256);
        }
        return [System.Tuple]::Create($codeValue, $detailValue)
    }
    static [RevError] Create([System.Net.WebException] $Exception) {
        $webResponse = New-Object Microsoft.PowerShell.Commands.WebResponseObject($Exception.Response, $Exception.Response.GetResponseStream());

        $path = $Exception.Response.ResponseUri.PathAndQuery;
        $body = [RevError]::GetDetail($webResponse.Content, $webResponse.StatusCode, $webResponse.StatusDescription);

        $Message = "$($body[0]) $($body[1]) $path";

        return [RevError]::new($Message, $Exception, $webResponse, $body[0], $body[1]);
    }
    static [RevError] Create([Microsoft.PowerShell.Commands.WebResponseObject] $response) {
        $path = $response.BaseResponse.RequestMessage.RequestUri.PathAndQuery;

        $body = [RevError]::GetDetail($response.Content, $response.StatusCode, $response.StatusDescription);

        $Message = "$($body[0]) $($body[1]) $($path)";

        return [RevError]::new($Message, $response, $body[0], $body[1]);
    }
    static [RevError] Create([System.Exception] $Exception, $method, $endpoint) {
        return [RevError]::new($Exception, $method, $endpoint);
    }
}

New-Module -Name "Rev" -ScriptBlock {

    <#
.SYNOPSIS
Configure Rev Client
#>
function New-RevClient() {
    [CmdletBinding()]
    [OutputType([RevClient])]
    param (
        [Parameter(Mandatory, Position=0, ParameterSetName="UserAuth")]
        [Parameter(Mandatory, Position=0, ParameterSetName="ApiKeyAuth")]
        [Parameter(Mandatory, Position=0, ParameterSetName="AccessToken")]
        [uri] $Url,

        [Parameter(Mandatory, ParameterSetName="Config")] $Config,

        [Parameter(Mandatory, ParameterSetName="Help", DontShow)] [Alias("h")]
        [switch] $Help,

        [Parameter(Position=1, ParameterSetName="UserAuth")] [string] $Username,
        [Parameter(Position=2, ParameterSetName="UserAuth")] $Password,

        [Parameter(Position=1, ParameterSetName="ApiKeyAuth")] [string] $ApiKey,
        [Parameter(Position=2, ParameterSetName="ApiKeyAuth")] $Secret,

        [Parameter(Position=1, ParameterSetName="AccessToken")] [string] $Token,
        [Parameter(Position=2, ParameterSetName="AccessToken")] [datetime] $Expiration,

        [Parameter(ParameterSetName="UserAuth")]
        [Parameter(ParameterSetName="ApiKeyAuth")]
        [switch] $Prompt,

        [Parameter(ParameterSetName="UserAuth")]
        [Parameter(ParameterSetName="ApiKeyAuth")]
        [Parameter(ParameterSetName="AccessToken")]
        [hashtable] $WebRequestArgs = @{},
        # If specified then don't set as default Rev for current PS Session, just return
        [Parameter(ParameterSetName="UserAuth")]
        [Parameter(ParameterSetName="ApiKeyAuth")]
        [Parameter(ParameterSetName="AccessToken")]
        [Parameter(ParameterSetName="Config")]
        [switch] $ReturnOnly,

        # If set then automatically connect once created
        [Parameter(ParameterSetName="UserAuth")]
        [Parameter(ParameterSetName="ApiKeyAuth")]
        [Parameter(ParameterSetName="AccessToken")]
        [Parameter(ParameterSetName="Config")]
        [switch] $Connect
    )

    $local:revcfg = @{};
    $local:rev = $null;

    # used to set necessary user/pass or apikey/secret pairs in prompting
    $auth = @{}

    switch ($PSCmdlet.ParameterSetName) {
        'Help' {
            if (-not $PSCommandPath) {
                Get-Help -Detailed $MyInvocation.MyCommand
                return
            }
            Get-Help -Detailed $PSCommandPath | Out-Host
            return
        }
        'Config' {
            # if path then import
            if ($Config -is [string]) {
                $local:rev = Import-RevClient $Config -ReturnOnly
            } elseif ($Config -is [object]) {
                $local:revcfg = $Config;
            } else {
                throw [System.ArgumentException]::new("Invalid Config Value")
            }
            break;
        }
        'UserAuth' {
            $auth = @{
                UserKey = "Username";
                PassKey = "Password";
                UserVal = $Username;
                PassVal = $Password;
            }
        }
        'ApiKeyAuth' {
            $auth = @{
                UserKey = "ApiKey";
                PassKey = "Secret";
                UserVal = $ApiKey;
                PassVal = $Secret;
            }
        }
        'AccessToken' {
            if (-not ($Token -and $Expiration)) {
                throw [System.ArgumentException]::new("Invalid Token/Expiration Value")
            }
            $local:revcfg.Url = ($Url -as [uri]).AbsoluteURI;
            $local:revcfg.Token = $Token;
            $local:revcfg.Expiration = [datetime]$Expiration;
            if ($WebRequestArgs) {
                $local:revcfg.WebRequestArgs = $WebRequestArgs;
            }
        }
        { $_ } {
            $local:revcfg.Url = ($Url -as [uri]).AbsoluteURI;
            if ($WebRequestArgs) {
                $local:revcfg.WebRequestArgs = $WebRequestArgs;
            }
            if ($auth.UserVal -and $auth.PassVal) {
                $local:revcfg.($auth.UserKey) = $auth.UserVal;
                $local:revcfg.($auth.PassKey) = $auth.PassVal;
            } else {
                if (-not $Prompt) {
                    throw [System.Exception]::new("Missing $($auth.UserKey)/$($auth.PassKey) Parameters");
                }
                $credArgs = @{
                    Message = "Specify Rev $($auth.UserKey)/$($auth.PassKey)";
                }
                if ($auth.UserVal) {
                    $credArgs.UserName = $auth.UserVal;
                }
                $credentials = Get-Credential @credArgs;
                if (-not $credentials) {
                    throw [System.Exception]::new("Missing $($auth.UserKey)/$($auth.PassKey) Parameters");
                }
                $local:revcfg.($auth.UserKey) = $credentials.GetNetworkCredential().UserName;
                $local:revcfg.($auth.PassKey) = $credentials.GetNetworkCredential().Password;
            }
        }
    }

    # import from config will set this already
    if (-not $local:rev) {
        $local:rev = [RevClient]::new($local:revcfg);
    }

    # Add default rate limits
    $local:rev.SetRateLimit("searchVideos", 120);
    $local:rev.SetRateLimit("uploadVideo", 30);
    $local:rev.SetRateLimit("videoDetails", 2000);
    $local:rev.SetRateLimit("updateVideo", 30);
    $local:rev.SetRateLimit("auditEndpoint", 60);
    $local:rev.SetRateLimit("viewReport", 120);
    $local:rev.SetRateLimit("loginReport", 10);

    if (-not $ReturnOnly) {
        Set-RevClient $local:rev;
    }
    if ($Connect) {
        $local:rev.Connect();
    }
    return $local:rev;
}

<#
.SYNOPSIS
Authenticate Rev Client
#>
function Connect-Rev {
    [CmdletBinding(DefaultParameterSetName="Client")]
    [Alias("Connect-Rev")]
    [OutputType([RevClient])]
    param (
        [Parameter(Position=0, ParameterSetName="Config")]
        $Config,

        [Parameter(Position=0, ParameterSetName="Client", ValueFromPipeline)]
        [RevClient] $Client,

        # If set then extend the session instead of re-connecting if already connected
        [Parameter(ParameterSetName="Client")]
        [Parameter(ParameterSetName="Config")]
        [switch] $Extend,

        # If specified then don't set as default Rev for current PS Session, just return
        [Parameter(ParameterSetName="Config")]
        [switch] $ReturnOnly
    )
    process {
        switch ($PSCmdlet.ParameterSetName) {
            "Config" {
                $params = @{
                    Connect = $true;
                    Config = $Config;
                    ReturnOnly = $ReturnOnly;
                }
                return New-RevClient @params;
            }
            Default {
                if (-not $Client) {
                    $Client = Get-RevClient
                }
                if ($Extend -and $Client.IsConnected()) {
                    $Client.ExtendSession()
                } else {
                    $Client.Connect();
                }
            }
        }
    }
}

[RevClient] $script:rev = $null

<#
.SYNOPSIS
Return the default [RevClient] instance
#>
function Get-RevClient {
    [CmdletBinding()]
    [OutputType([RevClient])]
    param (
        [Parameter()]
        [switch]
        $SkipNullCheck
    )
    if ($null -eq $script:rev -and -not $SkipNullCheck) {
        throw [System.InvalidOperationException]::new("Rev Client not initialized. Call New-RevClient first or specify already-created client with the -Client parameter");
    }
    return $script:rev;
}

<#
.SYNOPSIS
Set Default Rev Client
#>
function Set-RevClient {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [RevClient] $Client
    )
    $script:rev = $Client;
}

<#
.SYNOPSIS
Load Rev Client credentials/configuration from (secure) stored xml file
#>
function Import-RevClient {
    [CmdletBinding()]
    [OutputType([RevClient])]
    param (
        [Parameter(Mandatory, Position=0)]
        [Alias("Config")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        # If specified then don't set as default Rev for current PS Session, just return
        [Parameter()]
        [switch] $ReturnOnly,

        # Auto connect once imported
        [Parameter()]
        [switch] $Connect
    )
    process {
        $local:revcfg = Import-Clixml $Path -ErrorAction Stop

        $local:rev = [RevClient]::new($local:revcfg);
        if (-not $ReturnOnly) {
            Set-RevClient $local:rev;
        }
        try {
            if ($Connect) {
                $local:rev.Connect();
            }
        } catch [RevError] {
            Write-Warning "Connect Failed $_"
        }
        return $local:rev;
    }
}

<#
.SYNOPSIS
Save Rev Client credentials/configuration to (secure) XML file
#>
function Export-RevClient {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        # If not set use default Rev for current PS Session
        [Parameter(ValueFromPipeline)]
        [RevClient] $Client = (Get-RevClient)
    )
    process {
        $Params = @{
            Path        = $Path;
            Depth       = [int32]::MaxValue - 1
            Encoding    = 'UTF8'
            InputObject = [pscustomobject]@{
                Url        = [string] $Client.Url.AbsoluteUri;
                Username   = $Client.Username;
                Password   = $Client.Password;
                ApiKey     = $Client.ApiKey;
                Secret     = $Client.Secret;
                Token      = $Client.Token;
                Expiration = $Client.Expiration;
                WebRequestArgs = $Client.WebRequestArgs;
            }
        }
        Export-Clixml @Params
    }
}

<#
.SYNOPSIS
    Make REST API call to Rev
#>
function Invoke-Rev {
    [CmdletBinding()]
    param(
        # Method - HTTP VERB
        [Parameter()]
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        # Endpoint - the API endpoint, i.e. /api/v1/zones
        [Parameter(Mandatory, Position=0)] [string] $Endpoint,
        # Body - a hash or string for body of request (or query parameters for GET requests)
        [Parameter(ValueFromPipeline)] $Body,
        # hash of additional headers for request (example = User Agent)
        [Parameter()] [hashtable] $Headers = @{},
        # additional parameters to pass to Invoke-WebRequest
        [Parameter()] [hashtable] $RequestArgs,
        # Use specified key for rate limiting requests
        [Parameter()] [string] $RateLimitKey,
        # return raw http response object isntead of body
        [Switch] $Raw,
        # show progress bar (use only for downloads)
        [Switch] $Progress,
        [RevClient] $Client = (Get-RevClient)
    )

    if (-not $Client) {
        throw "No client specified - run Connect-Rev first";
    }
    if ($RateLimitKey) {
        $Client.QueueRateLimit($RateLimitKey);
    }
    $response = $Client.Request($Method, $Endpoint, $body, $Headers, $Progress, $RequestArgs);

    if ($Raw) {
        return $response;
    }

    return $Client.DecodeResponse($response);
}

<#
.SYNOPSIS
Logout of API Session
#>
function Disconnect-Rev {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeline)]
        [RevClient] $Client = (Get-RevClient)
    )
    process {
        return $Client.Disconnect();
    }
}

<#
.SYNOPSIS
Verify current Rev authentication session is valid
#>
function Test-Rev {
    [CmdletBinding()]
    [Alias("Test-RevSession")]
    param (
        [Parameter(Position=0, ValueFromPipeline)]
        [RevClient] $Client = (Get-RevClient)
    )
    process {
        return $Client.VerifySession();
    }
}

<#
.SYNOPSIS
Set the rate limit for given rate limit key
#>
function Set-RevRateLimit {
    [CmdletBinding()]
    param (
        # The key for the rate limit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)] [string] $Key,
        # how many requests allowed per minute
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)] [int32] $PerMinute,
        # Rev Client instance to set rate limits on. If not specified use default
        [Parameter()] [RevClient] $Client = (Get-RevClient)
    )
    process {
        $Client.SetRateLimit($Key, $PerMinute);
    }
}

<#
.SYNOPSIS
Get list of configured rate limits
#>
function Get-RevRateLimit {
    [CmdletBinding()]
    param (
        # The key for the rate limit
        [Parameter(Position=0, ValueFromPipelineByPropertyName)] [string] $Key,
        # Rev Client instance to set rate limits on. If not specified use default
        [Parameter()] [RevClient] $Client = (Get-RevClient)
    )
    process {
        if ($Key) {
            $Limit = ($Client.RateLimits.$Key).Limit;
            if ($null -eq $Limit) {
                return $null;
            }
            return [pscustomobject]@{ Key = $Key; Limit = $Limit };
        }
        return $Client.RateLimits.GetEnumerator() | ForEach-Object {
            [pscustomobject] @{
                Key = $_.Name;
                Limit = $_.Value.Limit
            }
        }
    }
}

<#
.SYNOPSIS
Rate Limit a pipeline based on specified key
.EXAMPLE
Set-RevRateLimit "mycustomkey" 10
(0..20) | Wait-RevRateLimit | % { Write-Host "$(Get-Date -format 'hh:mm:ss')"; Start-Sleep -seconds 1 }

Will go through 0-10 for 10 seconds, then wait 50 seconds before continuing
#>
filter Wait-RevRateLimit ([string] $Key, [RevClient] $Client = (Get-RevClient)) {
    $Client.QueueRateLimit($Key);
    $_;
}

<#
.SYNOPSIS
Get The account id of Rev Tenant
#>
function Get-RevAccountId {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeline)]
        [RevClient] $Client = (Get-RevClient)
    )
    process {
        $Client.GetAccountID()
        # $response = $Client.Get('/');
        # if ($response -match '"account":\{"id":"(?<accountId>[a-f0-9-]{36})"') {
        #     return $Matches.accountId;
        # } else {
        #     throw "Unable to determine Account ID"
        # }
    }
}


# private cmdlet
function Get-InternalRevResultSet {
    [CmdletBinding()]
    param (
        [Parameter()] [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        [Parameter(Mandatory)] [string] $Endpoint,
        [Parameter(Mandatory)] [string] $TotalKey,
        [Parameter(Mandatory)] [string] $HitsKey,
        [Parameter()] [hashtable] $Body = @{},
        [Parameter()] [hashtable] $RequestArgs = @{},
        [Parameter()] [string] $Activity = "Searching...",
        [Parameter()] [switch] $ShowProgress,
        [Parameter()] [scriptblock] $TransformResponse,
        [Parameter()] [string] $ScrollParameterName = "scrollId",
        [Parameter()] [ValidateSet("Continue", "Ignore", "Stop")] [string] $ScrollExpireAction = "Continue",
        [Parameter()] [Alias("First")] [int32] $MaxResults = [int32]::MaxValue,
        [Parameter()] [string] $RateLimitKey,
        [Parameter()] [RevClient] $Client = (Get-RevClient)
    )
    begin {
        $params = @{};
        $params.Method = $Method;
        $params.Endpoint = $Endpoint;
        $params.Body = $Body.Clone();
        $params.Client = $Client;
        $params.RequestArgs = $RequestArgs;

        $Current = 0;
        $Total = $MaxResults;
        $IsDone = $false;
    }
    process {
        while (-not $IsDone) {
            $page = Invoke-Rev @params;

            if ($null -ne $TransformResponse) {
                $page = $TransformResponse.Invoke($page, $params.Body);
            }

            if ($page.$TotalKey -ge $Current) {
                $Total = [math]::Min($page.$TotalKey, $MaxResults);
            }

            $params.Body.$ScrollParameterName = $page.$ScrollParameterName
            if (-not $params.Body.$ScrollParameterName) {
                $IsDone = $true;
            }

            $hits = $page.$HitsKey | Select-Object -First ($Total - $Current);
            $Current += $hits.Count;
            if ($Current -ge $Total) {
                $IsDone = $true;
            }

            if ($page.StatusCode -ge 400 -and $page.StatusDescription) {
                $IsDone = $true;
            }

            if ($IsDone) {
                $Total = [math]::Max($Total, 0);
                $params.Body.$ScrollParameterName = $null;
            }
            if ($ShowProgress) {
                $pct = switch ($Current) {
                    0 { 0; break; }
                    $Total { 100; break; }
                    { $Total -eq 0 } { 50; break; }
                    default {
                        100 * $Current / $Total;
                    }
                }
                Write-Progress -Activity $Activity -PercentComplete $pct;
            }

            $hits;

            if ($page.StatusCode -ge 400 -and $page.StatusDescription) {
                switch($ScrollExpireAction) {
                    "Continue" {
                        Write-Warning "Scroll Expired: $($page.StatusCode) $($page.StatusDescription)";
                    }
                    "Stop" {
                        throw [Exception]::new("Scroll Expired: $($page.StatusCode) $($page.StatusDescription)")
                    }
                    Default {

                    }
                }
            }
        }
    }
    end {
        if ($ShowProgress) {
            Write-Progress -Activity $Activity -Completed
        }
    }
}
Add-Type -AssemblyName 'System.Net.Http'

$script:mimeTypes = @{
    ".7z" = "application/x-7z-compressed";
    ".asf" = "video/x-ms-asf";
    ".avi" = "video/x-msvideo";
    ".csv" = "text/csv";
    ".doc" = "application/msword";
    ".docx" = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    ".f4v" = "video/x-f4v";
    ".flv" = "video/x-flv";
    ".gif" = "image/gif";
    ".jpeg" = "image/jpeg";
    ".jpg" = "image/jpeg";
    ".m4a" = "audio/mp4";
    ".m4v" = "video/x-m4v";
    ".mkv" = "video/x-matroska";
    ".mov" = "video/quicktime";
    ".mp3" = "audio/mpeg";
    ".mp4" = "video/mp4";
    ".mpg" = "video/mpeg";
    ".pdf" = "application/pdf";
    ".png" = "image/png";
    ".ppt" = "application/vnd.ms-powerpoint";
    ".pptx" = "application/vnd.openxmlformats-officedocument.presentationml.presentation";
    ".rar" = "application/x-rar-compressed";
    ".srt" = "application/x-subrip";
    ".svg" = "image/svg+xml";
    ".swf" = "application/x-shockwave-flash";
    ".ts" = "video/mp2t";
    ".txt" = "text/plain";
    ".wmv" = "video/x-ms-wmv";
    ".xls" = "application/vnd.ms-excel";
    ".xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    ".zip" = "application/zip";
    ".mks" = "video/x-matroska";
    ".mts" = "model/vnd.mts";
    ".vtt" = "text/vtt";
    ".wma" = "audio/x-ms-wma";
};
$script:mimeExtensions = @{};

function Get-InternalRevMimeInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Filename,
        [Parameter()] [string] $Extension,
        [Parameter()] [string] $ContentType,
        [Parameter()] [string] $DefaultExtension = ".mp4"
    )

    $wasChanged = $false;
    $Filename = [System.IO.Path]::GetFileName($Filename);

    if (-not $Extension) {
        $Extension = [System.IO.Path]::GetExtension($Filename);
    }

    # quick check
    if ($Extension -and $script:mimeExtensions.$Extension -eq $ContentType) {
        # no check needed, all good
    }
    else {
        if ($ContentType) {
            # lasy initialize
            if ($script:mimeExtensions.Keys.Count -eq 0) {
                $script:mimeTypes.GetEnumerator() | ForEach-Object {
                    $script:mimeExtensions.($_.Value) = $_.Key
                }
            }

            $expected = $script:mimeExtensions.$ContentType;
            if ($expected) {
                if ($Extension -and $Extension -ne $expected) {
                    $wasChanged = $true;
                }
                $Extension = $expected;
            } else {
                $wasChanged = $true
                $ContentType = $null
            }
        }
        if (-not $ContentType) {
            if ($Extension -and $script:mimeTypes.$Extension) {
                $ContentType = $script:mimeTypes.$Extension;
            } else {
                $wasChanged = $true;
                $Extension = $DefaultExtension;
                $ContentType = $script:mimeTypes.$Extension;
            }
        }
    }

    return [pscustomobject]@{
        Filename = [System.IO.Path]::ChangeExtension($Filename, $Extension)
        Extension = $Extension
        ContentType = $ContentType
        WasChanged = $wasChanged
    };
}

function New-RevFormDataField {
<#
.SYNOPSIS
    Create a Multipart Form Data Field
.DESCRIPTION
    Format a payload for adding to a multipart form-data payload for upload to Rev
#>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        # Name of form field
        [Parameter(Mandatory, ParameterSetName="Field", Position=0)] [string] $Name,
        # Value of payload. Should be a [fileinfo] object returned from Get-Item or string data
        [Parameter(Mandatory, ParameterSetName="Field", Position=1)] [object] $Value,

        # Optionally specify the content type of the data
        [Parameter(ParameterSetName="Field")] [string] $ContentType,

        # Optionally specify the filename for the field's disposition header
        [Parameter(ParameterSetName="Field")] [string] $FileName,

        # If already formatted as http content then just pass through unchanged
        [Parameter(Mandatory, ParameterSetName="Content", Position=0)] [System.Net.Http.HttpContent] $Content
    )

    # special case, passthrough
    if ($PSCmdlet.ParameterSetName -eq "Content") {
        return [pscustomobject]@{
            Content = $Content;
            ContentType = $ContentType;
            FileName = $FileName;
        };
    }

    [System.Net.Http.HttpContent] $result = $null;
    $disposition = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data");
    $disposition.Name = "`"$Name`"";

    if ($Value -is [System.IO.FileInfo]) {
        if (-not $FileName) {
            $FileName = $Value.Name;
        }

        # ensure valid allowed content type
        $mimeInfo = Get-InternalRevMimeInfo -Filename $FileName -ContentType $ContentType
        $ContentType = $mimeInfo.ContentType
        $FileName = $mimeInfo.Filename

        $stream = [System.IO.FileStream]::new($Value.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read);
        $result = [System.Net.Http.StreamContent]::new($stream);
    } else {
        $result = [System.Net.Http.StringContent]::new($Value);
    }
    $result.Headers.ContentDisposition = $disposition;
    if ($ContentType) {
        $result.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new($contentType);
    }
    if ($FileName) {
        # make safe
        $FileName = $FileName -replace '[^\w_. -]','';
        $result.Headers.ContentDisposition.FileName = "`"$FileName`"";
    }

    [pscustomobject]@{
        Content = $result;
        ContentType = $ContentType;
        FileName = $FileName;
    }
}

function New-RevFormData
{
<#
.SYNOPSIS
    Create a Multipart Form Data payload
.DESCRIPTION
    Videos - Uploads closed caption files for a video for hearing impaired viewers. Only .srt or .vtt files are supported.

#>
    [CmdletBinding()]
    [OutputType([System.Net.Http.MultipartFormDataContent])]
    param (
        # Specify fields to add. They should be in the format @{ Name="Name of Form field"; Value="string or [fileinfo] object from Get-FileInfo"; ContentType="optional content-type specification"; FileName="optional filename for content-disposition" }
        [Parameter(Position=0, ValueFromPipeline)]
        [ValidateScript({
            $valid = @($_) | where-object {
                $_ -is [System.Net.Http.HttpContent] -or ($_.Name -and $_.Value) -or ($_.Content -is [System.Net.Http.HttpContent])
            };
            return $valid.Count -gt 0 -and $valid.Count -eq $_.Count;
        })]
        [object[]] $Fields
    )
    process {
        $Form = [System.Net.Http.MultipartFormDataContent]::new();

        foreach ($Field in $Fields) {
            if ($Field -is [System.Net.Http.HttpContent]) {
                $Form.Add($Field);
            } elseif ($Field.Content -is [System.Net.Http.HttpContent]) {
                $Form.Add($Field.Content);
            } else {
                $content = New-RevFormDataField @Field;
                $Form.Add($content.Content);
            }
        }
        Write-Output $form -NoEnumerate
    }
}



function Set-RevVideo
{
<#
.SYNOPSIS
    Replace Video
.DESCRIPTION
    Videos - This endpoint replaces a given video with one that you upload.

.LINK
    https://revdocs.vbrick.com/reference/replacevideo
#>
    [CmdletBinding()]
    param(
        # Id of video to replace
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string[]]
        $VideoId,

        # Specifies a path video file.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FileName")]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        # content type of file. If the mimetype does not match the passed filename extension
        [Parameter()]
        [string[]] $ContentType,

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )
    process {
        New-RevVideo -VideoID $VideoId -Path $Path -ContentType $ContentType
    }
}
function Search-RevVideos
{
<#
.SYNOPSIS
    Search Videos
.DESCRIPTION
    Videos - This endpoint mimics the search control in the Rev portal. All results are based on the authenticated user making the API request.
.OUTPUTS
    @{
        [object[]] videos,
        [int] totalVideos,
        [string] scrollId,
        [int] statusCode,
        [string] statusDescription,
    }
.LINK
    https://revdocs.vbrick.com/reference/searchvideo
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Search string
        [Parameter(Position=0)]
        [Alias("Query")]
        [RevMetadataAttribute()]
        [string]
        $Q,

        # List of Category Ids to specify searching videos only in those categories.<p>Example: <code>Categories=a0e5cbf6-95cb-46e7-8600-4c07bc31f80b, b1f5cbf6-95cb-46e7-8600-4c07bc31g9pc.</code></p><p> Pass a blank entry to return uncategorized videos. Example: <code>Categories=</code></p>
        [Parameter()]
        [Alias("CategoryIds")]
        [RevMetadataAttribute()]
        [string]
        $Categories,

        # Include the first name and last name of the uploader.  Note that partial matches may be returned. Example: uploaders="john doe" is going to retrieve all videos uploaded by the user with first name and last name = "john doe". To return an exact result you must use the uploaderIds query string.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Uploaders,

        # Uploader GUIDs to get specific videos uploaded by these users. Example: <code>UploaderIds=abc, xyz</code>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $UploaderIds,

        # Include the first name and last name of the owner.  Note that partial matches may be returned. Example: owners="john doe" is going to retrieve all videos owned by the user with first name and last name = "john doe". To return an exact result you must use the ownerIds query string.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Owners,

        # Owner GUIDs to get specific videos owner by these users. Example: <code>ownerIds=abc, xyz</code>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $OwnerIds,

        # Status of video (Active/Inactive)
        [Parameter()]
        [ValidateSet("active", "inactive")]
        [RevMetadataAttribute()]
        [string]
        $Status,

        # Valid video published date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $FromPublishedDate,

        # Valid video published date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $ToPublishedDate,

        # Valid video upload date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $FromUploadDate,

        # Valid video upload date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $ToUploadDate,

        # Valid video modified date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $FromModifiedDate,

        # Valid video modified date
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $ToModifiedDate,

        # Only return live videos
        [Parameter()] [switch] $LiveOnly,

        # Only return vod videos
        [Parameter()] [switch] $VodOnly,

        # If true, search is performed as exact match on title, tags, categories, and uploader.
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $ExactMatch,

        # If provided, query results are sorted based on field(title, whenUploaded, uploaderName, duration, _score). Default is set to title.
        [Parameter()]
        [ValidateSet("title", "whenUploaded", "uploaderName", "duration", "_score", "viewCount", "averageRating", "whenModified", "whenPublished", "commentCount")]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # If provided, query results are sorted on ascending or descending order(asc, desc)
        [Parameter()]
        [ValidateSet("asc", "desc")]
        [RevMetadataAttribute()]
        [string]
        $SortDirection,

        # If provided, the query string fetches the unlisted setting of the video. This can be listed only, unlisted only, or to return all. Default setting fetches the listed only videos.
        [Parameter()]
        [ValidateSet("listed", "unlisted", "all")]
        [RevMetadataAttribute()]
        [string]
        $Unlisted,

        # If provided, the query results are fetched on the provided searchField only. If the exactMatch flag is also set along with searchField, then the results are fetched for an exact match on the provided searchField only.
        [Parameter()]
        [ValidateSet("title", "tags", "categories", "uploader")]
        [RevMetadataAttribute()]
        [string]
        $SearchField,

        # If true, search results include inner hits from transcription files. Default is false.
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $IncludeTranscriptSnippets,

        # Show recommended videos for the specified Username. Videos returned are based on the user’s last 10 viewed videos. Must be Account Admin or Media Admin to use this query. Sort order must be _score. User must exist.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RecommendedFor,

        # If true, only HLS videos are returned.
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $HasHls,

        # Number of access entities to get per page. (By default count is 1000)
        [Parameter()]
        [RevMetadataAttribute("Body/Count")]
        [int32]
        $PageSize = 100,

        [Parameter()]
        [Alias("First")]
        [RevMetadataAttribute(IsPassthru)]
        [int32]
        $MaxResults,

        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ShowProgress,

        [Parameter()]
        [ValidateSet("Continue", "Ignore", "Stop")]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $ScrollExpireAction,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    if ($LiveOnly -and -not $VodOnly) {
        $params.Body.Type = 'live';
    } elseif ($VodOnly) {
        $params.Body.Type = 'vod';
    }

    Write-Verbose "Searching for videos with parameters $(($params | ConvertTo-Json -Compress -ErrorAction Ignore))"

    Get-InternalRevResultSet -Method Get -Endpoint "/api/v2/videos/search" -TotalKey "totalVideos" -HitsKey "videos" -Activity "Searching Videos..." @params -Client $Client -RateLimitKey "searchVideos";
}

function New-RevVideo {
    <#
.SYNOPSIS
Upload a video to Rev
#>
    [CmdletBinding(DefaultParameterSetName="Upload")]
    [OutputType([string])]
    param (
        # Specifies a path video file.
        [Parameter(Mandatory, Position=0, ParameterSetName="Upload", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, Position=1, ParameterSetName="Replace", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FileName")] [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, Position=0, ParameterSetName="Replace")] [string] $VideoID,

        # content type of file. The mimetype MUST match the passed filename extension
        [Parameter(ParameterSetName="Upload")][Parameter(ParameterSetName="Replace")]
        [string] $ContentType,


        # Specify metadata as an object
        [Parameter(ParameterSetName="Upload")] [pscustomobject] $Metadata,

        # Only used for passing upload metadata through pipeline
        [Parameter(ParameterSetName="Upload", ValueFromPipeline)] [hashtable] $PipelineMetadata = @{},


        # Video title. If not specified, API uses uploaded filename as the title.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $Title,

        # Description is set to null if not specified
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $Description,

        # Rev username identifies the user the video is attached to. If not specified, or the username does not exist in Rev, the upload is rejected.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $Uploader,

        # By default, video owner is the user uploader unless otherwise assigned. The video owner automatically has view and edit rights and can include the Media Viewer role. <p>If a video owner is assigned, the uploader does <em>not</em> retain view/edit rights unless granted in video access controls.</p> @{ [string] userId; [string] username; [string] email }
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [object]
        $Owner,

        # set the owner by id
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute("Owner/Id")]
        [string] $OwnerId,

        # set the owner by username
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute("Owner/Username")]
        [string] $OwnerUsername,

        # set the owner by email
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute("Owner/Email")]
        [string] $OwnerEmail,

        # An array of category names attached to the video. If no categories are specified, or the category does not exist in Rev, no categories are attached. The request is also rejected if you do not have contribute rights to a restricted category and you attempt to add/edit or otherwise modify it. <p>This array is provided through the video metadata file and obtained through the <a href=/reference/getcategories>Get Categories</a> endpoint.</p><p>You should only use categories OR categoryIds but not both.</p>
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [Alias("CategoryNames")]
        [RevMetadataAttribute(IsPassthru)]
        [string[]]
        $Categories,

        # An array of category Ids attached to the video. If the category does not exist in Rev, the upload fails. The request is also rejected if you do not have contribute rights to a restricted category and you attempt to add/edit or otherwise modify it. <p>This array is provided through the video metadata file and obtained through the <a href=/reference/getcategories>Get Categories</a> endpoint.</p><p>You should only use categories OR categoryIds but not both.</p>
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string[]]
        $CategoryIds,

        # An array of strings tagged to the video
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string[]]
        $Tags,

        # Default=false. Status of the video after it is uploaded.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $IsActive,

        # Default=true. This enables or disables ratings for the uploaded video.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $EnableRatings,

        # Default=false. This enables or disables downloading of the video from Rev.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $EnableDownloads,

        # Default=true. This enables or disables ability to comment on uploaded video.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $EnableComments,

        # Default=false. This enables or disables the ability to allow external application access for a video.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $EnableExternalApplicationAccess,

        # Default=false. This enables or disables the ability to allow external url access for a video.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [bool]
        $EnableExternalViewersAccess,

        # Retain the total views count from an outside system as an optional param.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [int64]
        $LegacyViewCount,

        # This sets access control for the video. Keep in mind that Access Controls are strictly dictated by <a href=/docs/roles-and-permissions>Roles and Permissions</a> This is an enum and can have the following values: <code>Public/AllUsers/Private</code>. <p>A value of <strong>AllUsers</strong> is equal to all internal/authenticated users. A value of <strong>Private</strong> allows access to those Users, Groups, and Channels <em>explicitly</em> identified.</p><p> Be aware that you can assign multiple Users, Groups, and Channels in the <strong>accessControlEntites</strong> parameter in addition to the <strong>AllUser</strong> or <strong>Public</strong> settings. If no value is set, the default is <strong>Private</strong>.</p> <p>In the case of an incorrect value, the call is rejected with an HTTP 400 error.</p><p><strong>Note:</strong> If <strong>Channels</strong> is set at the videoAccessControl, it is translated to <strong>Private</strong> and a Channel <em>must</em> be specified in the accessControlEntities. If a Channel is included in the accessControlEntities, then the canEdit parameter is ignored.</p>
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [ValidateSet("Public", "AllUsers", "Private")]
        [string]
        $VideoAccessControl,

        # This provides explicit rights to a <strong>User/Group/Channel</strong> along with editing rights <strong>(CanEdit)</strong> to a video. If any value is invalid, it is rejected while valid values are still associated with the video. @{ [string] id; [string] name; [string] type; [bool] canEdit }
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [object[]]
        $AccessControlEntities,

        # A password for Public Video Access Control. Use this field when the videoAccessControl is set to Public only. Otherwise, this field is ignored.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $Password,

        # An array of customFields used in video/webcast endpoints. If the customField does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds). The <a href=/reference/custommetadata>Get Custom Fields</a> endpoint retrieves a list of custom fields.<p>Note: If a custom field is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p> @{ [string] id; [string] value; [string] name }
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [object[]]
        $CustomFields,

        # Specifies where the video originated. Possible values are 'REV', 'WEBEX', 'API', 'VIDEO CONFERENCE', 'WebexLiveStream', 'LiveEnrichment'
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [ValidateSet('REV', 'WEBEX', 'API', 'VIDEO CONFERENCE', 'WebexLiveStream', 'LiveEnrichment')]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $SourceType,

        # Default=false. This enables the video to bypass transcoding.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $DoNotTranscode,

        # Default=false. This enables the 360 video flag.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $Is360,

        # Default=false. This enables the unlisted video flag.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $Unlisted,

        # Date the video is published. If IsActive is set to true and PublishDate is not specified, a default value is set (i.e. Today's date). This should be specified based on the date in the the timezone of the current account.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $PublishDate,

        # An array of user Ids tagged in the video
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [string[]]
        $UserTags,

        #Default=false. Displays viewer information over the video for playback on the web.
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ViewerIdEnabled,

        # LINKED URL ONLY - specify is a linked URL instead of file upload
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [switch] $IsLinkedUrl,

        # LINKED URL ONLY - specify linked URL is a live url
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [switch] $IsLive,

        # LINKED URL ONLY - specify linked URL is a HLS / Adaptive Bitrate file
        [Parameter(ParameterSetName="Upload", ValueFromPipelineByPropertyName)]
        [switch] $IsHLS,

        # input filesize at which script will warn that upload may get buffered into memory and cause performance issues
        [Parameter()] [int64] $FilesizeWarningThresholdMB = 500,

        [Parameter()] [RevClient] $Client = (Get-RevClient)
    )
    process {
        $isReplace = $PSCmdlet.ParameterSetName -eq "Replace";

        # parse metadta
        $payload = $null;
        if (-not $isReplace) {
            # somewhat convoluted way to
            # default to metadata passed in through pipeline (as hashtable)
            # override with data passed in through -Metadata arg
            # override with individual specified parameters
            $payload = $PipelineMetadata.Clone();

            # Parses arguments with the RevMetadataAttribute set, which populates body based on input
            [void] [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation, $Metadata, $payload)

            # uploader is required, set to default if possible
            if (-not $payload.Uploader -and $Client.Username) {
                $payload.Uploader = $Client.Username
            }

            # make sure publish date is in correct format
            if (-not [string]::IsNullOrWhiteSpace($payload.PublishDate) -and ($payload.PublishDate -notmatch '\d{4}-\d{2}-\d{2}')) {
                Write-Verbose "Publish Date must be in the format YYYY-MM-DD - converting using current timezone";
                $payload.PublishDate = ([datetime]).ToString('yyyy-MM-dd');
            }
        }

        # rate limit uploads (after initial arg parsing)
        $Client.QueueRateLimit("uploadVideo");

        # Special handling for linked URL, which doesn't need to get file info
        if ($IsLinkedUrl) {
            $payload.LinkedUrl = @{
                Url = $Path;
                EncodingType = if ($IsHLS) { "HLS" } else { "H264" };
                Type = if ($IsLive) { "Live" } else { "Vod" };
                IsMulticast = $false;
            };
            $resp = $Client.Post("/api/v2/videos", $payload);
            return $resp.videoId;
        }

        # Validate and add video file
        $Info = Get-Item ($Path | Select-Object -first 1);
        $MetaInfo = Get-InternalRevMimeInfo -Filename $Info.Name -Extension $Info.Extension -ContentType $ContentType

        if ($MetaInfo.WasChanged) {
            Write-Verbose "Changed contenttype/extension of uploaded video to match $($Info.Name) -> $($MetaInfo.Filename) $($ContentType) -> $($MetaInfo.ContentType)"
        }

        # warn if filesize is big and old powershell
        $isModern = $global:PSVersionTable.PSVersion.Major -gt 5;
        if (-not $isModern) {
            if ($Info.Length -gt ($FilesizeWarningThresholdMB * 1mb)) {
                Write-Warning "WARNING: Rev Video Upload may buffer video contents into RAM before uploading. This can cause performance issues or out of memory errors."
            }
        }

        # create form
        $formFields = [System.Collections.Generic.List[object]]@(
            @{
                Name = "VideoFile";
                Value = $Info;
                ContentType = $MetaInfo.ContentType;
                FileName = $MetaInfo.Filename;
            }
        );

        # add upload metadata json
        if (-not $isReplace) {
            $formFields.Add(@{
                Name = "Video";
                Value = $payload | ConvertTo-Json -Depth 10 -Compress;
                ContentType = "application/json";
            });
        }
        $Form = New-RevFormData -Fields $formFields;
        
        try {
            if ($isReplace) {
                $Client.Put("/api/uploads/videos/$VideoID", $Form);
                return $VideoID;
            }

            $resp = $Client.Post("/api/uploads/videos", $Form);
            return $resp.videoId;
        } finally {
            $Form.Dispose();
        }
    }
}

function Wait-RevTranscode
{
<#
.SYNOPSIS
    Wait for a video to transcode
.DESCRIPTION
    This helper queries the status of a video and waits until processing is complete. If you pass multiple IDs then the function will wait until all are completed before moving on, unless -Race is specified
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] status,
        [bool] isProcessing,
        [float] overallProgress,
        [bool] isActive,
        [string] uploadedBy,
        [datetime] whenUploaded,
    }
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to retrieve status state
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [Alias("VideoIds")]
        [string[]]
        $VideoId,

        # How long to wait for completion before continuing. Default is wait 1 hour
        [Parameter()]
        [int64]
        $TimeoutSec = 60000,

        # how long to wait before checks of video status. Default is every 15 seconds
        [Parameter()]
        [int64]
        $PollIntervalSec = 15,

        # if true then return as soon as one of the specified video Ids finishes, rather than all
        [Parameter()]
        [switch]
        $Race,

        # if true then show progress bar
        [Parameter()]
        [switch]
        $Progress,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )
    begin {
        $idsToProcess = [System.Collections.Generic.List[string]]::new();
    }
    process {
        # grab all ids to process all at once in end block
        if ($_) {
            $idsToProcess.Add($_);
        }
    }
    end {
        $timeoutDate = (get-date) + [timespan]::FromSeconds($TimeoutSec);

        # prepare stats object for tracking progress
        $stats = @{};
        $numVideos = ($idsToProcess | Measure-Object).Count;
        $isMultipleProgress = $Progress -and $numVideos -gt 1;

        $idsToProcess | foreach-object { $i = 1 } {
            $videoData = @{
                progressArgs = @{
                    Id = $i++;
                }
                shouldComplete = $false;
                isComplete = $false;
                status = @{}
            }
            if ($isMultipleProgress) {
                $videoData.progressArgs.ParentId = 0;
            }
            $stats.$_ = $videoData;
        }


        if ($isMultipleProgress) {
            Write-Progress -Id 0 -Activity "Processing..." -PercentComplete 0
        }

        # helper function to write status to host
        function writeProgress($videoData, $setComplete = $false) {
            if (-not $Progress) {
                return;
            }
            $progressArgs = $videoData.progressArgs;
            if ($videoData.isComplete) {
                if ($videoData.shouldComplete) {
                    $videoData.shouldComplete = $false;
                    Write-Progress @progressArgs -Completed
                }
                return;
            }
            $videoData.shouldComplete = $true;
            $s = $videoData.status;
            if (-not $progressArgs.Activity) {
                $progressArgs.Activity = "{0} {1}" -f $s.videoId,$s.title;
            }
            $pct = [math]::Min($s.overallProgress * 100, 1);

            # ready state while still processing
            $statusMessage = $s.status;
            if ($s.status -eq "Ready" -and $s.isProcessing) {
                $statusMessage = "Processing"
                $pct = 50 + (0.5 * $pct);
            }

            Write-Progress @progressArgs -Status $statusMessage -PercentComplete $pct;
        }

        # loop until timeout
        try {
            while ((Get-Date) -lt $timeoutDate) {
                $completedVids = $idsToProcess | where-object {
                    $currentId = $_;
                    $videoData = $stats.$currentId;
                    if ($videoData.isComplete) {
                        return $true;
                    }

                    try {
                        $status = Get-RevVideoStatus $currentId;
                        $videoData.status = $status;

                        if ($status.overallProgress -eq 1 -and -not $status.isProcessing -or $status.status -eq 'ProcessingFailed') {
                            $videoData.isComplete = $true;
                        }
                    } catch {
                        $ex = $_.Exception;
                        # if video not found then skip
                        if ($ex.StatusCode -eq 404) {
                            $videoData.status = @{
                                videoId = $currentId;
                                status = 'Deleted';
                                isProcessing = $false;
                                overallProgress = 1;
                            }
                            $videoData.isComplete = $true;
                        } else {
                            throw $_
                        }
                    }

                    writeProgress $videoData;
                    return $videoData.isComplete;
                }

                if ($isMultipleProgress) {
                    Write-Progress -Id 0 -Activity "Processing..." -Status "$($completedVids.Count)/$numVideos" -PercentComplete (100 * $completedVids.Count / $numVideos)
                }

                # all videos finished
                if ($completedVids.Count -eq $numVideos) {
                    break;
                } elseif ($completedVids.Count -ge 1 -and $Race) {
                    # single video finished, break early
                    break;
                }

                Start-Sleep -Seconds $PollIntervalSec;
            }
            return $idsToProcess | foreach-object { $stats.$_.status };
        }
        finally {
            $stats.Values | foreach-object {
                # clear out progress bar
                if ($_.shouldComplete -and -not $_.isComplete) {
                    $_.isComplete = $true;
                    writeProgress $_
                }
            }
            if ($isMultipleProgress) {
                Write-Progress -Id 0 -Activity "Processing Complete" -Completed
            }
        }
    }
}

function Get-RevVideoDetails
{
<#
.SYNOPSIS
    Get Video Details/Metadata
.DESCRIPTION
    Videos - Retrieves video details and metadata of a given video.
.OUTPUTS
    @{
        [string] id,
        [string] title,
        [string] description,
        [string] thumbnailKey,
        [string] thumbnailUrl,
        [object] linkedUrl,
        [string[]] categories,
        [string[]] tags,
        [bool] isActive,
        [string] approvalStatus,
        [bool] enableRatings,
        [bool] enableDownloads,
        [bool] enableComments,
        [string] password, # This is a shared password for public guests. This field exists only in the response if the user has EDIT permission to the video.
        [string] status,
        [bool] canEdit,
        [string] videoAccessControl,
        [object[]] accessControlEntities, # This provides explicit rights to a <strong>User/Group/Channel</strong> along with editing rights <strong>(CanEdit)</strong> to a video. If any value is invalid, it is rejected while valid values are still associated with the video.
        [object[]] customFields, # An array of customFields attached to the video. If the customField does not exist in Rev or invalid values found for picklist, the upload fails. If values are not provided for a picklist and/or text field, they are not set for the video but the upload proceeds. The <a href=/reference/custommetadata>Get Custom Fields</a> endpoint retrieves a list of custom fields.<p>Note: If custom field is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the upload is rejected. Picklist types must be valid.</p>
        [string] expirationDate,
        [string] expirationAction, # This sets action when video expires. This is an enum and can have the following values: Delete/Inactivate.
        [string] uploadedBy,
        [string] whenUploaded,
        [string] lastViewed,
        [string] htmlDescription,
        [string] publishDate,
        [object[]] categoryPaths,
        [string] sourceType,
        [bool] is360,
        [bool] unlisted,
        [int] totalViews,
        [float] overallProgress,
        [bool] isProcessing,
        [object[]] userTags,
        [object] upLoader, # Video uploader.
        [object] owner, # Video owner.
        [bool] hasAudioOnly,
        [float] avgRating,
        [int] ratingsCount,
        [int] commentCount,
        [datetime] whenModified,
        [float] duration,
        [object[]] instances,
        [object] videoConference,
        [object] expiration,
        [bool] closedCaptionsEnabled,
        [object] approval,
        [bool] transcodeFailed,
        [string] source,
        [object] chapters,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideosdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the video to get details
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string[]]
        $VideoId,

        # If set only return the status (which has less information) rather than full details
        [Parameter()] [switch] $StatusOnly,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )
    process {
        $endpoint = if ($StatusOnly) {
            "/api/v2/videos/$VideoID/status"
        } else {
            "/api/v2/videos/$VideoID/details"
        }
        Invoke-Rev -Method Get -Endpoint $endpoint -RequestArgs $RequestArgs -Client $Client -RateLimitKey "videoDetails"
    }
}


function Edit-RevVideoDetails
{
<#
.SYNOPSIS
    Patch Video Details/Metadata
.DESCRIPTION
    Videos - Partially edits the metadata details of a video. You do not need to provide the fields that are not changing.<p>Operations supported: add,remove,copy,replace,test,move.</p><p>Keep in mind that Access Controls are strictly dictated by <a href=/docs/roles-and-permissions>Roles and Permissions.</a></p><p>Please refer to http://jsonpatch.com/ for the format of the request body.</p><strong>Examples:</strong><p>using categories: [{'op': 'add', 'path': '/Categories/0', 'value': '03846100-96ac-4628-bbe3-b23a0df1081d' }]</p><p>using accessControlEntities: [{ 'op': 'replace', 'path': '/accessControlEntities/0/CanEdit', 'value': 'false' }]</p><p>Non-Editable fields [Id,ApprovalStatus,UploadedBy,WhenUploaded,LastViewed] are ignored.</p></p>

.LINK
    https://revdocs.vbrick.com/reference/editvideopatch
#>
    [CmdletBinding()]
    param(
        # Id of the video to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Refer to http://jsonpatch.com/ for the format of the request body. (ex: [{ op="replace", path="/Title", value="new value" }])
        [Parameter(Mandatory)]
        [RevMetadataAttribute(PayloadName="Body", IsPassthru)]
        [object[]]
        $Operations,
        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Patch -Endpoint "/api/v2/videos/$VideoId" @params -Client $Client -RateLimitKey "updateVideo"
}


function Remove-RevVideo
{
<#
.SYNOPSIS
    Delete Video
.DESCRIPTION
    Videos - This endpoint deletes a video asset from Rev. This includes videos stored on a DME.

.LINK
    https://revdocs.vbrick.com/reference/deletevideo
#>
    [CmdletBinding()]
    param(
        # Id of video to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/videos/$VideoId" -RequestArgs $RequestArgs -Client $Client -RateLimitKey "updateVideo"
}


function Edit-RevVideoMigration
{
<#
.SYNOPSIS
    Migrate Video
.DESCRIPTION
    Videos - This endpoint is used during migrations to Rev from another system. During video import, you may want to retain the original uploader, upload date, and publish date. As a result, this API allows you to set only these fields to do so.<p>You can also use this endpoint to edit only these fields for previously added videos in the system if needed. This avoids the requirement of setting all fields when using other video editing endpoints.</p>

.LINK
    https://revdocs.vbrick.com/reference/migratevideo
#>
    [CmdletBinding()]
    param(
        # Id of video to migrate
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # The uploader is set to this user
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $UserName,

        # The video ownership is set to this user. Only the owner.userId is used for lookup @{ [string] userId; [string] username; [string] email }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $Owner,

        # Taken from the userName that uploaded the video
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $UploadedBy,

        # Upload date is set to this value. Example: <code>2019-02-26 15:53:12</code>
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $WhenUploaded,

        # By default, the publishDate is set to the current date the video is set to Active status. You can also set the publishDate to a date in the future to make the video Active at that time. If the video is already Active, the publishDate can be set to a date in the past. <p>Note: Format must be YYYY-MM-DD to avoid generating an error.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $PublishDate,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId/migration" @params -Client $Client -RateLimitKey "updateVideo"
}


function Get-RevVideoFile
{
<#
.SYNOPSIS
    Download Video
.DESCRIPTION
    Videos - This endpoint downloads a video asset from Rev. The original file upload is downloaded.

.LINK
    https://revdocs.vbrick.com/reference/downloadvideo
#>
    [CmdletBinding()]
    param(
        # Id of video to download
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Specifies the output file for which this cmdlet saves the response body. Enter a path and file name. If you omit the path, the default is the current location.
        [Parameter()]
        [RevMetadataAttribute(PayloadName = "RequestArgs/OutFile")]
        [string] $OutFile,

        # Indicates that the cmdlet returns the results, in addition to writing them to a file. This parameter is valid only when the OutFile parameter is also used in the command.
        [Parameter()]
        [RevMetadataAttribute(PayloadName = "RequestArgs/PassThru")]
        [switch] $PassThru,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ShowProgress,

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    # if ($OutFile -and -not $PassThru) {
    #     $Client.Download("/api/v2/videos/$VideoId/download", $OutFile, @{}, $ShowProgress, $RequestArgs);
    # }

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/download" @params -Client $Client
}

function Get-RevThumbnailFile
{
<#
.SYNOPSIS
    Download Video Thumbnail
.DESCRIPTION
    Videos - Downloads the video thumbnail image file.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/downloadvideothumbnailfile
#>
    [CmdletBinding(DefaultParameterSetName="VideoId")]
    [OutputType([object])]

    param(
        # ThumbnailUrl returned in video search results and video details
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName="VideoId")]
        [string]
        $VideoId,

        # ThumbnailUrl returned in video search results and video details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName, ParameterSetName="ThumbnailUrl")]
        [string]
        $ThumbnailUrl,

        # Specifies the output file for which this cmdlet saves the response body. Enter a path and file name. If you omit the path, the default is the current location.
        [Parameter(ParameterSetName="VideoId")]
        [Parameter(ParameterSetName="ThumbnailUrl")]
        [RevMetadataAttribute(PayloadName = "RequestArgs/OutFile")]
        [string] $OutFile,

        # Indicates that the cmdlet returns the results, in addition to writing them to a file. This parameter is valid only when the OutFile parameter is also used in the command.
        [Parameter(ParameterSetName="VideoId")]
        [Parameter(ParameterSetName="ThumbnailUrl")]
        [RevMetadataAttribute(PayloadName = "RequestArgs/PassThru")]
        [switch] $PassThru,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter(ParameterSetName="VideoId")]
        [Parameter(ParameterSetName="ThumbnailUrl")]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter(ParameterSetName="VideoId")]
        [Parameter(ParameterSetName="ThumbnailUrl")]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    $Endpoint = if ($VideoId) { "/api/v2/videos/$VideoId/thumbnail" } else { $ThumbnailUrl }

    Invoke-Rev -Method Get -Endpoint $Endpoint @params -Client $Client
}

function Get-RevVideoTranscriptionFiles
{
<#
.SYNOPSIS
    Get Video Transcription Files
.DESCRIPTION
    Videos - Get transcription files of a video.
.OUTPUTS
    @{
        [object[]] transcriptionFiles,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideotranscriptionfiles
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get the transcription files
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/transcription-files" -RequestArgs $RequestArgs -Client $Client
}


function Get-RevVideoTranscriptionFile
{
<#
.SYNOPSIS
    Download Video Transcription File
.DESCRIPTION
    Videos - Downloads a video transcription file.

.LINK
    https://revdocs.vbrick.com/reference/downloadvideotranscriptionfile
#>
    [CmdletBinding()]
    param(
        # Id of video to download
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $VideoId,

        # Language Id of the video transcription to download
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $LanguageId,

        # Specifies the output file for which this cmdlet saves the response body. Enter a path and file name. If you omit the path, the default is the current location.
        [Parameter()]
        [RevMetadataAttribute(PayloadName = "RequestArgs/OutFile")]
        [string] $OutFile,

        # Indicates that the cmdlet returns the results, in addition to writing them to a file. This parameter is valid only when the OutFile parameter is also used in the command.
        [Parameter()]
        [RevMetadataAttribute(PayloadName = "RequestArgs/PassThru")]
        [switch] $PassThru,
        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/transcription-files/$LanguageId" @params -Client $Client
}


function Get-RevRoles
{
<#
.SYNOPSIS
    Get Roles
.DESCRIPTION
    Administration - Get list of all roles.
.OUTPUTS
    @{
        [string] id,
        [string] name,
        [string] description,
    }
.LINK
    https://revdocs.vbrick.com/reference/getroles
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/users/roles" -RequestArgs $RequestArgs -Client $Client
}


function New-RevUser
{
<#
.SYNOPSIS
    Add User
.DESCRIPTION
    Users & Groups - Add a new user and assign roles and groups as needed.
.OUTPUTS
    @{
        [string] userId,
    }
.LINK
    https://revdocs.vbrick.com/reference/createuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Used to login to Rev. Not case sensitive but must be unique.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $UserName,

        # First name. Not required.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $FirstName,

        # Last name. Required.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $LastName,

        # Must be a vaild email format. Required.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Email,

        # Allows assignment of a title to the user
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Title,

        #
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $PhoneNumber,

        # Preferred language. Two digit language code. For example, en for English. View <a href=/docs/supported-languages>Supported Languages</a> for codes.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Language,

        # Group Ids to assign the user to
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $GroupIds,

        # Role Ids to assign the user to. Default=Media Viewer.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $RoleIds,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Post -Endpoint "/api/v2/users" @params -Client $Client
}


function Get-RevUser
{
<#
.SYNOPSIS
    Get User By ID
.DESCRIPTION
    Users & Groups - Get user details for a given user Id, username or email.
.OUTPUTS
    @{
        [string] userId,
        [string] username,
        [string] firstname,
        [string] lastname,
        [string] email,
        [string] title,
        [string] phone,
        [string] language,
        [object[]] roles,
        [object[]] groups,
        [object[]] channels,
        [string] profileImageUri,
    }
.LINK
    https://revdocs.vbrick.com/reference/getuser
#>
    [CmdletBinding(DefaultParameterSetName="UserId")]
    [OutputType([object])]

    param(
        # Id of the user to get details
        [Parameter(Mandatory, Position=0, ParameterSetName="UserId", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string[]]
        $UserId,

        # Get user by username
        [Parameter(Mandatory, ParameterSetName="Username", ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string[]]
        $Username,

        # Get user by email address
        [Parameter(Mandatory, ParameterSetName="Email", ValueFromPipelineByPropertyName)]
        [string[]]
        $Email,

        # Get details of current logged-in user
        [Parameter(Mandatory, ParameterSetName="CurrentUser")]
        [switch]
        $Me,

        # by default this cmdlet will return $null for missing users (404 response). Use this flag to throw an error instead
        [Parameter(ParameterSetName="UserId")]
        [Parameter(ParameterSetName="Username")]
        [Parameter(ParameterSetName="Email")]
        [switch]
        $ThrowIfMissing,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter(ParameterSetName="UserId")]
        [Parameter(ParameterSetName="Username")]
        [Parameter(ParameterSetName="Email")]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter(ParameterSetName="UserId")]
        [Parameter(ParameterSetName="Username")]
        [Parameter(ParameterSetName="Email")]
        [RevClient]
        $Client = (Get-RevClient)
    )
    begin {

    }
    process {
        $request = @{
            Method = "Get";
            Endpoint = "/api/v2/users/$userId";
            Body = @{};
        };
        switch ($PsCmdlet.ParameterSetName) {
            "UserId" { }
            "Username" {
                $request.Endpoint = "/api/v2/users/$Username";
                $request.Body.type = "username";
                break;
            }
            "Email" {
                $request.Endpoint = "/api/v2/users/$Email";
                $request.Body.type = "email";
                break;
            }
            "Me" {
                $request.Endpoint = "/api/v2/users/me";
            }
        }

        try {
            Invoke-Rev -Method Get @request -RequestArgs $RequestArgs -Client $Client
        } catch [RevError] {
            if (-not $ThrowIfMissing -and ([int]$_.StatusCode) -in @(401, 403, 404)) {
                return $null;
            }
            throw $_;
        }
    }
}


function Edit-RevUser
{
<#
.SYNOPSIS
    Patch User
.DESCRIPTION
    Partially edits the details of a user. You do not need to provide the fields that you are not changing.

.LINK
    https://revdocs.vbrick.com/reference/edituserdetails
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $UserId,

        # Refer to http://jsonpatch.com/ for the format of the request body. (ex: [{ op="replace", path="/Title", value="new value" }])
        [Parameter(Mandatory)]
        [RevMetadataAttribute(PayloadName="Body", IsPassthru)]
        [object[]]
        $Operations,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Patch -Endpoint "/api/v2/users/$UserId" @params -Client $Client
}


function Search-RevUsersGroupsChannels
{
<#
.SYNOPSIS
    Search Users, Groups and Channels
.DESCRIPTION
    Users & Groups - Searches the specified access entity (user/group/channel) in Rev for a specified query string. If no entity is specified, then all are searched.
.OUTPUTS
    @{
        [object[]] accessEntities,
        [int] totalEntities,
        [string] scrollId,
        [int] statusCode,
        [string] statusDescription,
    }
.LINK
    https://revdocs.vbrick.com/reference/searchaccessentity
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Search string. If no search string is provided, treated as a blank search. Example: If the group parameter is specified with no search string, the first 1000 groups are returned (count parameter default).
        [Parameter(Position=0)]
        [Alias("Query")]
        [RevMetadataAttribute()]
        [string]
        $Q,

        # Type of access entity to search (user/group). One or more may be provided. If no type is provided, all entities are included.
        [Parameter()]
        [ValidateSet("User", "Group", "Channel")]
        [RevMetadataAttribute()]
        [string]
        $Type,

        # Only return users
        [Parameter()] [switch] $Users,

        # Only return groups
        [Parameter()] [switch] $Groups,

        # Only return channels
        [Parameter()] [switch] $Channels,

        # Number of access entities to get per page. (By default count is 1000)
        [Parameter()]
        [RevMetadataAttribute("Body/Count")]
        [int32]
        $PageSize = 100,

        [Parameter()]
        [Alias("First")]
        [RevMetadataAttribute(IsPassthru)]
        [int32]
        $MaxResults,

        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ShowProgress,

        [Parameter()]
        [ValidateSet("Continue", "Ignore", "Stop")]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $ScrollExpireAction,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    if (-not $params.Body.Type) {
        if ($Users -and -not $Groups) {
            $params.Body.Type = 'User'
        } elseif ($Groups) {
            $params.Body.Type = 'Group'
        } elseif ($Channels) {
            $params.Body.Type = 'Channel'
        }
    }

    Get-InternalRevResultSet -Method Get -Endpoint "/api/v2/search/access-entity" -TotalKey "totalEntities" -HitsKey "accessEntities" -Activity "Searching Access Entities..." @params -Client $Client -RateLimitKey "searchAccessEntities";
}


function Search-RevUsers
{
<#
.SYNOPSIS
    Search Users
.DESCRIPTION
    Users - Searches the specified access entity in Rev for a specified query string.
.OUTPUTS
    @{
        [object[]] accessEntities,
        [int] totalEntities,
        [string] scrollId,
        [int] statusCode,
        [string] statusDescription,
    }
.LINK
    https://revdocs.vbrick.com/reference/searchaccessentity
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Search string. If no search string is provided, treated as a blank search. Example: If the group parameter is specified with no search string, the first 1000 groups are returned (count parameter default).
        [Parameter(Position=0)] [Alias("Query")] [RevMetadataAttribute()] [string] $Q,

        # Number of access entities to get per page. (By default count is 1000)
        [Parameter()] [RevMetadataAttribute("Body/Count")] [int32] $PageSize = 100,

        [Parameter()] [Alias("First")] [RevMetadataAttribute(IsPassthru)] [int32] $MaxResults,
        [Parameter()] [RevMetadataAttribute(IsPassthru)] [switch] $ShowProgress,
        [Parameter()] [ValidateSet("Continue", "Ignore", "Stop")] [RevMetadataAttribute(IsPassthru)] [string] $ScrollExpireAction,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()] [RevMetadataAttribute(IsPassthru)] [hashtable] $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()] [RevClient] $Client = (Get-RevClient)
    )

    Search-RevUsersGroupsChannels @PSBoundParameters -Type User;
}


function New-RevWebcast
{
<#
.SYNOPSIS
    Create Webcast
.DESCRIPTION
    Webcasts - Creates a new webcast.
.OUTPUTS
    @{
        [string] eventId,
    }
.LINK
    https://revdocs.vbrick.com/reference/createevent
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Webcast title
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Title,

        # Extended description for your webcast that displays as part of the Webcast Landing page before the event starts and as part of the Event Details section after broadcasting begins. The description also becomes part of the invitation text to attendees.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Description,

        # Must match this format: <code>YYYY-DD-MMT00:00:00Z</code>
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $StartDate,

        # Must match this format: <code>YYYY-DD-MMT00:00:00Z</code>
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $EndDate,

        # GUID for the presentation profile. Only required when Presentation Profile selected as a videoSourceType.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $PresentationProfileId,

        # Array of user Ids for the Webcast admins. If no Ids are passed, eventAdminEmails are checked.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string[]]
        $EventAdminIds,

        # DEPRECATED
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $EventAdminEmails,

        # Array of users who are Webex Hosts and Co-hosts (In Vbrick, Event Admins). @{ [string] email; [string] firstName; [string] lastName; [bool] isPrimary }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $EventAdmins,

        # Default=false. Enabled if Presentation Profile used as a video source and if you want the event to begin broadcasting at the appointed start time on its own without an Event Host to start it.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $AutomatedWebcast,

        # Default=false. Specifies if closed captions are enabled when Presentation Profile used as a video source.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $ClosedCaptionsEnabled,

        # Default=false. Select to enable polls in the webcast.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $PollsEnabled,

        # Default=true. Select to enable chat in the webcast.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $ChatEnabled,

        # Default=false, Select to enable Q&A feature in the webcast
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $QuestionAndAnswerEnabled,

        # Ids for users on the access control list. Only used with Private events.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $UserIds,

        # Ids for groups on the access control list. Only used with Private events.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $GroupIds,

        # Ids for users that will serve as webcast moderators.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $ModeratorIds,

        # Array of users who are moderators. This is equivalent to Panelists in Webex.<p>Note: For Partners, auto creation of hosts/moderators occurs if user is not in Rev and new fields are used. This is only available for Account Admins. Email and lastName are required for user auto creation.</p> @{ [string] email; [string] firstName; [string] lastName }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $Moderators,

        # Used only if isPublic is set to true.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Password,

        # Sets access control for the webcast. This is an enum and can have the following values: Public/TrustedPublic/AllUsers/Private.<p>Note: This parameter is strictly controlled by <a href=/docs/roles-and-permissions>Roles and Permissions</a>. TrustedPublic is only applicable for Partners.</p>
        [Parameter(Mandatory)]
        [ValidateSet("Public", "TrustedPublic", "AllUsers", "Private")]
        [RevMetadataAttribute()]
        [string]
        $AccessControl,

        # SIP address if recording a video conference as the source. Only required if SipAddress is the videoSourceType.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VcSipAddress,

        # This is an enum and can have the following values: [PresentationProfile, Rtmp, SipAddress, WebexTeam, WebexLiveStream, Zoom, Vod, WebrtcSinglePresenter]. WebrtcSinglePresenter represents <i>Webcam and Screenshare</i> source in rev UI <p>This field is required to create/edit WebexLiveStream event.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoSourceType,

        # Default=true, Specifies if the RTMP based webcast should use RTMPS or RTMP. True will set to RTMPS and false will set to RTMP.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsSecureRtmp,

        # Scheduled event type used for integrations, default value is Rev.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $WebcastType,

        # Used if recording a Webex Team meeting as the video source. @{ [string] roomId; [string] name }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $WebexTeam,

        # Used if recording a Zoom meeting as the video source. @{ [string] meetingId; [string] meetingPassword }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $Zoom,

        # This is an enum and can have the following values: [IDENTIFIED, SELFSELECT, ANONYMOUS]
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $QuestionOption,

        # Specifies if a presentation attached to the webcast is downloadable
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $PresentationFileDownloadAllowed,

        # Array of categoryIds to assign the event to. If you use categoryIds and they do not exist/are incorrect, the request is rejected. The request is also rejected if you do not have contribute rights to a restricted/secure category and you attempt to add/edit or otherwise modify it.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Categories,

        # Array of tag Ids to assign the event to. Can assign to multiple tags.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Tags,

        # Specifies if the webcast is unlisted. If it is unlisted, prevents it from being displayed to all Media Contributors, Media Viewers, and Event Hosts that did not create the Webcast. Further, resulting videos recorded are not visible or searchable in the Rev UI.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Unlisted,

        # Number between 0 and 1000000. Allows you to estimate the number of people that will attend so technical resources can be adjusted as needed.
        [Parameter()]
        [RevMetadataAttribute()]
        [int]
        $EstimatedAttendees,

        # May not exceed 120. Period of time before a Webcast starts when attendees are permitted to join the event.
        [Parameter()]
        [RevMetadataAttribute()]
        [int]
        $LobbyTimeMinutes,

        # Use if creating a pre-production event to set designated pre-production attendees and duration. @{ [string] duration; [string[]] userIds; [string[]] groupIds }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $PreProduction,

        # Creates a custom event-friendly URL for a Webcast that makes it easier to remember for attendees. May be reused for multiple events as long as they do not conflict in date and time.<p>This Url is returned in the parameter shortcutNameUrl when the <a href=/reference/getevent>Get Webcast Details</a> endpoint is untilized.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ShorcutName,

        # Use to set the Id of a video that is linked/associated to a Webcast that has finished recording.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $LinkedVideoId,

        # When true, the video in LinkedVideoId is automatically linked to a Webcast after it has concluded.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $AutoAssociateVod,

        # When true, users that access the Webcast are automatically redirected to the video set in LinkedVideoId. If false, they are directed the Webcast Landing page instead.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $RedirectVod,

        # If accessControl is set to Public, you can add custom fields to the Webcast to collect more data from public attendees. Use Ids returned in the <a href=/reference/createwebcastregistrationfield>Add Webcast Registration Fields</a> endpoint to specify the fields to use.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $RegistrationFieldIds,

        # An array of customFields used in video/webcast endpoints. If the customField does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds). The <a href=/reference/custommetadata>Get Custom Fields</a> endpoint retrieves a list of custom fields.<p>Note: If a custom field is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p> @{ [string] id; [string] value; [string] name }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CustomFields,

        # For enabling live subtitles on the webcast. Enabling subtitles requires Rev IQ license hours and the Rev IQ User role. @{ [string] sourceLanguage; [string[]] translationLanguages }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $LiveSubtitles,

        # Determines how a broadcasting Webcast behaves when a viewer joins. Enabled, it plays immediately and is muted. Disabled, there is a button to start the Webcast and it is not muted.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Autoplay,

        # Default=false. If false, the webcast is automatically recorded. <p>Note: When false, attempted use of the <a href=/reference/startrecordingevent>Start Webcast Recording</a> endpoint generates an error.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $DisableAutoRecording,

        # Default=false. When true, the Webcast URL is hidden on the Event Details page that is displayed to attendees while it is broadcasting.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $HideShareUrl,

        # Id of the user who is set as the uploader for the event recording.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RecordingUploaderUserId,

        # Used if recordingUploaderUserId is not provided. Email of the user who is set as the uploader for the event recording.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RecordingUploaderUserEmail,

        # Default=false. If true, registrants will automatically receive an email with the details they need to join the event. The <strong>allowPreRegistration</strong> attribute must be set to true before emailToPreRegistrants can be set to true.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $EmailToPreRegistrants,

        # Video Id. Only required when 'Vod' selected as a videoSourceType. Video must be Hls.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VodId,

        # Internal user Id. Only required when 'WebrtcSinglePresenter' selected as a videoSourceType.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $PresenterId,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Post -Endpoint "/api/v2/scheduled-events" @params -Client $Client
}


function Get-RevWebcast
{
<#
.SYNOPSIS
    Get Webcast Details
.DESCRIPTION
    Webcasts - Get webcast settings and metadata details for a specified webcast.
.OUTPUTS
    @{
        [string] eventId,
        [string] title,
        [string] description,
        [string] htmlDescription,
        [datetime] startDate,
        [datetime] endDate,
        [string] presentationProfileId,
        [string[]] eventAdminIds,
        [string] primaryHostId,
        [bool] automatedWebcast,
        [bool] closedCaptionsEnabled,
        [bool] pollsEnabled,
        [bool] chatEnabled,
        [string] questionOption, # This is an enum and can have the following values: IDENTIFIED/SELFSELECT/ANONYMOUS
        [bool] questionAndAnswerEnabled,
        [string[]] userIds,
        [string[]] groupIds,
        [string[]] moderatorIds,
        [string] password,
        [string] accessControl, # This sets access control for the video. This is an enum and can have the following values: Public/TrustedPublic/AllUsers/Private. TrustedPublic option is only available to Partners at this time.
        [string] eventUrl,
        [string] icsFileUrl,
        [string] vcSipAddress,
        [string] vcMicrosoftTeamsMeetingUrl,
        [string] videoSourceType, # This is an enum and can have the following values: PresentationProfile, Rtmp, SipAddress, WebexTeam, WebexLiveStream, Zoom, Vod, WebrtcSinglePresenter. WebrtcSinglePresenter represents <i>Webcam and Screenshare</i> source in rev UI.  This field is required to create/edit WebexLiveStream event.
        [object] rtmp, # Used if recording a rtmp stream as the video source.
        [string] webcastType, # Scheduled event type used for integrations, default value is Rev.
        [object] webexTeam, # Used if recording a Webex Team meeting as the video source.
        [object] zoom, # Used if recording a Zoom meeting as the video source.
        [object[]] backgroundImages,
        [object[]] categories,
        [string[]] tags,
        [bool] unlisted,
        [int] estimatedAttendees,
        [int] lobbyTimeMinutes,
        [object] webcastPreProduction, # Use if creating a pre-production event to set designated pre-production attendees and duration.
        [string] shortcutName,
        [string] shortcutNameUrl,
        [string] linkedVideoId,
        [bool] autoAssociateVod,
        [bool] redirectVod,
        [string] recordingUploaderUserId,
        [bool] presentationFileDownloadAllowed,
        [object[]] registrationFields,
        [object[]] customFields, # An array of customFields attached to the video. If the customField does not exist in Rev or invalid values found for picklist, the upload fails. If values are not provided for a picklist and/or text field, they are not set for the video but the upload proceeds. The <a href=/reference/custommetadata>Get Custom Fields</a> endpoint retrieves a list of custom fields.<p>Note: If custom field is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the upload is rejected. Picklist types must be valid.</p>
        [object] liveSubtitles, # Live Subtitles properties of the webcast.
        [bool] autoplay,
        [bool] disableAutoRecording, # Default=false. If false, the webcast is automatically recorded. <p>Note: When false, attempted use of the <a href=/reference/startrecordingevent>Start Webcast Recording</a> endpoint generates an error.
        [bool] hideShareUrl,
        [bool] enableCustomBranding,
        [string] vodId,
        [string] presenterId,
        [object] brandingSettings,
    }
.LINK
    https://revdocs.vbrick.com/reference/getevent
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to get details
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string[]]
        $EventId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )
    process {
        Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId" -RequestArgs $RequestArgs -Client $Client
    }


}


function Search-RevWebcasts
{
<#
.SYNOPSIS
    Search Webcasts By Custom Field or Date Range
.DESCRIPTION
    Webcasts - This endpoint searches all events for a given date range or custom field query.
.OUTPUTS
    [object[]] # events
.LINK
    https://revdocs.vbrick.com/reference/searchwebcasts
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Search parameter to use to match those events that are set to start on or after the date specified. Value should be less than or equal to endDate. If not specified, it assumes a value of endDate - 365 days.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $StartDate,

        # Search parameter to use to match those events that are set to start on or before the date specified. Value should be greater than or equal to startDate. If not specified, it assumes a value of the current date.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $EndDate,

        # Name of the field in the event that will be used to sort the dataset in the response. Default is 'Title'
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # Sort direction of the dataset. Values supported: 'asc' and 'desc'. Default is 'asc'.
        [Parameter()]
        [ValidateSet("asc","desc")]
        [RevMetadataAttribute()]
        [string]
        $SortDirection,

        # Number of records in the dataset to return per search request. Default is 100, minimum is 50 and maximum is 500.
        [Parameter()]
        [Alias("Size")]
        [RevMetadataAttribute("Size")]
        [int32]
        $PageSize,

        # List of custom fields to use when searching for events. All of the fields provided are concatenated as AND in the search request. The value to the property 'Value' is required. @{ [string] id; [string] value; [string] name }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CustomFields,

        [Parameter()]
        [Alias("First")]
        [RevMetadataAttribute(IsPassthru)]
        [int32]
        $MaxResults,

        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ShowProgress,

        [Parameter()]
        [ValidateSet("Continue", "Ignore", "Stop")]
        [RevMetadataAttribute(IsPassthru)]
        [string]
        $ScrollExpireAction,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Get-InternalRevResultSet -Method Post -Endpoint "/api/v2/search/scheduled-events" -TotalKey "total" -HitsKey "events" -Activity "Searching Webcasts..." @params -Client $Client -RateLimitKey "searchWebcasts";
}


function Edit-RevWebcast
{
<#
.SYNOPSIS
    Patch Webcast
.DESCRIPTION
    Webcasts - Partially edits the details of a webcast. You do not need to provide the fields that you are not changing.<p>Webcast <strong>status</strong> determines which fields are modifiable and when. <p>If the webcast pre-production or main event is <strong>in progress</strong>, only fields available for inline editing may be patched/edited.</p><p>If the webcast main event has been run once, only fields available <strong>after</strong> the webcast has ended are available for editing. That includes <em>all</em> fields with the <em>exception</em> of start/end dates, lobbyTimeMinutes, preProduction, duration, userIds, and groupIds.</p><p>If the webcast <strong>end time</strong> has passed and is <strong>Completed</strong>, only edits to linkedVideoId and redirectVod are allowed.</p><p>Event Admins can be removed using their email addresses as path pointer for the fields 'EventAdminEmails' and 'EventAdmins', provided that all of the Event Admins associated with the webcast have email addresses. This is also applicable for the field 'Moderators'.</p><p>Keep in mind that Access Controls are strictly dictated by <a href=/docs/roles-and-permissions>Roles and Permissions.</a></p><p>Please refer to http://jsonpatch.com/ for the format of the request body.</p><strong>Examples:</strong><p>using EventAdmins: [{ 'op': 'remove', 'path': '/EventAdmins/Email', 'value': 'x1@test.com' }]</p><p>using EventAdminEmails: [{ 'op': 'remove', 'path': '/EventAdminEmails', 'value': 'x2@test.com' }]</p><p>using Moderators: [{ 'op': 'remove', 'path': '/Moderators/Email', 'value': 'x3@test.com' }]</p>

.LINK
    https://revdocs.vbrick.com/reference/patchwebcast
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Refer to http://jsonpatch.com/ for the format of the request body. (ex: [{ op="replace", path="/Title", value="new value" }])
        [Parameter(Mandatory)]
        [RevMetadataAttribute(PayloadName="Body", IsPassthru)]
        [object[]]
        $Operations,
        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

        # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    Invoke-Rev -Method Patch -Endpoint "/api/v2/scheduled-events/$EventId" @params -Client $Client
}

function Get-RevWebcastStatus
{
<#
.SYNOPSIS
    Get Webcast Status
.DESCRIPTION
    Webcasts - Get current webcast status for a given webcast.
.OUTPUTS
    @{
        [string] eventTitle,
        [datetime] startDate,
        [datetime] endDate,
        [string] eventStatus,
        [string] slideUrl,
        [bool] isPreProduction,
        [string] sbmlResponse,
        [string] reason,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to get status
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/status" -RequestArgs $RequestArgs -Client $Client
}


Export-ModuleMember -Function @("Connect-Rev", "Disconnect-Rev", "Test-Rev", "Invoke-Rev", "New-RevClient", "Get-RevClient", "Set-RevClient", "Import-RevClient", "Export-RevClient", "Get-RevAccountId", "New-RevVideo", "Set-RevVideo", "Remove-RevVideo", "Search-RevVideos", "Wait-RevTranscode", "Edit-RevVideoDetails", "Edit-RevVideoMigration", "Get-RevVideoDetails", "Get-RevVideoFile", "Get-RevVideoTranscriptionFile", "Get-RevVideoTranscriptionFiles", "Get-RevThumbnailFile", "Get-RevWebcast", "Search-RevWebcasts", "New-RevWebcast", "Edit-RevWebcast", "Get-RevWebcastStatus", "Get-RevRoles", "Get-RevUser", "New-RevUser", "Search-RevUsers", "Search-RevUsersGroupsChannels", "New-RevFormData", "New-RevFormDataField", "Get-InternalRevResultSet", "Set-RevRateLimit", "Get-RevRateLimit", "Wait-RevRateLimit")
} | Import-Module -Global -Force
