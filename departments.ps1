[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$c = $configuration | ConvertFrom-Json

$ClientId = $c.clientid
$ClientSecret = $c.clientsecret
$BaseUrl = "https://api.personio.de/v2"

#region functions
function Invoke-PersonioRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Headers
    )

    process {
        try {
            # Write-Information "Invoking command '$($MyInvocation.MyCommand)' to Uri '$Uri'"
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::tls12

            [System.Collections.ArrayList]$ReturnValue = @()

            $tempUri = $Uri
            do {
                $splatRestMethodParameters = @{
                    Uri         = "$($tempUri)"
                    Method      = 'GET'
                    ContentType = 'application/json'
                    Headers     = $Headers
                    Verbose     = $false
                    ErrorAction = 'Stop'
                }
            
                $response = Invoke-RestMethod @splatRestMethodParameters

                if($response.'_data' -ne $null){
                
                    if ($response.'_data' -is [array]) {
                        [void]$ReturnValue.AddRange($response.'_data')
                    }
                    else {
                        [void]$ReturnValue.Add($response.'_data')
                    }
                }
                else {
                    [void]$ReturnValue.Add($response)
                }
                
                $tempUri = $($response.'_meta'.links.next.href)
                
            } while ($tempUri)

            return $ReturnValue

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion functions

try{
    $Body = @{
        client_id = $ClientId
        client_secret = $ClientSecret
        grant_type = 'client_credentials';
    };

    $header = [ordered]@{
        "Accept" = "application/json";
        "Content-Type" = 'application/x-www-form-urlencoded';
        'X-Personio-App-ID' = $c.PersonioAppId;
        'X-Personio-Partner-ID' = $c.PersonioPartnerId;
    }

    $response = Invoke-RestMethod -Method Post -Uri "https://api.personio.de/v2/auth/token" -Body $Body -Headers $header
    $accessToken = $response.access_token

    $authorizationHeaders = [ordered]@{
        Authorization = "Bearer $accesstoken";
        'Content-Type' = "application/json";
        Accept = "application/json";
        'X-Personio-App-ID' = $c.PersonioAppId;
        'X-Personio-Partner-ID' = $c.PersonioPartnerId;
    }

    $orgUnits = Invoke-PersonioRestMethod -Uri "$BaseUrl/org-units?type=department" -Headers $authorizationHeaders

    foreach ($orgUnit in $orgUnits)
    {
        $department = @{
            DisplayName = $orgUnit.name
            ExternalId = $orgUnit.id
            #ParentExternalId = $orgUnit.parent_id
        }
        
        Write-Output ($department | ConvertTo-Json -Depth 20);
    }

    Write-Verbose -Verbose "Department import completed";
}
catch {
    $ex = $PSItem
    Write-verbose -Verbose "Could not retrieve Personio employees. Error: $($ex.Exception.Message)"
    Write-verbose -Verbose "Could not retrieve Personio employees. ErrorDetails: $($ex.ErrorDetails)"
    throw ($ex)
}
