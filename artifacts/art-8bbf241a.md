# VM Rightsizing Changes & Cost Optimization Report
**Subscription:** sub-demo-001
**Date:** 2025
**Goal:** Reduce Azure production infrastructure costs by 25%

---

## Summary of Rightsizing Changes

| VM Name | Resource Group | Current SKU | Recommended SKU | Avg CPU (30d) | Current Cost | New Cost | Monthly Saving | Annual Saving |
|---|---|---|---|---|---|---|---|---|
| vm-dev-analytics | rg-dev | Standard_D8s_v3 | Standard_D2s_v3 | 1.2% | $388/mo | $97/mo | $291/mo | $3,492/yr |
| vm-staging-api | rg-staging | Standard_D4s_v3 | Standard_D2s_v3 | 3.8% | $194/mo | $97/mo | $97/mo | $1,164/yr |

**Total VM Rightsizing Savings: $388/mo | $4,656/yr**

---

## Orphaned Disk Deletions

| Disk Name | Resource Group | Size | SKU | Monthly Cost |
|---|---|---|---|---|
| disk-old-01 | rg-dev | 512 GB | Premium_LRS | $69.12/mo |
| disk-backup-02 | rg-staging | 256 GB | Standard_LRS | $9.60/mo |
| disk-test-03 | rg-dev | 128 GB | Premium_LRS | $17.28/mo |

**Total Disk Savings: $96/mo | $1,152/yr**

---

## Combined Optimization Potential

| Category | Monthly Savings | Annual Savings |
|---|---|---|
| VM Rightsizing | $582.00 | $6,984.00 |
| Orphaned Disks | $96.00 | $1,152.00 |
| **Grand Total** | **$678.00** | **$8,136.00** |

---

## Rightsizing Risk Assessment

### vm-dev-analytics
- **Risk Level:** 🟢 Low
- **Rationale:** Dev workload at 1.2% CPU — extreme over-provisioning. 2-core VM has ample headroom.
- **Recommended Action:** Resize to Standard_D2s_v3. Schedule during off-hours.
- **Rollback Plan:** Resize back to Standard_D4s_v3 if performance issues arise post-resize.

### vm-staging-api
- **Risk Level:** 🟡 Medium
- **Rationale:** Staging API at 3.8% CPU. Monitor for traffic spikes post-resize.
- **Recommended Action:** Resize to Standard_D2s_v3. Monitor for 1–2 weeks.
- **Rollback Plan:** Resize back to Standard_D4s_v3 if p95 latency degrades or CPU sustains >70%.

---

## Cost Monitoring Alerts (To Be Established)

- Budget alert at 80% and 100% of monthly budget per resource group
- CPU utilization alert: trigger if avg CPU < 5% for 7 consecutive days (flag for rightsizing review)
- CPU spike alert: trigger if avg CPU > 85% for 30 minutes post-rightsizing (rollback signal)
- Anomaly alert: trigger if daily spend increases >20% week-over-week

---

## Post-Optimization Validation Checklist

- [ ] Confirm vm-dev-analytics resize complete and VM is running
- [ ] Confirm vm-staging-api resize complete and VM is running
- [ ] Monitor CPU utilization for 7 days post-resize
- [ ] Monitor application response times / latency for 7 days post-resize
- [ ] Confirm orphaned disk deletions complete
- [ ] Validate monthly cost report reflects savings after first billing cycle
- [ ] Review and adjust budget alert thresholds after first month
