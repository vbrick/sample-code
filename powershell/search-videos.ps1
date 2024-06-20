<#
.SYNOPSIS
    Wrapper around logging into Rev and getting the video search results in a pipeline
.NOTES
  DISCLAIMER!
  This sample code is not an officially supported Vbrick product, and is provided AS-IS.
.EXAMPLE
    ./search-videos.ps1 -Url "https://my.rev.url" -ApiKey $env:REV_APIKEY -Secret $env:REV_SECRET -Details -MaxResults 10
#>

[CmdletBinding()]
param (
    # Rev URL
    [Parameter()] [uri] $Url,
    # API Key
    [Parameter()] [string] $ApiKey,
    # API Secret - passed as [securestring] or plain text
    [Parameter()] $Secret,
    # Get Video Details, not just search results
    [Parameter()] [switch] $Details,
    [Parameter()] [switch] $Examples,
    # Limit the total number of results returned, good for testing
    [Parameter()] [int64] $MaxResults = 10 # [int32]::MaxValue

)

begin {
    ### Initialization - loading script logic ###
    if ($PsVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Script may not work with Powershell 5. Consider using Powershell 7"
    }
    function GetScriptDirectory {
        if ($PSScriptRoot) {
            return $PSScriptRoot;
        }
        try { 
            $Invocation = (Get-Variable MyInvocation -Scope 1).Value
            Split-Path $Invocation.MyCommand.Path
        } catch { 
            (Get-Item -Path ".\" -Verbose).FullName
        }
    }

    # Load the rev-client.ps1 module
    # Could also run at command prompt as . .\rev-client.ps1
    . (Join-Path (GetScriptDirectory) "rev-client.ps1")

    ### Initialize Client Library ###

    Write-Progress -Activity "Vbrick Video Search" -Status "Connecting..." -Id 0;

    # Create new client. Is set as global for all Verb-RevX commandlets
    New-RevClient -Url $Url -ApiKey $ApiKey -Secret $Secret | Out-Null

    # Authenticate with API. Will throw error on login failure
    Connect-Rev

    ### OPTIONAL - update rate limiting. This is not usually necessary

    # Actual limit is 120/minute, but limit is at account level not user level
    Set-RevRateLimit -Key "searchVideos" -PerMinute 60
    # Actual limit is 2000/minute, but limit is at account level not user level, so best practice is to reduce for background tasks
    Set-RevRateLimit -Key "videoDetails" -PerMinute 500

    if (-not (Test-Rev)) {
        Write-Warning "Client not connected - should have thrown error"
    }
}
process {
    ### Query the Video Search API ###

    Write-Progress -Activity "Vbrick Video Search" -Status "Getting Search Results";
    # Configure Search parameters, see API Docs for options
    $SearchArgs = @{
        # Don't include "unlisted" (hidden) videos
        Unlisted = "listed";
        # Only Active videos (non-draft/published videos)
        Status = "active";
        # Get most recent videos first
        SortField = "whenModified";
        SortDirection = "desc";

        # PS-ONLY: Limit search results to a maximum number (useful for testing)
        MaxResults = $MaxResults;

        # PS-ONLY: Show PS progress bar
        ShowProgress = $true;
    }

    ### Enrich Search Results With Video Details ###
    if ($Details) {
        Write-Host "Getting Details for every video in search results" -ForegroundColor Magenta
        # The Search results API has a timeout of ~ 5 minutes, so best practice is to
        # first retrieve all search results, before passing through a pipeline that may cause delays
        $searchHits = Search-RevVideos @SearchArgs;

        Write-Progress -Activity "Vbrick Video Search" -Status "Getting Video Details";
        $i = 0; $n = $searchHits.Count;
        $searchHits | 
        ForEach-Object {
                Write-Progress -Activity "Vbrick Video Search" -Status "Getting Video Details" -PercentComplete (100 * $i++ / $n);
                $hit = $_;
                $VideoId = $hit.id;
                $details = Get-RevVideoDetails -VideoId $VideoId
                [pscustomobject]@{
                    VideoId = $VideoId;
                    Title = $hit.title;
                    ThumbnailUrl = $hit.thumbnailUrl;
                    AccessControl = $details.videoAccessControl;
                    WhenUploaded = $details.whenUploaded;
                    Duration = $details.duration;
                    SearchHit = $hit;
                    Details = $details;
                }
            }
    } else {
        Write-Host "Paging through Video Search Results" -ForegroundColor Magenta
        Search-RevVideos @SearchArgs | Tee-Object -Variable 'searchHits';
    }


    ### Demonstrate use of additional APIs
    if ($Examples) {
        Write-Host "Other Example API Calls:" -ForegroundColor Magenta

        # select random video from results
        $sampleVideo = $searchHits | Get-Random;
        $videoId = $sampleVideo.id;

        Write-Host "Getting details for $videoId" -ForegroundColor Magenta;

        $details = $videoId | Get-RevVideoDetails;
        # $details = Get-RevVideoDetails $videoId

        $details | Select-Object -ExcludeProperty instances,approval,expiration,upLoader,audioTracks | ConvertTo-Json

        Write-Host "Share Link to video (rather than embed url):`n" -ForegroundColor Magenta
        $revUrl = (Get-RevClient).Url
        $shareLink = [uri]::new($revUrl, "/sharevideo/$videoId")
        $shareLink.ToString();

        Write-Host "Video Owner Details:" -ForegroundColor Magenta
        $user = Get-RevUser -Username $sampleVideo.owner.username;
        $user | Select-Object firstname,lastname,email,channels

        Write-Host "`nDownloading preview image" -ForegroundColor Magenta;
        Get-RevThumbnailFile -VideoId $videoId -OutFile "$videoId.jpg";
        Get-Item "$videoId.jpg"
    } else {
        Write-Host "Done. To test more example API calls try running with -Details and/or -Examples flags"
    }
}

end {
    Write-Progress -Activity "Vbrick Video Search" -Completed;
}