#!/bin/bash

# Rollback script to restore alert ConfigMaps to ca-central-1-prod-live clusters
# This script assumes the git commit has been reverted and DTs have been rebuilt

set -e

# Configuration
ATT_ROOT="${ATT_ROOT:-/all-the-things}"
REGION="ca-central-1"
ENVIRONMENT="prod-live"
CLUSTERS=("bravo" "main" "jobs")
DRY_RUN="${DRY_RUN:-true}"

# List of all 75 DTs that have alerts component
DTS=(
    "address" "agent-portal-api" "airflow-att" "alm" "amplify" "anchor" "axp" 
    "balances" "business-identity" "capital-data-sourcing" "car" "card-processor" 
    "case-mgmt" "chameleon" "checkout" "chrono-collector" "chrono-mc" "comp-fin" 
    "connect" "consumer-auth" "contact-api-gateway" "counters2" "crypto" 
    "customer-care" "data-platform" "data-replication" "dbt" "disclosures" "dms" 
    "event-management" "external-service-proxy" "fraud" "funding" "furnishing" 
    "identity" "investigations" "investor-disbursements" "job-tracking" "ledger" 
    "loc" "marketplace" "members" "merch-portal" "merchant-api" "merchant-risk" 
    "merchcore" "ml-ofs" "ml-serving" "moms-spaghetti" "originations" "partner-api" 
    "partner-solutions" "payments" "pba" "pricing" "privacy-orchestrator" 
    "purchase-management" "purchase-servicing" "qual" "rewards-api" "rewards-rpc" 
    "rewards2" "search" "segments" "servicing-gateway" "servicing-orchestration" 
    "shop-api" "sre" "superapp" "tank" "trainyard2" "treasury2" "ucp" "usercomms" 
    "webhooks"
)

echo "ATT_ROOT: $ATT_ROOT"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "DRY_RUN: $DRY_RUN"

echo "Step 1: Verifying cluster.yaml files have alerts: true..."
for cluster in "${CLUSTERS[@]}"; do
    cluster_file="$ATT_ROOT/build-tools/kubernetes/resources/envs/${REGION}-${ENVIRONMENT}/${cluster}/cluster.yaml"
    if grep -q "alerts: true" "$cluster_file" 2>/dev/null; then
        echo "  ✓ ${cluster}/cluster.yaml has alerts: true"
    else
        echo "  ✗ ERROR: ${cluster}/cluster.yaml does not have alerts: true"
        echo "    Please revert the git commit first!"
        exit 1
    fi
done
echo ""

# Step 2: Rebuild all DTs to regenerate alert ConfigMaps
echo "Step 2: Rebuilding all DTs to regenerate alert ConfigMaps..."
echo "This will take several minutes..."

rebuild_count=0
failed_builds=""

for dt in "${DTS[@]}"; do
    echo "Building $dt..."
    if [ -d "$ATT_ROOT/deployable/$dt" ]; then
        cd "$ATT_ROOT/deployable/$dt"
        if make k8s_build_all_no_git > /tmp/rollback_build_${dt}.log 2>&1; then
            rebuild_count=$((rebuild_count + 1))
            echo "  ✓ $dt rebuilt successfully"
        else
            echo "  ✗ $dt build failed - check /tmp/rollback_build_${dt}.log"
            failed_builds="$failed_builds $dt"
        fi
    fi
done

echo ""
echo "Rebuilt $rebuild_count/${#DTS[@]} DTs successfully"
if [ -n "$failed_builds" ]; then
    echo "Failed builds: $failed_builds"
fi
echo ""

total_applied=0
failed_applies=""

for cluster in "${CLUSTERS[@]}"; do
    full_cluster="${REGION}-${ENVIRONMENT}-${cluster}"
    echo ""
    echo "Processing cluster: $full_cluster"
    
    # Set kubectl context
    echo "Setting kubectl context..."
    if [ "$DRY_RUN" == "false" ]; then
        # Using scc command to set context (organization-specific tool)
        scc --cluster "${ENVIRONMENT}-${cluster}" --region "$REGION" 2>/dev/null || {
            echo "  Warning: Could not set context with scc, trying kubectl directly"
            kubectl config use-context "$full_cluster" 2>/dev/null || {
                echo "  Error: Could not set kubectl context for $full_cluster"
                continue
            }
        }
    fi
    
    for dt in "${DTS[@]}"; do
        configmap_file="$ATT_ROOT/deployable/$dt/kubernetes/build/$full_cluster/~g_v1_configmap_alerts-${dt}.yaml"
        
        if [ -f "$configmap_file" ]; then
            namespace="$dt"
            
            if [ "$DRY_RUN" == "true" ]; then
                echo "  [DRY RUN] Would apply: $configmap_file to namespace $namespace"
                total_applied=$((total_applied + 1))
            else
                echo "  Applying alert ConfigMap for $dt in namespace $namespace..."
                if kubectl apply -f "$configmap_file" -n "$namespace" 2>/tmp/kubectl_apply_error.log; then
                    echo "Applied successfully"
                    total_applied=$((total_applied + 1))
                else
                    echo "Failed to apply - check /tmp/kubectl_apply_error.log"
                    failed_applies="$failed_applies ${dt}@${cluster}"
                fi
            fi
        else
            echo " ConfigMap file not found for $dt in $full_cluster"
        fi
    done
done

echo "DTs rebuilt: $rebuild_count/${#DTS[@]}"
echo "ConfigMaps applied: $total_applied"

if [ -n "$failed_builds" ]; then
    echo ""
    echo "Failed builds: $failed_builds"
fi

if [ -n "$failed_applies" ]; then
    echo ""
    echo "Failed applies: $failed_applies"
fi

if [ "$DRY_RUN" == "true" ]; then
    echo ""
    echo "This was a DRY RUN. To actually apply changes, run:"
    echo "  DRY_RUN=false $0"
fi

echo ""
echo "============================================"

# Step 4: Verify the ConfigMaps are present in clusters
if [ "$DRY_RUN" == "false" ]; then
    echo ""
    echo "Step 4: Verifying ConfigMaps in clusters..."
    
    for cluster in "${CLUSTERS[@]}"; do
        full_cluster="${REGION}-${ENVIRONMENT}-${cluster}"
        echo "Checking $full_cluster..."
        
        scc --cluster "${ENVIRONMENT}-${cluster}" --region "$REGION" 2>/dev/null
        
        # Count alert ConfigMaps across all namespaces
        count=$(kubectl get configmap -A | grep -c "alerts-" || echo "0")
        echo "  Found $count alert ConfigMaps in $full_cluster"
    done
fi
