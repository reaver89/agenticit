Param(
    [Parameter(Mandatory=$false, HelpMessage="The Azure subscription ID where the disk is located.")]
    [string]$SubscriptionId = (Get-AzContext).Subscription.Id,

    [Parameter(Mandatory=$false, HelpMessage="The resource group name where the disk is located.")]
    [string]$ResourceGroupName = "contoso-demo-rg",

    [Parameter(Mandatory=$false, HelpMessage="The name of the disk to modify.")]
    [string]$DiskName = "contoso-demo-web-vm_osdisk_1_1acfd0824c5e494591959430df779bdf",

    [Parameter(Mandatory=$false, HelpMessage="The target SKU for the disk (e.g., Standard_LRS, Premium_LRS). Default is Standard_LRS.")]
    [string]$TargetDiskSku = "Standard_LRS",

    [Parameter(Mandatory=$false, HelpMessage="The target disk size in GB. Default is 128 GB for S10.")]
    [int]$TargetDiskSizeGB = 128,

    [Parameter(Mandatory=$false, HelpMessage="The target disk tier (e.g., S10, E10). Default is S10.")]
    [string]$TargetDiskTier = "S10"
)

$ErrorActionPreference = 'Stop'

function Install-ModuleIfNotPresent {
    param(
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing PowerShell module: $ModuleName..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "Module $ModuleName installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install module $ModuleName. Error: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Host "Module $ModuleName is already installed." -ForegroundColor Green
    }
}

function Connect-AzureAccountWrapper {
    Write-Host "Attempting to connect to Azure..." -ForegroundColor Yellow
    try {
        # Check if already connected
        if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
            Write-Host "No active Azure context found. Please sign in." -ForegroundColor Yellow
            Connect-AzAccount -ErrorAction Stop
        }
        else {
            Write-Host "Already connected to Azure." -ForegroundColor Green
        }

        $currentContext = Get-AzContext
        Write-Host "Connected to subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor Green
        Write-Host "Tenant: $($currentContext.Tenant.Name) ($($currentContext.Tenant.Id))" -ForegroundColor Green

        # Select the target subscription if different from current context
        if ($currentContext.Subscription.Id -ne $SubscriptionId) {
            Write-Host "Switching to target subscription: $SubscriptionId..." -ForegroundColor Yellow
            Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
            Write-Host "Successfully switched to subscription: $(Get-AzContext).Subscription.Name" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to connect to Azure or select subscription. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Update-AzureDiskSku {
    param(
        [string]$ResourceGroupName,
        [string]$DiskName,
        [string]$TargetDiskSku,
        [string]$TargetDiskTier,
        [int]$TargetDiskSizeGB
    )

    $operationStatus = @{
        ResourceName = $DiskName;
        ResourceType = "microsoft.compute/disks";
        Status = "Failed";
        ErrorMessage = "";
        Action = "Change tier from 'Premium_LRS' to '$TargetDiskTier'";
        Details = "";
    }

    Write-Host "`nAttempting to update disk '$DiskName' in resource group '$ResourceGroupName' to SKU '$TargetDiskSku' (Tier: $TargetDiskTier, Size: ${TargetDiskSizeGB}GB)..." -ForegroundColor Cyan

    try {
        $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DiskName -ErrorAction Stop
        Write-Host "Current Disk SKU: $($disk.Sku.Name), Tier: $($disk.Tier), Size: $($disk.DiskSizeGB)GB" -ForegroundColor DarkGray

        if ($disk.Sku.Name -eq $TargetDiskSku -and $disk.Tier -eq $TargetDiskTier -and $disk.DiskSizeGB -eq $TargetDiskSizeGB) {
            Write-Host "Disk '$DiskName' is already configured with the target SKU '$TargetDiskSku' (Tier: $TargetDiskTier, Size: ${TargetDiskSizeGB}GB). Skipping." -ForegroundColor Green
            $operationStatus.Status = "Skipped"
            $operationStatus.Details = "Disk already at target configuration."
            return $operationStatus
        }

        # Create a new disk configuration object with the desired SKU and size
        $diskConfig = New-AzDiskConfig -SkuName $TargetDiskSku -Location $disk.Location -CreateOption Import -SourceResourceId $disk.Id -DiskSizeGB $TargetDiskSizeGB -Tier $TargetDiskTier

        # Update the disk
        Update-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DiskName -Disk $diskConfig -ErrorAction Stop

        Write-Host "Successfully updated disk '$DiskName' to SKU '$TargetDiskSku' (Tier: $TargetDiskTier, Size: ${TargetDiskSizeGB}GB)." -ForegroundColor Green
        $operationStatus.Status = "Success"
        $operationStatus.Details = "Disk updated to SKU '$TargetDiskSku', Tier '$TargetDiskTier', Size '${TargetDiskSizeGB}GB'."
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to update disk '$DiskName'. Error: $errorMessage"
        $operationStatus.ErrorMessage = $errorMessage
    }
    return $operationStatus
}

# --- Main Script Execution --- 

$scriptStartTime = Get-Date
$results = @()

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host " Azure Disk Downscale Remediation Script" -ForegroundColor Cyan
Write-Host " Starting at: $scriptStartTime" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Install required modules
Install-ModuleIfNotPresent -ModuleName Az.Accounts
Install-ModuleIfNotPresent -ModuleName Az.Compute

# 2. Connect to Azure
Connect-AzureAccountWrapper -SubscriptionId $SubscriptionId

# 3. Read inventory CSV
$inventoryPath = Join-Path $PSScriptRoot "inventory.csv"
if (-not (Test-Path $inventoryPath)) {
    Write-Warning "Inventory file not found: $inventoryPath. Attempting to remediate single disk based on parameters." -ForegroundColor Yellow
    # If inventory.csv is not found, proceed with the single disk defined by parameters
    $resource = [PSCustomObject]@{ 
        ResourceName = $DiskName;
        ResourceId = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/microsoft.compute/disks/$DiskName";
        ResourceType = "microsoft.compute/disks";
        ResourceGroup = $ResourceGroupName;
        RecommendedAction = "Change tier from 'E10 LRS Disk' to 'S10 LRS Disk'"; # Default action from remediation plan
    }
    $resources = @($resource)
} else {
    Write-Host "Reading resources from inventory file: $inventoryPath" -ForegroundColor Green
    $resources = Import-Csv -Path $inventoryPath
}

# 4. Process resources from inventory
foreach ($resource in $resources) {
    $resourceId = $resource.ResourceId
    $resourceName = $resource.ResourceName
    $resourceType = $resource.ResourceType
    $resourceGroup = $resource.ResourceGroup
    $action = $resource.RecommendedAction

    if ($resourceType -eq "microsoft.compute/disks") {
        # Extract target SKU and tier from RecommendedAction if available, otherwise use parameters
        $currentSkuMatch = $action | Select-String -Pattern "from '(.*?) LRS Disk'" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Groups | Select-Object -Last 2 | Select-Object -First 1 | Select-Object -ExpandProperty Value
        $targetSkuMatch = $action | Select-String -Pattern "to '(.*?) LRS Disk'" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value

        $diskSku = $TargetDiskSku # Default from parameter
        $diskTier = $TargetDiskTier # Default from parameter
        $diskSize = $TargetDiskSizeGB # Default from parameter

        if ($targetSkuMatch) {
            # Example: 'S10 LRS Disk' -> S10
            $diskTier = $targetSkuMatch.Replace(" LRS Disk", "")
            # Map tier to SKU name (e.g., S10 -> Standard_LRS, E10 -> Premium_LRS)
            if ($diskTier.StartsWith("S")) {
                $diskSku = "Standard_LRS"
            } elseif ($diskTier.StartsWith("E")) {
                $diskSku = "Premium_LRS"
            } else {
                Write-Warning "Could not determine SKU from tier '$diskTier'. Using default SKU '$TargetDiskSku'." -ForegroundColor Yellow
            }

            # Infer disk size from tier (common sizes for S10/E10 are 128GB)
            if ($diskTier -eq "S10" -or $diskTier -eq "E10") {
                $diskSize = 128
            }
        }

        $results += Update-AzureDiskSku -ResourceGroupName $resourceGroup -DiskName $resourceName -TargetDiskSku $diskSku -TargetDiskTier $diskTier -TargetDiskSizeGB $diskSize
    }
    else {
        Write-Warning "Skipping unsupported resource type '$resourceType' for resource '$resourceName'." -ForegroundColor Yellow
        $results += @{
            ResourceName = $resourceName;
            ResourceType = $resourceType;
            Status = "Skipped";
            ErrorMessage = "Unsupported resource type for this script.";
            Action = "N/A";
            Details = "";
        }
    }
}

$scriptEndTime = Get-Date
$duration = New-TimeSpan -Start $scriptStartTime -End $scriptEndTime

# --- Summary Report --- 
Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host " Remediation Summary Report" -ForegroundColor Cyan
Write-Host " End Time: $scriptEndTime" -ForegroundColor Cyan
Write-Host " Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$successfulOperations = $results | Where-Object { $_.Status -eq "Success" }
$failedOperations = $results | Where-Object { $_.Status -eq "Failed" }
$skippedOperations = $results | Where-Object { $_.Status -eq "Skipped" }

Write-Host "`nTotal Operations: $($results.Count)" -ForegroundColor White
Write-Host "Successful: $($successfulOperations.Count)" -ForegroundColor Green
Write-Host "Failed: $($failedOperations.Count)" -ForegroundColor Red
Write-Host "Skipped: $($skippedOperations.Count)" -ForegroundColor Yellow

if ($successfulOperations.Count -gt 0) {
    Write-Host "`n--- Successful Operations ---" -ForegroundColor Green
    $successfulOperations | Format-Table -Property ResourceName, ResourceType, Action, Details -AutoSize
}

if ($skippedOperations.Count -gt 0) {
    Write-Host "`n--- Skipped Operations ---" -ForegroundColor Yellow
    $skippedOperations | Format-Table -Property ResourceName, ResourceType, Action, Details -AutoSize
}

if ($failedOperations.Count -gt 0) {
    Write-Host "`n--- Failed Operations ---" -ForegroundColor Red
    $failedOperations | Format-Table -Property ResourceName, ResourceType, Action, ErrorMessage -AutoSize
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Script execution completed." -ForegroundColor Cyan
Write-Host "Review the summary above for details." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to exit"