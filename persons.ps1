$c = $configuration | ConvertFrom-Json;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
$AuthParams = @{
    client_id=$c.clientid;
    client_secret=$c.clientsecret;
};
$header = [ordered]@{
    Accept = "application/json";
}
$response = Invoke-RestMethod -Method Post -Uri https://api.personio.de/v1/auth -Body $AuthParams -Headers $header
$accessToken = $response.data.token

$authorization = [ordered]@{
    Authorization = "Bearer $accesstoken";
    'Content-Type' = "application/json";
    Accept = "application/json";
}
$response = Invoke-RestMethod -Method GET -Uri https://api.personio.de/v1/company/employees -Headers $authorization

foreach ($employee in $response.data)
{
    $person  = @{};
    $person['ExternalId'] = $employee.attributes.id.value
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
            "team" { $person[$prop.Name] = "$(($prop.Value).value.attributes.name)"; }
            "department" { }
            "supervisor" { }
            "hire_date" { }
            "termination_date" { }
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
            "position" { $contract['JobTitle'] = "$(($prop.Value).value)"; }
            "supervisor" { $contract['ManagerExternalId'] = "$(($prop.Value).value.attributes.id)"; }
            "cost_centers" { $contract['Costcenter'] = "$(($prop.Value).value.attributes.name)"; }
            "hire_date" { if ([string]::IsNullOrEmpty($(($prop.Value).value))) { $contract['StartDate'] = $null } else { $contract['StartDate'] = Get-date("$(($prop.Value).value)") -format 'o'; } }
            "termination_date" { if ([string]::IsNullOrEmpty($(($prop.Value).value))) { $contract['EndDate'] = $null } else { $contract['EndDate'] = Get-date("$(($prop.Value).value)") -format 'o'; } }
       }
    }
    [void]$person['Contracts'].Add($contract);
    Write-Output ($person | ConvertTo-Json -Depth 20);
}

Write-Verbose -Verbose "Person import completed";
