# Simple example script of logging into Rev API and making video-related queries
# DISCLAIMER! This sample code is not an officially supported Vbrick product, and is provided AS-IS.

$revUrl = "https://my.rev.url"
$apiKey = "my-api-key"
$secret = "my-secret"

function login() {
    $requestBody = @{
        apiKey = $apiKey;
        secret = $secret;
    };
    $requestBodyAsText = $requestBody | ConvertTo-Json -Compress;
	$resp = Invoke-RestMethod
        -Method Post
        -Uri "$revUrl/api/v2/authenticate" `
        -Body $requestBodyAsText `
        -ContentType "application/json";

    Write-Host "Session expires $(Get-Date $resp.expiration)";
    return $resp.token;
}

function getSearchResultsPage([string] $accessToken, [hashtable]$query = @{}) {
    $resp = Invoke-RestMethod `
        -Method Get `
        -Uri "$revUrl/api/v2/videos/search" `
        -Body $query `
        -Headers @{ Authorization = "Vbrick $accessToken" }

    return [pscustomobject]@{
        Total = $resp.totalVideos;
        Videos = $resp.videos;
        IsFinished = $resp.videos.Count -eq 0 -or -not $resp.scrollId;
        ScrollId = $resp.scrollId;
    }
}

function getDetails($accessToken, $VideoId) {
    $resp = Invoke-RestMethod `
        -Method Get `
        -Uri "$revUrl/api/v2/videos/$VideoID/details" `
        -Headers @{ Authorization = "Vbrick $accessToken" }
    return $resp;
}

function downloadThumbnail($accessToken, $VideoId, $OutputPath) {
    Invoke-RestMethod `
        -Method Get `
        -Uri "$revUrl/api/v2/videos/$VideoID/thumbnail" `
        -Headers @{ Authorization = "Vbrick $accessToken" } `
        -OutFile $OutputPath
}

function getUserInfo($accessToken, $Username) {
    Invoke-RestMethod `
        -Method Get `
        -Uri "$revUrl/api/v2/users/$Username" `
        -Body @{ type="username"} `
        -Headers @{ Authorization = "Vbrick $accessToken" }
}


function searchVideos() {
    [CmdletBinding()]
    param (
        [Parameter()] [string] $accessToken,
        [Parameter()] [int64] $pageSize = 50,
        [Parameter()] [int64] $maxPages = [int64]::MaxValue

    )
    process {
        $query = @{
            count = $pageSize;
            status="Active";
            unlisted = "listed";
            sortField = "whenModified";
            sortDirection = "desc";
        };
        
        for ($i = 0; $i -lt $maxPages; $i++) {
            # make api request and parse
            $page = getSearchResultsPage $accessToken $query;

            # output videos to pipeline
            $page.Videos;

            # add scrollId to get next page of requests
            if ($page.ScrollId) {
                $query.scrollId = $page.ScrollId;
            }
            if ($page.IsFinished) {
                # no more results, done
                break;
            }
        }
    }
}

Write-Host "Logging In";
$accessToken = login;

Write-Host "First page of videos:"
$searchHits = searchVideos $accessToken -maxPages 1;
$searchHits | Select-Object id,title,playbackUrl,viewCount,whenUploaded | Format-Table;

# select random video from results
$sampleVideo = $searchHits | Get-Random;
$videoId = $sampleVideo.id;

Write-Host "Getting details for $videoId";

$details = getDetails $accessToken $videoId;
$details | Select -ExcludeProperty instances,approval,expiration,upLoader,audioTracks | ConvertTo-Json

Write-Host "Share Link to video (rather than embed url):`n"
$shareLink = [uri]::new($revUrl, "/sharevideo/$videoId")
$shareLink.ToString();

Write-Host "Video Owner Details:"
$user = getUserInfo $accessToken $sampleVideo.owner.username;
$user | Select-Object firstname,lastname,email

Write-Host "`nWriting preview image to $videoId.jpg";
downloadThumbnail $accessToken $videoId "$videoId.jpg"

