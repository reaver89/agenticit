# =============================================================
# Cost Monitoring Alerts Setup — sub-demo-001 (PowerShell)
# Goal: Establish budget and performance alerts for post-
#       rightsizing cost governance
# =============================================================

$SubscriptionId = "sub-demo-001"
$RgDev          = "rg-dev"
$RgStaging      = "rg-staging"
$AlertEmail     = "your-team@example.com"  # <-- Replace with your email

Set-AzContext -SubscriptionId $SubscriptionId

# =============================================================
# 1. BUDGET ALERTS — Resource Group Level (80% and 100%)
# =============================================================

Write-Host "Creating budget alert for rg-dev..." -ForegroundColor Cyan

$devNotification80 = New-AzConsumptionBudgetNotification `
  -NotificationKey "Alert80" `
  -Enabled $true `
  -Operator "GreaterThan" `
  -Threshold 80 `
  -ContactEmail @($AlertEmail)

$devNotification100 = New-AzConsumptionBudgetNotification `
  -NotificationKey "Alert100" `
  -Enabled $true `
  -Operator "GreaterThan" `
  -Threshold 100 `
  -ContactEmail @($AlertEmail)

New-AzConsumptionBudget `
  -Name "rg-dev-monthly-budget" `
  -Amount 500 `
  -TimeGrain "Monthly" `
  -ResourceGroupName $RgDev `
  -Notification @($devNotification80, $devNotification100)

Write-Host "Creating budget alert for rg-staging..." -ForegroundColor Cyan

$stagingNotification80 = New-AzConsumptionBudgetNotification `
  -NotificationKey "Alert80" `
  -Enabled $true `
  -Operator "GreaterThan" `
  -Threshold 80 `
  -ContactEmail @($AlertEmail)

$stagingNotification100 = New-AzConsumptionBudgetNotification `
  -NotificationKey "Alert100" `
  -Enabled $true `
  -Operator "GreaterThan" `
  -Threshold 100 `
  -ContactEmail @($AlertEmail)

New-AzConsumptionBudget `
  -Name "rg-staging-monthly-budget" `
  -Amount 300 `
  -TimeGrain "Monthly" `
  -ResourceGroupName $RgStaging `
  -Notification @($stagingNotification80, $stagingNotification100)

# =============================================================
# 2. CPU UNDERUTILIZATION ALERT — vm-dev-analytics
#    Avg CPU < 5% over 7 days → flag for rightsizing review
# =============================================================

Write-Host "Creating CPU underutilization alert for vm-dev-analytics..." -ForegroundColor Cyan

$vmDevScope = "/subscriptions/$SubscriptionId/resourceGroups/$RgDev/providers/Microsoft.Compute/virtualMachines/vm-dev-analytics"

$lowCpuCondition = New-AzMetricAlertRuleV2Criteria `
  -MetricName "Percentage CPU" `
  -Operator "LessThan" `
  -Threshold 5 `
  -TimeAggregation "Average"

Add-AzMetricAlertRuleV2 `
  -Name "vm-dev-analytics-low-cpu" `
  -ResourceGroupName $RgDev `
  -TargetResourceScope $vmDevScope `
  -TargetResourceType "Microsoft.Compute/virtualMachines" `
  -TargetResourceRegion "eastus" `
  -Condition $lowCpuCondition `
  -WindowSize ([System.TimeSpan]::FromDays(7)) `
  -Frequency ([System.TimeSpan]::FromDays(1)) `
  -Severity 3 `
  -Description "vm-dev-analytics avg CPU below 5% for 7 days — candidate for further rightsizing or deallocation"

# =============================================================
# 3. CPU SPIKE ALERT — vm-dev-analytics (post-rightsizing)
#    CPU > 85% for 30 minutes → rollback signal
# =============================================================

Write-Host "Creating CPU spike alert for vm-dev-analytics..." -ForegroundColor Cyan

$highCpuConditionDev = New-AzMetricAlertRuleV2Criteria `
  -MetricName "Percentage CPU" `
  -Operator "GreaterThan" `
  -Threshold 85 `
  -TimeAggregation "Average"

Add-AzMetricAlertRuleV2 `
  -Name "vm-dev-analytics-high-cpu" `
  -ResourceGroupName $RgDev `
  -TargetResourceScope $vmDevScope `
  -TargetResourceType "Microsoft.Compute/virtualMachines" `
  -TargetResourceRegion "eastus" `
  -Condition $highCpuConditionDev `
  -WindowSize ([System.TimeSpan]::FromMinutes(30)) `
  -Frequency ([System.TimeSpan]::FromMinutes(5)) `
  -Severity 1 `
  -Description "vm-dev-analytics CPU above 85% — consider rolling back to Standard_D4s_v3"

# =============================================================
# 4. CPU SPIKE ALERT — vm-staging-api (post-rightsizing)
#    CPU > 85% for 30 minutes → rollback signal
# =============================================================

Write-Host "Creating CPU spike alert for vm-staging-api..." -ForegroundColor Cyan

$vmStagingScope = "/subscriptions/$SubscriptionId/resourceGroups/$RgStaging/providers/Microsoft.Compute/virtualMachines/vm-staging-api"

$highCpuConditionStaging = New-AzMetricAlertRuleV2Criteria `
  -MetricName "Percentage CPU" `
  -Operator "GreaterThan" `
  -Threshold 85 `
  -TimeAggregation "Average"

Add-AzMetricAlertRuleV2 `
  -Name "vm-staging-api-high-cpu" `
  -ResourceGroupName $RgStaging `
  -TargetResourceScope $vmStagingScope `
  -TargetResourceType "Microsoft.Compute/virtualMachines" `
  -TargetResourceRegion "eastus" `
  -Condition $highCpuConditionStaging `
  -WindowSize ([System.TimeSpan]::FromMinutes(30)) `
  -Frequency ([System.TimeSpan]::FromMinutes(5)) `
  -Severity 1 `
  -Description "vm-staging-api CPU above 85% — consider rolling back to Standard_D4s_v3"

# =============================================================
# 5. SUMMARY
# =============================================================

Write-Host ""
Write-Host "✅ All cost monitoring alerts configured successfully!" -ForegroundColor Green
Write-Host "📧 Alerts will be sent to: $AlertEmail" -ForegroundColor Green
Write-Host ""
Write-Host "Alert Summary:" -ForegroundColor Yellow
Write-Host "  - rg-dev budget alert:         80% and 100% of `$500/mo"
Write-Host "  - rg-staging budget alert:     80% and 100% of `$300/mo"
Write-Host "  - vm-dev-analytics low CPU:    < 5% avg over 7 days"
Write-Host "  - vm-dev-analytics high CPU:   > 85% for 30 mins (rollback signal)"
Write-Host "  - vm-staging-api high CPU:     > 85% for 30 mins (rollback signal)"
