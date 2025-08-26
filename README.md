# Kubernetes Alerts ConfigMap Rollback Scripts

This repository contains rollback scripts and documentation for restoring alert ConfigMaps to Kubernetes clusters after they have been disabled.

## Background

These scripts were created to support the deprecation of legacy alert ConfigMaps that were migrated to Chronosphere. The scripts provide a safe rollback mechanism if the deprecated ConfigMaps need to be restored.

## Contents

### Scripts

1. **rollback_alerts_configmaps.sh**
   - Complete rollback solution (all steps)
   - Verifies configuration changes
   - Rebuilds all affected deployables
   - Applies ConfigMaps to clusters
   - Includes dry-run mode for safety

2. **apply_alerts_configmaps_only.sh**
   - Quick recovery script
   - Assumes git revert and rebuild are complete
   - Only handles ConfigMap application to clusters
   - Faster for emergency recovery

### Documentation

- **docs/rollback_strategy.txt** - Detailed explanation of the rollback process and why each step is necessary

## Usage

### Complete Rollback

```bash
# First, revert the git commit that disabled alerts
git revert <commit-sha>

# Run the complete rollback script
export ATT_ROOT=/path/to/all-the-things
DRY_RUN=false ./rollback_alerts_configmaps.sh
```

### Quick Apply (if rebuild is already done)

```bash
export ATT_ROOT=/path/to/all-the-things
./apply_alerts_configmaps_only.sh
```

## Configuration

The scripts target:
- Region: ca-central-1
- Environment: prod-live
- Clusters: bravo, main, jobs
- 75 deployables with alert components

## Recovery Time

- Git revert: ~30 seconds
- Rebuild all deployables: 10-15 minutes
- Apply ConfigMaps: 3-5 minutes per cluster
- **Total recovery time: ~20-25 minutes**

## Prerequisites

- Access to the all-the-things repository
- kubectl configured with appropriate cluster access
- scc tool for cluster context switching (or modify scripts to use kubectl config directly)
- Appropriate permissions to apply ConfigMaps to namespaces

## Affected Deployables

The scripts handle 75 deployables that contain alert components:

address, agent-portal-api, airflow-att, alm, amplify, anchor, axp, balances, business-identity, capital-data-sourcing, car, card-processor, case-mgmt, chameleon, checkout, chrono-collector, chrono-mc, comp-fin, connect, consumer-auth, contact-api-gateway, counters2, crypto, customer-care, data-platform, data-replication, dbt, disclosures, dms, event-management, external-service-proxy, fraud, funding, furnishing, identity, investigations, investor-disbursements, job-tracking, ledger, loc, marketplace, members, merch-portal, merchant-api, merchant-risk, merchcore, ml-ofs, ml-serving, moms-spaghetti, originations, partner-api, partner-solutions, payments, pba, pricing, privacy-orchestrator, purchase-management, purchase-servicing, qual, rewards-api, rewards-rpc, rewards2, search, segments, servicing-gateway, servicing-orchestration, shop-api, sre, superapp, tank, trainyard2, treasury2, ucp, usercomms, webhooks

## Verification

After running the rollback:

```bash
# Check ConfigMaps are restored
kubectl get configmap -A | grep alerts- | wc -l
# Should show ~162 ConfigMaps

# Verify specific ConfigMap
kubectl get configmap -n address alerts-address -o yaml
```

## Important Notes

- These ConfigMaps are orphaned (not actively used)
- Primary monitoring continues through Chronosphere
- No service disruption during rollback
- ConfigMaps can be selectively restored if needed

## License

Internal use only

## Support

For questions or issues, contact the Kubernetes platform team. 