# Environment Variables
$AppId = Get-AutomationVariable -Name "AppId"
$PWord = Get-AutomationVariable -Name "PWord"
$TenantId = Get-AutomationVariable -Name "TenantId"
$CustomerId = Get-AutomationVariable -Name "CustomerId"
$SharedKey = Get-AutomationVariable -Name "SharedKey"
$LogType = "Limits"
$TimeStampField = ""
$locations = "canadacentral"

# Ensures you do not inherit an AzContext in your runbook
$null = Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
    $AzureConnection = (Connect-AzAccount -Identity).context
}
catch {
    Write-Output "There is no system-assigned user identity. Aborting." 
    exit
}

# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

# Function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
    -customerId $customerId `
    -sharedKey $sharedKey `
    -date $rfc1123date `
    -contentLength $contentLength `
    -method $method `
    -contentType $contentType `
    -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
    "Authorization" = $signature;
    "Log-Type" = $logType;
    "x-ms-date" = $rfc1123date;
    "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}

# Collecting Quota Information
$kqlQuery = Search-AzGraph -Query 'QuotaResources' -UseTenantScope
$Results = @()

foreach ($item in $kqlQuery)
{
    foreach ($limit in $item.properties.value)
    {
        $LimitName = $limit.Name.Value
        $LimitValue = $limit.limit
        $CurrentLimit = $limit.currentValue
        $Percentage = $null

        if ($LimitValue -ne 0)
        {
            $Percentage  = ([math]::Round($CurrentLimit/$LimitValue*100,0))
            if ($Percentage -ge 0)
            {
                $Results += @([pscustomobject]@{LimitType=$item.type;Location=$item.Location;LimitName=$LimitName;LimitValue=$LimitValue;CurrentLimit=$CurrentLimit;PercentageUsed=$Percentage;Limitid=$item.id})
            }
        }
    }
}

# Network Limits Limit
foreach ($location in $locations)
{
    $nwQuotas = Get-AzNetworkUsage -Location $location
    foreach($nwQuota in $nwQuotas)
    {
        $Percentage = 0
        if ($nwQuota.Limit -gt 0) 
        { 
            $Percentage = ($nwQuota.CurrentValue / $nwQuota.Limit)*100
        }

        $Results += @([pscustomobject]@{LimitType="NetworkLimit";Location=$location;LimitName=$nwQuota.ResourceType;LimitValue=$nwQuota.Limit;CurrentLimit=$nwQuota.CurrentValue;PercentageUsed=$Percentage;Limitid="NA"})
    }
}

# Converting data to Json
$json = $Results | ConvertTo-Json 

# Streaming logs to LAW using the Function
Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body $json -logType $logType
