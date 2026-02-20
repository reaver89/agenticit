Param(
    [Parameter(Mandatory=$false, HelpMessage="The path to the inventory CSV file.")]
    [string]$InventoryPath,

    [Parameter(Mandatory=$false, HelpMessage="Azure Tenant ID to authenticate against (e.g., vboxcloud.onmicrosoft.com).")]
    [string]$TenantId = "3e309880-3054-454b-9e01-60b01245a624",

    [Parameter(Mandatory=$false, HelpMessage="Azure Subscription ID to set as active context.")]
    [string]$SubscriptionId = "eca2646b-f770-43f0-8c71-c80e35801b1b",

    [Parameter(Mandatory=$false, HelpMessage="The desired SKU for the target disks (e.g., 'Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS').")]
    [string]$TargetDiskSku = "Standard_LRS",

    [Parameter(Mandatory=$false, HelpMessage="Set to true to perform a dry run without making any changes.")]
    [switch]$DryRun = $false
)

# Set default InventoryPath after param block (PSScriptRoot may be empty during param evaluation)
if (-not $InventoryPath) {
    $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $InventoryPath = Join-Path $ScriptDir "inventory.csv"
}

#region Functions
function Install-RequiredModules {
    $requiredModules = @('Az.Accounts', 'Az.Compute')

    # Install all missing modules first
    foreach ($moduleName in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $moduleName
        if (-not $installed) {
            Write-Host "Installing $moduleName..." -ForegroundColor Yellow
            try {
                Install-Module -Name $moduleName -Scope CurrentUser -Repository PSGallery -Force -WarningAction SilentlyContinue -ErrorAction Stop
                Write-Host "$moduleName installed." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to install $moduleName. $($_.Exception.Message)"
                exit 1
            }
        }
        else {
            Write-Host "$moduleName found: v$($installed.Version)" -ForegroundColor DarkGray
        }
    }

    # Import only if not already loaded in current session
    foreach ($moduleName in $requiredModules) {
        if (-not (Get-Module -Name $moduleName)) {
            Write-Host "Importing $moduleName..." -ForegroundColor DarkGray
            try {
                Import-Module $moduleName -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to import $moduleName. $($_.Exception.Message)"
                exit 1
            }
        }
    }

    Write-Host "All required modules loaded." -ForegroundColor Green
}

function Connect-AzureAccount {
    param(
        [string]$Tenant,
        [string]$Subscription
    )

    Write-Host "Starting Device Code authentication..." -ForegroundColor Yellow
    
    try {
        Update-AzConfig -EnableLoginByWam $false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

        Connect-AzAccount `
            -Tenant $Tenant `
            -Subscription $Subscription `
            -UseDeviceAuthentication `
            -WarningAction SilentlyContinue `
            -ErrorAction Stop

        $context = Get-AzContext
        Write-Host "Connected to Tenant: $($context.Tenant.Id)" -ForegroundColor Green
        Write-Host "Using Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green
    }
    catch {
        Write-Error "Authentication failed. $($_.Exception.Message)"
        Disconnect-AzAccount -ErrorAction SilentlyContinue
        Clear-AzContext -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

function Resize-AzureDisk {
    param(
        [string]$DiskId,
        [string]$ResourceGroupName,
        [string]$DiskName,
        [string]$TargetSku,      # 'Standard_LRS' (HDD), 'StandardSSD_LRS' (SSD), 'Premium_LRS' (Premium SSD)
        [int]$TargetSizeGB,      # e.g., 128
        [switch]$DryRun
    )

    $operationStatus = @{
        DiskId = $DiskId
        DiskName = $DiskName
        ResourceGroupName = $ResourceGroupName
        Status = "Failed"
        Message = ""
    }

    Write-Host "`nProcessing disk: $DiskName" -ForegroundColor Cyan

    try {
        $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DiskName -ErrorAction Stop
        Write-Host "Current: SKU=$($disk.Sku.Name), Size=$($disk.DiskSizeGB)GB" -ForegroundColor DarkGray
        Write-Host "Target:  SKU=$TargetSku, Size=$($TargetSizeGB)GB" -ForegroundColor DarkGray

        if ($TargetSizeGB -lt $disk.DiskSizeGB) {
            Write-Host "Note: Azure does not allow reducing disk size. Keeping current size ($($disk.DiskSizeGB)GB), only changing SKU." -ForegroundColor Yellow
            $TargetSizeGB = $disk.DiskSizeGB
        }

        if (($disk.Sku.Name -eq $TargetSku) -and ($disk.DiskSizeGB -eq $TargetSizeGB)) {
            Write-Host "Disk '$DiskName' is already at target configuration. Skipping." -ForegroundColor Green
            $operationStatus.Status = "Skipped"
            $operationStatus.Message = "Already at target SKU and size."
            return $operationStatus
        }

        # If disk is attached to a VM, deallocate the VM first
        $vmDeallocated = $false
        $vmName = $null
        if ($disk.DiskState -eq 'Attached') {
            $vmResource = $disk.ManagedBy
            if (-not $vmResource) {
                Write-Warning "Disk '$DiskName' is attached but ManagedBy is empty. Cannot determine VM."
                $operationStatus.Message = "Disk is attached but VM cannot be determined."
                return $operationStatus
            }
            $vmName = ($vmResource -split '/')[-1]

            # Check if VM is already deallocated
            $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status -ErrorAction Stop
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code

            if ($powerState -eq 'PowerState/deallocated') {
                Write-Host "VM '$vmName' is already deallocated. Proceeding with disk update." -ForegroundColor DarkGray
            }
            else {
                Write-Host "Disk is attached to VM '$vmName' (state: $powerState). Deallocating VM..." -ForegroundColor Yellow
                if (-not $DryRun) {
                    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Force -ErrorAction Stop
                    Write-Host "VM '$vmName' deallocated successfully." -ForegroundColor Green
                    $vmDeallocated = $true
                }
                else {
                    Write-Host "DryRun: Would deallocate VM '$vmName'." -ForegroundColor Magenta
                }
            }
        }

        if ($DryRun) {
            Write-Host "DryRun: Would update disk to SKU '$TargetSku' and size '$($TargetSizeGB)GB'." -ForegroundColor Magenta
            $operationStatus.Status = "DryRun"
            $operationStatus.Message = "Would update to SKU '$TargetSku' and size '$($TargetSizeGB)GB'."
        }
        else {
            Write-Host "Updating disk..." -ForegroundColor Yellow
            $diskUpdateConfig = New-AzDiskUpdateConfig -SkuName $TargetSku -DiskSizeGB $TargetSizeGB
            $updatedDisk = Update-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DiskName -DiskUpdate $diskUpdateConfig -ErrorAction Stop
            Write-Host "Successfully updated disk to SKU '$($updatedDisk.Sku.Name)' and size '$($updatedDisk.DiskSizeGB)GB'." -ForegroundColor Green
            $operationStatus.Status = "Success"
            $operationStatus.Message = "Updated to SKU '$TargetSku' and size '$($TargetSizeGB)GB'."
        }

        # Restart the VM if we deallocated it
        if ($vmDeallocated -and $vmName) {
            Write-Host "Starting VM '$vmName' back up..." -ForegroundColor Yellow
            Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction Stop
            Write-Host "VM '$vmName' started successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to update disk '$DiskName'. Error: $($_.Exception.Message)"
        $operationStatus.Message = "Error: $($_.Exception.Message)"

        # Try to restart VM if it was deallocated but disk update failed
        if ($vmDeallocated -and $vmName) {
            Write-Host "Attempting to restart VM '$vmName' after failure..." -ForegroundColor Yellow
            try {
                Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction Stop
                Write-Host "VM '$vmName' restarted successfully." -ForegroundColor Green
            }
            catch {
                Write-Error "CRITICAL: Failed to restart VM '$vmName'. Manual intervention required. $($_.Exception.Message)"
            }
        }
    }
    return $operationStatus
}
#endregion

#region Main Script Execution
$ErrorActionPreference = 'Continue'
$scriptStartTime = Get-Date
$results = @()

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host " Azure Disk Downscale Remediation Script" -ForegroundColor Cyan
Write-Host " Starting at: $scriptStartTime" -ForegroundColor Cyan
Write-Host " Target SKU: $TargetDiskSku" -ForegroundColor Cyan
if ($TenantId) { Write-Host " Target Tenant: $TenantId" -ForegroundColor Cyan }
if ($SubscriptionId) { Write-Host " Target Subscription: $SubscriptionId" -ForegroundColor Cyan }
Write-Host " Dry Run Mode: $($DryRun)" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# 1. Install and import required modules
Install-RequiredModules

# 2. Connect to Azure (device code auth with tenant and subscription)
Connect-AzureAccount -Tenant $TenantId -Subscription $SubscriptionId

# 3. Read inventory CSV
Write-Host "`nReading inventory from: $InventoryPath" -ForegroundColor Yellow
if (-not (Test-Path -LiteralPath $InventoryPath)) {
    Write-Error "Inventory file not found: $InventoryPath. Please ensure the file exists or provide the correct path using -InventoryPath parameter."
    exit 1
}

try {
    $resources = Import-Csv -LiteralPath $InventoryPath -ErrorAction Stop
    Write-Host "Successfully loaded $($resources.Count) resources from inventory." -ForegroundColor Green
}
catch {
    Write-Error "Failed to read inventory CSV file. Error: $($_.Exception.Message)"
    exit 1
}

# 4. Process each disk resource
foreach ($resource in $resources) {
    if ($resource.ResourceType -eq 'microsoft.compute/disks') {
        $diskId = $resource.ResourceId
        $diskName = $resource.ResourceName
        $resourceGroup = $resource.ResourceGroup
        $recommendedAction = $resource.RecommendedAction # e.g., "Change tier from 'E10 LRS Disk' to 'S10 LRS Disk'"

        # Parse target tier from RecommendedAction (e.g., 'S10 LRS Disk' -> 'S10')
        $targetTier = $null
        if ($recommendedAction -match "to '([EPS]\d+)\s") {
            $targetTier = $Matches[1]  # e.g., 'E10'
        }

        # Convert disk tier to SKU name and size in GB
        # Azure disk tier prefixes: E=StandardSSD_LRS, P=Premium_LRS, S=Standard_LRS (HDD)
        # Tier number to GB: 4=32, 6=64, 10=128, 15=256, 20=512, 30=1024, 40=2048, 50=4096
        $tierToGB = @{ 4=32; 6=64; 10=128; 15=256; 20=512; 30=1024; 40=2048; 50=4096; 60=8192; 70=16384; 80=32767 }
        
        if ($targetTier -and $targetTier -match '^([EPS])(\d+)$') {
            $tierPrefix = $Matches[1]
            $tierNumber = [int]$Matches[2]
            
            $finalTargetSku = switch ($tierPrefix) {
                'E' { 'StandardSSD_LRS' }
                'P' { 'Premium_LRS' }
                'S' { 'Standard_LRS' }
                default { $TargetDiskSku }
            }
            $finalTargetSizeGB = if ($tierToGB.ContainsKey($tierNumber)) { $tierToGB[$tierNumber] } else { 128 }
        }
        else {
            # Fallback to parameter defaults
            $finalTargetSku = $TargetDiskSku
            $finalTargetSizeGB = 128  # Default S10/E10 size (128GB)
        }

        $result = Resize-AzureDisk -DiskId $diskId -ResourceGroupName $resourceGroup -DiskName $diskName -TargetSku $finalTargetSku -TargetSizeGB $finalTargetSizeGB -DryRun:$DryRun
        $results += $result
    }
    else {
        Write-Host "Skipping resource '$($resource.ResourceName)' of type '$($resource.ResourceType)' as it is not a disk." -ForegroundColor DarkGray
    }
}

# 5. Generate Summary Report
$scriptEndTime = Get-Date
$duration = ($scriptEndTime - $scriptStartTime).TotalSeconds

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host " Remediation Summary Report" -ForegroundColor Cyan
Write-Host " End Time: $scriptEndTime" -ForegroundColor Cyan
Write-Host " Duration: $($duration) seconds" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_.Status -eq 'Success' }).Count
$failedCount = ($results | Where-Object { $_.Status -eq 'Failed' }).Count
$skippedCount = ($results | Where-Object { $_.Status -eq 'Skipped' }).Count
$dryRunCount = ($results | Where-Object { $_.Status -eq 'DryRun' }).Count

Write-Host "Total Disks Processed: $($results.Count)" -ForegroundColor White
Write-Host "Successful Updates: $successCount" -ForegroundColor Green
Write-Host "Failed Updates: $failedCount" -ForegroundColor Red
Write-Host "Skipped Disks: $skippedCount" -ForegroundColor Yellow
if ($DryRun) {
    Write-Host "Dry Run Operations: $dryRunCount" -ForegroundColor Magenta
}

if ($results.Count -gt 0) {
    Write-Host "`nDetails:" -ForegroundColor White
    $results | Format-Table -AutoSize
}

if ($failedCount -gt 0) {
    Write-Host "`nReview the 'Failed Updates' section above for details on disks that could not be processed." -ForegroundColor Red
}

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "Script execution completed." -ForegroundColor Cyan
Write-Host "Review the summary above for details." -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

Read-Host -Prompt "Press Enter to exit"
#endregion
