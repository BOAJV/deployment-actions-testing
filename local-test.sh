#!/bin/bash

echo "🧪 Starting Local Deployment Actions Testing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 passed${NC}"
    else
        echo -e "${RED}❌ $1 failed${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}📋 Step 1: YAML Syntax Validation${NC}"
# Validate values files and Chart.yaml only (skip templates due to Helm syntax)
yamllint -c .yamllint.yml test/charts/webapp/values*.yaml test/charts/webapp/Chart.yaml
check_status "Helm values and Chart YAML validation"

yamllint test/manifests/
check_status "Kubernetes manifest YAML validation"


echo -e "${YELLOW}📋 Step 2: Helm Chart Validation${NC}"
helm lint test/charts/webapp
check_status "Helm lint validation"

echo -e "${YELLOW}📋 Step 3: Helm Template Rendering Tests${NC}"

# Dev environment
helm template webapp test/charts/webapp \
    --values test/charts/webapp/values-dev.yaml \
    --debug --dry-run > /dev/null
check_status "Helm template rendering - Dev"

# Staging environment
helm template webapp test/charts/webapp \
    --values test/charts/webapp/values-staging.yaml \
    --debug --dry-run > /dev/null
check_status "Helm template rendering - Staging"

# Production environment
helm template webapp test/charts/webapp \
    --values test/charts/webapp/values-prod.yaml \
    --debug --dry-run > /dev/null
check_status "Helm template rendering - Production"

echo -e "${YELLOW}📋 Step 4: Helm Set-Values Testing${NC}"
helm template webapp test/charts/webapp \
    --values test/charts/webapp/values-staging.yaml \
    --set replicaCount=3,image.tag=staging-v1.0.0 \
    --debug --dry-run > /dev/null
check_status "Helm set-values parameter testing"

echo -e "${YELLOW}📋 Step 5: Kubernetes Manifest Validation${NC}"

# Function to test via bastion
test_via_bastion() {
    local success=true
    for manifest in test/manifests/*.yaml; do
        if ! ssh -i ~/.ssh/kp-bastion-hxmin-mgmt-dev6-20250924120213125800000012.pem ubuntu@3.219.25.128 "kubectl apply --dry-run=client -f -" < "$manifest" >/dev/null 2>&1; then
            success=false
            break
        fi
    done
    return $($success && echo 0 || echo 1)
}

# Try direct access first, fallback to bastion
if timeout 10 kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
    kubectl apply --dry-run=client -f test/manifests/ >/dev/null
    check_status "Kubernetes manifest validation (direct cluster access)"
else
    echo -e "${YELLOW}Direct cluster access failed, using bastion host...${NC}"
    if test_via_bastion; then
        check_status "Kubernetes manifest validation (via bastion host)"
    else
        echo -e "${RED}❌ Kubernetes manifest validation failed (bastion host)${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}🎉 All local tests completed successfully!${NC}"
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "   - Run workflow tests in GitHub Actions"
echo "   - Deploy to development environment"
echo "   - Test ArgoCD integration (requires ArgoCD server access)"