#!/bin/bash
# =============================================================
# Cost Monitoring Alerts Setup — sub-demo-001
# Goal: Establish budget and performance alerts for post-
#       rightsizing cost governance
# =============================================================

SUBSCRIPTION_ID="sub-demo-001"
RG_DEV="rg-dev"
RG_STAGING="rg-staging"
ALERT_EMAIL="your-team@example.com"  # <-- Replace with your email

# =============================================================
# 1. BUDGET ALERTS — Resource Group Level
#    Alerts at 80% and 100% of monthly budget
# =============================================================

echo "Creating budget alerts for rg-dev..."
az consumption budget create \
  --budget-name "rg-dev-monthly-budget" \
  --amount 500 \
  --time-grain Monthly \
  --resource-group $RG_DEV \
  --notifications \
    "key=Alert80,enabled=true,operator=GreaterThan,threshold=80,contactEmails=$ALERT_EMAIL" \
    "key=Alert100,enabled=true,operator=GreaterThan,threshold=100,contactEmails=$ALERT_EMAIL"

echo "Creating budget alerts for rg-staging..."
az consumption budget create \
  --budget-name "rg-staging-monthly-budget" \
  --amount 300 \
  --time-grain Monthly \
  --resource-group $RG_STAGING \
  --notifications \
    "key=Alert80,enabled=true,operator=GreaterThan,threshold=80,contactEmails=$ALERT_EMAIL" \
    "key=Alert100,enabled=true,operator=GreaterThan,threshold=100,contactEmails=$ALERT_EMAIL"

# =============================================================
# 2. CPU UNDERUTILIZATION ALERT — vm-dev-analytics
#    Trigger if avg CPU < 5% over 7 days (flag for review)
# =============================================================

echo "Creating CPU underutilization alert for vm-dev-analytics..."
az monitor metrics alert create \
  --name "vm-dev-analytics-low-cpu" \
  --resource-group $RG_DEV \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_DEV/providers/Microsoft.Compute/virtualMachines/vm-dev-analytics" \
  --condition "avg Percentage CPU < 5" \
  --window-size 7d \
  --evaluation-frequency 1d \
  --severity 3 \
  --description "vm-dev-analytics avg CPU below 5% for 7 days — candidate for further rightsizing or deallocation" \
  --action-group "" \
  --email-service-owners

# =============================================================
# 3. CPU SPIKE ALERT — vm-dev-analytics (post-rightsizing)
#    Trigger if CPU > 85% for 30 minutes — rollback signal
# =============================================================

echo "Creating CPU spike alert for vm-dev-analytics..."
az monitor metrics alert create \
  --name "vm-dev-analytics-high-cpu" \
  --resource-group $RG_DEV \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_DEV/providers/Microsoft.Compute/virtualMachines/vm-dev-analytics" \
  --condition "avg Percentage CPU > 85" \
  --window-size 30m \
  --evaluation-frequency 5m \
  --severity 1 \
  --description "vm-dev-analytics CPU above 85% — consider rolling back to Standard_D4s_v3" \
  --email-service-owners

# =============================================================
# 4. CPU SPIKE ALERT — vm-staging-api (post-rightsizing)
#    Trigger if CPU > 85% for 30 minutes — rollback signal
# =============================================================

echo "Creating CPU spike alert for vm-staging-api..."
az monitor metrics alert create \
  --name "vm-staging-api-high-cpu" \
  --resource-group $RG_STAGING \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_STAGING/providers/Microsoft.Compute/virtualMachines/vm-staging-api" \
  --condition "avg Percentage CPU > 85" \
  --window-size 30m \
  --evaluation-frequency 5m \
  --severity 1 \
  --description "vm-staging-api CPU above 85% — consider rolling back to Standard_D4s_v3" \
  --email-service-owners

# =============================================================
# 5. COST ANOMALY ALERT — Subscription Level
#    Trigger if daily spend increases >20% week-over-week
# =============================================================

echo "Creating cost anomaly alert at subscription level..."
az costmanagement alert create \
  --subscription $SUBSCRIPTION_ID \
  --alert-type Budget \
  --name "sub-demo-001-anomaly-alert" \
  --threshold 20 \
  --operator GreaterThan \
  --contact-emails $ALERT_EMAIL \
  --description "Daily spend anomaly: >20% increase week-over-week detected"

echo ""
echo "✅ All cost monitoring alerts configured successfully!"
echo "📧 Alerts will be sent to: $ALERT_EMAIL"
echo ""
echo "Alert Summary:"
echo "  - rg-dev budget alert:         80% and 100% of \$500/mo"
echo "  - rg-staging budget alert:     80% and 100% of \$300/mo"
echo "  - vm-dev-analytics low CPU:    < 5% avg over 7 days"
echo "  - vm-dev-analytics high CPU:   > 85% for 30 mins (rollback signal)"
echo "  - vm-staging-api high CPU:     > 85% for 30 mins (rollback signal)"
echo "  - Subscription anomaly alert:  >20% spend increase WoW"
