#STARTUP SCRIPT SINCE OS LOGIN OR IAP IS NOT POSSIBLE TO USE DUE TO ORG POLICY  (where its stored in my repo- gcp-ansible-playbooks/pipelines/schwab-rhel8/validate/validate_ephemeral.sh)



#validate_ephemeral.sh

#!/usr/bin/env bash
 
# Startup script for Case 2 (ephemeral image)
# Purpose: Validate Python 3 installation, run master validation (GCS script),
#          then UNINSTALL QUALYS and signal success for NEW image creation.
 
set -euo pipefail
 
# --- Configuration ---
VALIDATION_SCRIPT="/scripts/validate.sh"
VALIDATION_LOG="/var/log/runtime-validation.log"
METADATA_KEY="validation-script-gcs-path"
RESULT_METADATA_KEY="validation-result-gcs-path"
INSTANCE_NAME_METADATA_KEY="instance-name"
 
log() {
  echo "[startup-ephemeral][$(date -Is)] $*"
}
 
# Helper function for immediate failure and shutdown
fail_and_shutdown() {
    local message="$1"
    log "FATAL ERROR: ${message}"
    # Signal failure clearly to the workflow via serial port
    echo "RUNTIME_VALIDATION_RESULT=Fail"
    #log "Shutting down VM due to validation failure."
    # Use a non-zero exit code (1) to show failure within the startup process
    #/sbin/shutdown -h now || true
    exit 1
}
 
log "==================================================="
log "Starting Ephemeral Runtime Validation & Qualys Uninstall Flow..."
log "==================================================="
 
 
# --- 1. DIRECT PYTHON RUNTIME CHECK (Pre-Requisite) ---
# This ensures a basic runtime environment exists before downloading the master script.
 
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
 
log "Pre-requisite Python runtime validation PASSED. Proceeding to master GCS script."
 
 
# --- 2. MASTER VALIDATION (GCS) ---
 
# Fetch the GCS path from instance metadata
GCS_PATH=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${METADATA_KEY}" -H "Metadata-Flavor: Google")
 
if [[ -z "${GCS_PATH}" ]]; then
  fail_and_shutdown "Metadata key '${METADATA_KEY}' not found or empty."
fi
 
# Download and run the master validation script
log "Downloading master validation script from GCS path: ${GCS_PATH}"
# Note: Assuming /usr/bin/gsutil is available and permissions are correct
/usr/bin/gsutil cp "${GCS_PATH}" "${VALIDATION_SCRIPT}"
 
chmod +x "${VALIDATION_SCRIPT}"
if [[ ! -f "${VALIDATION_SCRIPT}" ]]; then
  fail_and_shutdown "Master validation script was not downloaded successfully to: ${VALIDATION_SCRIPT}"
fi
 
log "Running master validation script..."
log "------------------ GCS SCRIPT OUTPUT START ------------------"
"${VALIDATION_SCRIPT}" 2>&1 | tee -a "${VALIDATION_LOG}"
VALIDATION_EXIT_CODE=$?
log "------------------- GCS SCRIPT OUTPUT END -------------------"
 
log "Master validation script finished with exit code: ${VALIDATION_EXIT_CODE}"
 
if [ "${VALIDATION_EXIT_CODE}" -ne 0 ]; then
  fail_and_shutdown "Master validation script FAILED (Exit Code: ${VALIDATION_EXIT_CODE}). Aborting."
fi
 
log "Master validation script PASSED (Exit Code: 0). Proceeding to Qualys Uninstall."

# Upload validation log to GCS for retrieval
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
 
 
# --- 3. QUALYS UNINSTALL & FINAL PREPARATION ---
 
log "Starting Qualys agent uninstallation..."
 
# Replace this with your actual, idempotent uninstallation command.
# Example for a RHEL/CentOS system:
# /opt/qualys/qualys-cloud-agent/bin/qualys-cloud-agent.sh uninstall --purge || true
# Example for a Debian/Ubuntu system:
# apt-get purge -y qualys-cloud-agent || true
 
# **IMPORTANT: This is a placeholder command. Replace with your actual uninstall logic.**
log "Executing placeholder uninstallation command..."
if command -v systemctl &> /dev/null; then
  # Stop and remove the service
  systemctl stop qualys-cloud-agent.service || true
fi
# Assuming the actual uninstallation script/package manager command is here:
# /path/to/qualys/uninstall --force || fail_and_shutdown "Qualys uninstall command failed."
log "Qualys agent uninstallation complete (PLACEHOLDER SUCCESS)."
 
 
# --- 4. EMIT FINAL RESULT AND SHUT DOWN ---

# Set RESULT to "Pass" only if all steps (Validation + Uninstall) succeeded
RESULT="Pass"

log "Emitting final result: ${RESULT}"
# This signals the workflow's Cloud Build step to proceed with image creation and promotion
echo "RUNTIME_VALIDATION_RESULT=${RESULT}"

# Upload result to GCS for retrieval after VM shutdown
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

