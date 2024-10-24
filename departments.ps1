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
$pagesize = 20
$response = Invoke-RestMethod -Method GET -Uri "https://api.personio.de/v1/company/employees?limit=$($pagesize)&offset=0" -Headers $authorization 
$entries = $response.data

for ($i = 1; $i -lt $response.metadata.total_pages; $i++)
{
	$offset = $i * $pagesize
	$response = Invoke-RestMethod -Method GET -Uri "https://api.personio.de/v1/company/employees?limit=$($pagesize)&offset=$($offset)" -Headers $authorization 
	$entries += $response.data
}

$departments  = [System.Collections.ArrayList]@();
foreach ($employee in $entries)
{
    $department  = @{};
    $department['Name'] = $employee.attributes.department.value.attributes.name
    $department['DisplayName'] = $employee.attributes.department.value.attributes.name
    $department['ExternalId'] = $employee.attributes.department.value.attributes.id
    if ([string]::IsNullOrEmpty($department['ExternalId']) -eq $true)
    {
        $department['ExternalId'] = $department['Name']
    }
    if ($departments.Contains($department['ExternalId']) -eq $false)
    {
        Write-Output ($department | ConvertTo-Json -Depth 20);
        $departments += $department['ExternalId'];
    }
}

Write-Verbose -Verbose "Department import completed";
