<#
.SYNOPSIS
    VBrick Rev Client - Additional Cmdlets
.DESCRIPTION
    VBrick Rev Client
    Built 2024-10-07
    DISCLAIMER:
        This script is not an officially supported Vbrick product, and is provided AS-IS.

    This script is intended to be imported before running scripts that call the included cmdlets.

    It includes additional API wrapper cmdlets beyond the main ones provided in ./rev-client.ps1

    To get a list of the included CmdLets run this command (after loading script):
    
    get-command -Name "*-Rev*" | get-help | select Name,Synopsis

    
.NOTES
    While this library *should* work in Powershell v5, version 7 is recommended
.LINK
    https://revdocs.vbrick.com/reference/getting-started
.EXAMPLE
    . .\rev-client.ps1
    . .\rev-client-additional-cmdlets.ps1

    New-RevClient -Connect -Url "https://my.rev.url" -ApiKey "User API Key" -Secret "API Secret"
    Get-RevUser -Me

    This example will load this script file, create a new connection to Rev and get the details of the authenticated user
#>


function Search-RevGroups
{
<#
.SYNOPSIS
    Search Groups
.DESCRIPTION
    Groups - Searches the specified access entity in Rev for a specified query string.
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

    Search-RevUsersGroupsChannels @PSBoundParameters -Type Group;
}


function Search-RevChannels
{
<#
.SYNOPSIS
    Search Channels
.DESCRIPTION
    Channels - Searches the specified access entity in Rev for a specified query string.
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
        # Search string. If no search string is provided, treated as a blank search. Example: If the group parameter is specified with no search string, the first 1000 Channels are returned (count parameter default).
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

    Search-RevUsersGroupsChannels @PSBoundParameters -Type Channel;
}


function Get-RevCategories
{
<#
.SYNOPSIS
    Get Categories
.DESCRIPTION
    Administration - Get list of all categories based on query parameters. If no query paramter is passed, all categories are returned.
.OUTPUTS
    @{
        [object[]] categories,
    }
.LINK
    https://revdocs.vbrick.com/reference/getcategories
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # All child categories of given parentCategoryId are returned. To return top level categories only, set parentCategoryId as null or do not send parentCategoryId in the request.
        [Parameter()]
        [string]
        $ParentCategoryId,

        # If false, then return categories only at one level. If true or not provided, then return all the nested categories.
        [Parameter()]
        [bool]
        $IncludeAllDescendants = $true,

        # If enabled then return categories only at one level. This is switch version of the IncludeAllDescendants API parameter, and takes precedence if specified
        [Parameter()]
        [switch]
        $ExcludeDescendents,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $body = @{};
    if ($ParentCategoryId) { $body.parentCategoryId = $ParentCategoryId; }
    if ($ExcludeDescendents) {
        $body.includeAllDescendants = $false;
    } elseif ($null -ne $IncludeAllDescendants) {
        $body.includeAllDescendants = $IncludeAllDescendants;
    }

    Invoke-Rev -Method Get -Endpoint "/api/v2/categories" -Body $body -RequestArgs $RequestArgs -Client $Client | Select-Object -expand "categories"
}

function Update-RevWebcastRegistrationField
{
<#
.SYNOPSIS
    Update Webcast Registration Field
.DESCRIPTION
    Administration - Edit webcast registration fields used in Public webcasts.

.LINK
    https://revdocs.vbrick.com/reference/editwebcastregistrationfield
#>
    [CmdletBinding()]
    param(
        # Name of the custom registration field is displayed to users
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Type of field. Can be <code>Text</code> or <code>Select</code>.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $FieldType,

        # Default=false. Specifies whether the registrant is required to complete the field when registering for the event.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Required,

        # Field values when FieldType=<code>picklist</code>.  Required if FieldType=<code>picklist</code>.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Options,

        # Default=false. Specifies if the field is included in each public Webcast that is created.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IncludeInAllWebcasts,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/accounts/webcast-registration-fields" @params -Client $Client
}

function Remove-RevZone
{
<#
.SYNOPSIS
    Delete Zone
.DESCRIPTION
    Administration - Delete a zone.

.LINK
    https://revdocs.vbrick.com/reference/deletezone
#>
    [CmdletBinding()]
    param(
        # Id of zone to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/zones/$Id" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevWebcastRegistrationField
{
<#
.SYNOPSIS
    Delete Webcast Registration Field
.DESCRIPTION
    Administration - Delete a webcast registration field.

.LINK
    https://revdocs.vbrick.com/reference/deletewebcastregistrationfield
#>
    [CmdletBinding()]
    param(
        # Id of the field to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $FieldId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/accounts/webcast-registration-fields/$FieldId" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevJWTPublicKey
{
<#
.SYNOPSIS
    Delete JWT Public Key
.DESCRIPTION
    Administration - Deletes a JWT public key if it is no longer valid or has been rotated out. This API is only available for partner accounts.

.LINK
    https://revdocs.vbrick.com/reference/deletejwtpublickey
#>
    [CmdletBinding()]
    param(
        # Key Id of the key to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $Kid,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/jwt-public-keys/{kid}" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevCategory
{
<#
.SYNOPSIS
    Delete Category
.DESCRIPTION
    Administration - Delete a category.

.LINK
    https://revdocs.vbrick.com/reference/deletecategory
#>
    [CmdletBinding()]
    param(
        # Id of category to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $CategoryId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/categories/$CategoryId" -RequestArgs $RequestArgs -Client $Client
}

function New-RevWebcastRegistrationFields
{
<#
.SYNOPSIS
    Add Webcast Registration Fields
.DESCRIPTION
    Administration - Create webcast registration fields that can be used in Public webcasts. Used as a means to capture attendee details beyond name and email address when hosting Public events. <p>Use Ids returned in this endpoint in the <a href=/reference/createevent>Create Webcast</a> API to use a custom field.</p>
.OUTPUTS
    [string]
.LINK
    https://revdocs.vbrick.com/reference/createwebcastregistrationfield
#>
    [CmdletBinding()]
    [OutputType([string])]

    param(
        # Name of the custom registration field is displayed to users
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Type of field. Can be <code>Text</code> or <code>Select</code>.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $FieldType,

        # Default=false. Specifies whether the registrant is required to complete the field when registering for the event.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Required,

        # Field values when FieldType=<code>picklist</code>.  Required if FieldType=<code>picklist</code>.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Options,

        # Default=false. Specifies if the field is included in each public Webcast that is created.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IncludeInAllWebcasts,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/accounts/webcast-registration-fields" @params -Client $Client
}

function Get-RevWebcastRegistrationFields
{
<#
.SYNOPSIS
    Get Webcast Registration Fields
.DESCRIPTION
    Administration - Get a list of all webcast registration fields defined for Public webcasts.
.OUTPUTS
    @{
        [string] Id,
        [string] Name,
        [string] FieldType,
        [bool] Required,
        [string[]] Options,
        [bool] IncludeInAllWebcasts,
    }
.LINK
    https://revdocs.vbrick.com/reference/getwebcastregistrationfields
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/accounts/webcast-registration-fields" -RequestArgs $RequestArgs -Client $Client
}


function Get-RevMaintenanceSchedule
{
<#
.SYNOPSIS
    Get Maintenance Schedule
.DESCRIPTION
    Administration - This endpoint returns Rev’s scheduled maintenance windows (by date/time) for the current year. Maintenance dates vary for the different Rev environments and need to be maintained by environment region (US, EU and AU).
.OUTPUTS
    [object[]] # List of maintenance window
.LINK
    https://revdocs.vbrick.com/reference/maintenance-schedule
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/maintenance-schedule" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevJWTEncryptionKeysForAccount
{
<#
.SYNOPSIS
    Get JWT Encryption Keys for Account
.DESCRIPTION
    Administration - Get all JWT encryption keys for an account. This API is only available for partner accounts.
.OUTPUTS
    @{
        [object[]] encryptionKeys,
    }
.LINK
    https://revdocs.vbrick.com/reference/getjwtencryptionkeys
#>
    [CmdletBinding()]
    [OutputType([object])]

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



    Invoke-Rev -Method Get -Endpoint "/api/v2/jwt-encryption-keys" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevCustomFields
{
<#
.SYNOPSIS
    Get Custom Fields
.DESCRIPTION
    Administration - Get list of all custom fields.
.OUTPUTS
    @{
        [string] id, # Id of the custom field in the system.
        [string] name, # Name of the custom field in the system.
        [string] fieldType, # Type of the custome field (Text/Select).
        [bool] required, # Is custom field required in the system.
        [bool] displayedToUsers, # Is custom field dispalyed to user.
        [string] enum, # Options of custom field to set in case of "Select" type.
    }
.LINK
    https://revdocs.vbrick.com/reference/custommetadata
#>
    [CmdletBinding()]
    [OutputType([object])]

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



    Invoke-Rev -Method Get -Endpoint "/api/v2/video-fields" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevCategory
{
<#
.SYNOPSIS
    Get Category By ID
.DESCRIPTION
    Administration - Get a specified category by category Id.
.OUTPUTS
    @{
        [string] categoryId, # Id of category
        [string] name, # Name of the category
        [string] parentCategoryId, # Id of parent category with this category as child
        [bool] restricted,
        [object[]] categoryPolicyItems, # Used to add or update the users/groups that may manage restricted categories.
    }
.LINK
    https://revdocs.vbrick.com/reference/getcategory
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the category to get details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $CategoryId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/categories/$CategoryId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevBrandingSettings
{
<#
.SYNOPSIS
    Get Branding Settings
.DESCRIPTION
    Administration - Get the branding and style settings for a Rev entity.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getbrandingsettings
#>
    [CmdletBinding()]
    [OutputType([object])]

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



    Invoke-Rev -Method Get -Endpoint "/api/v2/accounts/branding-settings" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevSystemHealth
{
<#
.SYNOPSIS
    Get System Health
.DESCRIPTION
    Administration - This endpoint returns the status of Rev as shown on the Rev System Health page. The response should be a 200 OK unless there is a problem which is then displayed as a 5xx error.

.LINK
    https://revdocs.vbrick.com/reference/system-health
#>
    [CmdletBinding()]
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/system-health" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevIQCreditsUsage
{
<#
.SYNOPSIS
    Get Rev IQ Credits Usage
.DESCRIPTION
    Administration - Get Rev IQ credits usage. Data for video and live events is collected.
.OUTPUTS
    @{
        [string] scrollId,
        [float] total,
        [object[]] sessions,
    }
.LINK
    https://revdocs.vbrick.com/reference/getaccountiqcreditsusage
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Filter date for those recorded credits that happened on or after the WHEN field.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $StartDate,

        # Filter date for those recorded credits that happened on or before the WHEN field.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $EndDate,

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

    Get-InternalRevResultSet -Method Get -Endpoint "/api/v2/analytics/accounts/iq-credits-usage" -TotalKey "total" -HitsKey "sessions" -Activity "Rev IQ Credits Usage" @params -Client $Client;

}

function Get-RevAuditData ()
{
    <#
.SYNOPSIS
    Get Audit Data
.DESCRIPTION
    Audit - Get Rev Audit data
.OUTPUTS
    @{
        [string] MessageKey
        [string] entityKey
        [string] entityId
        [string] when
        [string] principal
        [string] previousState
        [string] currentState
    }
.LINK
    https://revdocs.vbrick.com/reference/getdevicesauditdetails
#>
    [CmdletBinding()]
    param (
        # Type of Audit data to retrieve
        [Parameter(Mandatory, Position=0)]
        [ValidateSet("UserAccess", "Users", "Groups", "Devices", "Videos", "ScheduledEvents", "Principals")]
        [string]
        $Type,

        # ID of user/group/device/video/event in question (if empty then get all)
        [Parameter(Position=1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if ($Type -eq 'Principals') { $_ -ne $null } else { $true }
        })]
        [string] $Id,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate = [datetime]::UtcNow,

        # Account ID of Rev account. If not specified then automatically get from Rev Client
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Maximum number of results to return
        [Parameter()]
        [Alias("First")]
        [RevMetadataAttribute(IsPassthru)]
        [int32]
        $MaxResults = [int32]::MaxValue,

        # whether to show progress bar
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [switch]
        $ShowProgress,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [RevMetadataAttribute(IsPassthru)]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    );

    if (-not $AccountId) {
        $AccountId = Get-RevAccountId -Client $Client;
    }

    # Parses arguments with the RevMetadataAttribute set, which populates body based on input
    $Params = [RevMetadataAttribute]::PopulatePayload($PSCmdlet.MyInvocation)

    $TypeCamelCase = $Type.Substring(0, 1).ToLower() + $Type.Substring(1)
    $Params.Endpoint = "/network/audit/accounts/$accountId/$TypeCamelCase";

    # convert csv response into standard object format
    $Params.TransformResponse = {
        param ($response, $query)
        $Total = [int32]($response.Headers.totalrecords | Select-Object -first 1);
        # apis output as CSV content
        $Hits = $response.Content | ConvertFrom-CSV | ForEach-Object {
            $_.When = [RevClient]::ISODate([RevClient]::ConvertJSDate($_.When));
            $_
        };

        # update fromdate each call
        $query.fromDate = $response.Headers.nextfromdate | select-object -first 1;
        $nextContinuationToken = $response.headers.nextcontinuationtoken | select-object -first 1;

        return @{
            total = $Total;
            entries = $Hits;
            nextContinuationToken = $nextContinuationToken;
        }
    };

    Get-InternalRevResultSet -Method Get -TotalKey "total" -HitsKey "entries" -Activity "Getting Audit Records..." -ScrollParameterName "nextContinuationToken" -Raw @params -Client $Client -RateLimitKey "auditEndpoint";
}
function Update-RevCategory
{
<#
.SYNOPSIS
    Update Category
.DESCRIPTION
    Administration - Edit a category.

.LINK
    https://revdocs.vbrick.com/reference/editcategory
#>
    [CmdletBinding()]
    param(
        # Id of the category to update
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $CategoryId,

        # Name of the category to edit
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # When true, the category is restricted and only the users/groups in categoryPolicyItems may add or edit content in the category or modify the category itself.
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $Restricted,

        # Used to add or update the users/groups that may manage restricted categories. @{ [string] id; [string] type; [string] itemType }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CategoryPolicyItems,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/categories/$CategoryId" @params -Client $Client
}

function New-RevZone
{
<#
.SYNOPSIS
    Add Zone
.DESCRIPTION
    Administration - Add a new zone.
.OUTPUTS
    @{
        [string] # zoneId
    }
.LINK
    https://revdocs.vbrick.com/reference/createzone
#>
    [CmdletBinding()]
    [OutputType([string])]

    param(
        # Zone name. Must be unique.
        [Parameter(Mandatory, Position=0)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # list of devices in the zone - get from get-zonedevices @{ [string] deviceType; [string] deviceId; [bool] liveOnly; [string[]] streams }
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $TargetDevices,

        # Id of parent zone if creating a child zone
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ParentZoneId,

        # Specify if the zone supports multicast streams
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $SupportsMulticast,

        # Individual Ip addresses added to the zone
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $IpAddresses,

        # A range of Ip addresses @{ [string] start; [string] end }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $IpAddressRanges,

        # Specifies to override the account slide delay settings
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $OverrideAccountSlideDelay,

        # Slide delay in seconds
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $SlideDelaySeconds,

        # Designate the zone a Rev Connect zone
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $RevConnectEnabled,

        # When revConnectEnabled, add or edit a Rev Connect Zone. @{ [bool] disableFallback; [int] maxZoneMeshes; [bool] groupPeersByZoneIPAddresses }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $RevConnectSetting,

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

    if ($params.IpAddressRanges -and ($params.IpAddressRanges | Select-Object -First 1) -is [string]) {
        Write-Verbose "New Zone ($name) - IP Address Ranges specified as strings, formatting correctly"
        $params.IpAddressRanges = $params.IpAddressRanges | ForEach-Object {
            $pair = $_ -split '-';
            [pscustomobject]@{ start = $pair[0]; end = $pair[-1] };
        }
    }

    # Enforce correct format for target devices
    $params.TargetDevices = $params.TargetDevices | foreach-object {
        $device = $_;
        # make sure valid input, not raw zonedevices output
        if ($device.deviceType -and $device.deviceId -and -not $device.videoStreams) {
            return $device;
        }
        $id = if ($device.deviceId) { $device.deviceId } else { $device.id }
        Write-Verbose "Attempting to format TargetDevice ($id) for new zone $Name correctly"
        $isInvalid = -not ($device.deviceType -and $id);
        $streams = if ($device.streams) { $device.streams } else { $device.videoStreams }

        $streams = $streams | ForEach-Object {
            if ($_ -and $_ -is [string]) {
                return $_
            }
            if ($null -ne $_.name) {
                return $_.name
            }
            $isInvalid = $true;
            return $null
        } | Where-Object { $_ }

        if ($isInvalid) {
            throw [System.InvalidOperationException]::new("Invalid TargetDevices for new Zone $Name")
        }

        [pscustomobject]@{
            DeviceId = $id;
            DeviceType = $device.deviceType;
            Streams = $device;
            LiveOnly = $device.liveOnly;
        }
    }

    Invoke-Rev -Method Post -Endpoint "/api/v2/zones "@params -Client $Client
}

function New-RevCategory
{
<#
.SYNOPSIS
    Add Category
.DESCRIPTION
    Administration - Add a new category.
.OUTPUTS
    [string] categoryId
.LINK
    https://revdocs.vbrick.com/reference/createcategory
#>
    [CmdletBinding()]
    [OutputType([string])]

    param(
        # Name of category to add
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Id of parent category to add the category as a child category. If specified, the Id needs to exist in Rev.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ParentCategoryId,

        # When true, the category is restricted and only the users/groups in categoryPolicyItems may add or edit content in the category or modify the category itself.
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $Restricted,

        # Used to add or update the users/groups that may manage restricted categories. @{ [string] id; [string] type; [string] itemType }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CategoryPolicyItems,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/categories" @params -Client $Client
}

function Get-RevZones
{
<#
.SYNOPSIS
    Get Zones
.DESCRIPTION
    Administration - Get list of all zones.
.OUTPUTS
    @{
        [string] accountId,
        [object] defaultZone,
        [object[]] zones,
    }
    or if -Flat:
    [object[]] zones (including defaultZone)
.LINK
    https://revdocs.vbrick.com/reference/getzones
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # If specified return zones as a flat list rather than nested object
        [Parameter()]
        [switch]
        $Flat,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $resp = Invoke-Rev -Method Get -Endpoint "/api/v2/zones" -RequestArgs $RequestArgs -Client $Client;

    if (-not $Flat) {
        return $resp;
    }

    $zoneList = [System.Collections.generic.list[object]]@();

    $recursiveAdd = {
        param($list, [object[]] $zones, $parentZone, $addFn)
        # iterate through each item in array
        foreach ($zone in $zones) {
            $parentZoneId = $null;
            $parentName = "";
            if ($parentZone) {
                $parentName = "$($parentZone.fullPath)/"
                $parentZoneId = $parentZone.id;
            }
            $zone | Add-Member -NotePropertyName "parentZoneId" -NotePropertyValue $parentZoneId;
            $fullZoneName = "$($parentName)$($zone.name)";
            $zone | Add-Member -NotePropertyName "fullPath" -NotePropertyValue $fullZoneName -Force

            # add item to flattened list
            $list.Add($zone);
            if ($zone.childZones.Count -le 0) {
                continue;
            }
            $childZones = $zone.childZones;
            # change to just returning zone ID
            $zone.childZones = $zone.childZones.id;
            # recursively add children
            $recursiveAdd.Invoke($list, $childZones, $zone, $addFn);
        }
    }
    $resp.defaultZone | Add-Member -NotePropertyName "childZones" -NotePropertyValue @()
    $recursiveAdd.Invoke($zoneList, @($resp.defaultZone), $null, $recursiveAdd);

    $recursiveAdd.Invoke($zoneList, $resp.zones, $null, $recursiveAdd);

    $zoneList;
}

function Get-RevZoneDevices
{
<#
.SYNOPSIS
    Get Zone Devices
.DESCRIPTION
    Administration - Get a list of all devices in a zone.
.OUTPUTS
    @{
        [object[]] devices,
    }
.LINK
    https://revdocs.vbrick.com/reference/getzonedevices
#>
    [CmdletBinding()]
    [OutputType([object])]

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



    Invoke-Rev -Method Get -Endpoint "/api/v2/zonedevices" -RequestArgs $RequestArgs -Client $Client | Select-Object -ExpandProperty 'devices'
}

function Get-RevPresentationProfiles
{
<#
.SYNOPSIS
    Get Presentation Profiles
.DESCRIPTION
    Administration - Get list of all presentation profiles.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/getpresentationprofiles
#>
    [CmdletBinding()]
    [OutputType([object])]

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

    Invoke-Rev -Method Get -Endpoint "/api/v2/presentation-profiles" -RequestArgs $RequestArgs -Client $Client | Select-Object -ExpandProperty 'profiles'
}

function Update-RevZone
{
<#
.SYNOPSIS
    Update Zone
.DESCRIPTION
    Administration - Edit a zone.

.LINK
    https://revdocs.vbrick.com/reference/editzone
#>
    [CmdletBinding()]
    param(
        # Id of zone to update
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Zone name. Must be unique.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Id of parent zone if creating a child zone
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ParentZoneId,

        # Specify if the zone supports multicast streams
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $SupportsMulticast,

        # Individual Ip addresses added to the zone
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $IpAddresses,

        # A range of Ip addresses @{ [string] start; [string] end }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $IpAddressRanges,

        #  @{ [string] deviceType; [string] deviceId; [bool] isActive; [bool] liveOnly; [string[]] streams }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $TargetDevices,

        # Specifies to override the account slide delay settings
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $OverrideAccountSlideDelay,

        # Slide delay in seconds
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $SlideDelaySeconds,

        # Designate the zone a Rev Connect zone
        [Parameter()]
        [RevMetadataAttribute()]
        [switch]
        $RevConnectEnabled,

        # When revConnectEnabled, add or edit a Rev Connect Zone. @{ [bool] disableFallback; [int] maxZoneMeshes; [bool] groupPeersByZoneIPAddresses }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $RevConnectSetting,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/zones/$Id "@params -Client $Client
}

function Get-RevAuditVideo
{
<#
.SYNOPSIS
    Get Audit for a Video
.DESCRIPTION
    Audit - Get audit details of a given video
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideoauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Video Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $VideoId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/videos/$VideoId" @params -Client $Client
}

function Get-RevAuditAllGroups
{
<#
.SYNOPSIS
    Get Audit for All Groups
.DESCRIPTION
    Audit - Get audit details of all groups.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getgroupsauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/groups" @params -Client $Client
}

function Get-RevAuditAllUserAccess
{
<#
.SYNOPSIS
    Get Audit of User Access for Account
.DESCRIPTION
    Audit - Get audit details for all of account's user access.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getuseraccessauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/userAccess" @params -Client $Client
}

function Get-RevAuditAllUsers
{
<#
.SYNOPSIS
    Get Audit for All Users
.DESCRIPTION
    Audit - Get audit details of all users.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getusersauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/users" @params -Client $Client
}

function Get-RevAuditAllVideos
{
<#
.SYNOPSIS
    Get Audit for All Videos
.DESCRIPTION
    Audit - Get audit details of all videos.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideosauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/videos" @params -Client $Client
}

function Get-RevAuditAllWebcasts
{
<#
.SYNOPSIS
    Get Audit for All Webcasts
.DESCRIPTION
    Audit - Get audit details of all webcasts.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventsauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/scheduledEvents" @params -Client $Client
}

function Get-RevAuditDevice
{
<#
.SYNOPSIS
    Get Audit for a Device
.DESCRIPTION
    Audit - Get audit details of a given device.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getdeviceauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Device Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $DeviceId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/devices/$DeviceId" @params -Client $Client
}

function Get-RevAuditGroup
{
<#
.SYNOPSIS
    Get Audit for a Group
.DESCRIPTION
    Audit - Get audit details of a given group.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getgroupauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Group Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $GroupId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/groups/$GroupId" @params -Client $Client
}

function Get-RevAuditAllDevices
{
<#
.SYNOPSIS
    Get Audit for All Devices
.DESCRIPTION
    Audit - Get audit details of all devices.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getdevicesauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $AccountId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/devices" @params -Client $Client
}

function Get-RevAuditUserAccess
{
<#
.SYNOPSIS
    Get Audit of User Access for User
.DESCRIPTION
    Audit - Get user access audit details of a given user.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getuseraccessauditdetailsbyuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # User Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $UserId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/userAccess/$UserId" @params -Client $Client
}

function Get-RevAuditUser
{
<#
.SYNOPSIS
    Get Audit for a User
.DESCRIPTION
    Audit - Get audit details for a given user.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getuserauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # User Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $UserId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/users/$UserId" @params -Client $Client
}

function Get-RevAuditPrincipal
{
<#
.SYNOPSIS
    Get Audit for a Principal
.DESCRIPTION
    Audit - Get audit details of a given principal.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/getprincipalauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Principal Id to get audit deatils for
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $PrincipalId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/principals/$PrincipalId" @params -Client $Client
}

function Get-RevAuditWebcast
{
<#
.SYNOPSIS
    Get Audit for a Webcast
.DESCRIPTION
    Audit - Get audit details of a given webcast.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventauditdetails
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account Id to get audit details
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $AccountId,

        # Event Id to get audit details
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Valid start date
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $FromDate,

        # Valid end date greater than the specified fromDate (start date)
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $ToDate,

        # Id from subsequent request to get next set of records
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $NextContinuationToken,


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

    Invoke-Rev -Method Get -Endpoint "/network/audit/accounts/$AccountId/scheduledEvents/$EventId" @params -Client $Client
}

function Update-RevUserSession
{
<#
.SYNOPSIS
    Extend User Login Session
.DESCRIPTION
    Authentication - This endpoint extends the current session by preventing it from timing out. Successful completion returns a new expiration date and time which expires the session at that new date and time.
.OUTPUTS
    @{
        [datetime] expiration,
    }
.LINK
    https://revdocs.vbrick.com/reference/extendsessiontimeout
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Account user Id
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $UserId,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/user/extend-session-timeout" @params -Client $Client
}

function Update-RevApiKeySession
{
<#
.SYNOPSIS
    Extend API Key Session
.DESCRIPTION
    Authentication - This endpoint extends the current user API key session by preventing it from timing out. Successful completion returns a new expiration date and time which then expires the session at that new date and time.
.OUTPUTS
    @{
        [datetime] expiration,
    }
.LINK
    https://revdocs.vbrick.com/reference/extendapikeysessiontimeout
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # ApiKey of the user extending the session timeout
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $ApiKey,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Post -Endpoint "/api/v2/auth/extend-session-timeout/$ApiKey" -RequestArgs $RequestArgs -Client $Client
}

function Stop-RevUserSession
{
<#
.SYNOPSIS
    User Logoff
.DESCRIPTION
    Authentication - This endpoint ends the login session. The userId value (provided in the login endpoint response) identifies the user who is logging out.

.LINK
    https://revdocs.vbrick.com/reference/logoff
#>
    [CmdletBinding()]
    param(
        # Account user Id
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $UserId,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/user/logoff" @params -Client $Client
}

function Stop-RevApiKeySession
{
<#
.SYNOPSIS
    Revoke API Key Session
.DESCRIPTION
    Authentication - This endpoint revokes the current user API key session.

.LINK
    https://revdocs.vbrick.com/reference/revoketoken
#>
    [CmdletBinding()]
    param(
        # ApiKey of the user revoking the token
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $ApiKey,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/tokens/$ApiKey" -RequestArgs $RequestArgs -Client $Client
}

function Test-RevClient
{
<#
.SYNOPSIS
    Checks User Session
.DESCRIPTION
    Authentication - Checks user session health for the provided authorization header.

.LINK
    https://revdocs.vbrick.com/reference/getusersession
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter(Position=0, ValueFromPipeline)]
        [RevClient]
        $Client = (Get-RevClient)
    )

    return $Client.VerifySession();
}

function Start-RevOAuthSession
{
<#
.SYNOPSIS
    OAuth Access Token
.DESCRIPTION
    Authentication - Obtains the access token that identifies the Rev user that granted access to the client.
.OUTPUTS
    @{
        [string] accessToken, # The Vbrick access token to identify user which will be used for API calls
        [string] refreshToken, # The refresh token that can be used to refresh an access_token when it expires.
        [string] userId, # User Id.
        [datetime] expiration, # Token expiration time in seconds
        [string] issuedBy, # The Token issuer, Vbrick here.
    }
.LINK
    https://revdocs.vbrick.com/reference/token
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Value of XXX for initial request and extend session
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $AuthCode,

        # Configured in the Rev client
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ApiKey,

        # The value should be set to <code>authorization_code</code> for the initial session request and set to <code>refresh_token</code> to extend an existing session
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $GrantType,

        # URL of web page to load after Rev credentials have been entered by the user. This page is where the final authentication steps will be performed and from which all subsequent API calls may be made. This value must be URL encoded.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RedirectUri,

        # Not applicable for initial request and can be omitted. After the initial request this value must be present and the value returned from the initial call for session extension. This value may remain the same for a given session and can be used repeatedly in extend session requests as long as the session remains valid. Each extend session generates a new accessToken value therefore the full authorization string must be recalculated after each extend session request before using in subsequent API calls.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RefreshToken,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/oauth/token" @params -Client $Client
}

function Start-RevApiKeySession
{
<#
.SYNOPSIS
    User Login API Key
.DESCRIPTION
    Authentication - This authentication API endpoint is used to authenticate individual user using user’s pre-generated API Key and Secret. Use the token that is returned in the response as the Authorization to run other public APIs. Once a session is established using this endpoint, subsequent API calls that uses the token returned from this endpoint will be limited according to the role and privileges of this particular user. Using this method, the user via API will have the same privileges and roles that user has when they login to Rev UI. This authentication mechanism can be used to automate Rev workflows using role and privileges of a given user.</br></br>Account Admins can generate user’s API Key and Secret combination. Secret is only visible at the time of generation. API Key and Secret combination can be regenerated and deleted. The key will not work for suspended users. Also authenticating a user using this method will consume a user license if the user is unlicensed
.OUTPUTS
    @{
        [string] token,
        [string] issuer,
        [datetime] expiration,
    }
.LINK
    https://revdocs.vbrick.com/reference/authenticateuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Configured in the Rev client
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $ApiKey,

        # Configured in the Rev client
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Secret,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/authenticate" @params -Client $Client
}

Add-Type -AssemblyName System.Web
function Get-RevOAuthUrl
{
<#
.SYNOPSIS
    OAuth Authorization
.DESCRIPTION
    Authentication - Successful invocation of this API results in the user being redirected to the URL specified in the redirect_uri parameter.
.OUTPUTS
    The Authorization URL on Rev to get OAuth auth token.

.LINK
    https://revdocs.vbrick.com/reference/authorization
#>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # OAuth ApiKey obtained after registering the app in Rev Admin -> System Settings -> API Keys page
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $ApiKey,

        # OAuth Secret obtained after registering the app in Rev Admin -> System Settings -> API Keys page
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Secret,

        # Redirect URL as set in Rev Admin -> System Settings -> API Keys page. This must match what's in Rev EXACTLY, and is where users will be redirected after logging into Rev
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $RedirectUri,

        # This is any state that the consumer wants to reflect back to it after approval. This is optional and the value will be url encoded.
        [Parameter()]
        [string]
        $State = "1",

        # Specify the Rev URL. If not specified will use URL from -Client (or Get-RevClient)
        [Parameter()]
        [string]
        $RevUrl,

        #
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient -SkipNullCheck)
    )


    $now = Get-Date;
    $timestamp = $now.ToUniversalTime().ToString('s') + 'Z'

    $verifier = "$($apiKey)::$($timestamp)"

    $encoding = [System.Text.UTF8Encoding]::new()
    $original = $encoding.GetBytes($verifier)
    $keyBytes = $encoding.GetBytes($secret)

    [System.Security.Cryptography.HMACSHA256] $hmacsha256 = $null;
    try {
        $hmacsha256 = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
        $signedBytes = $hmacsha256.ComputeHash($original);
        $signature = [System.Convert]::ToBase64String($signedBytes);
    } finally {
        if ($hmacsha256) {
            $hmacsha256.Dispose();
        }
    }

    if (-not $RevUrl) {
        if ($Client.Url) {
            $RevUrl = $Client.Url;
        } else {
            throw [System.ArgumentException]::new("Rev URL not specified")
        }
    }

    $query = [System.Web.HttpUtility]::ParseQueryString([string]::Empty);
    $query.Add('apiKey', $ApiKey);
    $query.Add('signature', $signature);
    $query.Add('verifier', $verifier);
    $query.Add('redirect_uri', $RedirectUri);
    $query.Add('response_type', 'code'); # 'code'
    $query.Add('state', $State);

    $builder = [System.UriBuilder]::new($RevUrl);
    $builder.Path = "/oauth/authorization";
    $builder.Query = $query.ToString();

    Write-Output $builder.Uri.OriginalString;
}

function Start-RevUserSession
{
<#
.SYNOPSIS
    User Login
.DESCRIPTION
    Authentication - Establish session via Username login.
.OUTPUTS
    @{
        [string] token,
        [string] issuer,
        [datetime] expiration,
        [string] email,
        [string] id,
        [string] username,
        [string] firstName,
        [string] lastName,
        [string] language,
    }
.LINK
    https://revdocs.vbrick.com/reference/loginuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Username of account trying to login
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Username,

        # Password of account trying to login
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Password,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/user/login" @params -Client $Client
}

function Edit-RevChannel
{
<#
.SYNOPSIS
    Patch Channel
.DESCRIPTION
    Channels - Partially edits the members and details of a channel. You do not need to provide the fields that you are not changing.<p>Please refer to http://jsonpatch.com/ for the format of the request body.</p><strong>Examples:</strong><p>To add members: [{'op': 'add',  'path': '/Members/-', 'value': {'id': '0e2a1bfc-0a36-4ee1e-ac1e-3647b256537d','type': 'Group','roleTypes': ['Member','Contributor']}} ]</p><p>To remove members : [{ 'op': 'remove',  'path': '/Members',  'value': '63a76eb9-fa62-46e0-bdb5-c8ad34aec086' }]</p><p>To update channel name : [{ 'op': 'replace', 'path': '/Name', 'value': 'New Name' }]</p>

.LINK
    https://revdocs.vbrick.com/reference/patchchannel
#>
    [CmdletBinding()]
    param(
        # Id of the channel to patch
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $ChannelId,

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

    Invoke-Rev -Method Patch -Endpoint "/api/v2/channels/$ChannelId" @params -Client $Client
}


function Set-RevChannelLogo
{
<#
.SYNOPSIS
    Upload Channel Logo Image
.DESCRIPTION
    Channels - Upload a logo image for a given channel.

.LINK
    https://revdocs.vbrick.com/reference/uploadchannellogofile
#>
    [CmdletBinding()]
    param(
        # Id of user to upload profile image
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $ChannelId,

        # Image
        [Parameter(Mandatory, Position=1, ValueFromPipeline)]
        [Alias("Image")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $fileField = New-RevFormDataField -Name "ImageFile" -Value (Get-Item $Path);
    $form = New-RevFormData -Fields @($fileField);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/channel-logo/$ChannelId" -Body $form -RequestArgs $RequestArgs -Client $Client
}


function Get-RevChannelsForUser
{
<#
.SYNOPSIS
    Get Channels For User
.DESCRIPTION
    Channels - Returns only the channels for the user making the API call.
.OUTPUTS
    @{
        [string] channelId,
        [string] name,
    }
.LINK
    https://revdocs.vbrick.com/reference/getuserchannels
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



    Invoke-Rev -Method Get -Endpoint "/search/channels" -RequestArgs $RequestArgs -Client $Client
}

function New-RevChannel
{
<#
.SYNOPSIS
    Create Channel
.DESCRIPTION
    Channels - Add a new channel and assign channel members and roles as needed.
.OUTPUTS
    @{
        [string] channelId,
    }
.LINK
    https://revdocs.vbrick.com/reference/createchannel
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Required. Name of the Channel, must be unique.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Description of Channel to create.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Description,

        # Users/groups to add as channel members. Includes a flag to indicate if a member is acting as a channel administrator. @{ [string] id; [string] type; [string[]] roleTypes }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $Members,

        # default sort order of channel results
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $DefaultSortOrder,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/channels" @params -Client $Client
}

function Remove-RevChannel
{
<#
.SYNOPSIS
    Delete Channel
.DESCRIPTION
    Channels - Delete a channel.

.LINK
    https://revdocs.vbrick.com/reference/deletechannel
#>
    [CmdletBinding()]
    param(
        # Id of channel to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $ChannelId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/channels/$ChannelId" -RequestArgs $RequestArgs -Client $Client
}

function Update-RevChannel
{
<#
.SYNOPSIS
    Update Channel
.DESCRIPTION
    Channels - Edit a channel.

.LINK
    https://revdocs.vbrick.com/reference/editchannel
#>
    [CmdletBinding()]
    param(
        # Id of channel to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $ChannelId,

        # Required. Name of the Channel, must be unique.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Description of Channel to create.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Description,

        # Users/groups to add as channel members. Includes a flag to indicate if a member is acting as a channel administrator. @{ [string] id; [string] type; [string[]] roleTypes }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $Members,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/channels/$ChannelId" @params -Client $Client
}

function Get-RevChannels
{
<#
.SYNOPSIS
    Get Channels
.DESCRIPTION
    Channels - Get list of all channels. Includes the channel members and specifies the type of member they are (user/group) along with their channel role.
.OUTPUTS
    @{
        [string] Id,
        [string] name,
        [string] description,
        [object[]] members,
    }
.LINK
    https://revdocs.vbrick.com/reference/getchannel
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Number of channels to return per page. Default=10.
        [Parameter()]
        [Alias("Size")]
        [int32]
        $PageSize = 10,

        # Max number of results to return. Default is all results
        [Parameter()]
        [Alias("First")]
        [int32] $MaxResults = [int32]::MaxValue,

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
        $body = @{
            page = 0;
            size = $PageSize;
        }
        $current = 0;
    }
    process {
        while($current -lt $MaxResults) {
            $page = Invoke-Rev -Method Get -Endpoint "/api/v2/channels" -Body $body -RequestArgs $RequestArgs -Client $Client
            if (-not $page) {
                break
            }
            $page = $page | Select-Object -first ($MaxResults - $current)
            $body.page += 1;
            $current += $page.Count;
            $page;
        }
    }
}

function Get-RevDMEDevices
{
<#
.SYNOPSIS
    Get DME Devices
.DESCRIPTION
    Devices - Get a list of all DME devices and their status.
.OUTPUTS
    @{
        [object[]] devices,
    }
.LINK
    https://revdocs.vbrick.com/reference/getdmedevices
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/devices/dmes" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevDMEHealthStatus
{
<#
.SYNOPSIS
    Get DME Health Status
.DESCRIPTION
    Devices - This endpoint retrieves the last reported, complete health status of a DME. Each DME communicates a health status based on a frequency determined by Rev. Currently, this is every 60 seconds. Customers implementing longitudinal comparisons should periodically call this endpoint.
.OUTPUTS
    @{
        [datetime] bootTime,
        [datetime] systemTime,
        [string] systemVersion,
        [string] fullVersion,
        [string] ipAddress,
        [string] natAddress,
        [string] hostname,
        [string] overallHealth,
        [float] cpuUsagePercent,
        [string] cpuUsageHealth,
        [string] rtmpServerVersion,
        [float] rtspCpuUsagePercent,
        [float] rtmpCpuUsagePercent,
        [float] mpsConnectionCount,
        [float] mpsThroughputBitsPerSec,
        [float] mpsThroughputPercent,
        [string] throughputHealth,
        [float] multiProtocolIncomingConnectionsCount,
        [float] multiProtocolOutgoingConnectionsCount,
        [float] mpsMulticastStreamCount,
        [float] multiProtocolMaxCount,
        [float] rtpIncomingConnectionsCount,
        [float] rtpOutgoingConnectionsCount,
        [float] rtpMulticastConnectionsCount,
        [float] rtpConnectionsMaxCount,
        [bool] iScsiEnabled,
        [float] diskContentTotal,
        [float] diskContentUsed,
        [string] diskContentHealth,
        [float] diskSystemTotal,
        [float] diskSystemUsed,
        [string] diskSystemHealth,
        [float] physicalMemoryTotal,
        [float] physicalMemoryUsed,
        [float] swapMemoryUsed,
        [float] swapMemoryTotal,
        [string] memoryHealth,
        [float] meshPeerTotalCount,
        [float] meshPeerReachableCount,
        [string] meshHealth,
        [float] transratingActiveCount,
        [float] transratingMaxCount,
        [object[]] recordings,
        [string] sslMediaTransfer,
        [bool] stbConnectorEnabled,
        [float] httpThroughputBitsPerSec,
        [float] httpConnectionCount,
        [float] throughputPhysicalBits,
        [object] meshStatistics,
        [string] lockdownStatus,
        [string] lockdownStatusDetail,
        [object[]] hlsDistributions,
        [object] serviceStatus,
        [float] numWorkers,
        [object[]] workers,
        [object] streamStatus,
    }
.LINK
    https://revdocs.vbrick.com/reference/getdmehealthstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of DME device to query
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $DeviceId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/devices/dmes/$DeviceId/health-status" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevDMEDevice
{
<#
.SYNOPSIS
    Delete DME Device
.DESCRIPTION
    Devices - Deletes a DME device.

.LINK
    https://revdocs.vbrick.com/reference/deletedmedevice
#>
    [CmdletBinding()]
    param(
        # Id of DME device to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $DeviceId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/devices/dmes" -RequestArgs $RequestArgs -Client $Client
}

function New-RevDMEDevice
{
<#
.SYNOPSIS
    Add DME Device
.DESCRIPTION
    Devices - Adds a new DME device.
.OUTPUTS
    @{
        [string] deviceId,
    }
.LINK
    https://revdocs.vbrick.com/reference/createdmedevice
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # DME device name
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # MAC address for the DME. Must be unique to the Rev account.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $MacAddress,

        # Default=false. Specifies if the DME is currently active.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsActive,

        # Default=false. Specifies if the DME should preposition content.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $PrepositionContent,

        # Default=false. Specifies the DME as a storage device.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsVideoStorageDevice,

        # Used to manually add video streams to the DME. @{ [string] name; [string] url; [string] encodingType; [bool] isMulticast }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $ManualVideoStreams,

        # Used to add an HLS stream, required for mobile devices.  This is not added by default. @{ [string] name; [bool] hasHls }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $VideoStreamGroupsToAdd,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/devices/dmes" @params -Client $Client
}

function Restart-RevDmeDevice
{
<#
.SYNOPSIS
    Reboot DME Device
.DESCRIPTION
    Devices - Reboots specific DME device. Returns successful response when reboot action added to queue.

.LINK
    https://revdocs.vbrick.com/reference/rebootdmedevice
#>
    [CmdletBinding()]
    param(
        # Id of DME device to reboot
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $DeviceId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Put -Endpoint "/api/v2/devices/dmes" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevPlaylists
{
<#
.SYNOPSIS
    Get Playlists
.DESCRIPTION
    Playlists - Get list of all playlists.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/getplaylists
#>
    [CmdletBinding()]
    [OutputType([object])]

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



    Invoke-Rev -Method Get -Endpoint "/api/v2/playlists" -RequestArgs $RequestArgs -Client $Client
}

function New-RevPlaylist
{
<#
.SYNOPSIS
    Add Playlist
.DESCRIPTION
    Playlists - Create a new playlist.
.OUTPUTS
    @{
        [string] playlistId,
    }
.LINK
    https://revdocs.vbrick.com/reference/createplaylist
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Name of the playlist. Must be unique.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Ids of videos to add to playlist. At least one video is required.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string[]]
        $VideoIds,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/playlists" @params -Client $Client
}

function Remove-RevPlaylist
{
<#
.SYNOPSIS
    Delete Playlist
.DESCRIPTION
    Playlists - Deletes a playlist.

.LINK
    https://revdocs.vbrick.com/reference/deleteplaylist
#>
    [CmdletBinding()]
    param(
        # Id of playlist to delete.
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/playlists/$Id" -RequestArgs $RequestArgs -Client $Client
}

function Update-RevFeaturedPlaylist
{
<#
.SYNOPSIS
    Update Featured Playlist
.DESCRIPTION
    Playlists - Edit the Rev Featured Playlist on the Home Page. You must have Account or Media Admin permissions.

.LINK
    https://revdocs.vbrick.com/reference/editfeaturedplaylist
#>
    [CmdletBinding()]
    param(
        # Video Ids to edit in the playlist
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoId,

        # Action to be taken - Add or Remove.
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Add", "Remove")]
        [string]
        $Action,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/playlists/featured-playlist" @params -Client $Client
}

function Update-RevPlaylist
{
<#
.SYNOPSIS
    Update Playlist
.DESCRIPTION
    Playlists - Edit videos in a playlist.

.LINK
    https://revdocs.vbrick.com/reference/editplaylist
#>
    [CmdletBinding()]
    param(
        # Id of Playlist to edit.
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Video Ids to edit in the playlist
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoId,

        # Action to be taken - Add or Remove.
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Add", "Remove")]
        [string]
        $Action,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/playlists/$Id" @params -Client $Client
}

function Remove-RevGroup
{
<#
.SYNOPSIS
    Delete Group
.DESCRIPTION
    Users & Groups - Delete a group.

.LINK
    https://revdocs.vbrick.com/reference/deletegroup
#>
    [CmdletBinding()]
    param(
        # Id of group to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/groups/$Id" -RequestArgs $RequestArgs -Client $Client
}

function New-RevGroup
{
<#
.SYNOPSIS
    Add Group
.DESCRIPTION
    Users & Groups - Add a new group and assign users and roles as needed.
.OUTPUTS
    @{
        [string] groupId,
    }
.LINK
    https://revdocs.vbrick.com/reference/creategroup
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Required. Unique name of Group.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # User Ids to add to Group
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $UserIds,

        # Role Ids to add to Group
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

    Invoke-Rev -Method Post -Endpoint "/api/v2/groups" @params -Client $Client
}

function Get-RevUsersByLoginDate
{
<#
.SYNOPSIS
    Get Users By Login Date
.DESCRIPTION
    Users & Groups - Get a list of users and their last login date. Users who have never logged in are not be returned.
.OUTPUTS
    @{
        [string] UserId,
        [string] FullName,
        [string] Username,
        [datetime] LastLogin,
    }
.LINK
    https://revdocs.vbrick.com/reference/loginreport
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # If provided, query results are sorted based on field.
        [Parameter()]
        [ValidateSet("LastLogin", "Username")]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # Sort order for sorting the result, asc or desc.
        [Parameter()]
        [ValidateSet("asc", "desc")]
        [RevMetadataAttribute()]
        [string]
        $SortOrder,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/users/login-report" @params -Client $Client
}

function Edit-RevGroup
{
<#
.SYNOPSIS
    Patch Group
.DESCRIPTION
    Users & Groups - Partially edits the details of a group. You do not need to provide the fields that you are not changing. For <strong>LDAP groups</strong>, only roles can be updated. For Rev system groups, <em>both</em> users and roles can be updated.<p>Please refer to http://jsonpatch.com/ for the format of the request body.</p><p><strong>Examples:</strong></p><p>To add users: [{ 'op': 'add', 'path': '/UserIds/-', 'value': '13443c6c-e2cc-49e2-b4b2-ec3ebad97fb1' }]</p><p>To add roles: [{ 'op': 'add', 'path': '/RoleIds/-', 'value': 'b14f6a56-254d-43ee-950b-145811ebfc8c' }]</p><p>To remove users: [{ 'op': 'remove', 'path': '/UserIds', 'value': 'b14f6a56-254d-43ee-950b-145811ebfc8c' }]</p><p>To remove roles: [{ 'op': 'remove', 'path': '/RoleIds', 'value': 'b14f6a56-254d-43ee-950b-145811ebfc8c' }]</p>

.LINK
    https://revdocs.vbrick.com/reference/patchgroup
#>
    [CmdletBinding()]
    param(
        # Id of the group to patch
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

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

    Invoke-Rev -Method Patch -Endpoint "/api/v2/groups/$Id" @params -Client $Client
}

function Get-RevUserByEmail
{
<#
.SYNOPSIS
    Get User by Email
.DESCRIPTION
    Users & Groups - Get user details for a given user account Email Address.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/getuserbyemailaddress
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Email address of user account to get
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Email,

        # Indicates the context of the value provided in the request path ':email'. If a value of 'email' is provided, the user is retrieved using the 'Email' property.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Type,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/users/$Email" @params -Client $Client
}

function Get-RevGroups
{
<#
.SYNOPSIS
    Get Groups
.DESCRIPTION
    Users & Groups - Get all groups. It supports pagination.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/getgroups
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Page size
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $Size,

        # Page number - use 0 or leave blank to get the first page of results, 1 to get the second page, etc.
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $Page,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/groups" @params -Client $Client
}

function Set-RevUserProfileImage
{
<#
.SYNOPSIS
    Upload User Profile Image
.DESCRIPTION
    Users & Groups - Upload a profile image for a given user.

.LINK
    https://revdocs.vbrick.com/reference/uploadprofileimage
#>
    [CmdletBinding()]
    param(
        # Id of user to upload profile image
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $UserId,

        # Image
        [Parameter(Mandatory, Position=1, ValueFromPipeline)]
        [Alias("Image")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $fileField = New-RevFormDataField -Name "ImageFile" -Value (Get-Item $Path);
    $form = New-RevFormData -Fields @($fileField);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/profile-image/$UserId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Update-RevGroup
{
<#
.SYNOPSIS
    Update Group
.DESCRIPTION
    Users & Groups - Edits a group.

.LINK
    https://revdocs.vbrick.com/reference/editgroup
#>
    [CmdletBinding()]
    param(
        # Id of group to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Required. Unique name of Group.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # User Ids to add to Group
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $UserIds,

        # Role Ids to add to Group
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

    Invoke-Rev -Method Put -Endpoint "/api/v2/groups/$Id" @params -Client $Client
}

function Get-RevUserByUsername
{
<#
.SYNOPSIS
    Get User by Username
.DESCRIPTION
    Users & Groups - Get user details for a given user account Username.
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
    https://revdocs.vbrick.com/reference/getuserbyusername
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Username of user account to get
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Username,

        # Indicates the context of the value provided in the request path ':username'. If a value of 'username' is provided, the user is retrieved using the 'Username' property.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Type,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/users/$Username" @params -Client $Client
}

function Remove-RevUserProfileImage
{
<#
.SYNOPSIS
    Delete User Profile Image
.DESCRIPTION
    Users & Groups - Delete a profile image for a given user.

.LINK
    https://revdocs.vbrick.com/reference/deleteprofileimage
#>
    [CmdletBinding()]
    param(
        # Id of user to delete profile image
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $UserId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/users/$UserId/profile-image" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevUser
{
<#
.SYNOPSIS
    Delete User
.DESCRIPTION
    Users & Groups - Delete a user account.

.LINK
    https://revdocs.vbrick.com/reference/deleteuser
#>
    [CmdletBinding()]
    param(
        # Id of the user to delete
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $UserId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/users/$UserId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevGroupMembers
{
<#
.SYNOPSIS
    Get Users in a Group
.DESCRIPTION
    Users & Groups - Returns the userIds for a given group.
.OUTPUTS
    [string[]] userIds
.LINK
    https://revdocs.vbrick.com/reference/getgroupmembership
#>
    [CmdletBinding()]
    [OutputType([string])]

    param(
        # Id of the group to get users
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        [Parameter()]
        [Alias("First")]
        [RevMetadataAttribute(IsPassthru)]
        [int64]
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

    Get-InternalRevResultSet -Method Get -Endpoint "/api/v2/search/groups/$Id/users" -TotalKey "totalUsers" -HitsKey "userIds" -Activity "Listing Group Members..." @params -Client $Client;
}

function Edit-RevUser
{
<#
.SYNOPSIS
    Patch User
.DESCRIPTION
    Users & Groups - Partially edits the details of a user. You do not need to provide the user fields that are not changing.<p><strong>Note:</strong> If the account is an LDAP user, only Roles, Groups, and Preferred Language may be updated.</p>

.LINK
    https://revdocs.vbrick.com/reference/edituserdetails
#>
    [CmdletBinding()]
    param(
        # Id of the user to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName, ParameterSetName="Edit")]
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName, ParameterSetName="Fields")]
        [Alias("Id")]
        [string]
        $UserId,

        # Refer to http://jsonpatch.com/ for the format of the request body. (ex: [{ op="replace", path="/Title", value="new value" }])
        [Parameter(Mandatory, ParameterSetName="Edit")]
        [object[]]
        $Operations,

        [Parameter(ParameterSetName="Fields")] [string] $UserName,
        [Parameter(ParameterSetName="Fields")] [string] $FirstName,
        [Parameter(ParameterSetName="Fields")] [string] $LastName,
        [Parameter(ParameterSetName="Fields")] [string] $Email,
        [Parameter(ParameterSetName="Fields")] [string] $Title,
        [Parameter(ParameterSetName="Fields")] [string] $PhoneNumber,
        [Parameter(ParameterSetName="Fields")] [string] $Language,
        [Parameter(ParameterSetName="Fields")] [string[]] $GroupIds,
        [Parameter(ParameterSetName="Fields")] [string[]] $RoleIds,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter(ParameterSetName="Edit")][Parameter(ParameterSetName="Fields")]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $params = @{
        RequestArgs = $RequestArgs;
    };
    if ($null -ne $Operations) {
        $params.Body = $Operations;
    } else {
        $params.Body = @('UserName', 'FirstName', 'LastName', 'Email', 'Title', 'PhoneNumber', 'Language', 'GroupIds', 'RoleIds') | Where-Object { $PSCmdlet.MyInvocation.BoundParameters.$_ } | ForEach-Object {
            $key = $_;
            $val = $PSCmdlet.MyInvocation.BoundParameters.$key;

            if ($null -eq $val) {
                return;
            }

            @{ op = 'replace'; path = "/$key"; value = $val; }
        }
    }

    Invoke-Rev -Method Patch -Endpoint "/api/v2/users/$UserId" @params -Client $Client
}

function Get-RevGroup
{
<#
.SYNOPSIS
    Get Group Details By ID
.DESCRIPTION
    Users & Groups - Return group id, group name and group roles for a given group id.
.OUTPUTS
    @{
        [string] groupName, # Name of the Group.
        [string] groupId, # Id of the Group
        [object[]] roles,
    }
.LINK
    https://revdocs.vbrick.com/reference/getgroup
#>
    [CmdletBinding(DefaultParameterSetName="Id")]
    [OutputType([object])]

    param(
        # Id of the group to get details
        [Parameter(Mandatory, Position=0, ParameterSetName="Id", ValueFromPipelineByPropertyName)]
        [Alias("GroupId")]
        [string]
        $Id,

        # name of the group to get details
        [Parameter(Mandatory, ParameterSetName="Name", ValueFromPipelineByPropertyName)]
        [Alias("GroupName")]
        [string] $Name,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter(ParameterSetName="Id")][Parameter(ParameterSetName="Name")]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter(ParameterSetName="Id")][Parameter(ParameterSetName="Name")]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $GroupId = $Id;
    if ($PSCmdlet.ParameterSetName -eq "Name") {
        $groups = Search-RevUsersGroups -Query $Name -Count 5 -Type Group -PageSize 5 -Client $Client;
        $GroupId = $groups | Select-Object { $_.Name -ieq $Name } -First 1 -ExpandProperty 'Id';
        if (-not $GroupId) {
            return $null;
        }
    }

    Invoke-Rev -Method Get -Endpoint "/api/v2/groups/$GroupId" -RequestArgs $RequestArgs -Client $Client
}



function Remove-RevVideoComments
{
<#
.SYNOPSIS
    Delete Video Comments
.DESCRIPTION
    Videos - Delete all comments or specific comments for a given video.

.LINK
    https://revdocs.vbrick.com/reference/deletevideocomments
#>
    [CmdletBinding()]
    param(
        # Id of video to delete comments
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # If commentIds are not provided, then <em>all</em> comments for that video will be deleted. To delete specific comments , provide comma-separated commentIds.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $CommentIds,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/videos/$VideoId/comments" @params -Client $Client
}

function Remove-RevVideoChapters
{
<#
.SYNOPSIS
    Delete Video Chapters
.DESCRIPTION
    Videos - Deletes all (or specified) video chapters that have been uploaded for a given video.

.LINK
    https://revdocs.vbrick.com/reference/deletevideochapters
#>
    [CmdletBinding()]
    param(
        # Id of the video
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # List of video chapter start time(s) (comma delimited) to delete. An empty value means to delete <em>all</em> chapters associated to the video.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $StartTime,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/videos/$VideoId/chapters" @params -Client $Client
}

function Get-RevVideoWatchReport
{
<#
.SYNOPSIS
    Get Video Watch Report
.DESCRIPTION
    Videos - Get status on whether or not a specific user has completed watching a video.
.OUTPUTS
    @{
        [string] userId,
        [string] videoId,
        [bool] completed,
        [datetime] whenCompleted,
    }
.LINK
    https://revdocs.vbrick.com/reference/uservideocompletion
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get status for
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $VideoId,

        # Id of user to get status for
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $UserId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/users/$UserId/status" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevVideoSupplementalFiles
{
<#
.SYNOPSIS
    Delete Video Supplemental Files
.DESCRIPTION
    Videos - Deletes all or specific supplemental files for a given video.

.LINK
    https://revdocs.vbrick.com/reference/deletevideosupplementalfiles
#>
    [CmdletBinding()]
    param(
        # Id of the video
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Provide fileIds separated by a ',' to delete specific supplemental files. If fileIds not provided, then <em>all</em> supplemental files associated to that video will be deleted.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $FileIds,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/videos/$VideoId/supplemental-files" @params -Client $Client
}

function Get-RevVideoTranslationStatus
{
<#
.SYNOPSIS
    Get Video Translation Status
.DESCRIPTION
    Videos - Get status of a video translation.
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] status,
        [string] language,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideotranslationstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get status
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # language Id of video to get status
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $Language,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/translations/$Language/status" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoTranscriptionStatus
{
<#
.SYNOPSIS
    Get Video Transcription Status
.DESCRIPTION
    Videos - Get the status of a video transcription.
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] transcriptionId,
        [string] status,
        [string] language,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideotranscriptionstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get status
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $VideoId,

        # Transcription Id of video to get status
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $TranscriptionId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/transcriptions/$TranscriptionId/status" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoSupplementalFiles
{
<#
.SYNOPSIS
    Get Video Supplemental Files
.DESCRIPTION
    Videos - Retrieve the supplemental files of a video. This endpoint requires view access and returns a blank array if there are no supplemental files associated to the video.
.OUTPUTS
    @{
        [object[]] supplementalFiles,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideosupplementalfiles
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get the supplemental files
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/supplemental-files" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoSupplementalFile
{
<#
.SYNOPSIS
    Download Video Supplemental File
.DESCRIPTION
    Videos - Downloads a supplemental file based on the video and file Id provided. This endpoint requires view rights for the video.

.LINK
    https://revdocs.vbrick.com/reference/downloadvideosupplementalfile
#>
    [CmdletBinding()]
    param(
        # Id of video
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $VideoId,

        # File Id of the video's supplemental file to download
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $FileId,

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

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/supplemental-files/$FileId" @params -Client $Client
}

function New-RevVideoComment
{
<#
.SYNOPSIS
    Add Video Comments
.DESCRIPTION
    Videos - This endpoint is used to add a comment on a specified video. The username that submits the comment must exist in Rev. If a valid commentId is specified in the request, a child comment will be created. If commentId is not specified, a parent comment will be created.
.OUTPUTS
    @{
        [string] commentId,
    }
.LINK
    https://revdocs.vbrick.com/reference/addcomments
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to submit comments for
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # The text of the comment
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Comment,

        # Username submitting the comment. This user must exist in Rev. Unless the user has been assigned the Account Admin role, this user must also match the authenticated user making the API call.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $UserName,

        # If not provided, parent comment will be created. If parent commentId is provided, then it will create child comment to that parent. If child commentid is provided, then child comment for the corresponding parent comment will be created.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $CommentId,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/videos/$VideoId/comments" @params -Client $Client
}

function Request-RevVideoFacialRecognition
{
<#
.SYNOPSIS
    Tag Users in Video
.DESCRIPTION
    Videos - This endpoint sends a video for Facial Recognition and tags the user accounts recognized in the video. The Rev account must have <a href=/docs/facial-recognition>Facial Recognition</a> activated and the user account must be enabled for recognition (i.e., profile not opted out and have a recognizable profile picture uploaded). You must also have the <a href=/docs/roles-and-permissions#granular-roles-and-permissions>Rev IQ User</a> role to use this function.

.LINK
    https://revdocs.vbrick.com/reference/tagusersinvideo
#>
    [CmdletBinding()]
    param(
        # Id of the video to use in tagging users
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



    Invoke-Rev -Method Post -Endpoint "/api/v2/videos/$VideoId/user-tags" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevVideoTranscriptionFiles
{
<#
.SYNOPSIS
    Delete Video transcription Files
.DESCRIPTION
    Videos - Deletes all or specific transcription files for a given video.

.LINK
    https://revdocs.vbrick.com/reference/deletetranscriptionfiles
#>
    [CmdletBinding()]
    param(
        # Id of the video
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Provide locale's separated by a ',' to delete specific transcription files. If locale not provided, then <em>all</em> transcription files associated to that video will be deleted.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Locale,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/videos/$VideoId/transcription-files" @params -Client $Client
}

function Request-RevVideoTranscode
{
<#
.SYNOPSIS
    Transcode Video
.DESCRIPTION
    Videos - Transcode video on-demand with new presets. This endpoint bypasses the need to upload the video again.

.LINK
    https://revdocs.vbrick.com/reference/transcodevideo
#>
    [CmdletBinding()]
    param(
        # Id of video to transcode
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



    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId/transcode-on-demand" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoStatus
{
<#
.SYNOPSIS
    Get Video Status
.DESCRIPTION
    Videos - This endpoint retrieves the current status of a specific video during upload and when upload is complete. To know whether a video is fully processed, including transcoding, use the field <b>isProcessing</b> along with with <b>status</b> state that is returned in the response. <p>For example, if the value of <b>isProcessing</b> is FALSE and the status is <b>Ready</b>, then the video has been fully processed. If the value of <b>isProcessing</b> is TRUE and status is <b>Ready</b>, then it means the video is available for playback but the transcoding process is still in progress.</p><p>The progress of the overall processing of the video can be tracked using the field <b>overallProgress</b> whose value ranges from 0.0 to 1.0 where 1.0 means that the processing is 100% completed.</p><p>Possible status states during upload: [NotUploaded, Uploading, UploadingFinished, Ingesting, Processing]</p><p>Possible final status states once upload is complete: [Canceled, UploadFailed, ProcessingFailed, Ready, ReadyButProcessingFailed]</p>
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
.LINK
    https://revdocs.vbrick.com/reference/getvideostatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to retrieve status state
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/status" -RequestArgs $RequestArgs -Client $Client
}

function Request-RevVideoTranscribe
{
<#
.SYNOPSIS
    Transcribe Video
.DESCRIPTION
    Videos - This endpoint selects a transcription integration and generates a transcription file for a specified video.
.OUTPUTS
    @{
        [string] videoId,
        [string] transcriptionId,
        [string] status,
        [string] language,
        [string] transcriptionService, # Type of transcription service to use by Rev for the video transcription.
    }
.LINK
    https://revdocs.vbrick.com/reference/transcribevideo
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the video to transcribe
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # View the latest <a href=/docs/supported-languages>Supported Languages</a> in Rev technical requirements.
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("en", "en-gb", "fr", "de", "pt-br", "es", "zh-cmn-hans", "en-au", "hi", "nl", "it")]
        [string]
        $Language,

        # Vbrick, Voicebase, or null. If both are enabled, then Vbrick is used. If type = Vbrick, only Rev IQ user role can use this service/endpoint. This applies only if serviceType is Vbrick.
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Vbrick", "VoiceBase")]
        [string]
        $ServiceType,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/videos/$VideoId/transcription" @params -Client $Client
}

function Request-RevVideoTranslate
{
<#
.SYNOPSIS
    Translate Video
.DESCRIPTION
    Videos - Translates a specified video. You must include both the source language and an array of target languages to translate the source language to. You must also have the <a href=/docs/roles-and-permissions#granular-roles-and-permissions>Rev IQ User</a> role to use this function.
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] sourceLanguage,
        [object[]] targetLanguages,
    }
.LINK
    https://revdocs.vbrick.com/reference/translatevideo
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the video to translate
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        #
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("en", "en-gb", "fr", "de", "pt-br", "es", "zh-cmn-hans")]
        [string]
        $SourceLanguage,

        #
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $TargetLanguages,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/videos/$VideoId/translations" @params -Client $Client
}

function Set-RevVideoChapters
{
<#
.SYNOPSIS
    Update Video Chapters
.DESCRIPTION
    Videos - This endpoint uploads and edits a chapter(s) for a specified video. Using the <strong>PUT</strong> method (editing) chapters <em>replaces</em> an existing chapter if it is a duplicate timestamp. <p>New chapters are created if the chapter does not exist at the specified timestamp. There can be multiple chapter titles and start times.</p><p>The endpoint requires the user have edit rights to the video.</p>

.LINK
    https://revdocs.vbrick.com/reference/uploadvideochaptersupdate
#>
    [CmdletBinding()]
    param(
        # Id of video to upload chapters to
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



    Invoke-Rev -Method Put -Endpoint "/api/v2/uploads/chapters/$VideoId" -RequestArgs $RequestArgs -Client $Client
}

function Start-RevPresentationProfileRecording
{
<#
.SYNOPSIS
    Start/Schedule Presentation Profile Recording
.DESCRIPTION
    Videos - This endpoint starts or schedules a Presentation Profile recording. It does <em>not</em> reserve the source device or the recording device. It assumes that the source device is live and a recording device is available when the recording is scheduled to start.
.OUTPUTS
    @{
        [string] scheduledRecordingId,
    }
.LINK
    https://revdocs.vbrick.com/reference/startscheduledrecording
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        #
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $PresentationProfileId,

        # Default: false.  <p>If false, a DME defined in the presentation profile is used as the recording device. If true, the account primary/secondary recording device is used.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $UseAccountRecordingDevice,

        # Start date/time in UTC.  <p>Default: current date/time. If not specified, current time is used. Example: <code>2018-05-21T20:20:00Z</code></p>
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $StartDate,

        # End date/time in UTC. Default: 2 hours after the startDate.  <p>The default duration (2 hours) is a configurable system setting.  The max duration is 10 hours by default.  Example: <code>2018-05-21T20:20:00Z</code></p>
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $EndDate,

        # The title of the recording.  <p>Default: the presentation profile name.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Title,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/pp/start-recording" @params -Client $Client
}

function Start-RevVideoConferenceRecording
{
<#
.SYNOPSIS
    Start Video Conference Recording
.DESCRIPTION
    Videos - Video Conference endpoints allow you to record SIP-based video conference meetings and store/modify/search the resulting VOD videos in Rev. The VC endpoints are available only with a Rev-Cloud subscription.<p>Refer to <a href=/docs/video-conference-vc-integrations>Video Conference (VC)Integrations</a> for supported endpoints.</p><p>This endpoint starts a video conference recording. A SIP address and account access to the video conference recording integration is required.</p>
.OUTPUTS
    @{
        [string] videoId,
    }
.LINK
    https://revdocs.vbrick.com/reference/startrecording
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Name given to the video. Defaults to the SIP address if not provided.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Title,

        # SIP address for the video recording. Normally the conference room SIP address.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SipAddress,

        #
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SipPin,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/vc/start-recording" @params -Client $Client
}

function Stop-RevPresentationProfileRecording
{
<#
.SYNOPSIS
    Stop/Cancel Presentation Profile Recording
.DESCRIPTION
    Videos - This endpoint stops or cancels (if it has not started) a Webcast recording from a Presentation Profile. It requires the scheduledRecordingId returned from the Start/Schedule Recording endpoint.
.OUTPUTS
    @{
        [string] recordingVideoId,
        [string] status,
    }
.LINK
    https://revdocs.vbrick.com/reference/stopscheduledrecording
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Recording Id that needs to be stopped or cancelled
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $ScheduledRecordingId,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/pp/stop-recording" @params -Client $Client
}

function Stop-RevVideoConferenceRecording
{
<#
.SYNOPSIS
    Stop Video Conference Recording
.DESCRIPTION
    Videos - Stop a video conference recording.
.OUTPUTS
    @{
        [string] type,
    }
.LINK
    https://revdocs.vbrick.com/reference/stoprecording
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to stop recording
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoId,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/vc/stop-recording" @params -Client $Client
}

function Update-RevVideoAccessControl
{
<#
.SYNOPSIS
    Update Video Access Control
.DESCRIPTION
    Videos - This endpoint edits the Access Control permissions on a specific video.<p>Allows Access Control entities to be set for all four types. Note that if set to <b>Public</b>, the Public setting must first be enabled on the Rev account and a password may then be set if desired. If set to <b>Channels</b>, there should be one valid Channel in the account, otherwise the request is rejected. The default setting is <b>Private</b>.</p>

.LINK
    https://revdocs.vbrick.com/reference/editvideoaccesscontrol
#>
    [CmdletBinding()]
    param(
        # Id of video to modify access to
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # This sets access control for the video. Keep in mind that Access Controls are strictly dictated by <a href=/docs/roles-and-permissions>Roles and Permissions.</a> This is an enum and can have the following values: <code>Public/AllUsers/Private</code>. <p>A value of <strong>AllUsers</strong> is equal to all internal/authenticated users. A value of <strong>Private</strong> allows access to those Users, Groups, and Channels <em>explicitly</em> identified.</p><p> Be aware that you can assign multiple Users, Groups, and Channels in the <strong>accessControlEntites</strong> parameter in addition to the <strong>AllUser</strong> or <strong>Public</strong> settings. If no value is set, the default is <strong>Private</strong>.</p> <p>In the case of an incorrect value, the call is rejected with an HTTP 400 error.</p><p><strong>Note:</strong> If <strong>Channels</strong> is set at the videoAccessControl, it is translated to <strong>Private</strong> and a Channel <em>must</em> be specified in the accessControlEntities. If a Channel is included in the accessControlEntities, then the canEdit parameter is ignored.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Public", "AllUsers", "Private")]
        [string]
        $AccessControl,

        # This provides explicit rights to a <strong>User/Group/Channel</strong> along with editing rights <strong>(CanEdit)</strong> to a video. If any value is invalid, it is rejected while valid values are still associated with the video. @{ [string] id; [string] name; [string] type; [bool] canEdit }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $AccessControlEntities,

        # Only videos with Public access control can update the password with a value
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Password,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId/access-control" @params -Client $Client
}

function Update-RevVideoComments
{
<#
.SYNOPSIS
    Update Video Comments
.DESCRIPTION
    Videos - This endpoint is used to submit a comment on a specified video. The username that submits the comment must exist in Rev.<p>This endpoint will be deprecated in favor of the <a href=/reference/addcomments>Add Video Comments</a> endpoint.</p>

.LINK
    https://revdocs.vbrick.com/reference/submitcomments
#>
    [CmdletBinding()]
    param(
        # Id of video to submit comments for
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # The text of the comment
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Comment,

        # Username submitting the comment. This user must exist in Rev. Unless the user has been assigned the Account Admin role, this user must also match the authenticated user making the API call.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $UserName,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId/comment" @params -Client $Client
}

function Update-RevVideoDetails
{
<#
.SYNOPSIS
    Update Video Details/Metadata
.DESCRIPTION
    Videos - This endpoint is used to set or modify all metadata fields for a specific video. Note that if you are only changing one field (categories for example) <em>all</em> other metadata fields must also be submitted with this API call. Otherwise, those values that are not set are reset to defaults or nullified entirely.<p>To edit specific fields instead of all fields, use the <a href=/reference/migratevideo>Migrate Video</a> and/or <a href=/reference/editvideoaccesscontrol>Edit Video Access Control</a> endpoints instead.</p>

.LINK
    https://revdocs.vbrick.com/reference/editvideo
#>
    [CmdletBinding()]
    param(
        # Id of the video to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # The video title
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Title,

        # The video description
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Description,

        #  @{ [string] Url; [string] EncodingType; [string] Type; [bool] IsMulticast }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $LinkedUrl,

        # If you use categoryIds and they do not exist/are incorrect, the request is rejected. The request is also rejected if you do not have contribute rights to a restricted category and you attempt to add/edit or otherwise modify it.
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $Categories,

        # Assign the video to multiple tag GUIDs if desired
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Tags,

        # Default=false. The video status.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsActive,

        # Date field to prompt expirationAction. Format must be: <code>YYYY-MM-DD</code>.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ExpirationDate,

        # This sets action when video expires. This is an enum and can have the following values: Delete/Inactivate.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ExpirationAction,

        # By default, the publishDate is set to the current date the video is set to Active. You can also set the publishDate to a date in the future to make the video Active. If the video is already Active, the publishDate can be set to a date in the past. Format must be <code>YYYY-MM-DD</code> to avoid generating an error.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $PublishDate,

        # Default=true. Allows video to be rated.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $EnableRatings,

        # Default=true. Allows video to be downloaded.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $EnableDownloads,

        # Default=true. Allows comments on the video.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $EnableComments,

        # This sets access control for the video. Keep in mind that Access Controls are strictly dictated by <a href=/docs/roles-and-permissions>Roles and Permissions.</a> This is an enum and can have the following values: <code>Public/AllUsers/Private</code>. <p>A value of <strong>AllUsers</strong> is equal to all internal/authenticated users. A value of <strong>Private</strong> allows access to those Users, Groups, and Channels <em>explicitly</em> identified.</p><p> Be aware that you can assign multiple Users, Groups, and Channels in the <strong>accessControlEntites</strong> parameter in addition to the <strong>AllUser</strong> or <strong>Public</strong> settings. If no value is set, the default is <strong>Private</strong>.</p> <p>In the case of an incorrect value, the call is rejected with an HTTP 400 error.</p><p><strong>Note:</strong> If <strong>Channels</strong> is set at the videoAccessControl, it is translated to <strong>Private</strong> and a Channel <em>must</em> be specified in the accessControlEntities. If a Channel is included in the accessControlEntities, then the canEdit parameter is ignored.</p>
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Public", "AllUsers", "Private")]
        [string]
        $VideoAccessControl,

        # This provides explicit rights to a <strong>User/Group/Channel</strong> along with editing rights <strong>(CanEdit)</strong> to a video. If any value is invalid, it is rejected while valid values are still associated with the video. @{ [string] id; [string] name; [string] type; [bool] canEdit }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $AccessControlEntities,

        # Used if the videoAccessControl is set to Public.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Password,

        # An array of customFields attached to the video. If the customField does not exist in Rev or invalid values found for picklist, the upload fails. If values are not provided for a picklist and/or text field, they are not set for the video but the upload proceeds. The <a href=/reference/custommetadata>Get Custom Fields</a> endpoint retrieves a list of custom fields.<p>Note: If custom field is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the upload is rejected. Picklist types must be valid.</p> @{ [string] id; [string] name; [string] value; [bool] required; [bool] displayedToUsers; [string] fieldType }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CustomFields,

        # Specifies if the video is unlisted.  If unlisted, it is not visible or searchable in the Rev UI by other users.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Unlisted,

        # An array of user ids that are tagged in the video. The account must be licensed and enabled for Facial Recognition. If the user does not exist, a 500 error is returned.
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $UserTags,

        # By default, video owner is the user uploader unless otherwise assigned. The video owner automatically has view and edit rights and can include the Media Viewer role. <p>If a video owner is assigned, the uploader does <em>not</em> retain view/edit rights unless granted in video access controls.</p> @{ [string] userId; [string] username; [string] email }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $Owner,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId" @params -Client $Client -RateLimitKey "updateVideo"
}

function Update-RevVideoRating
{
<#
.SYNOPSIS
    Update Video Rating
.DESCRIPTION
    Videos - This endpoint is used to submit a numerical rating on a specified video.

.LINK
    https://revdocs.vbrick.com/reference/submitvideorating
#>
    [CmdletBinding()]
    param(
        # Id of video to set rating
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Numerical rating. Numbers 1 to 5. Must be a whole number, no decimals.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Rating,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$VideoId/rating" @params -Client $Client
}

function Request-RevVideoForApproval
{
<#
.SYNOPSIS
    Send Video for Approval
.DESCRIPTION
    Videos - Submits a video for approval to an approver.

.LINK
    https://revdocs.vbrick.com/reference/sendvideoapproval
#>
    [CmdletBinding()]
    param(
        # Id of video to approve
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Id of approval process template used to approve
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $TemplateId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$Id/approval/submitted/$TemplateId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideosPendingApproval
{
<#
.SYNOPSIS
    Get Videos Pending Approval
.DESCRIPTION
    Videos - Get a list of videos pending approval from an approver.
.OUTPUTS
    @{
        [string] id, # Id of video
        [string] title, # Title of video
        [string] htmlDescription, # Description of video
        [string] approvalStatus, # Approval Status of video
        [string] ApprovalProcessName, # Approval process name
        [string] ApprovalProcessStepName, # Current approval process step name
        [int] ApprovalProcessStepNumber, # Current approval process step number
        [int] ApprovalProcessStepsCount, # Total number of steps in the approval process
    }
.LINK
    https://revdocs.vbrick.com/reference/getpendingapprovalvideos
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Number of videos to get. Should not exceed 250 for better performance (By default count is 50)
        [Parameter()]
        [RevMetadataAttribute()]
        [int]
        $Count,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/approval/pending" @params -Client $Client
}

function Get-RevVideoPresentationChapterStatus
{
<#
.SYNOPSIS
    Get Video Presentation Chapter Status
.DESCRIPTION
    Videos - Retrieves the status of all presentation file chapters that have been uploaded for a specified video.<p>Status return values can be [Initialized, InProgress, Completed, Error]</p>
.OUTPUTS
    @{
        [string] status,
        [string] details, # Status description
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideopresentationstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get the presentation chapter status
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/presentation-status" -RequestArgs $RequestArgs -Client $Client
}

function Set-RevVideoThumbnail
{
<#
.SYNOPSIS
    Upload Video Thumbnail
.DESCRIPTION
    Videos - Uploads an alternate image to be used as a thumbnail for a specified video. Rev auto-generates a default thumbnail if you do not upload one of your choice. Note that if you replace Rev’s auto-generated thumbnail with one that you upload it will be deleted and may <em>not</em> be recovered.

.LINK
    https://revdocs.vbrick.com/reference/uploadthumbnailfiles
#>
    [CmdletBinding()]
    param(
        # Id of video to upload image
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Image
        [Parameter(Mandatory, Position=1, ValueFromPipeline)]
        [Alias("Thumbnail")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $fileField = New-RevFormDataField -Name "ThumbnailFile" -Value (Get-Item $Path);
    $form = New-RevFormData -Fields @($fileField);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/images/$VideoId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Set-RevVideoPresentation
{
<#
.SYNOPSIS
    Upload Video Presentation Chapters
.DESCRIPTION
    Videos - This endpoint uploads a PowerPoint presentation to create chapters for a specified video. <p>Posting chapters replaces <em>all</em> existing chapters a video contains. The first slide begins at 00:00:00 with the rest evenly distributed throughout the duration of the video. The slide titles are the names of the chapter titles. If there are slides without titles, the slide number is the title. The endpoint requires the user have edit rights to the video.</p>

.LINK
    https://revdocs.vbrick.com/reference/uploadpresentationfile
#>
    [CmdletBinding()]
    param(
        # Id of video to set presentation chapters
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Powerpoint File
        [Parameter(Mandatory, Position=1, ValueFromPipeline)]
        [Alias("PowerPoint")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    # force powerpoint content type
    $fileField = New-RevFormDataField -Name "File" -Value (Get-Item $Path) -ContentType 'application/vnd.ms-powerpoint';
    $form = New-RevFormData -Fields @($fileField);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/video-presentations/$VideoId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoReport
{
<#
.SYNOPSIS
    Get Video Report
.DESCRIPTION
    Videos - This endpoint returns detailed viewing information for one or more videos. The report includes individual video viewing sessions, along with information on whether each user completed the video.<p>If video Ids are not specified in the call, the response includes data for every video in your Rev account. Maximum duration for a reporting period is 31 days.
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] dateViewed,
        [string] userName,
        [string] firstName,
        [string] lastName,
        [string] emailAddress,
        [bool] completed,
        [string] zone,
        [string] device,
        [string] playBackUrl,
        [string] browser,
        [string] userDeviceType,
        [string] viewingTime,
        [string] publicCDNTime,
        [string] eCDNTime,
        [string] viewingStartTime,
        [string] viewingEndTime,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideoreport
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of video to return data for. If no Ids are specified, data for all videos in the system are returned.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoIds,

        # If after date is used, only video views with a start date <em>after</em> the specified date (up to 31 days) are included in the response. If <em>both</em> dates are used, video views between the specified dates are returned, not exceeding 31 days. If <em>no</em> dates are specified, video views between the current date and 31 days in the past from the start date are returned.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $After,

        # If before date is used, only video views with a start date <em>before</em> the specified date (up to 31 days) are included in the response. If <em>both</em> dates are used, video views between the specified dates are returned, not exceeding 31 days. If <em>no</em> dates are specified, video views between the current date and 31 days in the past from the start date are returned.
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $Before,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/report" @params -Client $Client
}

function Add-RevVideoClosedCaption
{
<#
.SYNOPSIS
    Upload Video Closed Caption
.DESCRIPTION
    Videos - Uploads closed caption files for a video for hearing impaired viewers. Only .srt or .vtt files are supported.

.LINK
    https://revdocs.vbrick.com/reference/uploadtranscriptionfiles
#>
    [CmdletBinding()]
    [Alias("Add-RevVideoTranscription")]
    param(
        # Id of video to set transcription files
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Subtitle Filename
        [Parameter(Mandatory, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory, Position=2)]
        [Alias("Lang")]
        [ValidateSet('de', 'en', 'en-gb', 'es-es', 'es-419', 'es', 'fr', 'fr-ca', 'id', 'it', 'ko', 'ja', 'nl', 'no', 'pl', 'pt', 'pt-br', 'th', 'tr', 'fi', 'sv', 'ru', 'el', 'zh', 'zh-tw', 'zh-cmn-hans')]
        [string]
        $Language,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $fileField = New-RevFormDataField -Name "File" -Value (Get-Item $Path) -ContentType 'application/x-subrip' -FileName "$Language.srt";

    $jsonData = [array]@(@{
        fileName = $fileField.FileName;
        language = $Language;
    });

    $jsonField = New-RevFormDataField -Name "TranscriptionFiles" -Value ($jsonData | ConvertTo-Json -Compress);

    $form = New-RevFormData -Fields @($fileField, $jsonField);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/transcription-files/$VideoId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Add-RevVideoChapters
{
<#
.SYNOPSIS
    Upload Video Chapters
.DESCRIPTION
    Videos - This endpoint uploads a chapter(s) for a specified video. Posting chapters replaces <em>all</em> existing chapters a video contains. There can be multiple chapter titles and start times. The endpoint requires the user have edit rights to the video.

.LINK
    https://revdocs.vbrick.com/reference/uploadvideochapters
#>
    [CmdletBinding()]
    param(
        # Id of video to upload chapters to
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Chapter objects in the format @{ time="00:10:01"; title="chapter title"; imageFile="C:\Temp\image.jpg" } . time is mandatory, and one or both of title and imageFile must be included as well.
        [Parameter(Mandatory, Position=1)]
        [object[]]
        $Chapters,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $form = New-RevFormData;

    $jsonData = @{};
    $jsonData.chapters = $Chapters | foreach-object {
        $chapter = $_;
        $out = @{
            time = if ($chapter.time) { $chapter.time } else { $chapter.startTime };
        }
        if ($chapter.title) {
            $out.title = $chapter.title;
        }
        # add image file to form
        if ($chapter.imageFile) {
            $fileInfo = Get-Item $chapter.imageFile;
            $field = New-RevFormDataField -Name "File" -Value (Get-Item $fileInfo);
            # set output filename to the calculated filename of payload rather than input full path
            $out.imageFile = $field.FileName;
            $form.Add($field.Content);
        }
        $out;
    };

    $jsonField = New-RevFormDataField -Name "Chapters" -Value ($jsonData | ConvertTo-Json -Compress);
    $form.Add($jsonField.Content);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/chapters/$VideoId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Approve-RevVideo
{
<#
.SYNOPSIS
    Approve Video
.DESCRIPTION
    Videos - Approve a specified video.

.LINK
    https://revdocs.vbrick.com/reference/approvevideo
#>
    [CmdletBinding()]
    param(
        # Id of video to approve
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Reason for approving the video
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Reason,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$Id/approval/approved" @params -Client $Client
}

function Assert-RevThumbnailFile
{
<#
.SYNOPSIS
    Get Video Thumbnail
.DESCRIPTION
    Videos - Get the video thumbnail file header info. The <strong>HEAD</strong> method is a pre-flight query that returns the size and mime-type to be added to the response Headers.

.LINK
    https://revdocs.vbrick.com/reference/headvideothumbnailfile
#>
    [CmdletBinding()]
    param(
        # File key of the video thumbnail to download.<p>Obtained via the <a href=/reference/getvideosdetails>Get Video Metadata</a> endpoint and the <b>thumbnailKey</b> property that is returned.</p>
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Key,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Head -Endpoint "/api/v2/media/videos/thumbnails/$Key" -RequestArgs $RequestArgs -Client $Client
}

function Deny-RevVideo
{
<#
.SYNOPSIS
    Reject Video
.DESCRIPTION
    Videos - Reject a video approval.

.LINK
    https://revdocs.vbrick.com/reference/rejectvideo
#>
    [CmdletBinding()]
    param(
        # Id of video to reject
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,

        # Reason for rejecting the video
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Reason,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/videos/$Id/approval/rejected" @params -Client $Client
}


function Add-RevVideoSupplementalFiles
{
<#
.SYNOPSIS
    Upload Video Supplemental Files
.DESCRIPTION
    Videos - This endpoint uploads one or more supplemental files to associate with a specified video. Typical file types include PowerPoint and PDF documents that provide a viewer with additional information.

.LINK
    https://revdocs.vbrick.com/reference/upload-supplemental-files
#>
    [CmdletBinding()]
    param(
        # Id of video to upload supplemental files
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $VideoId,

        # Attachment Filename
        [Parameter(Mandatory, Position=1, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )

    $form = New-RevFormData;

    # JSON array that lists the attachments and their filenames
    $jsonData = @{
        files = [system.collections.generic.list[object]]@();
    };

    $Path | ForEach-Object {
        $field = New-RevFormDataField -Name "File" -Value (Get-Item $_);
        $form.Add($field.Content);
        $jsonData.files.Add(@{ filename = $field.FileName });
    }

    $jsonField = New-RevFormDataField -Name "SupplementalFiles" -Value ($jsonData | ConvertTo-Json -Compress);

    $form.Add($jsonField.Content);

    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/supplemental-files/$VideoId" -Body $form -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoConferenceRecordingStatus
{
<#
.SYNOPSIS
    Get Video Conference Recording Status
.DESCRIPTION
    Videos - Get status of video conference recording.
.OUTPUTS
    @{
        [string] status,
    }
.LINK
    https://revdocs.vbrick.com/reference/recordingstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video to get status.
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $Id,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/vc/recording-status/$Id" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevPresentationProfileRecordingStatus
{
<#
.SYNOPSIS
    Get Presentation Profile Recording Status
.DESCRIPTION
    Videos - Get the status of the presentation profile recording. Status responses include [Scheduled, Starting, Recording, Stopping, Failed, Cancelled].
.OUTPUTS
    @{
        [datetime] startDate,
        [datetime] endDate,
        [string] status,
    }
.LINK
    https://revdocs.vbrick.com/reference/scheduledrecordingstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the scheduled recording
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $Scheduledrecordingid,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/pp/recording-status/$Scheduledrecordingid" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevPublicVideos
{
<#
.SYNOPSIS
    Get Public Videos
.DESCRIPTION
    Videos - Returns a list of public videos by category, status, and related metadata.
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [string] description,
        [string] thumbnailUrl,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideos
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # List of Category Ids to specify searching videos only in those categories.<p>Example: <code>Categories=a0e5cbf6-95cb-46e7-8600-4c07bc31f80b, b1f5cbf6-95cb-46e7-8600-4c07bc31g9pc.</code></p><p> Pass a blank entry to return uncategorized videos. Example: <code>Categories=</code></p>
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Category,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/videos" @params -Client $Client
}


function Get-RevUserTagStatusInVideo
{
<#
.SYNOPSIS
    Get User Tag Status in Video
.DESCRIPTION
    Videos - Get tagging status of users in a video.<p>Possible status states include: [InProgress, Failed, Finished]
.OUTPUTS
    @{
        [string] videoId,
        [string] title,
        [object] userTagsStatus,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideotaggingstatus
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the video to use in tagging users
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/user-tags/status" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoApprovalProcessesList
{
<#
.SYNOPSIS
    Get Video Approval Processes List
.DESCRIPTION
    Videos - Gets a list of previously created approval processes for a user. This endpoint is for the user that is authenticated to Rev making this API call.
.OUTPUTS
    @{
        [string] id, # Id of approval template
        [string] name, # Name of  approval template
    }
.LINK
    https://revdocs.vbrick.com/reference/getapprovalprocess
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/approval/templates" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoChapters
{
<#
.SYNOPSIS
    Get Video Chapters
.DESCRIPTION
    Videos - Returns all video chapters that have been uploaded for a given video.
.OUTPUTS
    @{
        [object[]] chapters,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideoschapters
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of the video to get chapters
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/chapters" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoComments
{
<#
.SYNOPSIS
    Get Video Comments
.DESCRIPTION
    Videos - Returns list of comments for a given video.
.OUTPUTS
    @{
        [string] id,
        [string] title,
        [object[]] comments,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideocomments
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of video to get comments
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/comments" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevVideoOEmbed
{
<#
.SYNOPSIS
    Get Video oEmbed
.DESCRIPTION
    Videos - Gets oEmbed JSON data for a given video for video embedding. This is typically used for integrations into other social systems with activity feeds so users can watch video inline of an activity feed.<p>This API does not require an authorization header.</p>
.OUTPUTS
    @{
        [int] height,
        [int] width,
        [string] html,
        [int] thumbnail_height,
        [int] thumbnail_width,
        [string] title,
        [string] type,
        [string] version,
    }
.LINK
    https://revdocs.vbrick.com/reference/oembed
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Rev URL of video to embed must be <code>URL (Percent) Encoded</code>. Please refer to https://en.wikipedia.org/wiki/Percent-encoding for details.  <p>Example:</p><p>Url: https://myRevURL.vbrick.com/#/videos/5e0625da-d2a0-45d7-a221-deb49b9623ab</p><p>Encoded Url: <code>https%3A%2F%2FmyRevURL.vbrick.com%2F%23%2Fvideos%2F5e0625da-d2a0-45d7-a221-deb49b9623ab</code></p><p> For shared url example :</p><p>Url: https://myRevURL.vbrick.com/sharevideo/5e0625da-d2a0-45d7-a221-deb49b9623ab</p> <p>Encoded shared Url: <code>https%3A%2F%2FmyRevURL.vbrick.com%2Fsharevideo%2F5e0625da-d2a0-45d7-a221-deb49b9623ab</code></p>
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Url,

        # Height of video to embed
        [Parameter()]
        [RevMetadataAttribute()]
        [int]
        $Height,

        # Width of video to embed
        [Parameter()]
        [RevMetadataAttribute()]
        [int]
        $Width,

        # Set if video autoplays on load
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $Autoplay,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/oembed" @params -Client $Client
}

function Get-RevVideoPlayback
{
<#
.SYNOPSIS
    Get Video Playback
.DESCRIPTION
    Videos - This endpoint retrieves a playback URL and thumbnail URL for a given video. Note that the playback URL is used for embedding purposes only and is <em>not</em> a direct link to the video file itself.
.OUTPUTS
    @{
        [object] video,
    }
.LINK
    https://revdocs.vbrick.com/reference/getvideoplaybackurl
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of video
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/videos/$VideoId/playback-url" -RequestArgs $RequestArgs -Client $Client
}

function Set-RevWebcastBranding
{
<#
.SYNOPSIS
    Upload Webcast Branding
.DESCRIPTION
    Webcasts - This endpoint uploads and updates a webcast branding settings for a specified webcast. <p>The endpoint requires the user have edit rights to the webcast.</p>

.LINK
    https://revdocs.vbrick.com/reference/uploadwebcastbranding
#>
    [CmdletBinding()]
    param(
        # Id of webcast to set the branding
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



    Invoke-Rev -Method Put -Endpoint "/api/v2/uploads/webcast-branding/$EventId" -RequestArgs $RequestArgs -Client $Client
}

function Set-RevWebcastBackgroundImage
{
<#
.SYNOPSIS
    Upload Webcast Background Image
.DESCRIPTION
    Webcasts - Upload background image file for a webcast. Note that when you upload a background image Rev always scales it to fit the various screen sizes. When a background image is returned in a subsequent call, the available scale sizes available are also returned.

.LINK
    https://revdocs.vbrick.com/reference/uploadbackgroundfile
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to upload image
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



    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/background-image/$EventId" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevWebcastVideoLink
{
<#
.SYNOPSIS
    Delete Webcast Video Link
.DESCRIPTION
    Webcasts - This endpoint deletes a video link from a Webcast.

.LINK
    https://revdocs.vbrick.com/reference/deletelinkedvideo
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to delete the current linked video file
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



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/linked-video" -RequestArgs $RequestArgs -Client $Client
}

function Update-RevWebcast
{
<#
.SYNOPSIS
    Update Webcast
.DESCRIPTION
    Webcasts - Edit an existing webcast.

.LINK
    https://revdocs.vbrick.com/reference/editevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

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

        # Default=false, Specifies if the exiting RTMP based webcast URL and Key needs to be regenerated.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $RegenerateRtmpUrlAndKey,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId" @params -Client $Client
}

function Set-RevWebcastPresentationFile
{
<#
.SYNOPSIS
    Upload Webcast Presentation File
.DESCRIPTION
    Webcasts - Upload a presentation file for a webcast.

.LINK
    https://revdocs.vbrick.com/reference/uploadpresentationfile
#>
    [CmdletBinding()]
    param(
        # Id of webcast to upload presentation file
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



    Invoke-Rev -Method Post -Endpoint "/api/v2/uploads/presentation/$EventId" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevWebcastPresentationFile
{
<#
.SYNOPSIS
    Delete Webcast Presentation File
.DESCRIPTION
    Webcasts - Delete the current presentation file for a webcast.

.LINK
    https://revdocs.vbrick.com/reference/deletepresentationfile
#>
    [CmdletBinding()]
    param(
        # Id of webcast to delete the current presentation file
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



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/presentation" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevWebcastsByCustomFieldOrDateRange
{
<#
.SYNOPSIS
    Delete Webcasts By Custom Field or Date Range
.DESCRIPTION
    Webcasts - This endpoint deletes all events for a given date range or custom field query. The response returns a jobId and a count of webcasts to be deleted. The jobId can be used to check the <a href=/reference/getdeletewebcastsjobstatus>status</a> of the deletion.
.OUTPUTS
    @{
        [string] jobId,
        [float] count,
        [string] statusUrl,
    }
.LINK
    https://revdocs.vbrick.com/reference/deleteevents
#>
    [CmdletBinding()]
    [OutputType([object])]

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

        # List of custom fields to use when searching for events to delete. All of the fields provided are concatenated as AND in the search request. The value to the property 'Value' is required. @{ [string] id; [string] value; [string] name }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $CustomFields,

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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events" @params -Client $Client
}

function Start-RevWebcast
{
<#
.SYNOPSIS
    Start Webcast
.DESCRIPTION
    Webcasts - Starts a webcast. <p>If attempts to start an event that uses live subtitles when the account has no viewing hours. Returns 401 unauthorized error with response message, 'This event requires viewing hours. Please disable subtitles or contact your Rev Admin.'</p>

.LINK
    https://revdocs.vbrick.com/reference/startevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to start
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Default=false. If true, a Pre-Production webcast is started.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $PreProduction,

        # Required for Webcasts with WebexLiveStream as a video source. This is the base64encoded string of the SBML json.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SbmlRequest,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/start" @params -Client $Client
}

function Update-RevWebcastVideoLink
{
<#
.SYNOPSIS
    Update Webcast Video Link
.DESCRIPTION
    Webcasts - This endpoint updates a video that was previously linked to from a webcast.

.LINK
    https://revdocs.vbrick.com/reference/updatelinkedvideo
#>
    [CmdletBinding()]
    param(
        # Id of webcast to update video link
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Id of video to replace on webcast
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $VideoId,

        # Default=true. Specify whether or not to redirect to the video automatically. If false, the user is taken to the Webcast Landing page instead.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $RedirectVod,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/linked-video" @params -Client $Client
}

function Start-RevWebcastRecording
{
<#
.SYNOPSIS
    Start Webcast Recording
.DESCRIPTION
    Webcasts - Start recording a webcast. <strong>Important:</strong> If <code>disableAutoRecording=false</code> in <a href=/reference/createevent>Create Webcast</a> and/or <a href=/reference/editevent>Update Webcast</a>, you cannot use this endpoint.  An error message is generated if you attempt to do so.

.LINK
    https://revdocs.vbrick.com/reference/startrecordingevent
#>
    [CmdletBinding()]
    param(
        # Id of webcast to start recording
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



    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/record" -RequestArgs $RequestArgs -Client $Client
}

function Stop-RevWebcast
{
<#
.SYNOPSIS
    End Webcast
.DESCRIPTION
    Webcasts - Ends a webcast.

.LINK
    https://revdocs.vbrick.com/reference/endevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to end
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Default=false. If true, a Pre-Production webcast is ended.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $PreProduction,

        # Default=false. If true, webcast is ended after a delay of 15s. This is currently only available to Partner accounts.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $GracefulEnd,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/start" @params -Client $Client
}

function Stop-RevWebcastBroadcast
{
<#
.SYNOPSIS
    Stop Broadcasting Webcast
.DESCRIPTION
    Webcasts - Stop broadcasting a webcast.

.LINK
    https://revdocs.vbrick.com/reference/pausebroadcastevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to stop broadcasting
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Default=false. If true, webcast broadast is stopped after a delay of 15s. This is currently only available to Partner accounts.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $GracefulEnd,


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

    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/broadcast" @params -Client $Client
}

function Stop-RevWebcastRecording
{
<#
.SYNOPSIS
    Stop Webcast Recording
.DESCRIPTION
    Webcasts - Stop recording a webcast. <strong>Important:</strong> If <code>disableAutoRecording=false</code> in <a href=/reference/createevent>Create Webcast</a> and/or <a href=/reference/editevent>Update Webcast</a>, you cannot use this endpoint.  An error message is generated if you attempt to do so.

.LINK
    https://revdocs.vbrick.com/reference/stoprecordingevent
#>
    [CmdletBinding()]
    param(
        # Id of webcast to stop recording
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



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/record" -RequestArgs $RequestArgs -Client $Client
}

function Update-RevGuestRegistration
{
<#
.SYNOPSIS
    Update Guest Registration
.DESCRIPTION
    Webcasts - Edits a specific Public webcast guest user's registration.

.LINK
    https://revdocs.vbrick.com/reference/editguestuser
#>
    [CmdletBinding()]
    param(
        # Id of the Public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Id of guest user's registration to edit
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $RegistrationId,

        # Name of guest user. Required.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Must be a vaild email format. Required and must be unique. Email is used for validation and cannot be updated. Should match with provided registrationId user mail.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Email,

        # RegistrationFields used in webcast endpoints. If the registrationFields does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds).<p>Note: If a webcast registration field  is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p> @{ [string] id; [string] name; [string] value }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $RegistrationFieldsAnswers,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/registrations/$RegistrationId" @params -Client $Client
}

function Remove-RevWebcastBackgroundImage
{
<#
.SYNOPSIS
    Delete Webcast Background Image
.DESCRIPTION
    Webcasts - Delete the current background image for a webcast.

.LINK
    https://revdocs.vbrick.com/reference/deletebackgroundimage
#>
    [CmdletBinding()]
    param(
        # ID of the webcast to delete the background image
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



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/background-image" -RequestArgs $RequestArgs -Client $Client
}

function Update-RevWebcastAccessControl
{
<#
.SYNOPSIS
    Update Webcast Access Control
.DESCRIPTION
    Webcasts - Edits access control entities of an existing webcast.

.LINK
    https://revdocs.vbrick.com/reference/editeventcontrolentities
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to edit
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # User Ids on the access control list
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $UserIds,

        # Usernames for users on the access control list
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $Usernames,

        # Group Ids on the access control list
        [Parameter()]
        [RevMetadataAttribute()]
        [string[]]
        $GroupIds,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/access-control" @params -Client $Client
}

function Start-RevWebcastBroadcast
{
<#
.SYNOPSIS
    Start Broadcasting Webcast
.DESCRIPTION
    Webcasts - Start broadcasting a webcast.

.LINK
    https://revdocs.vbrick.com/reference/broadcastevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to start broadcasting
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



    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/broadcast" -RequestArgs $RequestArgs -Client $Client
}

function Remove-RevWebcast
{
<#
.SYNOPSIS
    Delete Webcast
.DESCRIPTION
    Webcasts - Delete a webcast.

.LINK
    https://revdocs.vbrick.com/reference/deleteevent
#>
    [CmdletBinding()]
    param(
        # Id of the webcast to delete
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



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId" -RequestArgs $RequestArgs -Client $Client
}

function New-RevGuestRegistration
{
<#
.SYNOPSIS
    Add Guest Registration
.DESCRIPTION
    Webcasts - Register one or more attendees/guest users for an upcoming Public webcast. Make sure you first enable Public webcast pre-registration before adding registrations.
.OUTPUTS
    @{
        [string] name, # Name of guest user.
        [string] email, # EmailId of the guestUser.
        [string] registrationId, # RegistrationId. Id of the registered guest user.
        [string] eventId, # EventId of the webcast for which guest user registered.
        [string] token, # Guest user token that can be used on the webcast link to the public event to automatically log the public user into the event.
        [object[]] registrationFieldsAnswers, # RegistrationFields used in webcast endpoints. If the registrationFields does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds).<p>Note: If a webcast registration field  is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p>
    }
.LINK
    https://revdocs.vbrick.com/reference/createguestwebcastuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the upcoming public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Name of guest user. Required.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Name,

        # Must be a vaild email format. Required and must be unique.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $Email,

        # RegistrationFields used in webcast endpoints. If the registrationFields does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds).<p>Note: If a webcast registration field  is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p> @{ [string] id; [string] name; [string] value }
        [Parameter()]
        [RevMetadataAttribute()]
        [object[]]
        $RegistrationFieldsAnswers,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/scheduled-events/$EventId/registrations" @params -Client $Client
}

function Get-RevWebcastAttendeesRealtime
{
<#
.SYNOPSIS
    Get Webcast Attendees Realtime
.DESCRIPTION
    Webcasts - Retrieves real-time attendees of a running webcast.
.OUTPUTS
    @{
        [string] scrollId,
        [float] total,
        [float] hostCount,
        [float] moderatorCount,
        [float] attendeeCount, # The sum of the count of attendee and account admin in user type.
        [object[]] attendees,
        [string] status, # Indicates the state of the real-time aggregation of a webcast. Possible values: 'Active', 'Initiated'. Active = webcast is currently aggregating. Initiated = a request to start aggregating is processed.
        [int] experiencedRebufferingPercentage, # In percentage.
        [int] averageExperiencedRebufferDuration,
        [int] experiencedErrorsPerAttendees,
        [int] multicastErrorsPerAttendees,
    }
.LINK
    https://revdocs.vbrick.com/reference/getrealtimeattendeessearchrequest
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the currently running webcast to get attendees
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,


        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter()]
        [RevMetadataAttribute()]
        [int32]
        $RunNumber,

        # Default=Full Name
        [Parameter()]
        [ValidateSet('FullName', 'Email', 'ZoneName', 'StreamType', 'IpAddress', 'Browser', 'OsFamily', 'StreamAccessed', 'PlayerDevice', 'OsName', 'UserType', 'Username', 'AttendeeType')]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # How data is sorted in the response. Supported Values: 'asc', 'desc'. Default is 'asc'
        [Parameter()]
        [ValidateSet("asc","desc")]
        [RevMetadataAttribute()]
        [string]
        $SortDirection,

        # Number of matching records to return in the response. Default is 50. Maximum is 500.
        [Parameter()]
        [RevMetadataAttribute("Count")]
        [int32]
        $PageSize,

        # Search query. When specified, searches the Search Fields for the specified string.
        [Parameter()]
        [Alias("Query")]
        [RevMetadataAttribute()]
        [string]
        $Q,

        # A comma-separated list of fields to include in search. <p>Supported fields: 'FullName', 'Email', 'ZoneName', 'StreamType', 'IpAddress', 'Browser', 'OsFamily', 'StreamAccessed', 'PlayerDevice', 'OsName', 'UserType', 'Username', 'AttendeeType'</p>
        [Parameter()]
        [ValidateSet('FullName', 'Email', 'ZoneName', 'StreamType', 'IpAddress', 'Browser', 'OsFamily', 'StreamAccessed', 'PlayerDevice', 'OsName', 'UserType', 'Username', 'AttendeeType')]
        [RevMetadataAttribute()]
        [string]
        $SearchField,

        # User session status. Supported values: 'All', 'Online', 'Offline'. Default is 'All'.
        [Parameter()]
        [ValidateSet("All", "Online", "Offline")]
        [RevMetadataAttribute()]
        [string]
        $Status,

        # The shape of data to return in the response. Supported values: 'Base', 'All' and 'Counts'. Default is 'Base'. 'Counts' returns total count for host (hostCount), moderator (moderatorCount), and attendees (attendeeCount). 'Base' returns just 'UserId', 'Username', 'Email', 'StartTime', 'SessionId', 'FullName'. The values for the total count are also included. 'All includes 'Base' details, metrics, session, system, and user details. The values for the total count are also included.
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("All", "Base", "Counts")]
        [string]
        $AttendeeDetails,

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

    Get-InternalRevResultSet -Method Post -Endpoint "/api/v2/scheduled-events/$EventId/real-time/attendees" -TotalKey "total" -HitsKey "attendees" -Activity "Getting Attendees..." @params -Client $Client -RateLimitKey "attendeesRealtime";
}

function Get-RevWebcastAttendees
{
<#
.SYNOPSIS
    Get Webcast Attendees Report
.DESCRIPTION
    Webcasts - Get attendees for a completed webcast. You may specify Pre-Production versus Main Event.
.OUTPUTS
    @{
        [int] totalSessions,
        [string] totalPublicCDNTime,
        [string] totalECDNTime,
        [float] hostCount,
        [float] moderatorCount,
        [float] attendeeCount, # The sum of the count of attendee and account admin in user type.
        [int] experiencedRebufferingPercentage, # In percentage.
        [int] averageExperiencedRebufferDuration,
        [int] experiencedErrorsPerAttendees,
        [int] multicastErrorsPerAttendees,
        [object[]] sessions,
        [string] scrollId,
    }
.LINK
    https://revdocs.vbrick.com/reference/getposteventsessions
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to get attendee report
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter()]
        [RevMetadataAttribute()]
        [int32]
        $RunNumber,

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

    Get-InternalRevResultSet -Method Get -Endpoint "/api/v2/scheduled-events/$eventId/post-event-report" -TotalKey "totalSessions" -HitsKey "sessions" -Activity "Getting Entities..." -RateLimitKey "viewReport" @params -Client $Client;
}

function New-RevWebcastAnswer
{
<#
.SYNOPSIS
    Add Webcast Answer
.DESCRIPTION
    Webcasts - Add answer to a webcast question.
.OUTPUTS
    @{
        [datetime] whenAsked,
        [string] question,
        [string] askedBy,
        [string] repliedBy,
        [datetime] whenReplied,
        [string] lastAction,
        [string] reply,
        [bool] isPublic,
    }
.LINK
    https://revdocs.vbrick.com/reference/puteventquestionanswer
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Id of the question to add answer to
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $QuestionId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RunNumber,

        # Answer text to add
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $AnswerText,

        # The reason the question is closed. Values include [Declined, FollowUp, Answered, RepliedDirectly]
        [Parameter()]
        [RevMetadataAttribute()]
        [ValidateSet("Declined", "FollowUp", "Answered", "RepliedDirectly")]
        [string]
        $CloseReason,

        # The user that asks/answers a question. Defaults to the authenticated API user. If specified, the user must have at least view permission on the Webcast (Attendee, Account Admin, Moderator, or Host). @{ [string] Id; [string] Username; [string] Email }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $AnsweredBy,

        # Default=true. Specifies if the answer is Private or Public.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsPublic,

        # Timestamp when the question is answered
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $WhenAnswered,

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

    Invoke-Rev -Method Put -Endpoint "/api/v2/scheduled-events/$EventId/questions/$QuestionId/answer" @params -Client $Client
}

function Edit-RevGuestRegistration
{
<#
.SYNOPSIS
    Patch Guest Registration
.DESCRIPTION
    Webcasts - Partially edits specific guest user registration details of a Public webcast. You do not need to provide the fields that you are not changing. Please refer to http://jsonpatch.com/ for the format of the request body.<p>Patch operations on User details editable fields [Name, RegistrationFieldsAnswers].</p>

.LINK
    https://revdocs.vbrick.com/reference/patchguestuser
#>
    [CmdletBinding()]
    param(
        # Id of the Public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Id of guest user's registration to patch
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $RegistrationId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Patch -Endpoint "/api/v2/scheduled-events/$EventId/registrations/$RegistrationId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevAllRegistrationsForAWebcast
{
<#
.SYNOPSIS
    Get All Registrations for a Webcast
.DESCRIPTION
    Webcasts - Retrieve a list of <em>all</em> registrations for a specific Public webcast (with optional pagination).
.OUTPUTS
    @{
        [string] scrollId, # ScrollId Used for retrieving next set of guestusers.
        [object[]] guestUsers,
    }
.LINK
    https://revdocs.vbrick.com/reference/getguestusers
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the upcoming Public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # If provided, query results are sorted based on field (name, email). Default is set to name.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # If provided, query results are sorted on ascending or descending order (asc, desc).
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SortDirection,

        # Page size. Default is 10.
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $Size,

        # The scrollId returned in first request. This can be passed in subsequent requests to fetch next set of results. This is forward only and you cannot get back the search results that are scrolled once.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ScrollId,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/registrations" @params -Client $Client
}

function Remove-RevGuestRegistration
{
<#
.SYNOPSIS
    Delete Guest Registration
.DESCRIPTION
    Webcasts - Deletes a specific guest user registration for a Public webcast.

.LINK
    https://revdocs.vbrick.com/reference/deleteguestuser
#>
    [CmdletBinding()]
    param(
        # Id of the Public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Id of guest user's registration to delete
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $RegistrationId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Delete -Endpoint "/api/v2/scheduled-events/$EventId/registrations/$RegistrationId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevDeleteWebcastsJobStatus
{
<#
.SYNOPSIS
    Get Delete Webcasts Job Status
.DESCRIPTION
    Webcasts - Get the status of the <a href=/reference/deleteevents>Delete Webcasts By Custom Field or Date Range</a> job.<p>Status states returned can be [Initialized, InProgress, Completed]
.OUTPUTS
    @{
        [string] jobId,
        [string] status,
        [float] count,
        [float] processedCount,
        [float] failedCount,
        [float] remainingCount,
    }
.LINK
    https://revdocs.vbrick.com/reference/getdeletewebcastsjobstatus
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # jobId returned in <a href=/reference/deleteevents>Delete Webcasts By Custom Field or Date Range</a> endpoint
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $JobId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/delete-status/$JobId" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevWebcastAttendeesReportDeprecated
{
<#
.SYNOPSIS
    Get Webcast Attendees Report (Deprecated)
.DESCRIPTION
    Webcasts - This is a deprecated version.  Use <a href=/reference/getposteventsessions>Get Webcast Attendees Report</a> instead.
.OUTPUTS
    [object]
.LINK
    https://revdocs.vbrick.com/reference/geteventreport
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to get the attendee report
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/report" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevWebcastComments
{
<#
.SYNOPSIS
    Get Webcast Comments Log
.DESCRIPTION
    Webcasts - Get comments log for a specified webcast.
.OUTPUTS
    @{
        [object] general,
        [object] header,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventcomments
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of the webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $RunNumber,

        # The number of comments to return. The default is 10000 if not specified. Can use with scrollId on return. Example: If totalComments > Count/Size, then provide the scrollId returned from the first request to get the next set of comments. (e.g. scrollId=n)
        [Parameter()]
        [RevMetadataAttribute()]
        [float]
        $Size,

        # The scrollId returned in first request to search. This can be passed in subsequent requests to fetch next set of results. This is forward only and you cannot get back the search results that are scrolled once.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ScrollId,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/comments" @params -Client $Client
}

function Get-RevWebcastPlaybackURLs
{
<#
.SYNOPSIS
    Get Webcast Playback URLs
.DESCRIPTION
    Webcasts - Get a list of all playback urls for a given webcast.
.OUTPUTS
    @{
        [string] Label,
        [int] QValue,
        [string] Player,
        [string] Url,
        [string] ZoneId,
        [int] SlideDelaySeconds,
        [string] VideoFormat,
        [string] VideoInstanceId,
        [string] DeviceId,
    }
.LINK
    https://revdocs.vbrick.com/reference/getplaybackurl
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to get urls
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # Device user agent. This is used for determining the stream to deliver
        [Parameter()]
        [RevMetadataAttribute('Headers/User-Agent')]
        [string]
        $UserAgent,

        # IP addresses of user/client with comma separated values (Example: <code>127.0.0.0</code>, <code>10.0.10.124</code>). This is used for <a href=/docs/manage-and-add-zones>Zoning rules</a> in determining the streams to return.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $Ip,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/playback-url" @params -Client $Client
}

function Get-RevWebcastPollReport
{
<#
.SYNOPSIS
    Get Webcast Poll Report
.DESCRIPTION
    Webcasts - Get poll(s) report for a specified webcast.
.OUTPUTS
    @{
        [string] question,
        [int] totalResponses,
        [int] totalNoResponses,
        [bool] allowMultipleAnswers,
        [datetime] whenPollCreated,
        [object[]] pollAnswers,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventpolls
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of the webcast to get poll report
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $RunNumber,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/poll-results" @params -Client $Client
}

function Get-RevWebcastPresentationFile
{
<#
.SYNOPSIS
    Get Webcast Presentation File
.DESCRIPTION
    Webcasts - Get the current presentation file for a webcast.

.LINK
    https://revdocs.vbrick.com/reference/downloadpresentationfile
#>
    [CmdletBinding()]
    param(
        # Id of webcast to get the current presentation file
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



    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/presentation" -RequestArgs $RequestArgs -Client $Client
}

function Get-RevWebcastQAReport
{
<#
.SYNOPSIS
    Get Webcast Q&A Report
.DESCRIPTION
    Webcasts - Get questions and answers report of a specified webcast.
.OUTPUTS
    @{
        [datetime] whenAsked,
        [string] question,
        [string] askedBy,
        [string] repliedBy,
        [datetime] whenReplied,
        [string] lastAction,
        [string] reply,
        [bool] isPublic,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventquestions
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Id of the webcast to get Q&A report
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [string]
        $RunNumber,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/questions" @params -Client $Client
}

function Get-RevWebcastsByTimeRange
{
<#
.SYNOPSIS
    Get Webcasts By Time Range
.DESCRIPTION
    Webcasts - Gets a list of webcasts for a given time duration.
.OUTPUTS
    @{
        [string] id, # Id of event
        [string] title, # Title of event
        [string] description, # Description of event
        [datetime] startDate, # Event Start Date
        [datetime] endDate, # Event End Date
        [string] listingType, # This is an access control enum and can have the following values: Public/TrustedPublic/AllUsers/Private. TrustedPublic option is only available for Partners and WebexEvents type webcasts.
        [string] eventUrl, # url of event
        [object[]] backgroundImages,
        [object[]] categories,
        [string[]] tags,
        [bool] unlisted,
        [int] estimatedAttendees,
        [int] lobbyTimeMinutes,
        [object] preProduction, # Use if creating a pre-production event to set designated pre-production attendees and duration.
        [string] shortcutName,
        [string] videoSourceType, # This is an enum and can have the following values: PresentationProfile, Rtmp, SipAddress, WebexTeam, WebexLiveStream, Zoom, Vod, WebrtcSinglePresenter. WebrtcSinglePresenter represents <i>Webcam and Screenshare</i> source in rev UI.  This field is required to create/edit WebexLiveStream event.
        [object] rtmp, # Used if recording a rtmp stream as the video source.
        [string] webcastType, # Scheduled event type used for integrations, default value is Rev.
        [object] webexTeam, # Used if recording a Webex Team meeting as the video source.
        [object] zoom, # Used if recording a Zoom meeting as the video source.
        [string] vodId,
        [string] presenterId,
    }
.LINK
    https://revdocs.vbrick.com/reference/geteventslist
#>
    [CmdletBinding()]
    [OutputType([object[]])]

    param(
        # Events with an end date after specified date are included in the response. If date not included, this will by default be set to either 12 months prior to the before parameter, or the current date and time if before is not set.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $After,

        # Events with a start date on or before specified date are included in the response. If date not included, this will by default be set to either 12 months after the after parameter, or 12 months from the current date and time if after is not set.
        [Parameter(Mandatory)]
        [RevMetadataAttribute()]
        [datetime]
        $Before,

        # If provided, the query results are sorted based on field(startDate, title). Default is set to startDate.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SortField,

        # If provided, the query results are sorted on ascending or descending order(asc, desc)
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $SortDirection,


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

    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events" @params -Client $Client
}


function Get-RevGuestRegistration
{
<#
.SYNOPSIS
    Get Guest Registration
.DESCRIPTION
    Webcasts - Retrieve details of a specific guest user Public webcast registration.
.OUTPUTS
    @{
        [string] name, # Name of guest user.
        [string] email, # EmailId of the guestUser.
        [string] registrationId, # RegistrationId. Id of the registered guest user.
        [string] token, # Guest user token that can be used on the webcast link to the public event to automatically log the public user into the event.
        [object[]] registrationFieldsAnswers, # RegistrationFields used in webcast endpoints. If the registrationFields does not exist in Rev or invalid values are found for picklists, an error is returned. If values are not provided for a picklist and/or text field, they are not set (the endpoint proceeds).<p>Note: If a webcast registration field  is marked required in Rev, it <em>must</em> be provided in API call, otherwise it is optional. If it is required and not provided, the call is rejected. Picklist types must be valid.</p>
        [datetime] whenCreated,
        [datetime] whenModified,
    }
.LINK
    https://revdocs.vbrick.com/reference/getguestuser
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the Public webcast
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [string]
        $EventId,

        # Id of guest user's registration to retrieve
        [Parameter(Mandatory, Position=1, ValueFromPipelineByPropertyName)]
        [string]
        $RegistrationId,


        # Extra arguments to pass to Invoke-WebRequest
        [Parameter()]
        [hashtable]
        $RequestArgs = @{},

        # The Rev Client instance to use. If not defined use default one for this session
        [Parameter()]
        [RevClient]
        $Client = (Get-RevClient)
    )



    Invoke-Rev -Method Get -Endpoint "/api/v2/scheduled-events/$EventId/registrations/$RegistrationId" -RequestArgs $RequestArgs -Client $Client
}

function New-RevWebcastQuestion
{
<#
.SYNOPSIS
    Add Webcast Question
.DESCRIPTION
    Webcasts - Adds a question to a webcast.
.OUTPUTS
    @{
        [string] questionId,
    }
.LINK
    https://revdocs.vbrick.com/reference/puteventquestion
#>
    [CmdletBinding()]
    [OutputType([object])]

    param(
        # Id of the webcast to add a question
        [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)]
        [Alias("Id")]
        [string]
        $EventId,

        # The current run of the referred event. Defaults to Main Event runNumber(0). Should be passed for pre-production.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $RunNumber,

        # Question text to add
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $QuestionText,

        # External questionId if any are in external system. Default is blank.
        [Parameter()]
        [RevMetadataAttribute()]
        [string]
        $ExternalId,

        # The user that asks/answers a question. Defaults to the authenticated API user. If specified, the user must have at least view permission on the Webcast (Attendee, Account Admin, Moderator, or Host). @{ [string] Id; [string] Username; [string] Email }
        [Parameter()]
        [RevMetadataAttribute()]
        [object]
        $AskedBy,

        # Default=false. When true, question is set to anonymous.
        [Parameter()]
        [RevMetadataAttribute()]
        [bool]
        $IsAnonymous,

        # Timestamp when question is asked
        [Parameter()]
        [RevMetadataAttribute()]
        [datetime]
        $WhenAsked,

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

    Invoke-Rev -Method Post -Endpoint "/api/v2/scheduled-events/$EventId/questions" @params -Client $Client
}
