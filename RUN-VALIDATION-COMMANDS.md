# Commands to Run Validation on VM

## Workflow Visual Overview

### High-Level Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD WORKFLOW                                 │
│                    Input: {image_id, server_type}                      │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   INIT STEP    │
                    │ Load defaults  │
                    │ Parse input    │
                    └────────┬───────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ ROUTE BY TYPE  │
                    │ server_type?   │
                    └───┬────────┬───┘
                        │        │
        ┌───────────────┘        └───────────────┐
        │                                          │
        ▼                                          ▼
┌───────────────┐                        ┌───────────────┐
│  CASE 1:     │                        │  CASE 2:     │
│  PERSISTENT  │                        │  EPHEMERAL   │
└──────┬───────┘                        └──────┬───────┘
       │                                        │
       │                                        │
       ▼                                        ▼
```

---

### Case 1: Persistent Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CASE 1: PERSISTENT FLOW                               │
└─────────────────────────────────────────────────────────────────────────┘

1. VALIDATION
   ┌─────────────────────────────────────┐
   │ Cloud Build: validate_image()        │
   │  ├─ Create validation VM            │
   │  ├─ Download validate.sh from GCS   │
   │  └─ Run validate.sh via SSH        │
   │     └─ Validates: Python, Java,     │
   │        Node.js, PostgreSQL          │
   └─────────────────────────────────────┘
                    │
                    ▼
2. CHECK RESULT
   ┌─────────────────────────────────────┐
   │ Read result from VM                  │
   │ Result: Pass / Fail                  │
   └─────────────────────────────────────┘
                    │
                    ▼
3. PROMOTION (if Pass)
   ┌─────────────────────────────────────┐
   │ Publish to Pub/Sub                   │
   │ Topic: runtime-workflow-promote-topic│
   └─────────────────────────────────────┘
                    │
                    ▼
4. CLEANUP
   ┌─────────────────────────────────────┐
   │ Delete validation VM                 │
   │ Original image unchanged             │
   └─────────────────────────────────────┘
```

---

### Case 2: Ephemeral Flow (with GCS Upload)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CASE 2: EPHEMERAL FLOW                               │
└─────────────────────────────────────────────────────────────────────────┘

1. VALIDATION VM CREATION
   ┌─────────────────────────────────────┐
   │ Cloud Build: validate_image_ephemeral│
   │  ├─ Create VM with startup script   │
   │  ├─ Startup: validate_ephemeral.sh  │
   │  └─ Metadata: GCS paths for scripts  │
   └─────────────────────────────────────┘
                    │
                    ▼
2. STARTUP SCRIPT EXECUTION (on VM boot)
   ┌─────────────────────────────────────┐
   │ validate_ephemeral.sh runs:         │
   │  ├─ 1. Check Python 3 & pip3        │
   │  ├─ 2. Download validate.sh from GCS │
   │  ├─ 3. Run validate.sh              │
   │  │    └─ Downloads individual        │
   │  │       validation scripts from GCS │
   │  │    └─ Validates: Python, Java,   │
   │  │       Node.js, PostgreSQL        │
   │  ├─ 4. Upload validation log to GCS │
   │  │    └─ gs://bucket/validation_logs│
   │  ├─ 5. Uninstall Qualys agent       │
   │  ├─ 6. Upload result JSON to GCS    │
   │  │    └─ gs://bucket/{image}_result.json│
   │  └─ 7. Shutdown VM                   │
   └─────────────────────────────────────┘
                    │
                    ▼
3. RESULT RETRIEVAL
   ┌─────────────────────────────────────┐
   │ Cloud Build: Poll serial port       │
   │  ├─ Check for RUNTIME_VALIDATION_   │
   │  │   RESULT=Pass/Fail               │
   │  └─ Check GCS for result JSON       │
   │     └─ More reliable after shutdown │
   └─────────────────────────────────────┘
                    │
                    ▼
4. IMAGE CREATION (if Pass)
   ┌─────────────────────────────────────┐
   │ Create new image from validated VM   │
   │ Name: {image_id}-ephemeral-{timestamp}│
   └─────────────────────────────────────┘
                    │
                    ▼
5. PROMOTION (if Pass)
   ┌─────────────────────────────────────┐
   │ Copy image to display project        │
   │ Project: spoke-project1-476804      │
   └─────────────────────────────────────┘
                    │
                    ▼
6. CLEANUP
   ┌─────────────────────────────────────┐
   │ Delete validation VM                 │
   │ Original image unchanged             │
   └─────────────────────────────────────┘
```

---

### GCS Script Flow (Case 2 - Ephemeral)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GCS SCRIPT DOWNLOAD FLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

VM Startup
    │
    ▼
┌─────────────────────────────────────┐
│ validate_ephemeral.sh (startup)     │
│  ├─ Reads metadata:                 │
│  │   validation-script-gcs-path      │
│  └─ Downloads: validate.sh          │
│     from: gs://bucket/scripts/       │
│            validation/validate.sh    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ validate.sh (master script)          │
│  ├─ Reads GCS paths from env vars   │
│  ├─ Downloads individual scripts:    │
│  │   ├─ install-python/validation/   │
│  │   │   validate.sh                 │
│  │   ├─ install-java-sdk/validation/ │
│  │   │   validate.sh                 │
│  │   ├─ install-nodejs/validation/  │
│  │   │   validate.sh                 │
│  │   └─ install-database-cient/     │
│  │       validation/validate.sh      │
│  └─ Runs each validation script      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Upload Results to GCS                │
│  ├─ Validation log:                  │
│  │   gs://bucket/validation_logs/    │
│  │   {instance}_timestamp.log        │
│  └─ Result JSON:                     │
│     gs://bucket/{image}_result.json  │
└─────────────────────────────────────┘
```

---

### Validation Script Execution Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    VALIDATION SCRIPT EXECUTION                           │
└─────────────────────────────────────────────────────────────────────────┘

validate.sh (Master Script)
    │
    ├─► Setup Environment
    │   ├─ Create temp directory
    │   ├─ Check gsutil availability
    │   └─ Download individual scripts from GCS
    │
    ├─► Python Runtime Validation
    │   ├─ Check Python 3 installation
    │   ├─ Check pip3 functionality
    │   ├─ Test standard library
    │   └─ Test package installation
    │
    ├─► Java SDK Validation
    │   ├─ Check Java installation
    │   ├─ Verify JAVA_HOME
    │   └─ Test Java compilation
    │
    ├─► Node.js Runtime Validation
    │   ├─ Check Node.js installation
    │   ├─ Check npm availability
    │   └─ Test package installation
    │
    └─► Database Client Validation
        ├─ Check PostgreSQL client
        ├─ Test connection capability
        └─ Verify client tools

    │
    ▼
Generate Summary Report
    ├─ Pass/Fail status per runtime
    ├─ Total duration
    └─ Log file location
```

---

## Step 1: Copy Directory to VM

```bash
# Set variables
export PROJECT_ID="sandbox-dev-478813"
export VM_NAME="test-rhel-vm-qualys"
export ZONE="us-central1-a"

# Copy the entire anisble-workflow-iap directory to VM
gcloud compute scp \
  --recurse \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  ./anisble-workflow-iap \
  ${VM_NAME}:/tmp/
```

## Step 2: SSH into VM and Run Validation

```bash
# SSH into VM and run validation
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    chmod +x validate_all.sh
    ./validate_all.sh
  "
```

## Step 3: Run with Options (Optional)

### Run with verbose output:
```bash
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --verbose
  "
```

### Run specific runtime only:
```bash
# Test Python only
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --runtime python
  "

# Test Java only
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --runtime java
  "

# Test Node.js only
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --runtime node
  "

# Test Database Client only
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --runtime postgresql
  "
```

### Continue even if one fails:
```bash
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh --continue
  "
```

## Step 4: Download Log Files (Optional)

```bash
# Download validation logs
gcloud compute scp \
  --recurse \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  ${VM_NAME}:/tmp/anisble-workflow-iap/scripts/validation/validation_results_*.log \
  ./
```

## Complete One-Liner (Copy + Run)

```bash
# Set variables
export PROJECT_ID="sandbox-dev-478813"
export VM_NAME="test-rhel-vm-qualys"
export ZONE="us-central1-a"

# Copy directory
gcloud compute scp --recurse --zone=${ZONE} --project=${PROJECT_ID} ./anisble-workflow-iap ${VM_NAME}:/tmp/

# Run validation
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID} --command="cd /tmp/anisble-workflow-iap/scripts/validation && chmod +x validate_all.sh && ./validate_all.sh"
```

## Check Exit Code

The script returns:
- **0** = All validations passed
- **1** = One or more validations failed
- **2** = Script usage error
- **3** = Environment setup error

To capture exit code:
```bash
gcloud compute ssh ${VM_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID} \
  --command="
    cd /tmp/anisble-workflow-iap/scripts/validation
    ./validate_all.sh
    echo 'Exit Code: '\$?
  "
```

---

## Step 5: Check GCS Results (Ephemeral Workflow)

When running the ephemeral workflow, results are automatically uploaded to GCS. You can retrieve them even after the VM shuts down:

### Check for Result JSON

```bash
# Set variables
export PROJECT_ID="sandbox-dev-478813"
export IMAGE_ID="test-rhel-vm-agent-image"
export GCS_BUCKET="${PROJECT_ID}-workflow-scripts"

# List result files
gsutil ls gs://${GCS_BUCKET}/*_result.json

# Download and view a specific result
gsutil cp gs://${GCS_BUCKET}/${IMAGE_ID}_result.json - | python3 -m json.tool
```

### Check Validation Logs

```bash
# List all validation logs
gsutil ls gs://${GCS_BUCKET}/validation_logs/

# Download and view a specific log
gsutil cp gs://${GCS_BUCKET}/validation_logs/{instance_name}_*.log - | tail -50
```

### Complete Result Check (One-liner)

```bash
# Set variables
export PROJECT_ID="sandbox-dev-478813"
export IMAGE_ID="test-rhel-vm-agent-image"
export GCS_BUCKET="${PROJECT_ID}-workflow-scripts"

# Check result JSON
echo "=== Result JSON ==="
gsutil cp gs://${GCS_BUCKET}/${IMAGE_ID}_result.json - 2>/dev/null | python3 -m json.tool || echo "Result not found yet"

# Check latest validation log
echo ""
echo "=== Latest Validation Log ==="
LATEST_LOG=$(gsutil ls gs://${GCS_BUCKET}/validation_logs/ | grep ${IMAGE_ID} | tail -1)
if [ -n "${LATEST_LOG}" ]; then
  gsutil cp "${LATEST_LOG}" - | tail -50
else
  echo "No validation logs found"
fi
```

---

## Workflow Execution Commands

### Run Persistent Workflow

```bash
gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project=sandbox-dev-478813 \
  --data='{"image_id":"test-rhel-vm-agent-image","server_type":"persistent"}'
```

### Run Ephemeral Workflow

```bash
gcloud workflows execute runtime-validation-workflow \
  --location=us-central1 \
  --project=sandbox-dev-478813 \
  --data='{"image_id":"test-rhel-vm-agent-image","server_type":"ephemeral"}'
```

### Check Workflow Execution Status

```bash
# List recent executions
gcloud workflows executions list \
  --workflow=runtime-validation-workflow \
  --location=us-central1 \
  --project=sandbox-dev-478813 \
  --limit=5

# Get specific execution details
gcloud workflows executions describe {EXECUTION_ID} \
  --workflow=runtime-validation-workflow \
  --location=us-central1 \
  --project=sandbox-dev-478813
```

