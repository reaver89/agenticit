#!/bin/bash
# ============================================================
# Script: List All Azure VMs
# Description: Retrieves all Virtual Machines across a 
#              subscription with key details including name,
#              resource group, location, size, OS, and status.
# Prerequisites: Azure CLI installed & logged in (az login)
# ============================================================

# ------------------------------
# Configuration
# ------------------------------
SUBSCRIPTION_ID="sub-demo-001"  # Replace with your subscription ID

# Set the active subscription
az account set --subscription "$SUBSCRIPTION_ID"

echo "=============================================="
echo " Listing All Azure VMs"
echo " Subscription: $SUBSCRIPTION_ID"
echo "=============================================="

# ------------------------------
# 1. Basic VM List (Name, RG, Location, Size, OS, Status)
# ------------------------------
echo ""
echo ">>> All VMs with Status:"
echo ""
az vm list \
  --subscription "$SUBSCRIPTION_ID" \
  --show-details \
  --query "[].{
    Name:name,
    ResourceGroup:resourceGroup,
    Location:location,
    Size:hardwareProfile.vmSize,
    OS:storageProfile.osDisk.osType,
    PowerState:powerState,
    ProvisioningState:provisioningState
  }" \
  --output table

# ------------------------------
# 2. VM Count Summary
# ------------------------------
echo ""
echo ">>> Total VM Count:"
az vm list --subscription "$SUBSCRIPTION_ID" --query "length([])" --output tsv

# ------------------------------
# 3. VMs by Resource Group
# ------------------------------
echo ""
echo ">>> VMs grouped by Resource Group:"
az vm list \
  --subscription "$SUBSCRIPTION_ID" \
  --query "sort_by([].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize}, &ResourceGroup)" \
  --output table

# ------------------------------
# 4. Running VMs Only
# ------------------------------
echo ""
echo ">>> Running VMs only:"
az vm list \
  --subscription "$SUBSCRIPTION_ID" \
  --show-details \
  --query "[?powerState=='VM running'].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize, Location:location}" \
  --output table

# ------------------------------
# 5. Stopped/Deallocated VMs (cost optimization candidates)
# ------------------------------
echo ""
echo ">>> Stopped or Deallocated VMs (still incurring disk costs):"
az vm list \
  --subscription "$SUBSCRIPTION_ID" \
  --show-details \
  --query "[?powerState=='VM deallocated' || powerState=='VM stopped'].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize, PowerState:powerState}" \
  --output table

# ------------------------------
# 6. Export Full VM List to JSON
# ------------------------------
OUTPUT_FILE="azure_vm_list_$(date +%Y%m%d).json"
echo ""
echo ">>> Exporting full VM details to $OUTPUT_FILE ..."
az vm list \
  --subscription "$SUBSCRIPTION_ID" \
  --show-details \
  --output json > "$OUTPUT_FILE"

echo ""
echo "✅ Done! Full VM list exported to: $OUTPUT_FILE"
echo "=============================================="
