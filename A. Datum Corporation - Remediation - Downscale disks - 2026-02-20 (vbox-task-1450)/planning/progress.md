## Done
- Project created from template: remediation
- Generated remediation script: `/scripts/remediation_script_20260220_193420.ps1`

## Key Findings
- The generated PowerShell script `remediation_script_20260220_193420.ps1` is designed to resize and change the SKU of Azure managed disks.
- It supports authentication via device code flow using Tenant ID and Subscription ID.
- The script can read disk information from a CSV file (`inventory.csv` by default).
- It can deallocate VMs before resizing attached disks and restart them afterward.
- The script includes a dry-run mode to simulate changes without applying them.
- It maps Azure disk tier prefixes (E, P, S) and numbers to specific SKUs (StandardSSD_LRS, Premium_LRS, Standard_LRS) and sizes in GB.
- The script handles cases where the target size is smaller than the current size by only changing the SKU.

## In Progress
- Executing the generated remediation script.

## Pending
- Reviewing the output of the remediation script to confirm successful disk updates or identify any failures.
- Potentially running the script with the `-DryRun` parameter first if not already done.