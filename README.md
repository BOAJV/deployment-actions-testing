# Deployment Actions Testing Repository

This repository contains test fixtures and workflows for validating the composite GitHub Actions for Helm and ArgoCD deployments.

## Repository Structure

```
├── .github/workflows/          # GitHub Actions test workflows
│   ├── test-helm-deploy.yaml   # Helm deployment action tests
│   ├── test-argocd-deploy.yaml # ArgoCD deployment action tests
│   └── validation-tests.yaml   # YAML and manifest validation tests
└── test/                       # Test fixtures and configurations
    ├── charts/                 # Sample Helm charts for testing
    │   └── webapp/             # Test web application chart
    │       ├── Chart.yaml
    │       ├── values*.yaml    # Environment-specific values
    │       └── templates/      # Helm templates
    ├── k8s/                    # Kustomize configurations
    │   ├── base/               # Base Kubernetes resources
    │   └── overlays/           # Environment-specific overlays
    │       ├── dev/
    │       ├── staging/
    │       └── prod/
    └── manifests/              # Raw Kubernetes manifests
```

## Testing Strategy

### Phase 1: Validation Testing
- YAML syntax validation
- Helm chart linting and template rendering
- Kustomize build validation
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
2. **Kustomize Applications**: Deploy using Kustomize overlays
3. **Directory Applications**: Deploy raw Kubernetes manifests
4. **Sync Policies**: Test manual and automated sync policies
5. **Multi-Environment**: Test application promotion across environments

## Environment Setup

### Required Tools
- Helm 3.x
- kubectl
- kustomize
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

### Validate Helm Charts
```bash
# Lint the chart
helm lint test/charts/webapp

# Test template rendering
helm template webapp test/charts/webapp --values test/charts/webapp/values-dev.yaml --debug --dry-run
```

### Validate Kustomize
```bash
# Build and validate overlays
kustomize build test/k8s/overlays/dev
kustomize build test/k8s/overlays/staging
kustomize build test/k8s/overlays/prod
```

### Validate Kubernetes Manifests
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

# Validate Kustomize output
kustomize build test/k8s/overlays/dev --enable-helm
```