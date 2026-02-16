Param(
    [Parameter(Mandatory=$false, HelpMessage="The path to the inventory CSV file. Defaults to 'inventory.csv' in the script's directory.")]
    [string]$InventoryPath = (Join-Path $PSScriptRoot "inventory.csv"),

    [Parameter(Mandatory=$false, HelpMessage="The Azure subscription ID to connect to. If not provided, the default subscription will be used.")]
    [string]$SubscriptionId = "",

    [Parameter(Mandatory=$false, HelpMessage="Set to true to perform a WhatIf operation without making actual changes.")]
    [switch]$WhatIf = $false
)

#region Functions

function Write-Log {
    Param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "Script"
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$Timestamp] [$Level] [$Component] $Message"
}

function Install-ModuleIfNotPresent {
    Param(
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log -Message "Installing PowerShell module: $ModuleName..." -Component "Dependency"
        try {
            Install-Module -Name $ModuleName -Force -Scope CurrentUser -ErrorAction Stop
            Write-Log -Message "Module $ModuleName installed successfully." -Component "Dependency"
        }
        catch {
            Write-Log -Message "Failed to install module $ModuleName. Error: $($_.Exception.Message)" -Level "ERROR" -Component "Dependency"
            throw "Failed to install module $ModuleName."
        }
    }
    else {
        Write-Log -Message "Module $ModuleName is already installed." -Component "Dependency"
    }
    Import-Module -Name $ModuleName -ErrorAction Stop
}

function Connect-Azure {
    Param(
        [string]$SubscriptionId
    )
    Write-Log -Message "Attempting to connect to Azure..." -Component "Authentication"
    try {
        # Check if already connected
        if ((Get-AzContext -ErrorAction SilentlyContinue) -and (Get-AzContext).Account.Id) {
            Write-Log -Message "Already connected to Azure." -Component "Authentication"
            # If a specific subscription is requested, ensure we are in the correct context
            if ($SubscriptionId -and (Get-AzContext).Subscription.Id -ne $SubscriptionId) {
                Write-Log -Message "Switching to subscription ID: $SubscriptionId" -Component "Authentication"
                Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
            }
            elseif (-not $SubscriptionId) {
                Write-Log -Message "Using current default subscription." -Component "Authentication"
            }
        }
        else {
            Write-Log -Message "No active Azure session found. Prompting for interactive login..." -Component "Authentication"
            Connect-AzAccount -ErrorAction Stop | Out-Null
            Write-Log -Message "Successfully connected to Azure." -Component "Authentication"
            if ($SubscriptionId) {
                Write-Log -Message "Selecting subscription ID: $SubscriptionId" -Component "Authentication"
                Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
            }
            else {
                Write-Log -Message "No subscription ID provided. Using default subscription." -Component "Authentication"
            }
        }
        $currentSubscription = (Get-AzContext).Subscription.Name
        $currentTenant = (Get-AzContext).Tenant.Id
        Write-Log -Message "Connected to subscription: '$currentSubscription' (ID: $((Get-AzContext).Subscription.Id)) in tenant: '$currentTenant'" -Component "Authentication"
        return $true
    }
    catch {
        Write-Log -Message "Failed to connect to Azure. Error: $($_.Exception.Message)" -Level "FATAL" -Component "Authentication"
        return $false
    }
}

#endregion

#region Script Execution

$ErrorActionPreference = 'Stop'
$script:SuccessfulOperations = @()
$script:FailedOperations = @()

try {
    Write-Log -Message "Starting disk downscaling remediation script..."

    # Install required Az modules
    Install-ModuleIfNotPresent -ModuleName Az.Accounts
    Install-ModuleIfNotPresent -ModuleName Az.Compute

    # Authenticate to Azure
    if (-not (Connect-Azure -SubscriptionId $SubscriptionId)) {
        throw "Authentication failed. Exiting script."
    }

    # Read inventory CSV
    if (-not (Test-Path $InventoryPath)) {
        throw "Inventory file not found: $InventoryPath"
    }
    Write-Log -Message "Loading resources from inventory file: $InventoryPath" -Component "Inventory"
    $resources = Import-Csv -Path $InventoryPath

    if (-not $resources) {
        Write-Log -Message "No resources found in the inventory file. Exiting." -Level "WARNING"
        exit 0
    }

    Write-Log -Message "Processing $($resources.Count) resources for disk downscaling."

    foreach ($resource in $resources) {
        $resourceId = $resource.ResourceId
        $resourceName = $resource.ResourceName
        $resourceType = $resource.ResourceType
        $resourceGroup = $resource.ResourceGroup
        $recommendedAction = $resource.RecommendedAction

        Write-Log -Message "Processing resource: '$resourceName' (Type: '$resourceType')" -Component "ResourceProcessing"

        if ($resourceType -eq "microsoft.compute/disks") {
            try {
                # Extract target tier from RecommendedAction
                # Example: 'Change tier from 'E10 LRS Disk' to 'S10 LRS Disk''
                if ($recommendedAction -match "to '(?<TargetTier>[^']*)'") {
                    $targetTier = $Matches.TargetTier.Split(' ')[0]
                    Write-Log -Message "Identified target disk tier for '$resourceName': $targetTier" -Component "DiskUpdate"

                    # Get the current disk object
                    $disk = Get-AzDisk -ResourceId $resourceId -ErrorAction Stop
                    $currentSku = $disk.Sku.Name

                    if ($currentSku -eq $targetTier) {
                        Write-Log -Message "Disk '$resourceName' is already at the target tier '$targetTier'. Skipping." -Level "INFO" -Component "DiskUpdate"
                        $script:SuccessfulOperations += "Disk '$resourceName' already at target tier '$targetTier'."
                        continue
                    }

                    Write-Log -Message "Attempting to update disk '$resourceName' from '$currentSku' to '$targetTier'." -Component "DiskUpdate"

                    if ($WhatIf) {
                        Write-Log -Message "WhatIf: Disk '$resourceName' would be updated to SKU '$targetTier'." -Component "DiskUpdate"
                        $script:SuccessfulOperations += "WhatIf: Disk '$resourceName' would be updated to SKU '$targetTier'."
                    }
                    else {
                        # Update-AzDisk requires the disk object, not just the ID
                        $diskConfig = New-AzDiskConfig -Disk $disk -SkuName $targetTier
                        Update-AzDisk -ResourceGroupName $resourceGroup -DiskName $resourceName -Disk $diskConfig -ErrorAction Stop | Out-Null
                        Write-Log -Message "Successfully updated disk '$resourceName' to SKU '$targetTier'." -Component "DiskUpdate"
                        $script:SuccessfulOperations += "Successfully updated disk '$resourceName' to SKU '$targetTier'."
                    }
                }
                else {
                    Write-Log -Message "Could not parse target tier from RecommendedAction for disk '$resourceName': '$recommendedAction'. Skipping." -Level "WARNING" -Component "DiskUpdate"
                    $script:FailedOperations += "Disk '$resourceName': Could not parse target tier from RecommendedAction."
                }
            }
            catch {
                Write-Log -Message "Failed to update disk '$resourceName'. Error: $($_.Exception.Message)" -Level "ERROR" -Component "DiskUpdate"
                $script:FailedOperations += "Disk '$resourceName': Failed to update. Error: $($_.Exception.Message)"
            }
        }
        else {
            Write-Log -Message "Resource type '$resourceType' for '$resourceName' is not supported by this script. Skipping." -Level "WARNING" -Component "ResourceProcessing"
            $script:FailedOperations += "Resource '$resourceName': Unsupported resource type '$resourceType'."
        }
    }
}
catch {
    Write-Log -Message "A fatal error occurred: $($_.Exception.Message)" -Level "FATAL"
    $script:FailedOperations += "Fatal Error: $($_.Exception.Message)"
}
finally {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Script execution completed." -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "Successful Operations: $($script:SuccessfulOperations.Count)" -ForegroundColor Green
    if ($script:SuccessfulOperations.Count -gt 0) {
        $script:SuccessfulOperations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
    }

    Write-Host "Failed Operations: $($script:FailedOperations.Count)" -ForegroundColor Red
    if ($script:FailedOperations.Count -gt 0) {
        $script:FailedOperations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }

    Write-Host "`nReview the summary above for details." -ForegroundColor Cyan
    Read-Host -Prompt "Press Enter to exit"
}

#endregion
