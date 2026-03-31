#Requires -Modules Az.Accounts, Az.ResourceGraph, ImportExcel

<#
.SYNOPSIS
    Collects Azure resource quotas and network usage/limits, then exports to an Excel file with separate worksheets.

.DESCRIPTION
    Queries resource usage/quotas via REST API (Invoke-AzRestMethod) for Compute, Network, Storage,
    and other providers across all enabled subscriptions — without switching Azure context.
    Exports results as separate worksheets ("ResourceQuotas" and "NetworkLimits") in a single .xlsx file.
    Requires the ImportExcel module (Install-Module ImportExcel).

.PARAMETER Locations
    Comma-separated list of Azure regions to query. Defaults to "canadacentral,canadaeast,eastus2,centralus".

.PARAMETER OutputPath
    Path for the output Excel file. Defaults to "AzureLimitsAndQuotas_<timestamp>.xlsx" in the current directory.

.PARAMETER SubscriptionId
    Optional. A single subscription ID (GUID) to query. When omitted, all enabled subscriptions in the tenant are queried.

.PARAMETER QuotaProviders
    Array of Azure resource provider names to query quotas for.
    Defaults to: Microsoft.Compute, Microsoft.Network, Microsoft.Storage
    Each provider must support the /locations/{location}/usages REST endpoint.

.EXAMPLE
    .\AzureNetworkLimitsToCSV.ps1
    .\AzureNetworkLimitsToCSV.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    .\AzureNetworkLimitsToCSV.ps1 -Locations "eastus,westus2" -OutputPath "C:\Reports\LimitsAndQuotas.xlsx"
    .\AzureNetworkLimitsToCSV.ps1 -QuotaProviders @('Microsoft.Compute','Microsoft.Network')
#>

[CmdletBinding()]
param(
    [string]$Locations = "canadacentral,canadaeast,eastus2,centralus",
    [string]$OutputPath = "AzureLimitsAndQuotas_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx",
    [string]$SubscriptionId,
    [string[]]$QuotaProviders = @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.Storage')
)

# --- Validation Steps ---

# 1. Check required modules are available
$requiredModules = @('Az.Accounts', 'Az.ResourceGraph', 'ImportExcel')
$missingModules = @()
foreach ($mod in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        $missingModules += $mod
    }
}
if ($missingModules.Count -gt 0) {
    Write-Error "Missing required PowerShell modules: $($missingModules -join ', '). Install them with: Install-Module $($missingModules -join ', ')"
    exit 1
}

# Import modules
foreach ($mod in $requiredModules) {
    Import-Module $mod -ErrorAction Stop
}

# 2. Check if connected to Azure
$context = Get-AzContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Host "Not connected to Azure. Attempting interactive login..." -ForegroundColor Yellow
    try {
        Connect-AzAccount -ErrorAction Stop | Out-Null
        $context = Get-AzContext
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        exit 1
    }
}
Write-Host "Connected to Azure as: $($context.Account.Id) | Tenant: $($context.Tenant.Id)" -ForegroundColor Green

# 3. Validate output path is writable
$outputDir = Split-Path -Path $OutputPath -Parent
if ([string]::IsNullOrEmpty($outputDir)) {
    $outputDir = (Get-Location).Path
    $OutputPath = Join-Path $outputDir $OutputPath
}
if (-not (Test-Path $outputDir)) {
    try {
        New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Cannot create output directory '$outputDir': $_"
        exit 1
    }
}

# 5. Validate locations
$locationList = $Locations.Split(",").Trim()
if ($locationList.Count -eq 0) {
    Write-Error "No valid locations specified."
    exit 1
}

Write-Host "Locations to query: $($locationList -join ', ')" -ForegroundColor Cyan

# --- Collect Subscriptions ---

if ($SubscriptionId) {
    Write-Host "Targeting single subscription: $SubscriptionId" -ForegroundColor Cyan
    $Subscriptions = @([PSCustomObject]@{
        SubscriptionName = $SubscriptionId
        SubscriptionId   = "/subscriptions/$SubscriptionId"
    })
    # Try to resolve the friendly name
    try {
        $subLookup = Search-AzGraph -Query "ResourceContainers | where type == 'microsoft.resources/subscriptions' | where id =~ '/subscriptions/$SubscriptionId' | project name" -UseTenantScope -ErrorAction Stop
        if ($subLookup.Count -gt 0) {
            $Subscriptions[0].SubscriptionName = $subLookup[0].name
        }
    } catch { }
} else {
    $SubQuery = 'ResourceContainers
                | where type == "microsoft.resources/subscriptions"
                | project SubscriptionName = name, SubscriptionId = id, State = properties.state
                | where State == "Enabled"'
    $Subscriptions = Search-AzGraph -Query $SubQuery -First 1000 -UseTenantScope
}

if ($Subscriptions.Count -eq 0) {
    Write-Warning "No enabled subscriptions found. Exiting."
    exit 0
}

Write-Host "Found $($Subscriptions.Count) enabled subscription(s)." -ForegroundColor Cyan

# --- Collect Resource Quotas and Network Limits via REST API ---

# API versions per provider for the /locations/{location}/usages endpoint
$providerApiVersions = @{
    'Microsoft.Compute' = '2024-07-01'
    'Microsoft.Network' = '2024-01-01'
    'Microsoft.Storage' = '2023-05-01'
}
$defaultApiVersion = '2023-06-01'

Write-Host "`nCollecting resource quotas and network limits per subscription (via REST, no context switching)..." -ForegroundColor Cyan
$QuotaResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$NetworkResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$totalSubs = $Subscriptions.Count
$currentSub = 0

foreach ($subscription in $Subscriptions) {
    $currentSub++
    $subId = $subscription.SubscriptionId.Split('/')[2]
    Write-Host "[$currentSub/$totalSubs] Processing subscription: $($subscription.SubscriptionName) ($subId)" -ForegroundColor White

    foreach ($location in $locationList) {
        foreach ($provider in $QuotaProviders) {
            $apiVersion = $providerApiVersions[$provider]
            if (-not $apiVersion) { $apiVersion = $defaultApiVersion }

            $path = "/subscriptions/$subId/providers/$provider/locations/$location/usages?api-version=$apiVersion"
            try {
                $response = Invoke-AzRestMethod -Path $path -Method GET -ErrorAction Stop
            }
            catch {
                continue
            }

            if ($response.StatusCode -ne 200) { continue }

            $content = $response.Content | ConvertFrom-Json
            foreach ($usage in $content.value) {
                $limitValue = $usage.limit
                $currentValue = $usage.currentValue
                $usageName = $usage.name.value
                $localizedName = $usage.name.localizedValue

                if ($limitValue -gt 0 -and $currentValue -gt 0) {
                    $Percentage = [math]::Round(($currentValue / $limitValue) * 100, 2)

                    $record = [PSCustomObject]@{
                        Timestamp        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                        Provider         = $provider
                        Location         = $location
                        QuotaName        = $usageName
                        LocalizedName    = $localizedName
                        LimitValue       = $limitValue
                        CurrentValue     = $currentValue
                        PercentageUsed   = $Percentage
                        Unit             = $usage.unit
                        SubscriptionId   = $subId
                        SubscriptionName = $subscription.SubscriptionName
                    }

                    if ($provider -eq 'Microsoft.Network') {
                        $NetworkResults.Add($record)
                    } else {
                        $QuotaResults.Add($record)
                    }
                }
            }
        }
    }
}

Write-Host "`nCollection complete: $($QuotaResults.Count) quota record(s), $($NetworkResults.Count) network limit record(s)." -ForegroundColor Cyan

# --- Export to Excel ---

if ($QuotaResults.Count -eq 0 -and $NetworkResults.Count -eq 0) {
    Write-Warning "No data collected. File will not be created."
    exit 0
}

# Remove existing file to avoid appending to old data
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

if ($QuotaResults.Count -gt 0) {
    $QuotaResults | Export-Excel -Path $OutputPath -WorksheetName 'ResourceQuotas' -AutoSize -FreezeTopRow -BoldTopRow
    Write-Host "Exported $($QuotaResults.Count) resource quota record(s) to worksheet 'ResourceQuotas'." -ForegroundColor Green
}

if ($NetworkResults.Count -gt 0) {
    $NetworkResults | Export-Excel -Path $OutputPath -WorksheetName 'NetworkLimits' -AutoSize -FreezeTopRow -BoldTopRow
    Write-Host "Exported $($NetworkResults.Count) network limit record(s) to worksheet 'NetworkLimits'." -ForegroundColor Green
}

Write-Host "`nOutput file: $OutputPath" -ForegroundColor Green
