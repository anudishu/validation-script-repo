# Workflow Setup Guide

This guide lists all placeholders and values that need to be changed before using this workflow.

## 📋 Quick Start - Configuration Placeholders

**IMPORTANT:** All configuration values are now clearly marked with placeholders in the format `<<PLACEHOLDER_NAME>>` at the beginning of the `workflow-both-case.yml` file.

### Where to Find Placeholders

Open `workflow-both-case.yml` and look for the **"CONFIGURATION PLACEHOLDERS"** section in the `init` step (around line 30-70). All placeholders are clearly marked and documented.

### Required Changes

All placeholders are located in the `init` step of the workflow. Search for `<<PLACEHOLDER_NAME>>` and replace with your actual values:

1. **<<BUILD_PROJECT_ID>>** - Your build project ID (where VMs are created and validated)
2. **<<DISPLAY_PROJECT_ID>>** - Your display project ID (where ephemeral images are promoted)
3. **<<SERVICE_ACCOUNT_EMAIL>>** - Your service account email
4. **<<REPO_URL>>** - Your GitHub repository URL containing validation scripts
5. **<<REPO_BRANCH>>** - Your repository branch (default: "master")
6. **<<ZONE>>** - Your GCP zone (e.g., "us-central1-a")
7. **<<MACHINE_TYPE>>** - Your VM machine type (e.g., "n1-standard-1")
8. **<<REGION>>** - Your GCP region (e.g., "us-central1")
9. **<<LOCATION_ID>>** - Your location ID (typically same as region)
10. **<<PUBSUB_TOPIC_NAME>>** - Your Pub/Sub topic name for promotion notifications
11. **<<PUBSUB_VALIDATION_TOPIC_NAME>>** - Your Pub/Sub topic name for validation results

---

## 🎯 Workflow Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        RUNTIME VALIDATION WORKFLOW                                   │
│                         (Combined Case 1 & Case 2)                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                    ┌─────────────┐
                                    │   INPUT     │
                                    │ image_id    │
                                    │server_type  │
                                    └──────┬──────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │  Workflow Init Step    │
                              │  (Configuration)       │
                              └────────────┬───────────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │  Route by server_type  │
                              └──────┬────────┬────────┘
                                     │        │
                    ┌────────────────┘        └────────────────┐
                    │                                            │
                    ▼                                            ▼
        ┌───────────────────────┐                  ┌───────────────────────┐
        │   CASE 1: PERSISTENT  │                  │   CASE 2: EPHEMERAL    │
        └───────────────────────┘                  └───────────────────────┘
                    │                                            │
                    ▼                                            ▼
        ┌───────────────────────┐                  ┌───────────────────────┐
        │  Cloud Build Trigger   │                  │  Cloud Build Trigger   │
        │  - Clone Repo          │                  │  - Clone Repo          │
        │  - Create VM           │                  │  - Create VM            │
        │  - Run validate.sh     │                  │  - Run startup script  │
        └───────────┬───────────┘                  └───────────┬───────────┘
                    │                                            │
                    ▼                                            ▼
        ┌───────────────────────┐                  ┌───────────────────────┐
        │  Validation VM         │                  │  Validation VM         │
        │  (Persistent)          │                  │  (Ephemeral)           │
        │  - Runs validation     │                  │  - Runs validation     │
        │  - Returns result      │                  │  - Publishes to        │
        └───────────┬───────────┘                  │    Pub/Sub topic       │
                    │                              └───────────┬───────────┘
                    │                                            │
                    ▼                                            ▼
        ┌───────────────────────┐                  ┌───────────────────────┐
        │  Check Result          │                  │  Check Result          │
        │  (Pass/Fail)           │                  │  (Pass/Fail)           │
        └───────┬───────────────┘                  └───────┬───────────────┘
                │                                            │
        ┌───────┴────────┐                         ┌───────┴────────┐
        │                │                         │                │
        ▼                ▼                         ▼                ▼
   ┌────────┐    ┌──────────┐              ┌────────┐    ┌──────────┐
   │  Pass   │    │   Fail   │              │  Pass   │    │   Fail   │
   └────┬───┘    └────┬──────┘              └────┬───┘    └────┬──────┘
        │             │                            │             │
        ▼             │                            ▼             │
┌───────────────┐     │                    ┌───────────────┐     │
│ Publish to    │     │                    │ Create New   │     │
│ Pub/Sub Topic │     │                    │ Ephemeral     │     │
│ (Promotion)   │     │                    │ Image         │     │
└───────┬───────┘     │                    └───────┬───────┘     │
        │             │                            │             │
        │             │                            ▼             │
        │             │                    ┌───────────────┐     │
        │             │                    │ Promote Image │     │
        │             │                    │ to Display    │     │
        │             │                    │ Project       │     │
        │             │                    └───────┬───────┘     │
        │             │                            │             │
        └─────────────┴────────────────────────────┴─────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Cleanup Step        │
                    │   - Delete VM         │
                    │   - (Optional) Delete │
                    │     Image             │
                    └───────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Return Results      │
                    │   - scan_result       │
                    │   - validation_status │
                    │   - new_image_id      │
                    │   - promotion_result  │
                    └───────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              PUB/SUB TOPICS USAGE                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘

CASE 1 (Persistent):
  Workflow ──[Publish]──> runtime-workflow-promote-topic ──> External System
  Purpose: Notify downstream workflows about promotion/cleanup actions

CASE 2 (Ephemeral):
  VM Startup Script ──[Publish]──> runtime-validation-results ──> Cloud Build
  Purpose: Retrieve validation results from VM asynchronously


┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              KEY COMPONENTS                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘

📦 Repository (GitHub)
  ├── scripts/validation/validate.sh (Case 1)
  └── pipeline/rhel8/validation/validate_ephemeral.sh (Case 2)

☁️  Google Cloud Services
  ├── Cloud Workflows (Orchestration)
  ├── Cloud Build (VM Creation & Validation)
  ├── Compute Engine (VMs)
  ├── Pub/Sub (Messaging)
  └── Image Registry (Image Storage)

🔑 Service Account
  └── Requires permissions in both Build & Display projects
```

---

## 📋 Detailed Configuration Guide

### 1. Project IDs

**Location:** `workflow-both-case.yml` - `init` step, look for `<<BUILD_PROJECT_ID>>` and `<<DISPLAY_PROJECT_ID>>`

**Action Required:**
- Replace `<<BUILD_PROJECT_ID>>` with your **build project ID** (where VMs are created and validated)
- Replace `<<DISPLAY_PROJECT_ID>>` with your **display project ID** (where ephemeral images are promoted)

**Example:**
```yaml
- project_id: ${default(map.get(input, "project_id"), "my-build-project-123456")}
- display_project_id: ${default(map.get(input, "display_project_id"), "my-display-project-789012")}
```

---

### 2. Service Account

**Location:** `workflow-both-case.yml` - `init` step, look for `<<SERVICE_ACCOUNT_EMAIL>>`

**Action Required:**
- Replace `<<SERVICE_ACCOUNT_EMAIL>>` with your service account email
- Format: `{service-account-name}@{project-id}.iam.gserviceaccount.com`

**Example:**
```yaml
- service_account: ${default(
    map.get(input, "service_account"), "my-sa@my-project-123456.iam.gserviceaccount.com")}
```

**Service Account Permissions Required:**

**In Build Project:**
- `roles/compute.instanceAdmin.v1` - Create/delete VMs
- `roles/compute.storageAdmin` - Create/manage images
- `roles/storage.objectAdmin` - Access GCS bucket
- `roles/cloudbuild.builds.editor` - Run Cloud Build jobs
- `roles/workflows.invoker` - Invoke workflows

**In Display Project:**
- `roles/compute.imageUser` - Create images (for promotion)

**Grant Display Project Permission:**
```bash
gcloud projects add-iam-policy-binding {DISPLAY_PROJECT_ID} \
  --member="serviceAccount:{SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/compute.imageUser"
```

---

### 3. Repository Configuration

**Location:** `workflow-both-case.yml` - `init` step, look for `<<REPO_URL>>` and `<<REPO_BRANCH>>`

**Action Required:**
- Replace `<<REPO_URL>>` with your GitHub repository URL containing validation scripts
- Replace `<<REPO_BRANCH>>` with your repository branch (default: "master")

**Repository Structure Required:**
```
your-repo/
  ├── scripts/
  │   └── validation/
  │       └── validate.sh
  └── pipeline/
      └── rhel8/
          └── validation/
              └── validate_ephemeral.sh
```

**Example:**
```yaml
- repo_url: ${default(map.get(input, "repo_url"), "https://github.com/your-org/validation-script-repo.git")}
- repo_branch: ${default(map.get(input, "repo_branch"), "master")}
```

---

### 4. Zone and Machine Type

**Location:** `workflow-both-case.yml` - `init` step, look for `<<ZONE>>` and `<<MACHINE_TYPE>>`

**Action Required:**
- Replace `<<ZONE>>` with your preferred zone (e.g., "us-central1-a", "us-east1-b")
- Replace `<<MACHINE_TYPE>>` with your preferred machine type (e.g., "n1-standard-1", "n1-standard-2", "e2-medium")

**Example:**
```yaml
- zone: ${default(map.get(input, "zone"), "us-central1-a")}
- machine_type: ${default(map.get(input, "machine_type"), "n1-standard-1")}
```

---

### 5. Region and Location ID

**Location:** `workflow-both-case.yml` - `init` step, look for `<<REGION>>` and `<<LOCATION_ID>>`

**Action Required:**
- Replace `<<REGION>>` with your preferred region (e.g., "us-central1", "us-east1")
- Replace `<<LOCATION_ID>>` with your location ID (typically same as region)

**Example:**
```yaml
- region: ${default(map.get(input, "region"), "us-central1")}
- location_id: ${default(map.get(input, "location_id"), "us-central1")}
```

---

### 6. Pub/Sub Topics

**Location:** `workflow-both-case.yml` - Look for `<<PUBSUB_TOPIC_NAME>>` and `<<PUBSUB_VALIDATION_TOPIC_NAME>>`

**Action Required:**
- Replace `<<PUBSUB_TOPIC_NAME>>` with your Pub/Sub topic name for promotion notifications
- Replace `<<PUBSUB_VALIDATION_TOPIC_NAME>>` with your Pub/Sub topic name for validation results

**Create Pub/Sub Topics:**
```bash
# Promotion topic
gcloud pubsub topics create <<PUBSUB_TOPIC_NAME>> \
  --project={BUILD_PROJECT_ID}

# Validation results topic
gcloud pubsub topics create <<PUBSUB_VALIDATION_TOPIC_NAME>> \
  --project={BUILD_PROJECT_ID}
```

---

### 6. Workflow Deployment

**Deploy the workflow:**
```bash
gcloud workflows deploy runtime-validation-workflow \
  --source=workflow-both-case.yml \
  --location=us-central1 \
  --project={BUILD_PROJECT_ID}
```

---

## 🔧 Configuration Summary

| Placeholder | Description | Your Value |
|------------|-------------|------------|
| **<<BUILD_PROJECT_ID>>** | Build project ID (where VMs are created) | `_____________` |
| **<<DISPLAY_PROJECT_ID>>** | Display project ID (where images are promoted) | `_____________` |
| **<<SERVICE_ACCOUNT_EMAIL>>** | Service account email | `_____________` |
| **<<REPO_URL>>** | GitHub repository URL | `_____________` |
| **<<REPO_BRANCH>>** | Repository branch | `_____________` |
| **<<ZONE>>** | GCP zone | `_____________` |
| **<<MACHINE_TYPE>>** | VM machine type | `_____________` |
| **<<REGION>>** | GCP region | `_____________` |
| **<<LOCATION_ID>>** | Location ID | `_____________` |
| **<<PUBSUB_TOPIC_NAME>>** | Pub/Sub topic for promotions | `_____________` |
| **<<PUBSUB_VALIDATION_TOPIC_NAME>>** | Pub/Sub topic for validation results | `_____________` |

---

## 📝 Quick Setup Checklist

1. **Open `workflow-both-case.yml`** and find the `init` step
2. **Search for "CONFIGURATION PLACEHOLDERS"** section
3. **Replace all `<<PLACEHOLDER_NAME>>` values** with your actual values:
   - [ ] Replace `<<BUILD_PROJECT_ID>>` with your build project ID
   - [ ] Replace `<<DISPLAY_PROJECT_ID>>` with your display project ID
   - [ ] Replace `<<SERVICE_ACCOUNT_EMAIL>>` with your service account email
   - [ ] Replace `<<REPO_URL>>` with your repository URL
   - [ ] Replace `<<REPO_BRANCH>>` with your repository branch
   - [ ] Replace `<<ZONE>>` with your preferred zone
   - [ ] Replace `<<MACHINE_TYPE>>` with your preferred machine type
   - [ ] Replace `<<REGION>>` with your preferred region
   - [ ] Replace `<<LOCATION_ID>>` with your location ID
   - [ ] Replace `<<PUBSUB_TOPIC_NAME>>` with your Pub/Sub topic name
   - [ ] Replace `<<PUBSUB_VALIDATION_TOPIC_NAME>>` with your validation topic name
4. **Additional Setup:**
   - [ ] Grant service account `compute.imageUser` role in display project
   - [ ] Create Pub/Sub topics (if they don't exist)
   - [ ] Ensure repository contains required validation scripts
   - [ ] Deploy workflow

---

## 🚀 Usage Examples

**Run Persistent Case:**
```bash
gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project={BUILD_PROJECT_ID} \
  --data='{"image_id":"your-image-name","server_type":"persistent"}'
```

**Run Ephemeral Case:**
```bash
gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project={BUILD_PROJECT_ID} \
  --data='{"image_id":"your-image-name","server_type":"ephemeral"}'
```

**Run Both in Parallel:**
```bash
# Execute both commands in separate terminals or use background processes
gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project={BUILD_PROJECT_ID} \
  --data='{"image_id":"your-image-name","server_type":"persistent"}'

gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project={BUILD_PROJECT_ID} \
  --data='{"image_id":"your-image-name","server_type":"ephemeral"}'
```

---

## ⚙️ Optional Parameters

You can override defaults via input:

```json
{
  "image_id": "your-image-name",
  "server_type": "ephemeral",
  "project_id": "override-build-project",
  "display_project_id": "override-display-project",
  "service_account": "override-service-account@project.iam.gserviceaccount.com",
  "gcs_bucket": "override-bucket-name",
  "gcs_scripts_path": "scripts",
  "zone": "us-east1-b",
  "machine_type": "n1-standard-2",
  "delete_image": false,
  "skip_destroy": false,
  "skip_promotion": false
}
```

---

## 🔍 Verification Steps

1. **Check GCS scripts exist:**
   ```bash
   gsutil ls gs://{BUCKET}/scripts/validate.sh
   gsutil ls gs://{BUCKET}/scripts/validate_ephemeral.sh
   ```

2. **Check service account permissions:**
   ```bash
   gcloud projects get-iam-policy {BUILD_PROJECT_ID} \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:{SERVICE_ACCOUNT}"
   ```

3. **Test workflow execution:**
   ```bash
   gcloud workflows executions list \
     --workflow=runtime-validation-workflow \
     --location=us-central1 \
     --project={BUILD_PROJECT_ID}
   ```

---

## 📞 Support

If you encounter issues:
1. Check Cloud Build logs for detailed errors
2. Verify all GCS scripts are uploaded correctly
3. Ensure service account has all required permissions
4. Check that image names don't exceed 63 characters
5. Verify VM instance names are unique (use `-persistent` and `-ephemeral` suffixes)

