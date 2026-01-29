# Deployment Actions Testing Repository

This repository contains test fixtures and workflows for validating the composite GitHub Actions for Helm and ArgoCD deployments.

## Repository Structure

```
├── .github/workflows/          # GitHub Actions test workflows
│   ├── test-helm-deploy.yaml   # Helm deployment action tests
│   ├── test-argocd-deploy.yaml # ArgoCD deployment action tests
│   └── validation-tests.yaml   # YAML and manifest validation tests
├── local-test.sh              # Local testing script with bastion host support
├── .yamllint.yml              # YAML validation configuration
└── test/                      # Test fixtures and configurations
    ├── charts/                # Sample Helm charts for testing
    │   └── webapp/            # Test web application chart
    │       ├── Chart.yaml
    │       ├── values*.yaml   # Environment-specific values
    │       └── templates/     # Helm templates
    └── manifests/             # Raw Kubernetes manifests
```

## Testing Strategy

### Phase 1: Validation Testing
- YAML syntax validation
- Helm chart linting and template rendering
- Kubernetes manifest validation
- Dry-run executions of both actions

### Phase 2: Integration Testing
- Actual deployments to development clusters
- Multi-environment workflow testing
- Error handling and rollback scenarios
- ArgoCD sync policy validation

## Test Scenarios

### Helm Deploy Action Tests
1. **Basic Deployment**: Deploy using default values
2. **Environment-Specific**: Deploy with different values files for dev/staging/prod
3. **Value Overrides**: Test `set-values` parameter functionality
4. **Failure Scenarios**: Invalid chart paths, missing dependencies
5. **Namespace Management**: Test `create-namespace` functionality

### ArgoCD Deploy Action Tests
1. **Helm Applications**: Deploy Helm charts via ArgoCD
2. **Sync Policies**: Test manual and automated sync policies
3. **Multi-Environment**: Test application promotion across environments

## Environment Setup

### Required Tools
- Helm 3.x
- kubectl
- ArgoCD CLI
- yamllint (for validation)

### Required Secrets (for integration testing)
```yaml
KUBECONFIG_DEV: <base64-encoded-kubeconfig>
KUBECONFIG_STAGING: <base64-encoded-kubeconfig>
KUBECONFIG_PROD: <base64-encoded-kubeconfig>
ARGOCD_DEV_TOKEN: <argocd-token>
ARGOCD_STAGING_TOKEN: <argocd-token>
ARGOCD_PROD_TOKEN: <argocd-token>
```

### Repository Variables
```yaml
ARGOCD_SERVER: argocd.company.com
CONTAINER_REGISTRY: ghcr.io
```

## Running Tests Locally

Use the provided local testing script:

```bash
./local-test.sh
```

This script automatically:
- Validates YAML syntax for all test files
- Lints and tests Helm chart rendering
- Validates Kubernetes manifests
- Falls back to bastion host access when direct cluster connectivity fails

### Manual Testing Commands

#### Validate Helm Charts
```bash
# Lint the chart
helm lint test/charts/webapp

# Test template rendering
helm template webapp test/charts/webapp --values test/charts/webapp/values-dev.yaml --debug --dry-run
```

#### Validate Kubernetes Manifests
```bash
# Dry-run apply
kubectl apply --dry-run=client -f test/manifests/
```

## Action Usage Examples

### Helm Deploy Action
```yaml
- name: Deploy to Development
  uses: Hexagon-Mining-Infrastructure/terraform-composite-actions/helm-deploy@main
  with:
    chart-path: './test/charts/webapp'
    release-name: 'webapp-dev'
    namespace: 'webapp-dev'
    environment: 'dev'
    values-file: './test/charts/webapp/values-dev.yaml'
    create-namespace: 'true'
```

### ArgoCD Deploy Action
```yaml
- name: Deploy via ArgoCD
  uses: Hexagon-Mining-Infrastructure/terraform-composite-actions/argocd-deploy@main
  with:
    argocd-server: ${{ vars.ARGOCD_SERVER }}
    argocd-token: ${{ secrets.ARGOCD_DEV_TOKEN }}
    application-name: 'webapp-dev'
    target-namespace: 'webapp-dev'
    repo-url: ${{ github.server_url }}/${{ github.repository }}
    helm-chart-path: 'test/charts/webapp'
    helm-values-file: 'test/charts/webapp/values-dev.yaml'
    environment: 'dev'
    sync-policy: 'automated'
```

---

# 🚀 **Collective Goal: Standardized Deployment Automation for Hexagon Mining Infrastructure**

## 🎯 **Overall Objective**
The deployment-actions-testing repository works together with the terraform-composite-actions repository to create a **comprehensive, standardized deployment automation system** for Hexagon Mining Infrastructure's Kubernetes applications using **GitOps principles** and **reusable GitHub Actions**.

---

## 📦 **Repository Roles**

### 1️⃣ **terraform-composite-actions** (feature/add-deployment-actions branch)
**Role**: **Deployment Action Library**
- **`helm-deploy/`** - Direct Helm chart deployments
- **`argocd-deploy/`** - GitOps deployments via ArgoCD  
- **`deploy/`** - General deployment orchestration

### 2️⃣ **deployment-actions-testing**
**Role**: **Testing & Validation Framework**
- Test fixtures for all deployment scenarios
- Comprehensive validation workflows
- Local testing capabilities with bastion host support

---

## 🏗️ **Architecture & Workflow**

### **Deployment Patterns Supported:**
1. **Direct Helm Deployments** 
   - Traditional `helm install/upgrade` approach
   - Environment-specific values files
   - Namespace management and value overrides

2. **GitOps via ArgoCD**
   - Helm applications managed by ArgoCD
   - Automated sync policies
   - Environment promotion workflows

3. **Multi-Environment Support**
   - Dev/Staging/Production configurations
   - Environment-specific secrets and values
   - Progressive deployment strategies

---

## 🔄 **Complete Deployment Flow**

```
Developer pushes code → GitHub Actions triggered → Test deployment-actions
                                ↓
                    ┌─── Helm Deploy Action ───┐
                    │                          ├─── Direct K8s deployment
                    └─── ArgoCD Deploy Action ──┘      ↓
                                              GitOps via ArgoCD
                                                       ↓
                                           Environment-specific clusters
```

### **Testing Strategy:**
- **Phase 1**: YAML validation, Helm linting, manifest validation
- **Phase 2**: Live deployment testing with actual clusters
- **Local Testing**: Comprehensive script with bastion host failover

---

## 🎁 **Key Benefits This System Provides**

### **1. Standardization**
- Consistent deployment patterns across all Hexagon Mining projects
- Reusable composite actions eliminate code duplication
- Standardized testing and validation procedures

### **2. GitOps Integration**
- ArgoCD integration for declarative deployments
- Automatic sync policies and drift detection
- Environment promotion through GitOps workflows

### **3. Multi-Environment Support**
- Seamless dev → staging → production pipelines
- Environment-specific configurations and secrets
- Cluster connectivity through bastion hosts and VPN

### **4. Comprehensive Testing**
- Local validation before deployment
- Dry-run capabilities for safe testing
- Integration testing with actual clusters
- Automated rollback and error handling

### **5. Developer Experience**
- Simple, declarative workflow syntax
- Intelligent fallbacks (direct access → bastion host)
- Clear error messages and debugging capabilities
- Comprehensive documentation and examples

---

## 🚀 **End Result**
When fully implemented, any Hexagon Mining Infrastructure team can deploy applications to Kubernetes clusters using simple workflow steps like:

```yaml
- name: Deploy to Production
  uses: Hexagon-Mining-Infrastructure/terraform-composite-actions/argocd-deploy@main
  with:
    argocd-server: ${{ vars.ARGOCD_SERVER }}
    application-name: 'my-app-prod'
    helm-chart-path: 'charts/my-app'
    environment: 'production'
    sync-policy: 'automated'
```

This creates a **unified, scalable, and maintainable deployment ecosystem** across the entire Hexagon Mining Infrastructure organization! 🎯

## Contributing

When adding new test scenarios:

1. Add test fixtures in appropriate directories
2. Update workflow files to include new test cases
3. Document any new requirements or setup steps
4. Ensure tests cover both success and failure scenarios

## Troubleshooting

### Common Issues
- **Chart not found**: Verify `chart-path` points to valid Helm chart
- **Permission denied**: Check kubeconfig permissions and cluster access
- **ArgoCD authentication**: Verify token permissions and server connectivity
- **YAML parsing**: Use yamllint to validate syntax

### Debug Commands
```bash
# Check Helm template output
helm template --debug webapp test/charts/webapp --values test/charts/webapp/values-dev.yaml

# Test ArgoCD connectivity
argocd app list --server argocd.company.com --auth-token $ARGOCD_TOKEN

# Run local tests
./local-test.sh
```