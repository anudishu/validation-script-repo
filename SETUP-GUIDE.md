# Workflow Setup Guide

This guide lists all placeholders and values that need to be changed before using this workflow.

## 📋 Required Changes

### 1. Project IDs

**Location:** `workflow-both-case.yml` - Line ~22-34

**Current Values:**
```yaml
- project_id: ${default(map.get(input, "project_id"), "sandbox-dev-478813")}
- display_project_id: ${default(map.get(input, "display_project_id"), "spoke-project1-476804")}
```

**Action Required:**
- Replace `sandbox-dev-478813` with your **build project ID** (where VMs are created and validated)
- Replace `spoke-project1-476804` with your **display project ID** (where ephemeral images are promoted)

---

### 2. Service Account

**Location:** `workflow-both-case.yml` - Line ~40-41

**Current Value:**
```yaml
- service_account: ${default(
    map.get(input, "service_account"), "sa-kitchen-sh@sandbox-dev-478813.iam.gserviceaccount.com")}
```

**Action Required:**
- Replace `sa-kitchen-sh@sandbox-dev-478813.iam.gserviceaccount.com` with your service account email
- Format: `{service-account-name}@{project-id}.iam.gserviceaccount.com`

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

### 3. GCS Bucket Configuration

**Location:** `workflow-both-case.yml` - Line ~36-37

**Current Values:**
```yaml
- gcs_bucket: ${default(map.get(input, "gcs_bucket"), project_id + "-workflow-scripts")}
- gcs_scripts_path: ${default(map.get(input, "gcs_scripts_path"), "scripts")}
```

**Action Required:**
- **Option 1:** Keep default - bucket name will be `{project_id}-workflow-scripts` (e.g., `sandbox-dev-478813-workflow-scripts`)
- **Option 2:** Change to your existing bucket name

**GCS Bucket Structure Required:**
```
gs://{BUCKET_NAME}/
  └── scripts/
      ├── validate.sh
      └── validate_ephemeral.sh
```

**Upload Scripts to GCS:**
```bash
# Set variables
BUCKET="your-project-id-workflow-scripts"
PROJECT_ID="your-project-id"

# Create bucket (if doesn't exist)
gsutil mb -p ${PROJECT_ID} -l us-central1 gs://${BUCKET} || true

# Upload scripts
gsutil cp scripts/validation/validate.sh gs://${BUCKET}/scripts/validate.sh
gsutil cp pipeline/rhel8/validation/validate_ephemeral.sh gs://${BUCKET}/scripts/validate_ephemeral.sh
```

---

### 4. Zone and Machine Type

**Location:** `workflow-both-case.yml` - Line ~43-44

**Current Values:**
```yaml
- zone: ${default(map.get(input, "zone"), "us-central1-a")}
- machine_type: ${default(map.get(input, "machine_type"), "n1-standard-1")}
```

**Action Required:**
- Change `us-central1-a` to your preferred zone
- Change `n1-standard-1` to your preferred machine type

---

### 5. Pub/Sub Topic

**Location:** `workflow-both-case.yml` - Line ~209

**Current Value:**
```yaml
topic: ${"projects/" + project_id + "/topics/runtime-workflow-promote-topic"}
```

**Action Required:**
- Create Pub/Sub topic if it doesn't exist:
```bash
gcloud pubsub topics create runtime-workflow-promote-topic \
  --project={PROJECT_ID}
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

| Item | Current Value | Your Value |
|------|--------------|------------|
| **Build Project ID** | `sandbox-dev-478813` | `_____________` |
| **Display Project ID** | `spoke-project1-476804` | `_____________` |
| **Service Account** | `sa-kitchen-sh@sandbox-dev-478813.iam.gserviceaccount.com` | `_____________` |
| **GCS Bucket** | `{project_id}-workflow-scripts` | `_____________` |
| **Zone** | `us-central1-a` | `_____________` |
| **Machine Type** | `n1-standard-1` | `_____________` |
| **Pub/Sub Topic** | `runtime-workflow-promote-topic` | `_____________` |

---

## 📝 Quick Setup Checklist

- [ ] Update build project ID
- [ ] Update display project ID  
- [ ] Update service account email
- [ ] Create/verify GCS bucket exists
- [ ] Upload `validate.sh` to `gs://{BUCKET}/scripts/validate.sh`
- [ ] Upload `validate_ephemeral.sh` to `gs://{BUCKET}/scripts/validate_ephemeral.sh`
- [ ] Grant service account `compute.imageUser` role in display project
- [ ] Create Pub/Sub topic (if using notifications)
- [ ] Update zone (if different)
- [ ] Update machine type (if different)
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

