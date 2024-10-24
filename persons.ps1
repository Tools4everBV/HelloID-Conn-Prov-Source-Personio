$c = $configuration | ConvertFrom-Json;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
$AuthParams = @{
    client_id=$c.clientid;
    client_secret=$c.clientsecret;
};
$header = [ordered]@{
    Accept = "application/json";
    'X-Personio-App-ID' = $c.clientdomain;
}
$response = Invoke-RestMethod -Method Post -Uri https://api.personio.de/v1/auth -Body $AuthParams -Headers $header
$accessToken = $response.data.token

$authorization = [ordered]@{
    Authorization = "Bearer $accesstoken";
    'Content-Type' = "application/json";
    Accept = "application/json";
    'X-Personio-App-ID' = $c.clientdomain;
}
$pagesize = 50
$response = Invoke-RestMethod -Method GET -Uri "https://api.personio.de/v1/company/employees?limit=$($pagesize)&offset=0" -Headers $authorization 
$entries = $response.data

for ($i = 1; $i -lt $response.metadata.total_pages; $i++)
{
	$offset = $i * $pagesize
	$response = Invoke-RestMethod -Method GET -Uri "https://api.personio.de/v1/company/employees?limit=$($pagesize)&offset=$($offset)" -Headers $authorization 
	$entries += $response.data
}

foreach ($employee in $entries)
{
    $person  = @{};
    $person['ExternalId'] = $employee.attributes.id.value
    $person['DisplayName'] = $employee.attributes.last_name.value + ", " + $employee.attributes.first_name.value
    if ($employee.attributes.status.value -eq "Inactive" -and [string]::IsNullOrEmpty($person['ExternalId']) -eq $true)
    {
        Write-Verbose -Verbose "Skipped inactive: " + $person['ExternalId']
        continue;
    }
    if ([string]::IsNullOrEmpty($person['ExternalId']) -eq $true)
    {
        Write-Verbose -Verbose "Skipped else: " + $person['ExternalId']
        continue;
    }
    foreach($prop in $employee.attributes.PSObject.properties)
    { 
        switch ($prop.Name)
        {
            "office" { $person[$prop.Name] = "$(($prop.Value).value.attributes.name)"; }
            "team" { }
            "department" { }
            "supervisor" { }
            "hire_date" { }
            "termination_date" { }
            "last_working_day" { }
            "contract_end_date" { }
            "cost_centers" { }
		    Default { $person[$prop.Name] = "$(($prop.Value).value)"; }
	    }
    }
    $person['Contracts'] = [System.Collections.ArrayList]@();
    $contract = @{};
    $contract['SequenceNumber'] = "1";
    foreach($prop in $employee.attributes.PSObject.properties)
    {
       switch ($prop.Name)
       {
            "department" { 
                $contract['DepartmentName'] = "$(($prop.Value).value.attributes.name)"; 
                $contract['DepartmentNumber'] = "$(($prop.Value).value.attributes.id)";}
            "team" { $contract[$prop.Name] = "$(($prop.Value).value.attributes.name)"; }
            "office" { $contract[$prop.Name] = "$(($prop.Value).value.attributes.name)"; }
            "position" { $contract['JobTitle'] = "$(($prop.Value).value)"; }
            "supervisor" { $contract['ManagerExternalId'] = "$(($prop.Value).value.attributes.id.value)"; }
            "employment_type" { $contract['type'] = "$(($prop.Value).value)"; }
            "cost_centers" { $contract['Costcenter'] = "$(($prop.Value).value.attributes.name)"; }
            "hire_date" { if ([string]::IsNullOrEmpty($(($prop.Value).value))) { $contract['StartDate'] = $null } else { $contract['StartDate'] = Get-date("$(($prop.Value).value)") -format 'o'; } }
            "termination_date" { }
            "last_working_day" { }
            "contract_end_date" { }
       }
    }
    if ([string]::IsNullOrEmpty($employee.attributes.termination_date.value)) 
    { 
        if ([string]::IsNullOrEmpty($employee.attributes.last_working_day.value)) 
        { 
            if ([string]::IsNullOrEmpty($employee.attributes.contract_end_date.value)) 
            { 
                $contract['EndDate'] = $null 
            }
            else 
            {
                $contract['EndDate'] = Get-date($employee.attributes.contract_end_date.value) -format 'o'; 
            }
        }
        else 
        {
            $contract['EndDate'] = Get-date($employee.attributes.last_working_day.value) -format 'o'; 
        }
    } 
    else 
    { 
        $contract['EndDate'] = Get-date($employee.attributes.termination_date.value) -format 'o'; 
    }
    [void]$person['Contracts'].Add($contract);
    Write-Output ($person | ConvertTo-Json -Depth 20);
}

Write-Verbose -Verbose "Person import completed";
