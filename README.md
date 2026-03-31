# Azure Limits & Quotas Export

PowerShell script that collects Azure resource quotas and network usage/limits across all enabled subscriptions (or a single one) and exports the results to an Excel file with separate worksheets.

## How It Works

The script uses `Invoke-AzRestMethod` to call the Azure REST API directly for each subscription and location — **no context switching required**, making it efficient for tenants with hundreds of subscriptions.

It queries the `/locations/{location}/usages` endpoint for each configured provider and collects all resources where current usage is greater than zero. Results are split into two worksheets:

| Worksheet | Description |
|---|---|
| **ResourceQuotas** | Compute, Storage, and other provider quotas |
| **NetworkLimits** | Network-specific usage and limits |

## Prerequisites

### PowerShell Modules

Install the following modules before running the script:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
Install-Module Az.ResourceGraph -Scope CurrentUser
Install-Module ImportExcel -Scope CurrentUser
```

| Module | Purpose |
|---|---|
| `Az.Accounts` | Azure authentication and `Invoke-AzRestMethod` |
| `Az.ResourceGraph` | Enumerate enabled subscriptions across the tenant |
| `ImportExcel` | Export results to `.xlsx` without requiring Excel installed |

### Azure Permissions

- **Reader** role (or equivalent) on the target subscriptions to query usage/quota APIs.
- Access to Azure Resource Graph to enumerate subscriptions (unless using `-SubscriptionId`).

### Authentication

Connect to Azure before running the script:

```powershell
Connect-AzAccount
```

The script will detect if you're not connected and attempt an interactive login automatically.

## Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `-Locations` | String | No | `canadacentral,canadaeast,eastus2,centralus` | Comma-separated list of Azure regions to query |
| `-OutputPath` | String | No | `AzureLimitsAndQuotas_<timestamp>.xlsx` | Path for the output Excel file |
| `-SubscriptionId` | String | No | *(all enabled subs)* | Single subscription ID (GUID) to query |
| `-QuotaProviders` | String[] | No | `Microsoft.Compute, Microsoft.Network, Microsoft.Storage` | Resource providers to query for usage/quotas |

## Usage Examples

### Query all subscriptions (default locations)

```powershell
.\AzureNetworkLimitsToCSV.ps1
```

### Query a single subscription

```powershell
.\AzureNetworkLimitsToCSV.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Custom locations and output path

```powershell
.\AzureNetworkLimitsToCSV.ps1 -Locations "eastus,westus2,westeurope" -OutputPath "C:\Reports\QuotaReport.xlsx"
```

### Query only Compute and Network providers

```powershell
.\AzureNetworkLimitsToCSV.ps1 -QuotaProviders @('Microsoft.Compute', 'Microsoft.Network')
```

## Expected Output

The script generates an `.xlsx` file with two worksheets:

### ResourceQuotas Worksheet

| Column | Description |
|---|---|
| Timestamp | Date/time of collection |
| Provider | Azure resource provider (e.g., `Microsoft.Compute`) |
| Location | Azure region |
| QuotaName | Internal quota/resource name |
| LocalizedName | Human-readable quota name |
| LimitValue | Maximum allowed quota |
| CurrentValue | Current usage |
| PercentageUsed | Usage as a percentage of the limit |
| Unit | Unit of measurement |
| SubscriptionId | Subscription GUID |
| SubscriptionName | Subscription display name |

### NetworkLimits Worksheet

Same columns as above, filtered to `Microsoft.Network` provider results.

### Console Output

The script displays progress as it runs:

```
Connected to Azure as: user@domain.com | Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Locations to query: canadacentral, canadaeast, eastus2, centralus
Found 42 enabled subscription(s).

Collecting resource quotas and network limits per subscription (via REST, no context switching)...
[1/42] Processing subscription: MySubscription (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
[2/42] Processing subscription: AnotherSub (yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy)
...

Collection complete: 350 quota record(s), 120 network limit record(s).
Exported 350 resource quota record(s) to worksheet 'ResourceQuotas'.
Exported 120 network limit record(s) to worksheet 'NetworkLimits'.

Output file: C:\path\to\AzureLimitsAndQuotas_20260331_143022.xlsx
```

## Supported Providers

The default providers queried are listed below. You can add others that support the standard `/locations/{location}/usages` REST endpoint.

| Provider | API Version | Resources Tracked |
|---|---|---|
| `Microsoft.Compute` | 2024-07-01 | VM cores, availability sets, managed disks, etc. |
| `Microsoft.Network` | 2024-01-01 | Virtual networks, NICs, NSGs, load balancers, public IPs, etc. |
| `Microsoft.Storage` | 2023-05-01 | Storage accounts |

## Legacy Scripts

The original automation-account-based scripts that stream data to Log Analytics Workspace are preserved:

- `AzureLimits.ps1` — Collects quotas via Resource Graph and network limits, posts to LAW
- `AzureNetworkLimits.ps1` — Collects network limits across subscriptions, posts to LAW

See [oldreadme.md](oldreadme.md) for setup instructions for the legacy scripts.
