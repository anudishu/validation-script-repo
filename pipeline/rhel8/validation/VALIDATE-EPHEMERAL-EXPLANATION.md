# validate_ephemeral.sh - Visual Explanation

## Overview

This is a **startup script** that runs automatically when a VM boots up. It's used in **Case 2 (Ephemeral)** workflow to validate Python, run comprehensive tests, remove Qualys agent, and signal the workflow that validation is complete.

---

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              VM BOOTS UP (Startup Script Runs)              │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  INITIAL SETUP  │
                    │  - Set variables│
                    │  - Enable logging│
                    │  - Read metadata│
                    └────────┬────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │   STEP 1: PYTHON RUNTIME CHECK         │
        │   (Pre-requisite Validation)           │
        └───────────────┬────────────────────────┘
                        │
            ┌───────────┴───────────┐
            │                      │
         PASS?                  FAIL?
            │                      │
            ▼                      ▼
    ┌──────────────┐      ┌──────────────┐
    │ Continue     │      │ FAIL & EXIT  │
    └──────┬───────┘      └──────────────┘
           │
           ▼
        ┌────────────────────────────────────────┐
        │   STEP 2: DOWNLOAD VALIDATION SCRIPT   │
        │   - Get GCS path from metadata         │
        │   - Download validate.sh from GCS      │
        └───────────────┬────────────────────────┘
                        │
            ┌───────────┴───────────┐
            │                      │
      SUCCESS?                 FAIL?
            │                      │
            ▼                      ▼
    ┌──────────────┐      ┌──────────────┐
    │ Continue     │      │ FAIL & EXIT  │
    └──────┬───────┘      └──────────────┘
           │
           ▼
        ┌────────────────────────────────────────┐
        │   STEP 3: RUN MASTER VALIDATION        │
        │   - Execute validate.sh                │
        │   - Downloads individual scripts        │
        │     from GCS                           │
        │   - Validates: Python, Java, Node,     │
        │     PostgreSQL                         │
        │   - Capture exit code                   │
        └───────────────┬────────────────────────┘
                        │
            ┌───────────┴───────────┐
            │                      │
      PASS?                    FAIL?
            │                      │
            ▼                      ▼
    ┌──────────────┐      ┌──────────────┐
    │ Continue     │      │ FAIL & EXIT  │
    └──────┬───────┘      └──────────────┘
           │
           ▼
        ┌────────────────────────────────────────┐
        │   STEP 4: UPLOAD VALIDATION LOG        │
        │   - Upload log to GCS                  │
        │   - Path: gs://bucket/validation_logs/ │
        │     {instance}_timestamp.log           │
        └───────────────┬────────────────────────┘
                        │
                        ▼
        ┌────────────────────────────────────────┐
        │   STEP 5: UNINSTALL QUALYS AGENT       │
        │   - Stop Qualys service                 │
        │   - Remove Qualys agent                 │
        └───────────────┬────────────────────────┘
                        │
                        ▼
        ┌────────────────────────────────────────┐
        │   STEP 6: SIGNAL SUCCESS               │
        │   - Write "RUNTIME_VALIDATION_RESULT=  │
        │     Pass" to serial port               │
        └───────────────┬────────────────────────┘
                        │
                        ▼
        ┌────────────────────────────────────────┐
        │   STEP 7: UPLOAD RESULT JSON           │
        │   - Create result JSON                  │
        │   - Upload to GCS                      │
        │   - Path: gs://bucket/{image}_result.json│
        └───────────────┬────────────────────────┘
                        │
                        ▼
        ┌────────────────────────────────────────┐
        │   STEP 8: SHUTDOWN VM                  │
        │   - Sync filesystem                     │
        │   - Shutdown VM                        │
        │   - VM ready for image creation        │
        └────────────────────────────────────────┘
```

---

## Detailed Step-by-Step Breakdown

### Step 1: Python Runtime Check (Pre-Flight)

```bash
# Lines 44-58
log "Checking for Python 3 installation (python3 -V)..."
if ! command -v python3 &> /dev/null; then
    fail_and_shutdown "Python 3 executable ('python3') not found in PATH. Installation failed."
fi
PYTHON_VERSION=$(python3 -V 2>&1)
log "Python 3 successfully found. Version: ${PYTHON_VERSION}"

log "Checking for pip 3 package manager installation (pip3 -V)..."
if ! command -v pip3 &> /dev/null; then
    fail_and_shutdown "pip 3 executable ('pip3') not found in PATH. Python package management validation failed."
fi
PIP_VERSION=$(pip3 -V 2>&1)
log "pip 3 successfully found. Version: ${PIP_VERSION}"
```

**Purpose**: Ensures basic Python environment exists before downloading scripts  
**Checks**:
- ✅ Python 3 is installed and in PATH
- ✅ pip3 is installed and in PATH  
**Failure Action**: Immediately exits with error code 1

---

### Step 2: Download Master Validation Script

```bash
# Lines 63-78
# Get GCS path from VM metadata
GCS_PATH=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${METADATA_KEY}" -H "Metadata-Flavor: Google")

if [[ -z "${GCS_PATH}" ]]; then
  fail_and_shutdown "Metadata key '${METADATA_KEY}' not found or empty."
fi

# Download script from GCS
log "Downloading master validation script from GCS path: ${GCS_PATH}"
/usr/bin/gsutil cp "${GCS_PATH}" "${VALIDATION_SCRIPT}"

chmod +x "${VALIDATION_SCRIPT}"
if [[ ! -f "${VALIDATION_SCRIPT}" ]]; then
  fail_and_shutdown "Master validation script was not downloaded successfully to: ${VALIDATION_SCRIPT}"
fi
```

**Purpose**: Downloads the comprehensive validation script from GCS  
**Process**:
1. Reads GCS path from VM metadata (`validation-script-gcs-path`)
2. Downloads script using `gsutil cp`
3. Saves to `/scripts/validate.sh`
4. Makes it executable

**Failure Action**: Exits if download fails

---

### Step 3: Run Master Validation

```bash
# Lines 80-92
log "Running master validation script..."
log "------------------ GCS SCRIPT OUTPUT START ------------------"
"${VALIDATION_SCRIPT}" 2>&1 | tee -a "${VALIDATION_LOG}"
VALIDATION_EXIT_CODE=$?
log "------------------- GCS SCRIPT OUTPUT END -------------------"

log "Master validation script finished with exit code: ${VALIDATION_EXIT_CODE}"

if [ "${VALIDATION_EXIT_CODE}" -ne 0 ]; then
  fail_and_shutdown "Master validation script FAILED (Exit Code: ${VALIDATION_EXIT_CODE}). Aborting."
fi
```

**Purpose**: Runs comprehensive validation tests  
**What it validates**:
- Python version and functionality
- Java SDK installation
- Node.js installation
- Database Client (PostgreSQL) installation

**Output**: Logged to `/var/log/runtime-validation.log`  
**Failure Action**: Exits if validation fails

---

### Step 4: Uninstall Qualys Agent

```bash
# Lines 97-113
log "Starting Qualys agent uninstallation..."

# Placeholder - needs actual uninstall command
log "Executing placeholder uninstallation command..."
if command -v systemctl &> /dev/null; then
  # Stop and remove the service
  systemctl stop qualys-cloud-agent.service || true
fi
log "Qualys agent uninstallation complete (PLACEHOLDER SUCCESS)."
```

**Purpose**: Removes Qualys agent so new image is clean  
**Current Status**: ⚠️ **PLACEHOLDER** - needs actual uninstall command  
**Recommended Commands**:
```bash
# For RHEL/CentOS:
/opt/qualys/qualys-cloud-agent/bin/qualys-cloud-agent.sh uninstall --purge || true

# For Debian/Ubuntu:
apt-get purge -y qualys-cloud-agent || true
```

**Failure Action**: Logs warning but continues (non-blocking)

---

### Step 4: Upload Validation Log to GCS

```bash
# Lines 96-111
log "Uploading validation log to GCS..."
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" || echo "unknown")
RESULT_GCS_PATH=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${RESULT_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "")
GCS_LOG_PATH=""
if [[ -n "${RESULT_GCS_PATH}" ]]; then
    # Extract bucket and create log path
    GCS_BUCKET=$(echo "${RESULT_GCS_PATH}" | sed 's|gs://||' | cut -d'/' -f1)
    GCS_LOG_PATH="gs://${GCS_BUCKET}/validation_logs/${INSTANCE_NAME}_$(date +%Y%m%d_%H%M%S).log"
    if /usr/bin/gsutil cp "${VALIDATION_LOG}" "${GCS_LOG_PATH}" 2>/dev/null; then
        log "Validation log uploaded to: ${GCS_LOG_PATH}"
    else
        log "Warning: Failed to upload validation log to GCS"
        GCS_LOG_PATH=""
    fi
fi
```

**Purpose**: Uploads validation log to GCS for retrieval after VM shutdown  
**GCS Path**: `gs://{bucket}/validation_logs/{instance_name}_{timestamp}.log`  
**Failure Action**: Logs warning but continues (non-blocking)

---

### Step 5: Uninstall Qualys Agent

```bash
# Lines 114-132
log "Starting Qualys agent uninstallation..."

# Placeholder - needs actual uninstall command
log "Executing placeholder uninstallation command..."
if command -v systemctl &> /dev/null; then
  # Stop and remove the service
  systemctl stop qualys-cloud-agent.service || true
fi
log "Qualys agent uninstallation complete (PLACEHOLDER SUCCESS)."
```

**Purpose**: Removes Qualys agent so new image is clean  
**Current Status**: ⚠️ **PLACEHOLDER** - needs actual uninstall command  
**Recommended Commands**:
```bash
# For RHEL/CentOS:
/opt/qualys/qualys-cloud-agent/bin/qualys-cloud-agent.sh uninstall --purge || true

# For Debian/Ubuntu:
apt-get purge -y qualys-cloud-agent || true
```

**Failure Action**: Logs warning but continues (non-blocking)

---

### Step 6: Signal Success

```bash
# Lines 140-142
RESULT="Pass"

log "Emitting final result: ${RESULT}"
# This signals the workflow's Cloud Build step to proceed with image creation and promotion
echo "RUNTIME_VALIDATION_RESULT=${RESULT}"
```

**Purpose**: Signals workflow that validation is complete  
**Communication**: Serial port output (read by workflow)

---

### Step 7: Upload Result JSON to GCS

```bash
# Lines 144-169
log "Uploading validation result to GCS..."
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" || echo "unknown")
RESULT_GCS_PATH=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${RESULT_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "")

if [[ -n "${RESULT_GCS_PATH}" ]]; then
    # Create result JSON
    RESULT_JSON="/tmp/validation_result.json"
    cat > "${RESULT_JSON}" << EOF
{
  "instance_name": "${INSTANCE_NAME}",
  "scan_result": "${RESULT}",
  "timestamp": "$(date -Iseconds)",
  "validation_log_gcs_path": "${GCS_LOG_PATH:-not_uploaded}"
}
EOF
    
    # Upload result JSON to GCS
    if /usr/bin/gsutil cp "${RESULT_JSON}" "${RESULT_GCS_PATH}" 2>/dev/null; then
        log "Validation result uploaded to: ${RESULT_GCS_PATH}"
    else
        log "Warning: Failed to upload validation result to GCS"
    fi
else
    log "Warning: Result GCS path not provided in metadata, skipping GCS upload"
fi
```

**Purpose**: Uploads result JSON to GCS for reliable retrieval after VM shutdown  
**GCS Path**: `gs://{bucket}/{image_id}_result.json`  
**JSON Contents**:
- `instance_name`: VM instance name
- `scan_result`: "Pass" or "Fail"
- `timestamp`: ISO timestamp
- `validation_log_gcs_path`: Path to validation log in GCS

**Failure Action**: Logs warning but continues (non-blocking)

---

### Step 8: Shutdown VM

```bash
# Lines 171-189
log "Shutting down VM to allow for NEW ephemeral image creation."
# Sync filesystem to ensure all writes are complete
sync
# Give a moment for any final operations
sleep 2
# Shutdown the VM - try multiple methods for reliability
if command -v shutdown &> /dev/null; then
    /sbin/shutdown -h now || /usr/sbin/shutdown -h now || true
elif command -v systemctl &> /dev/null; then
    systemctl poweroff || true
elif command -v poweroff &> /dev/null; then
    /sbin/poweroff || /usr/sbin/poweroff || true
else
    log "Warning: No shutdown command found, VM will remain running"
fi

exit 0
```

**Purpose**: Shuts down VM cleanly for image creation  
**Process**:
1. Sync filesystem to ensure all writes complete
2. Wait 2 seconds for final operations
3. Try multiple shutdown methods for reliability
4. Exit cleanly

**Result**: VM shuts down cleanly, ready for image creation

---

## Complete Execution Flow

```
VM BOOT
   │
   ├─→ [Startup Script Executes]
   │
   ├─→ STEP 1: Check Python/pip
   │   ├─→ ✅ Found → Continue
   │   └─→ ❌ Not Found → EXIT 1
   │
   ├─→ STEP 2: Download validate.sh
   │   ├─→ Get GCS path from metadata
   │   ├─→ Download via gsutil
   │   ├─→ ✅ Success → Continue
   │   └─→ ❌ Fail → EXIT 1
   │
   ├─→ STEP 3: Run validate.sh
   │   ├─→ Downloads individual scripts from GCS
   │   ├─→ Execute comprehensive tests
   │   │   ├─→ Python validation
   │   │   ├─→ Java validation
   │   │   ├─→ Node.js validation
   │   │   └─→ Database validation
   │   ├─→ ✅ Exit 0 → Continue
   │   └─→ ❌ Exit non-zero → EXIT 1
   │
   ├─→ STEP 4: Upload Validation Log
   │   ├─→ Upload log to GCS
   │   ├─→ Path: gs://bucket/validation_logs/
   │   │     {instance}_timestamp.log
   │   └─→ Continue (non-blocking)
   │
   ├─→ STEP 5: Remove Qualys
   │   ├─→ Stop service
   │   ├─→ Uninstall agent
   │   └─→ Continue (non-blocking)
   │
   ├─→ STEP 6: Signal Success
   │   ├─→ Write "RUNTIME_VALIDATION_RESULT=Pass"
   │   └─→ Continue
   │
   ├─→ STEP 7: Upload Result JSON
   │   ├─→ Create result JSON
   │   ├─→ Upload to GCS
   │   ├─→ Path: gs://bucket/{image}_result.json
   │   └─→ Continue (non-blocking)
   │
   ├─→ STEP 8: Shutdown VM
   │   ├─→ Sync filesystem
   │   ├─→ Wait 2 seconds
   │   ├─→ Execute shutdown command
   │   └─→ Exit 0
   │
   └─→ [VM Stopped - Ready for Image Creation]
```

---

## Key Components

### Configuration Variables

```bash
VALIDATION_SCRIPT="/scripts/validate.sh"                    # Where to save downloaded script
VALIDATION_LOG="/var/log/runtime-validation.log"            # Log file location
METADATA_KEY="validation-script-gcs-path"                   # Metadata key for GCS script path
RESULT_METADATA_KEY="validation-result-gcs-path"           # Metadata key for GCS result path
INSTANCE_NAME_METADATA_KEY="instance-name"                  # Metadata key for instance name
```

### Helper Functions

#### `log()` Function
```bash
log() {
  echo "[startup-ephemeral][$(date -Is)] $*"
}
```
**Output Format**: `[startup-ephemeral][2024-01-01T12:00:00] message`

#### `fail_and_shutdown()` Function
```bash
fail_and_shutdown() {
    local message="$1"
    log "FATAL ERROR: ${message}"
    echo "RUNTIME_VALIDATION_RESULT=Fail"
    exit 1
}
```
**Actions**:
- Logs error message
- Writes failure to serial port
- Exits with code 1

---

## Communication with Workflow

### How Workflow Reads Results (Dual Method)

```
┌─────────────────────────────────────────────────────────────┐
│  METHOD 1: Serial Port Output (Real-time)                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [startup-ephemeral][2024-01-01...]                  │    │
│  │ Starting Ephemeral Runtime...                       │    │
│  │ Python 3 successfully found...                      │    │
│  │ ...                                                  │    │
│  │ RUNTIME_VALIDATION_RESULT=Pass                      │ ← Workflow reads this
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  METHOD 2: GCS Result JSON (After Shutdown)                │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ gs://bucket/{image}_result.json                       │    │
│  │ {                                                      │    │
│  │   "instance_name": "vm-name",                         │    │
│  │   "scan_result": "Pass",                              │ ← Workflow reads this
│  │   "timestamp": "2024-01-01T12:00:00Z",                │    │
│  │   "validation_log_gcs_path": "gs://bucket/logs/..."   │    │
│  │ }                                                      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Workflow Retrieval Strategy                                │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 1. Poll Serial Port (60 iterations × 10s)           │    │
│  │    for "RUNTIME_VALIDATION_RESULT=Pass/Fail"        │    │
│  │                                                      │    │
│  │ 2. After polling, check GCS for result JSON         │    │
│  │    (More reliable after VM shutdown)                │    │
│  │                                                      │    │
│  │ 3. Use GCS result if available,                     │    │
│  │    fallback to serial port result                   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling

### Failure Points & Actions

| Step | Failure Condition | Action |
|------|-------------------|--------|
| **Step 1** | Python3 not found | `fail_and_shutdown()` → EXIT 1 |
| **Step 1** | pip3 not found | `fail_and_shutdown()` → EXIT 1 |
| **Step 2** | GCS path empty | `fail_and_shutdown()` → EXIT 1 |
| **Step 2** | Download fails | `fail_and_shutdown()` → EXIT 1 |
| **Step 3** | validate.sh fails | `fail_and_shutdown()` → EXIT 1 |
| **Step 4** | Log upload fails | Log warning, continue (non-blocking) |
| **Step 5** | Qualys removal fails | Log warning, continue (non-blocking) |
| **Step 6** | Signal write fails | Continue (non-critical) |
| **Step 7** | Result JSON upload fails | Log warning, continue (non-blocking) |
| **Step 8** | Shutdown fails | Log warning, try alternative methods |

### Error Output Format

```
[startup-ephemeral][2024-01-01T12:00:00] FATAL ERROR: Python 3 executable ('python3') not found in PATH. Installation failed.
RUNTIME_VALIDATION_RESULT=Fail
[VM exits with code 1]
```

---

## Integration with Workflow

### How It Fits in Case 2 Flow

```
┌─────────────────────────────────────────────┐
│  Workflow: validate_image_ephemeral()        │
│  ┌─────────────────────────────────────┐    │
│  │ 1. Create VM with startup script    │    │
│  │    --metadata-from-file=            │    │
│  │      startup-script=                │    │
│  │      validate_ephemeral.sh          │    │
│  │    --metadata=                      │    │
│  │      validation-script-gcs-path=    │    │
│  │      gs://bucket/validate.sh        │    │
│  │      validation-result-gcs-path=    │    │
│  │      gs://bucket/{image}_result.json│    │
│  │      instance-name={instance_name}  │    │
│  └─────────────────────────────────────┘    │
│              │                                │
│              ▼                                │
│  ┌─────────────────────────────────────┐    │
│  │ 2. VM Boots → Script Runs            │    │
│  │    (This is where validate_          │    │
│  │     ephemeral.sh executes)          │    │
│  │    - Validates runtimes              │    │
│  │    - Uploads log to GCS              │    │
│  │    - Uploads result JSON to GCS      │    │
│  │    - Shuts down VM                   │    │
│  └─────────────────────────────────────┘    │
│              │                                │
│              ▼                                │
│  ┌─────────────────────────────────────┐    │
│  │ 3. Poll Serial Port                 │    │
│  │    Wait for "RUNTIME_VALIDATION_    │    │
│  │    RESULT=Pass/Fail"                │    │
│  │    (60 iterations × 10s)            │    │
│  └─────────────────────────────────────┘    │
│              │                                │
│              ▼                                │
│  ┌─────────────────────────────────────┐    │
│  │ 4. Check GCS for Result JSON        │    │
│  │    (More reliable after shutdown)    │    │
│  │    - Download result JSON            │    │
│  │    - Use if available               │    │
│  │    - Fallback to serial port result  │    │
│  └─────────────────────────────────────┘    │
│              │                                │
│              ▼                                │
│  ┌─────────────────────────────────────┐    │
│  │ 5. Continue workflow based on       │    │
│  │    result                            │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## What validate.sh Does (Called in Step 3)

When `validate.sh` is executed, it:

1. **Downloads individual validation scripts from GCS**:
   - Checks for local `roles/` directory
   - If not found, downloads from GCS bucket
   - Path: `gs://{bucket}/scripts/validation/roles/{role}/validation/validate.sh`
2. **Runs them sequentially**:
   - `install-python/validation/validate.sh` → Python validation
   - `install-java-sdk/validation/validate.sh` → Java validation
   - `install-nodejs/validation/validate.sh` → Node.js validation
   - `install-database-cient/validation/validate.sh` → PostgreSQL validation
3. **Consolidates results**:
   - ✅ All pass → Exit 0
   - ❌ Any fail → Exit 1
4. **Logs everything** to `/var/log/runtime-validation.log`

---

## Key Features

### ✅ Automatic Execution
- Runs automatically on VM boot
- No manual intervention needed
- No SSH/IAP required

### ✅ Comprehensive Validation
- Pre-flight Python checks
- Full validation via validate.sh (all runtimes)
- Detailed logging

### ✅ Clean Image Preparation
- Removes Qualys agent
- Shuts down cleanly
- Ready for image creation

### ✅ Workflow Integration
- Signals via serial port (real-time)
- Uploads results to GCS (reliable after shutdown)
- Dual retrieval method for reliability
- Standardized result format
- Error handling

### ✅ GCS Integration
- Uploads validation logs for debugging
- Uploads result JSON for reliable retrieval
- Works even after VM shutdown
- No dependency on serial port availability

---

## Important Notes

1. **Placeholder Qualys Removal**: The script has placeholder code for Qualys removal (line 113). Replace with actual uninstall command:
   ```bash
   # For RHEL/CentOS:
   /opt/qualys/qualys-cloud-agent/bin/qualys-cloud-agent.sh uninstall --purge || true
   
   # For Debian/Ubuntu:
   apt-get purge -y qualys-cloud-agent || true
   ```

2. **GCS Access**: VM needs `gsutil` and proper IAM permissions to:
   - Download scripts from GCS
   - Upload validation logs to GCS
   - Upload result JSON to GCS

3. **Result Retrieval**: Workflow uses dual method:
   - **Serial Port**: Real-time polling (60 iterations × 10 seconds)
   - **GCS Result JSON**: More reliable after VM shutdown

4. **GCS Paths**: Ensure metadata includes:
   - `validation-script-gcs-path`: Path to validate.sh
   - `validation-result-gcs-path`: Path for result JSON
   - `instance-name`: Instance name for log naming

5. **Shutdown**: VM must shut down cleanly for image creation to work. Script includes:
   - Filesystem sync before shutdown
   - Multiple shutdown method attempts
   - 2-second delay for final operations

---

## Summary

This script is the **heart of Case 2 validation**. It:
- ✅ Validates Python environment automatically
- ✅ Downloads and runs comprehensive tests (all runtimes)
- ✅ Uploads validation logs to GCS for debugging
- ✅ Removes Qualys agent
- ✅ Signals workflow via serial port (real-time)
- ✅ Uploads result JSON to GCS (reliable after shutdown)
- ✅ Prepares VM for clean image creation

All without requiring SSH, IAP, or manual intervention!

### GCS Upload Benefits

1. **Reliable Result Retrieval**: Results available even after VM shutdown
2. **Debugging**: Full validation logs available in GCS
3. **Audit Trail**: Timestamped results and logs for tracking
4. **No Serial Port Dependency**: Workflow can read from GCS if serial port unavailable

