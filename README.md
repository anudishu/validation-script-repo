# Ansible IAP Deployment - Automated Cloud Build & Workflows

A fully automated Ansible deployment system using Google Cloud Build, Workflows, and Identity-Aware Proxy (IAP) for secure, zero-trust VM access.

## 🎯 Overview

This project provides **three deployment methods** for managing Linux golden images with complete automation:

1. **Workflow + Cloud Build** (Production) - Orchestrated deployment from GitHub
2. **Direct Cloud Build** (Testing) - Quick deployment with local files  
3. **Local Ansible** (Development) - Direct Ansible execution

**Key Features:**
- 🔐 IAP-based secure access (no external IPs needed)
- 🤖 Fully automated via service accounts
- 🔑 SSH keys stored securely in Secret Manager
- 📦 Supports RHEL 7/8/9 and Ubuntu
- ✅ Automated validation scripts
- 🌐 Cloud NAT for VM internet access

---

## 🚀 Quick Start (Choose Your Method)

### Method 1: Workflow + Cloud Build (Recommended for Production)

**Best for:** CI/CD pipelines, scheduled deployments, production environments

```bash
# One command to deploy
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"golden-image-rhel9.yml","target_vm":"ansible-rhel9-vm"}' \
  --location=us-central1
```

**Features:**
- ✅ Pulls latest code from GitHub automatically
- ✅ Full orchestration with error handling
- ✅ Detailed logging and monitoring
- ✅ Can be triggered from CI/CD or scheduled

### Method 2: Direct Cloud Build (Testing)

**Best for:** Quick testing, local development, rapid iteration

```bash
# Deploy with local changes
cd "Ansible-new-updated-iap copy"
gcloud builds submit . --config=cloudbuild.yaml
```

**Features:**
- ✅ Uses local files (no Git push needed)
- ✅ Faster execution
- ✅ Good for testing changes quickly

### Method 3: Local Ansible (Development)

**Best for:** Development, debugging, immediate feedback

```bash
# Direct Ansible execution
ansible-playbook -i hosts.runtime.yml playbooks/golden-image-rhel9.yml
```

**Features:**
- ✅ Immediate feedback
- ✅ Best for debugging
- ✅ No cloud resources needed

---

## 📋 Prerequisites

### 1. Google Cloud Project Setup

```bash
# Set your project
export PROJECT_ID="probable-cove-474504-p0"
gcloud config set project $PROJECT_ID

# Authenticate
gcloud auth login
```

### 2. Required APIs (Already Enabled)

- ✅ Cloud Build API
- ✅ Cloud Workflows API
- ✅ Secret Manager API
- ✅ IAP API
- ✅ Compute Engine API

### 3. Service Account (Already Configured)

**Service Account:** `ansible-automation@probable-cove-474504-p0.iam.gserviceaccount.com`

**Permissions:**
- Cloud Build Editor
- IAP Tunnel Resource Accessor
- Secret Manager Secret Accessor
- Compute Instance Admin
- Storage Object Admin
- Logs Writer

---

## 🏗 Architecture

```
┌──────────────────────────────────────────────────────┐
│  GITHUB REPOSITORY                                   │
│  https://github.com/anudishu/anisble-workflow-iap.git│
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│  GOOGLE CLOUD WORKFLOW                               │
│  - Triggers Cloud Build                              │
│  - Monitors execution                                │
│  - Returns results                                   │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│  CLOUD BUILD                                         │
│  1. Clone code from GitHub                           │
│  2. Install Ansible                                  │
│  3. Get SSH key from Secret Manager                  │
│  4. Connect via IAP tunnel                           │
│  5. Run Ansible playbook                             │
│  6. Validate deployment                              │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│  TARGET VM (No External IP)                          │
│  - Receives deployment via IAP tunnel                │
│  - Installs/configures software                      │
│  - Returns validation results                        │
└──────────────────────────────────────────────────────┘
```

---

## 📖 Deployment Guide

### Using Workflow (Production Method)

#### Basic Deployment
```bash
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"golden-image-rhel9.yml"}' \
  --location=us-central1
```

#### Deploy Different Playbook
```bash
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"golden-image-rhel8.yml","target_vm":"my-vm"}' \
  --location=us-central1
```

#### Deploy to Different VM
```bash
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"target_vm":"production-vm","vm_zone":"us-east1-b"}' \
  --location=us-central1
```

#### Custom Parameters
```bash
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{
    "target_vm": "my-custom-vm",
    "vm_zone": "us-west1-a", 
    "playbook": "my-playbook.yml",
    "git_branch": "develop"
  }' \
  --location=us-central1
```

### Using Cloud Build (Testing Method)

#### Basic Deployment
```bash
cd "Ansible-new-updated-iap copy"
gcloud builds submit . --config=cloudbuild.yaml
```

#### Deploy Different Playbook
```bash
gcloud builds submit . --config=cloudbuild.yaml \
  --substitutions=_PLAYBOOK=golden-image-rhel8.yml
```

#### Deploy to Different VM
```bash
gcloud builds submit . --config=cloudbuild.yaml \
  --substitutions=_TARGET_VM=my-vm,_VM_ZONE=us-west1-a
```

### Using Local Ansible (Development Method)

#### Run Playbook
```bash
ansible-playbook -i hosts.runtime.yml playbooks/golden-image-rhel9.yml
```

#### Run with Verbose Output
```bash
ansible-playbook -i hosts.runtime.yml playbooks/golden-image-rhel9.yml -vvv
```

#### Test Connectivity
```bash
ansible all -i hosts.runtime.yml -m ping
```

---

## 📁 Project Structure

```
Ansible-new-updated-iap/
├── README.md                            # This file
├── ansible.cfg                          # Ansible configuration
├── hosts.runtime.yml                    # Inventory for local use
├── cloudbuild.yaml                      # Cloud Build config
├── ansible-workflow-cloudbuild.yaml     # Workflow definition
│
├── playbooks/                           # Ansible playbooks
│   ├── golden-image-rhel7.yml
│   ├── golden-image-rhel8.yml
│   ├── golden-image-rhel9.yml
│   └── site.yml
│
├── roles/                               # Ansible roles
│   ├── install-java-sdk/               # Java 17 installation
│   ├── install-nodejs/                 # Node.js 18 installation
│   ├── install-python/                 # Python 3.9 installation
│   └── install-database-client/        # PostgreSQL client
│
├── validation/                          # Validation scripts
│   ├── validate_all.sh                 # Master validation
│   ├── validate_java.sh
│   ├── validate_node.sh
│   ├── validate_python.sh
│   └── validate_postgresql.sh
│
└── vars/                                # OS-specific variables
    ├── rhel7.yml
    ├── rhel8.yml
    └── rhel9.yml
```

---

## 🔐 Security Configuration

### IAP Access

All VM access goes through **Identity-Aware Proxy (IAP)**:
- ✅ No external IPs on VMs
- ✅ Encrypted tunnels
- ✅ Identity-based authentication
- ✅ Centralized access control

### SSH Key Storage

SSH keys are stored in **Secret Manager**:
- **Secret Name:** `ansible-ssh-private-key`
- **Access:** Only service account can read
- **Never exposed** in code or logs

### Network Security

- ✅ VMs have no external IP addresses
- ✅ Cloud NAT provides outbound internet (for package downloads)
- ✅ IAP tunnel for inbound SSH access
- ✅ All connections encrypted and authenticated

---

## 📊 Monitoring & Logs

### View Workflow Executions

```bash
# List recent workflow runs
gcloud workflows executions list ansible-cloudbuild-workflow \
  --location=us-central1 \
  --limit=10

# View specific execution
gcloud workflows executions describe <EXECUTION_ID> \
  --workflow=ansible-cloudbuild-workflow \
  --location=us-central1
```

### View Cloud Build Logs

```bash
# Stream build logs
gcloud builds log <BUILD_ID> --stream

# View completed build
gcloud builds describe <BUILD_ID>

# List recent builds
gcloud builds list --limit=10
```

### Cloud Console Links

- **Workflows:** https://console.cloud.google.com/workflows?project=probable-cove-474504-p0
- **Cloud Build:** https://console.cloud.google.com/cloud-build?project=probable-cove-474504-p0
- **Secret Manager:** https://console.cloud.google.com/security/secret-manager?project=probable-cove-474504-p0

---

## 🛠 Configuration

### Available Playbooks

- `golden-image-rhel7.yml` - RHEL 7 deployment
- `golden-image-rhel8.yml` - RHEL 8 deployment  
- `golden-image-rhel9.yml` - RHEL 9 deployment (default)

### Installed Software

Each golden image includes:
- ☕ **Java 17 LTS** (OpenJDK)
- 🟢 **Node.js 18 LTS** (via NodeSource)
- 🐍 **Python 3.9+** (System Python)
- 🐘 **PostgreSQL Client** (Latest stable)

### Validation

After deployment, validation runs automatically:
```bash
# Validation includes:
- Java version check
- Node.js version check
- Python version check  
- PostgreSQL client check
- Service availability
- Basic smoke tests
```

---

## 🔄 Making Changes

### Update Playbooks or Roles

1. **Make changes locally**
2. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin master
   ```
3. **Deploy via workflow** (pulls latest from GitHub):
   ```bash
   gcloud workflows run ansible-cloudbuild-workflow \
     --data='{"playbook":"golden-image-rhel9.yml"}' \
     --location=us-central1
   ```

### Test Changes Locally First

Before pushing to GitHub:
```bash
# Test with Cloud Build (uses local files)
gcloud builds submit . --config=cloudbuild.yaml

# Or test with local Ansible
ansible-playbook -i hosts.runtime.yml playbooks/golden-image-rhel9.yml
```

---

## 🎯 For Team Members (Shivani)

### Setup (One-Time)

```bash
# 1. Authenticate to Google Cloud
gcloud auth login

# 2. Set the project
gcloud config set project probable-cove-474504-p0
```

### Deploy Ansible (Anytime)

```bash
# That's it! One command to deploy:
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"golden-image-rhel9.yml"}' \
  --location=us-central1
```

**No SSH keys or credentials needed!** Everything is handled automatically by:
- Service account authentication
- SSH keys from Secret Manager
- IAP tunnel for secure access

---

## 🐛 Troubleshooting

### Workflow Failed

**Check workflow logs:**
```bash
gcloud workflows executions describe <EXECUTION_ID> \
  --workflow=ansible-cloudbuild-workflow \
  --location=us-central1
```

### Cloud Build Failed

**Check build logs:**
```bash
gcloud builds log <BUILD_ID>
```

**Common Issues:**

1. **SSH Connection Failed**
   - Check IAP permissions
   - Verify SSH key in Secret Manager
   - Ensure VM is running

2. **Playbook Not Found**
   - Verify playbook path in repository
   - Check git branch (default: master)

3. **Package Download Failed**
   - Check Cloud NAT is configured
   - Verify VM has internet access via NAT

4. **Permission Denied**
   - Check service account permissions
   - Verify IAP tunnel permissions

### Test IAP Connectivity Locally

```bash
# Test IAP tunnel
gcloud compute start-iap-tunnel ansible-rhel9-vm 22 \
  --local-host-port=localhost:2222 \
  --zone=us-central1-a

# In another terminal, test SSH
ssh -i ~/.ssh/ansible_test_key \
  -p 2222 \
  askcloudedge_gmail_com@localhost
```

---

## 📝 Configuration Files

### Workflow Configuration

**File:** `ansible-workflow-cloudbuild.yaml`

Default parameters:
```yaml
project_id: "probable-cove-474504-p0"
target_vm: "ansible-rhel9-vm"
vm_zone: "us-central1-a"
playbook: "golden-image-rhel9.yml"
git_repo: "https://github.com/anudishu/anisble-workflow-iap.git"
git_branch: "master"
```

### Cloud Build Configuration  

**File:** `cloudbuild.yaml`

Default substitutions:
```yaml
_TARGET_VM: "ansible-rhel9-vm"
_VM_ZONE: "us-central1-a"
_PLAYBOOK: "golden-image-rhel9.yml"
```

### Inventory Configuration

**File:** `hosts.runtime.yml`

```yaml
all:
  children:
    targets:
      hosts:
        ansible-rhel9-vm:
          ansible_host: ansible-rhel9-vm
          ansible_user: askcloudedge_gmail_com
          ansible_ssh_common_args: >-
            -o ProxyCommand="gcloud compute start-iap-tunnel ansible-rhel9-vm 22 
            --listen-on-stdin --project=probable-cove-474504-p0 --zone=us-central1-a
            --impersonate-service-account=ansible-automation@probable-cove-474504-p0.iam.gserviceaccount.com
            --verbosity=warning"
          ansible_ssh_private_key_file: '/Users/Sumit_Kumar/.ssh/ansible_test_key'
          ansible_python_interpreter: auto_silent
```

---

## 🎯 Use Cases & Best Practices

### Development
```bash
# Make changes → test locally
ansible-playbook -i hosts.runtime.yml playbooks/golden-image-rhel9.yml
```

### Testing
```bash
# Make changes → test with Cloud Build
gcloud builds submit . --config=cloudbuild.yaml
```

### Production
```bash
# Push to GitHub → deploy with workflow
git push origin master
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"golden-image-rhel9.yml"}' \
  --location=us-central1
```

### CI/CD Integration

Trigger from your CI/CD pipeline:
```yaml
# Example: GitHub Actions
- name: Deploy Ansible
  run: |
    gcloud workflows run ansible-cloudbuild-workflow \
      --data='{"playbook":"${{ env.PLAYBOOK }}"}' \
      --location=us-central1
```

### Scheduled Deployments

Use Cloud Scheduler:
```bash
gcloud scheduler jobs create http daily-updates \
  --schedule="0 2 * * *" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/probable-cove-474504-p0/locations/us-central1/workflows/ansible-cloudbuild-workflow/executions" \
  --message-body='{"argument":"{\"playbook\":\"daily-updates.yml\"}"}'
```

---

## 🔗 Quick Reference

### Essential Commands

```bash
# Workflow deployment (production)
gcloud workflows run ansible-cloudbuild-workflow \
  --data='{"playbook":"PLAYBOOK_NAME"}' \
  --location=us-central1

# Cloud Build deployment (testing)
gcloud builds submit . --config=cloudbuild.yaml

# Local deployment (development)
ansible-playbook -i hosts.runtime.yml playbooks/PLAYBOOK_NAME

# Test connectivity
ansible all -i hosts.runtime.yml -m ping

# View workflow logs
gcloud workflows executions list ansible-cloudbuild-workflow --location=us-central1

# View build logs
gcloud builds log <BUILD_ID>
```

---

## 📚 Resources

- **GitHub Repository:** https://github.com/anudishu/anisble-workflow-iap.git
- **Google Cloud Workflows:** https://cloud.google.com/workflows/docs
- **Google Cloud Build:** https://cloud.google.com/build/docs
- **Identity-Aware Proxy:** https://cloud.google.com/iap/docs
- **Ansible Documentation:** https://docs.ansible.com

---

## 🎉 Success Indicators

When everything is working correctly:

✅ **Workflow Execution**: Status = SUCCESS  
✅ **Cloud Build**: Status = SUCCESS (2-3 minutes)  
✅ **IAP Connectivity**: SSH tunnel establishes  
✅ **Ansible Playbook**: Completes all tasks  
✅ **Validation**: All checks pass  

---

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review Cloud Build logs
3. Verify IAP permissions and connectivity
4. Check service account permissions

---

**Last Updated:** November 13, 2025  
**Status:** ✅ Fully Operational  
**Repository:** https://github.com/anudishu/anisble-workflow-iap.git  
**Project:** probable-cove-474504-p0
