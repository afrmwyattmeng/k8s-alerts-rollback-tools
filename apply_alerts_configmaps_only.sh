
set -e

ATT_ROOT="${ATT_ROOT:-/Desktop/all-the-things}"
REGION="ca-central-1"
ENVIRONMENT="prod-live"
CLUSTERS=("bravo" "main" "jobs")

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

for cluster in "${CLUSTERS[@]}"; do
    full_cluster="${REGION}-${ENVIRONMENT}-${cluster}"
    
    echo "Setting context for $full_cluster..."
    scc --cluster "${ENVIRONMENT}-${cluster}" --region "$REGION"
    
    echo "Applying ConfigMaps to $full_cluster..."
    applied=0
    
    for dt in "${DTS[@]}"; do
        configmap_file="$ATT_ROOT/deployable/$dt/kubernetes/build/$full_cluster/~g_v1_configmap_alerts-${dt}.yaml"
        
        if [ -f "$configmap_file" ]; then
            kubectl apply -f "$configmap_file" -n "$dt"
            applied=$((applied + 1))
            echo "  Applied: alerts-${dt}"
        fi
    done
    
    echo "Applied $applied ConfigMaps to $full_cluster"
    echo ""
done
