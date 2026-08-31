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

            #Write-Verbose "Retrieved $($ReturnValue.Count) objects for $Uri"

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
    
    $persons = Invoke-PersonioRestMethod -Uri "$BaseUrl/persons" -Headers $authorizationHeaders 

    $legalEntities = Invoke-PersonioRestMethod -Uri "$BaseUrl/legal-entities" -Headers $authorizationHeaders
    $legalEntitiesGrouped = $legalEntities | Group-Object id -CaseSensitive -AsHashTable -AsString

    $orgUnits = Invoke-PersonioRestMethod -Uri "$BaseUrl/org-units?type=department" -Headers $authorizationHeaders
    $orgUnitsGrouped = $orgUnits | Group-Object id -CaseSensitive -AsHashTable -AsString

    $workPlaces = Invoke-PersonioRestMethod -Uri "$BaseUrl/workplaces" -Headers $authorizationHeaders
    $workPlacesGrouped = $workPlaces | Group-Object id -CaseSensitive -AsHashTable -AsString

    $costCenters = Invoke-PersonioRestMethod -Uri "$BaseUrl/cost-centers" -Headers $authorizationHeaders
    $costCentersGrouped = $costCenters | Group-Object id -CaseSensitive -AsHashTable -AsString

    $jobs = Invoke-PersonioRestMethod -Uri "$BaseUrl/jobs" -Headers $authorizationHeaders
    $jobsGrouped = $jobs | Group-Object id -CaseSensitive -AsHashTable -AsString

    foreach ($person in $persons)
    {
        [System.Collections.ArrayList]$expandedEmployments = @()

        $personEmployments = Invoke-PersonioRestMethod -Uri "$BaseUrl/persons/$($person.id)/employments" -Headers $authorizationHeaders

        if ($null -ne $personEmployments) {
            foreach ($employment in $personEmployments) {
                $legalEntity = $legalEntitiesGrouped["$($employment.legal_entity.id)"]
                if ($null -ne $legalEntity) {
                    # In case multiple are found with the same ID, we always select the first one in the array
                    $legalEntity = $legalEntity | Select-Object -First 1

                    if (![string]::IsNullOrEmpty($legalEntity)) {
                        foreach ($property in $legalEntity.PsObject.Properties) {
                            # Add a property for each field in object
                            $employment | Add-Member -MemberType NoteProperty -Name ("legalEntity_" + $property.Name) -Value $property.Value -Force
                        }
                    }
                }

                $workPlace = $workPlacesGrouped["$($employment.office.id)"]
                if ($null -ne $workPlace) {
                    # In case multiple are found with the same ID, we always select the first one in the array
                    $workPlace = $workPlace | Select-Object -First 1

                    if (![string]::IsNullOrEmpty($workPlace)) {
                        foreach ($property in $workPlace.PsObject.Properties) {
                            # Add a property for each field in object
                            $employment | Add-Member -MemberType NoteProperty -Name ("workplace_" + $property.Name) -Value $property.Value -Force
                        }
                    }
                }

                $job = $jobsGrouped["$($employment.job.id)"]
                if ($null -ne $job) {
                    # In case multiple are found with the same ID, we always select the first one in the array
                    $job = $job | Select-Object -First 1

                    if (![string]::IsNullOrEmpty($job)) {
                        foreach ($property in $job.PsObject.Properties) {
                            # Add a property for each field in object
                            $employment | Add-Member -MemberType NoteProperty -Name ("job_" + $property.Name) -Value $property.Value -Force
                        }
                    }
                }

                $orgUnitDepartmentId = $($employment.org_units | Where-Object {$_.type -eq 'department'}).id
                $orgUnit = $orgUnitsGrouped["$orgUnitDepartmentId"]
                if ($null -ne $orgUnit) {
                    # In case multiple are found with the same ID, we always select the first one in the array
                    $orgUnit = $orgUnit | Select-Object -First 1

                    if (![string]::IsNullOrEmpty($orgUnit)) {
                        foreach ($property in $orgUnit.PsObject.Properties) {
                            # Add a property for each field in object
                            $employment | Add-Member -MemberType NoteProperty -Name ("orgUnit_" + $property.Name) -Value $property.Value -Force
                        }
                    }

                    if(-not([string]::IsNullOrEmpty($orgUnit.parent_id))){
                        $parentOrgUnit = $orgUnitsGrouped[$orgUnit.parent_id]
                        if (![string]::IsNullOrEmpty($parentOrgUnit)) {
                            foreach ($property in $parentOrgUnit.PsObject.Properties) {
                                # Add a property for each field in object
                                $employment | Add-Member -MemberType NoteProperty -Name ("parentOrgUnit_" + $property.Name) -Value $property.Value -Force
                            }
                        }
                    }
                }

                if ($null -ne $employment.cost_centers -and $employment.cost_centers.Count -gt 0) {
                    foreach ($employmentCostCenter in $employment.cost_centers) {

                        # Maak een kopie van het employment
                        $expandedEmployment = $employment | Select-Object *

                        $costCenter = $costCentersGrouped["$($employmentCostCenter.id)"]

                        if ($null -ne $costCenter) {
                            $costCenter = $costCenter | Select-Object -First 1

                            foreach ($property in $costCenter.PsObject.Properties) {
                                $expandedEmployment | Add-Member -MemberType NoteProperty -Name ("costcenter_" + $property.Name) -Value $property.Value -Force
                            }

                            $expandedEmployment | Add-Member -MemberType NoteProperty -Name ("costcenter_weight") -Value $employmentCostCenter.weight -Force
                        }

                        $expandedEmployment | Add-Member -MemberType NoteProperty -Name ("ExternalId") -Value ($employment.id + '_' + $employmentCostCenter.id) -Force
                        [void]$expandedEmployments.Add($expandedEmployment)
                    }
                }
                else {
                    # Geen kostenplaats: employment toch behouden
                    $employment | Add-Member -MemberType NoteProperty -Name ("ExternalId") -Value ($employment.id) -Force
                    [void]$expandedEmployments.Add($employment)
                }
            }
        }

        # Add custom attributes to person object
        if ($null -ne $person.custom_attributes -and ($person.custom_attributes).Count -gt 0) {
            foreach ($custom_attribute in $person.custom_attributes) {
                #Write-Warning "Adding $($custom_attribute.id) for $($person.preferred_name)"
                $person | Add-Member -MemberType NoteProperty -Name ("customattribute_" + ($custom_attribute.id.Replace('.', '_'))) -Value $custom_attribute.value -Force
            }
        }

        # Remove unnecessary fields from object (to avoid unnecessary large objects)
        $person.PSObject.Properties.Remove('custom_attributes')

        $person | Add-Member -MemberType NoteProperty -Name 'DisplayName' -Value "$($person.preferred_name)".trim(" ")
        $person | Add-Member -MemberType NoteProperty -Name 'ExternalId'  -Value $person.id
        $person | Add-Member -MemberType NoteProperty -Name 'Contracts'   -Value @($expandedEmployments)
        
        #if($person.ExternalId -eq '34243358'){
        Write-Output ($person | ConvertTo-Json -Depth 20);
        #}
    }

    Write-Verbose -Verbose "Person import completed";
}
catch {
    $ex = $PSItem
    Write-verbose -Verbose "Could not retrieve Personio employees. Error: $($ex.Exception.Message)"
    Write-verbose -Verbose "Could not retrieve Personio employees. ErrorDetails: $($ex.ErrorDetails)"
    throw ($ex)
}
