#STARTUP SCRIPT SINCE OS LOGIN OR IAP IS NOT POSSIBLE TO USE DUE TO ORG POLICY  (where its stored in my repo- gcp-ansible-playbooks/pipelines/schwab-rhel8/validate/validate_ephemeral.sh)



#validate_ephemeral.sh

#!/usr/bin/env bash
 
# Startup script for Case 2 (ephemeral image)
# Purpose: Validate Python 3 installation, run master validation (from repository),
#          then UNINSTALL QUALYS and signal success for NEW image creation.
 
set -euo pipefail
 
# --- Configuration ---
VALIDATION_LOG="/var/log/runtime-validation.log"
REPO_ROOT_METADATA_KEY="repo-root-path"
REPO_URL_METADATA_KEY="repo-url"
REPO_BRANCH_METADATA_KEY="repo-branch"
PROJECT_ID_METADATA_KEY="project-id"
PUBSUB_TOPIC_METADATA_KEY="pubsub-topic"
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
 
log "Pre-requisite Python runtime validation PASSED. Proceeding to clone repository and run master validation script."
 
 
# --- 2. CHECK/COPY REPOSITORY ---
 
# Fetch repo root path from instance metadata
REPO_ROOT=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${REPO_ROOT_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "/workspace/repo")
 
log "Repository root path: ${REPO_ROOT}"
 
# Check if repository already exists (copied from Cloud Build via SCP)
if [[ -d "${REPO_ROOT}/.git" ]] || [[ -f "${REPO_ROOT}/scripts/validation/validate.sh" ]]; then
  log "✅ Repository already exists at ${REPO_ROOT} (copied from Cloud Build)"
  log "Skipping clone - using existing repository"
else
  # Fallback: Clone repository if it wasn't copied from Cloud Build
  log "Repository not found at ${REPO_ROOT}, attempting to clone..."
  
  # Fetch repo URL and branch from metadata (fallback)
  REPO_URL=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${REPO_URL_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "")
  REPO_BRANCH=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${REPO_BRANCH_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "master")
  
  if [[ -z "${REPO_URL}" ]]; then
    fail_and_shutdown "Repository not found at ${REPO_ROOT} and repo URL not provided in metadata. Cloud Build should have copied the repo."
  fi
  
  log "Cloning repository from ${REPO_URL} (branch: ${REPO_BRANCH}) to ${REPO_ROOT}..."
  
  # Install git if not available
  if ! command -v git &> /dev/null; then
    log "Installing git..."
    if command -v yum &> /dev/null; then
      yum install -y git || fail_and_shutdown "Failed to install git"
    elif command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y git || fail_and_shutdown "Failed to install git"
    else
      fail_and_shutdown "Cannot install git: package manager not found"
    fi
  fi
  
  # Create directory and clone
  mkdir -p "$(dirname "${REPO_ROOT}")"
  if git clone -b "${REPO_BRANCH}" "${REPO_URL}" "${REPO_ROOT}" 2>&1 | tee -a "${VALIDATION_LOG}"; then
    log "✅ Repository cloned successfully (fallback method)"
  else
    fail_and_shutdown "Failed to clone repository from ${REPO_URL}"
  fi
fi
 
# --- 3. MASTER VALIDATION (REPO) ---
 
# Construct path to master validation script
VALIDATION_SCRIPT="${REPO_ROOT}/scripts/validation/validate.sh"
 
log "Master validation script path: ${VALIDATION_SCRIPT}"
 
# Verify the script exists
if [[ ! -f "${VALIDATION_SCRIPT}" ]]; then
  fail_and_shutdown "Master validation script not found at: ${VALIDATION_SCRIPT}"
fi
 
# Make sure it's executable
chmod +x "${VALIDATION_SCRIPT}"
 
log "Running master validation script from repository..."
log "------------------ VALIDATION SCRIPT OUTPUT START ------------------"
"${VALIDATION_SCRIPT}" 2>&1 | tee -a "${VALIDATION_LOG}"
VALIDATION_EXIT_CODE=$?
log "------------------- VALIDATION SCRIPT OUTPUT END -------------------"
 
log "Master validation script finished with exit code: ${VALIDATION_EXIT_CODE}"
 
if [ "${VALIDATION_EXIT_CODE}" -ne 0 ]; then
  fail_and_shutdown "Master validation script FAILED (Exit Code: ${VALIDATION_EXIT_CODE}). Aborting."
fi
 
log "Master validation script PASSED (Exit Code: 0). Proceeding to Qualys Uninstall."

# --- 4. PREPARE VALIDATION RESULT DATA ---

# Get instance metadata for result publishing
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" || echo "unknown")
PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${PROJECT_ID_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "")
PUBSUB_TOPIC=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${PUBSUB_TOPIC_METADATA_KEY}" -H "Metadata-Flavor: Google" || echo "")

log "Instance metadata retrieved:"
log "  Instance Name: ${INSTANCE_NAME}"
log "  Project ID: ${PROJECT_ID}"
log "  Pub/Sub Topic: ${PUBSUB_TOPIC}"
 
 
# --- 5. QUALYS UNINSTALL & FINAL PREPARATION ---
 
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
 
 
# --- 6. EMIT FINAL RESULT AND SHUT DOWN ---

# Set RESULT to "Pass" only if all steps (Validation + Uninstall) succeeded
RESULT="Pass"

log "Emitting final result: ${RESULT}"
# This signals the workflow's Cloud Build step to proceed with image creation and promotion
echo "RUNTIME_VALIDATION_RESULT=${RESULT}"

# Publish result to Pub/Sub for retrieval after VM shutdown
log "Publishing validation result to Pub/Sub..."
TIMESTAMP=$(date -Iseconds)

# Read validation log content (limit to last 10KB to avoid message size limits)
VALIDATION_LOG_CONTENT=""
if [[ -f "${VALIDATION_LOG}" ]]; then
    # Get last 10KB of log
    VALIDATION_LOG_CONTENT=$(tail -c 10240 "${VALIDATION_LOG}" 2>/dev/null | base64 -w 0 || echo "")
fi

# Create result JSON
RESULT_JSON="/tmp/validation_result.json"
cat > "${RESULT_JSON}" << EOF
{
  "instance_name": "${INSTANCE_NAME}",
  "scan_result": "${RESULT}",
  "timestamp": "${TIMESTAMP}",
  "validation_log_preview": "${VALIDATION_LOG_CONTENT:0:1000}"
}
EOF

# Publish to Pub/Sub if topic is provided
if [[ -n "${PUBSUB_TOPIC}" && -n "${PROJECT_ID}" ]]; then
    # Install gcloud if not available (for Pub/Sub publishing)
    if ! command -v gcloud &> /dev/null; then
        log "Installing gcloud CLI..."
        if command -v yum &> /dev/null; then
            # For RHEL/CentOS, we need to add Google Cloud SDK repo
            log "Note: gcloud installation requires manual setup on RHEL. Using alternative method."
        elif command -v apt-get &> /dev/null; then
            # For Debian/Ubuntu
            export CLOUDSDK_CORE_DISABLE_PROMPTS=1
            curl https://sdk.cloud.google.com | bash || log "Warning: Failed to install gcloud"
        fi
    fi
    
    # Try to publish using gcloud
    if command -v gcloud &> /dev/null; then
        if gcloud pubsub topics publish "${PUBSUB_TOPIC}" \
            --project="${PROJECT_ID}" \
            --message="$(cat "${RESULT_JSON}")" \
            --attribute=instance_name="${INSTANCE_NAME}",scan_result="${RESULT}",timestamp="${TIMESTAMP}" 2>&1 | tee -a "${VALIDATION_LOG}"; then
            log "✅ Validation result published to Pub/Sub topic: ${PUBSUB_TOPIC}"
        else
            log "Warning: Failed to publish validation result to Pub/Sub"
        fi
    else
        # Fallback: Use curl to publish via Pub/Sub REST API
        log "gcloud not available, attempting to use REST API..."
        ACCESS_TOKEN=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || echo "")
        if [[ -n "${ACCESS_TOKEN}" ]]; then
            PUBSUB_URL="https://pubsub.googleapis.com/v1/${PUBSUB_TOPIC}:publish"
            MESSAGE_DATA=$(cat "${RESULT_JSON}" | base64 -w 0)
            PUBLISH_BODY="{\"messages\":[{\"data\":\"${MESSAGE_DATA}\",\"attributes\":{\"instance_name\":\"${INSTANCE_NAME}\",\"scan_result\":\"${RESULT}\",\"timestamp\":\"${TIMESTAMP}\"}}]}"
            
            if curl -X POST "${PUBSUB_URL}" \
                -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                -H "Content-Type: application/json" \
                -d "${PUBLISH_BODY}" 2>&1 | tee -a "${VALIDATION_LOG}"; then
                log "✅ Validation result published to Pub/Sub via REST API"
            else
                log "Warning: Failed to publish validation result to Pub/Sub via REST API"
            fi
        else
            log "Warning: Could not obtain access token for Pub/Sub publishing"
        fi
    fi
else
    log "Warning: Pub/Sub topic or project ID not provided in metadata, skipping Pub/Sub publish"
    log "Result will be available via serial port output only"
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

