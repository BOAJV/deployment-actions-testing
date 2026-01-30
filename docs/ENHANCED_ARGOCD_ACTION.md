# Enhanced ArgoCD Deployment Action with GitHub App Authentication

## Overview
This document outlines the enhancements needed for our ArgoCD composite action to support production-grade authentication and the bootstrap deployment pattern.

## 🔧 Current vs Enhanced Action Parameters

### Current Authentication (Token-based)
```yaml
# Current - basic token authentication
argocd-username: 'admin'
argocd-password: 'test-token'  # Static token
```

### Enhanced Authentication (GitHub App + ESO)
```yaml
# Enhanced - GitHub App authentication
github-app-enabled:
  description: 'Enable GitHub App authentication for repository access'
  required: false
  default: 'false'
  
github-app-id:
  description: 'GitHub App ID (can be from secret)'
  required: false

github-app-installation-id:
  description: 'GitHub App Installation ID (can be from secret)'
  required: false

github-app-private-key:
  description: 'GitHub App private key (can be from secret/file)'
  required: false

# ESO Integration
external-secret-enabled:
  description: 'Enable External Secret for repository credentials'
  required: false
  default: 'false'

secret-store-ref:
  description: 'Reference to ClusterSecretStore or SecretStore'
  required: false
  default: 'eso-cluster-secret-store'

vault-secret-path:
  description: 'Path to secret in Vault (e.g., kv/argocd-github-app-credential)'
  required: false

# Repository Authentication
repo-auth-method:
  description: 'Repository authentication method (token|github-app|external-secret)'
  required: false
  default: 'token'
```

## 🏗️ Enhanced Action Steps

### 1. Authentication Method Detection
```bash
- name: Detect Authentication Method
  shell: bash
  run: |
    AUTH_METHOD="${{ inputs.repo-auth-method }}"
    
    case "$AUTH_METHOD" in
      "github-app")
        echo "🔐 Using GitHub App authentication"
        echo "auth-method=github-app" >> $GITHUB_OUTPUT
        ;;
      "external-secret")
        echo "🔐 Using External Secret authentication"
        echo "auth-method=external-secret" >> $GITHUB_OUTPUT
        ;;
      "token"|*)
        echo "🔐 Using token authentication"
        echo "auth-method=token" >> $GITHUB_OUTPUT
        ;;
    esac
```

### 2. External Secret Creation (when enabled)
```bash
- name: Create External Secret for Repository Authentication
  if: inputs.external-secret-enabled == 'true'
  shell: bash
  run: |
    cat > /tmp/repo-external-secret.yaml << EOF
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: ${{ inputs.application-name }}-repo-creds
      namespace: ${{ inputs.application-namespace }}
    spec:
      refreshInterval: 5m
      secretStoreRef:
        name: ${{ inputs.secret-store-ref }}
        kind: ClusterSecretStore
      target:
        name: ${{ inputs.application-name }}-repo-creds
        creationPolicy: Owner
        template:
          type: Opaque
          metadata:
            labels:
              argocd.argoproj.io/secret-type: repository
          data:
            type: git
            url: ${{ inputs.repo-url }}
            githubAppID: "{{ .appid }}"
            githubAppInstallationID: "{{ .installationid }}"
            githubAppPrivateKey: |
              {{ .privatekey }}
      data:
      - secretKey: appid
        remoteRef:
          key: ${{ inputs.vault-secret-path }}
          property: app-id
      - secretKey: installationid
        remoteRef:
          key: ${{ inputs.vault-secret-path }}
          property: installation-id
      - secretKey: privatekey
        remoteRef:
          key: ${{ inputs.vault-secret-path }}
          property: private-key
    EOF
    
    echo "📋 Applying External Secret for repository authentication..."
    kubectl apply -f /tmp/repo-external-secret.yaml
    
    # Wait for secret to be created
    echo "⏳ Waiting for External Secret to create repository credentials..."
    kubectl wait --for=condition=Ready externalsecret/${{ inputs.application-name }}-repo-creds \
      -n ${{ inputs.application-namespace }} --timeout=120s
```

### 3. GitHub App Repository Registration
```bash
- name: Register GitHub App Repository with ArgoCD
  if: steps.auth-detect.outputs.auth-method == 'github-app'
  shell: bash
  run: |
    echo "🔗 Registering GitHub App repository with ArgoCD..."
    
    # Create temporary repository credential file
    cat > /tmp/repo-creds.yaml << EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: ${{ inputs.application-name }}-repo-creds
      namespace: ${{ inputs.application-namespace }}
      labels:
        argocd.argoproj.io/secret-type: repository
    type: Opaque
    stringData:
      type: git
      url: ${{ inputs.repo-url }}
      githubAppID: "${{ inputs.github-app-id }}"
      githubAppInstallationID: "${{ inputs.github-app-installation-id }}"
      githubAppPrivateKey: |
        ${{ inputs.github-app-private-key }}
    EOF
    
    kubectl apply -f /tmp/repo-creds.yaml
    echo "✅ Repository credentials applied"
```

### 4. Enhanced Application Manifest with Authentication
```bash
- name: Prepare Enhanced Application Manifest
  shell: bash
  run: |
    # Enhanced manifest with authentication awareness
    cat > /tmp/application.yaml << EOF
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${{ inputs.application-name }}
      namespace: ${{ inputs.application-namespace }}
      labels:
        environment: ${{ inputs.environment }}
        managed-by: github-actions
        auth-method: $(echo "${{ inputs.repo-auth-method }}")
      annotations:
        argocd.argoproj.io/sync-wave: "1"
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: ${{ inputs.project }}
      source:
        repoURL: ${{ inputs.repo-url }}
        targetRevision: ${{ inputs.target-revision }}
        path: ${{ inputs.path }}
        $(echo -e "$SOURCE_CONFIG")
      destination:
        server: https://kubernetes.default.svc
        namespace: ${{ inputs.target-namespace }}
      syncPolicy:
        automated:
          prune: ${{ inputs.auto-prune }}
          selfHeal: ${{ inputs.self-heal }}
        syncOptions:
          - CreateNamespace=true
          - ApplyOutOfSyncOnly=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      revisionHistoryLimit: 3
    EOF
```

## 🎯 Bootstrap Mode Enhancement

### New Input Parameter
```yaml
bootstrap-mode:
  description: 'Enable bootstrap mode for initial ArgoCD deployment'
  required: false
  default: 'false'

bootstrap-apps-path:
  description: 'Path to additional ArgoCD applications to deploy after bootstrap'
  required: false
  default: 'applications/'
```

### Bootstrap Logic
```bash
- name: Bootstrap Additional Applications
  if: inputs.bootstrap-mode == 'true'
  shell: bash
  run: |
    echo "🚀 Bootstrap mode: Deploying additional ArgoCD applications..."
    
    # Wait for main application to be healthy
    echo "⏳ Waiting for bootstrap application to be healthy..."
    argocd app wait "${{ inputs.application-name }}" --health --timeout 300
    
    # Deploy additional applications if specified
    if [[ -n "${{ inputs.bootstrap-apps-path }}" ]]; then
      echo "📁 Looking for additional applications in: ${{ inputs.bootstrap-apps-path }}"
      
      # Clone repository to access application manifests
      git clone "${{ inputs.repo-url }}" /tmp/repo
      cd /tmp/repo
      git checkout "${{ inputs.target-revision }}"
      
      if [[ -d "${{ inputs.bootstrap-apps-path }}" ]]; then
        echo "📋 Found application manifests, deploying..."
        for app_file in "${{ inputs.bootstrap-apps-path }}"/*.yaml; do
          if [[ -f "$app_file" ]]; then
            echo "🔄 Deploying: $(basename "$app_file")"
            kubectl apply -f "$app_file"
          fi
        done
        echo "✅ Bootstrap applications deployed"
      else
        echo "ℹ️ No additional applications found in bootstrap path"
      fi
    fi
```

## 🧪 Updated Test Workflow

### Enhanced Test with Authentication
```yaml
# Updated test workflow
- name: Test ArgoCD Bootstrap with GitHub App Auth
  uses: Hexagon-Mining-Infrastructure/terraform-composite-actions/argocd-deploy@main
  with:
    argocd-server: 'argocd.test.local'
    argocd-username: 'admin'
    argocd-password: '${{ secrets.ARGOCD_TOKEN }}'
    application-name: 'argocd-bootstrap'
    target-namespace: 'argocd'
    repo-url: ${{ github.server_url }}/${{ github.repository }}
    path: 'test/argocd-bootstrap'
    environment: 'test'
    bootstrap-mode: 'true'
    bootstrap-apps-path: 'test/applications'
    repo-auth-method: 'github-app'
    github-app-id: '${{ secrets.GITHUB_APP_ID }}'
    github-app-installation-id: '${{ secrets.GITHUB_APP_INSTALLATION_ID }}'
    github-app-private-key: '${{ secrets.GITHUB_APP_PRIVATE_KEY }}'
    external-secret-enabled: 'true'
    secret-store-ref: 'eso-cluster-secret-store'
    vault-secret-path: 'kv/argocd-github-app-credential'
```

## 📁 Required Test Structure

```
test/
├── argocd-bootstrap/           # ArgoCD itself (Helm chart)
│   ├── Chart.yaml
│   └── values.yaml
├── applications/               # Apps to deploy after ArgoCD
│   ├── monitoring.yaml
│   ├── secrets.yaml
│   └── test-app.yaml
└── external-secrets/           # ESO configurations
    ├── cluster-secret-store.yaml
    └── github-app-secret.yaml
```

## 🔄 Migration Path

### Step 1: Backward Compatibility
- Keep existing token-based authentication as default
- Add new parameters as optional
- Maintain current test workflows

### Step 2: Add GitHub App Support  
- Implement GitHub App authentication logic
- Create test examples with GitHub App
- Document setup process

### Step 3: Add ESO Integration
- Implement External Secret creation
- Add Vault integration examples
- Create end-to-end bootstrap tests

### Step 4: Production Ready
- Default to GitHub App authentication
- Add comprehensive error handling
- Create production deployment guides