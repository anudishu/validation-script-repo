#!/bin/bash
# Master Runtime Validation Script
# Orchestrates all runtime validation scripts with per-runtime strategy
# Exit Codes: 0 = All validations passed, 1 = One or more validations failed

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_LOG="${SCRIPT_DIR}/validation_results_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="/tmp/validate_all_$$"
VALIDATION_SCRIPTS_DIR="${TEMP_DIR}/validation_scripts"

# GCS bucket configuration (can be overridden via environment variable)
GCS_BUCKET="${GCS_VALIDATION_BUCKET:-sandbox-dev-478813-workflow-scripts}"
GCS_SCRIPTS_PATH="${GCS_VALIDATION_SCRIPTS_PATH:-scripts/validation/roles}"

# Runtime validation scripts - mapped to GCS paths
# Format: "gcs_path:Runtime Name:Emoji:runtime_key"
VALIDATION_SCRIPTS=(
    "${GCS_SCRIPTS_PATH}/install-python/validation/validate.sh:Python Runtime:🐍:python"
    "${GCS_SCRIPTS_PATH}/install-java-sdk/validation/validate.sh:Java SDK:☕:java"
    "${GCS_SCRIPTS_PATH}/install-nodejs/validation/validate.sh:Node.js Runtime:🟢:node"
    "${GCS_SCRIPTS_PATH}/install-database-cient/validation/validate.sh:Database Client:🐘:postgresql"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_step() {
    echo -e "\n${CYAN}======================================${NC}" | tee -a "$VALIDATION_LOG"
    echo -e "${CYAN}$1${NC}" | tee -a "$VALIDATION_LOG"
    echo -e "${CYAN}======================================${NC}" | tee -a "$VALIDATION_LOG"
}

log_header() {
    echo -e "${PURPLE}$1${NC}" | tee -a "$VALIDATION_LOG"
}

# Usage function
show_usage() {
    cat << EOF
Master Runtime Validation Script
=================================

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -s, --strategy      Validation strategy (default: per-runtime)
                        Options: per-runtime, global
    -r, --runtime       Validate specific runtime only
                        Options: python, java, node, postgresql (or database)
    -v, --verbose       Enable verbose output
    -c, --continue      Continue validation after failures (default: stop on first failure)
    -l, --log-file      Custom log file path (default: auto-generated)
    --parallel          Run validations in parallel (experimental)
    --skip-setup        Skip environment setup checks
    --cleanup           Clean up temporary files and exit

EXAMPLES:
    # Run all validations with per-runtime strategy (default)
    $0

    # Run specific runtime validation
    $0 --runtime python

    # Continue validation even after failures
    $0 --continue

    # Run with verbose output
    $0 --verbose

    # Run specific runtime with verbose output
    $0 --runtime java --verbose

VALIDATION STRATEGY:
    Per-Runtime Strategy (Recommended for Stabilization):
    • Install Python → Validate Python → Install Java → Validate Java → ...
    • Pros: Immediate failure detection, clear root cause identification
    • Cons: Slightly longer execution time, more complex logic

    Global Strategy (Future Option):
    • Install all runtimes → Run comprehensive validation
    • Pros: Faster execution, simpler structure
    • Cons: Harder to pinpoint specific runtime issues

EXIT CODES:
    0 - All validations passed
    1 - One or more validations failed
    2 - Script usage error
    3 - Environment setup error

EOF
}

# Parse command line arguments
parse_arguments() {
    STRATEGY="per-runtime"
    SPECIFIC_RUNTIME=""
    VERBOSE=false
    CONTINUE_ON_FAILURE=false
    PARALLEL=false
    SKIP_SETUP=false
    CLEANUP_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--strategy)
                STRATEGY="$2"
                if [[ "$STRATEGY" != "per-runtime" && "$STRATEGY" != "global" ]]; then
                    log_error "Invalid strategy: $STRATEGY. Use 'per-runtime' or 'global'"
                    exit 2
                fi
                shift 2
                ;;
            -r|--runtime)
                SPECIFIC_RUNTIME="$2"
                if [[ "$SPECIFIC_RUNTIME" != "python" && "$SPECIFIC_RUNTIME" != "java" && "$SPECIFIC_RUNTIME" != "node" && "$SPECIFIC_RUNTIME" != "postgresql" && "$SPECIFIC_RUNTIME" != "database" ]]; then
                    log_error "Invalid runtime: $SPECIFIC_RUNTIME. Use 'python', 'java', 'node', 'postgresql', or 'database'"
                    exit 2
                fi
                # Map 'database' to 'postgresql' for compatibility
                if [[ "$SPECIFIC_RUNTIME" == "database" ]]; then
                    SPECIFIC_RUNTIME="postgresql"
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--continue)
                CONTINUE_ON_FAILURE=true
                shift
                ;;
            -l|--log-file)
                VALIDATION_LOG="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --skip-setup)
                SKIP_SETUP=true
                shift
                ;;
            --cleanup)
                CLEANUP_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 2
                ;;
        esac
    done
}

# Environment setup
setup_environment() {
    if [[ "$SKIP_SETUP" == "true" ]]; then
        log_info "Skipping environment setup as requested"
        return 0
    fi
    
    log_step "Environment Setup"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    log_info "Created temporary directory: $TEMP_DIR"
    
    # Initialize log file
    cat > "$VALIDATION_LOG" << EOF
Runtime Validation Log
======================
Timestamp: $(date -Iseconds)
Script: $0
Strategy: $STRATEGY
Specific Runtime: ${SPECIFIC_RUNTIME:-"All"}
Verbose: $VERBOSE
Continue on Failure: $CONTINUE_ON_FAILURE
Host: $(hostname)
User: $(whoami)
Working Directory: $(pwd)
Log File: $VALIDATION_LOG

EOF

    log_info "Validation log initialized: $VALIDATION_LOG"
    log_info "GCS Bucket: gs://${GCS_BUCKET}"
    log_info "GCS Scripts Path: ${GCS_SCRIPTS_PATH}"
    
    # Create directory for downloaded validation scripts
    mkdir -p "$VALIDATION_SCRIPTS_DIR"
    log_info "Created validation scripts directory: $VALIDATION_SCRIPTS_DIR"
    
    # Check if gsutil is available
    if ! command -v gsutil &> /dev/null; then
        log_error "gsutil is not installed or not in PATH"
        log_error "Cannot download validation scripts from GCS"
        return 1
    fi
    
    # Download validation scripts from GCS
    log_info "Downloading validation scripts from GCS..."
    local missing_scripts=()
    for script_info in "${VALIDATION_SCRIPTS[@]}"; do
        local gcs_path=$(echo "$script_info" | cut -d: -f1)
        local runtime_name=$(echo "$script_info" | cut -d: -f2)
        local gcs_full_path="gs://${GCS_BUCKET}/${gcs_path}"
        local local_script="${VALIDATION_SCRIPTS_DIR}/$(basename ${gcs_path})"
        
        log_info "Downloading ${runtime_name} validation script from ${gcs_full_path}..."
        if gsutil cp "${gcs_full_path}" "${local_script}" 2>/dev/null; then
            chmod +x "${local_script}"
            log_success "Downloaded ${runtime_name} validation script"
        else
            missing_scripts+=("${gcs_full_path}")
            log_error "Failed to download ${runtime_name} validation script from ${gcs_full_path}"
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing validation scripts in GCS: ${missing_scripts[*]}"
        log_error "Please ensure all validation scripts are uploaded to: gs://${GCS_BUCKET}/${GCS_SCRIPTS_PATH}/"
        return 1
    fi
    
    log_success "All validation scripts downloaded from GCS"
    
    log_success "Environment setup completed"
    return 0
}

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary directory: $TEMP_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Run single validation script
run_validation() {
    local gcs_path="$1"
    local runtime_name="$2"
    local emoji="$3"
    local runtime_key="$4"
    local script_filename=$(basename "${gcs_path}")
    local validation_script="${VALIDATION_SCRIPTS_DIR}/${script_filename}"
    local runtime_lower=$(echo "$runtime_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    local output_file="$TEMP_DIR/${runtime_lower}_validation.log"
    
    log_step "$emoji $runtime_name Validation"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Executing: $validation_script"
        log_info "Output will be saved to: $output_file"
    fi
    
    # Run the validation script
    local start_time=$(date +%s)
    local exit_code=0
    
    if "$validation_script" > "$output_file" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Process results
    if [[ $exit_code -eq 0 ]]; then
        log_success "$emoji $runtime_name validation PASSED (${duration}s)"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "\n${BLUE}=== $runtime_name Validation Output ===${NC}"
            cat "$output_file"
            echo -e "${BLUE}=== End $runtime_name Output ===${NC}\n"
        fi
    else
        log_error "$emoji $runtime_name validation FAILED (${duration}s, exit code: $exit_code)"
        echo -e "\n${RED}=== $runtime_name Validation Error Output ===${NC}"
        cat "$output_file"
        echo -e "${RED}=== End $runtime_name Error Output ===${NC}\n"
        
        # Save error details to main log
        {
            echo ""
            echo "ERROR DETAILS FOR $runtime_name:"
            echo "Exit Code: $exit_code"
            echo "Duration: ${duration}s"
            echo "Output:"
            cat "$output_file"
            echo ""
        } >> "$VALIDATION_LOG"
    fi
    
    return $exit_code
}

# Per-runtime validation strategy
run_per_runtime_validation() {
    log_header "🎯 Per-Runtime Validation Strategy"
    log_info "Strategy: Install → Validate → Next (Sequential)"
    log_info "Benefits: Immediate failure detection, clear root cause identification"
    
    local failed_runtimes=()
    local passed_runtimes=()
    local total_start_time=$(date +%s)
    
    for script_info in "${VALIDATION_SCRIPTS[@]}"; do
        local gcs_path=$(echo "$script_info" | cut -d: -f1)
        local runtime_name=$(echo "$script_info" | cut -d: -f2)
        local emoji=$(echo "$script_info" | cut -d: -f3)
        local runtime_key=$(echo "$script_info" | cut -d: -f4)
        
        # Skip if specific runtime requested and this isn't it
        if [[ -n "$SPECIFIC_RUNTIME" ]]; then
            if [[ "$runtime_key" != "$SPECIFIC_RUNTIME" ]]; then
                continue
            fi
        fi
        
        if run_validation "$gcs_path" "$runtime_name" "$emoji" "$runtime_key"; then
            passed_runtimes+=("$emoji $runtime_name")
        else
            failed_runtimes+=("$emoji $runtime_name")
            
            if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
                log_error "Per-runtime strategy stopping at first failure: $runtime_name"
                log_info "This allows immediate focus on the problematic runtime"
                break
            fi
        fi
    done
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    # Display summary
    log_step "🏁 Per-Runtime Validation Summary"
    log_info "Total Duration: ${total_duration}s"
    log_info "Strategy Benefits Realized:"
    log_info "  ✅ Sequential validation completed"
    log_info "  ✅ Immediate failure detection enabled"
    log_info "  ✅ Root cause isolation achieved"
    
    if [[ ${#passed_runtimes[@]} -gt 0 ]]; then
        log_success "Passed Runtimes (${#passed_runtimes[@]}):"
        for runtime in "${passed_runtimes[@]}"; do
            log_success "  $runtime"
        done
    fi
    
    if [[ ${#failed_runtimes[@]} -gt 0 ]]; then
        log_error "Failed Runtimes (${#failed_runtimes[@]}):"
        for runtime in "${failed_runtimes[@]}"; do
            log_error "  $runtime"
        done
        return 1
    fi
    
    log_success "🎉 All runtime validations PASSED using per-runtime strategy!"
    return 0
}

# Global validation strategy (placeholder for future implementation)
run_global_validation() {
    log_header "🌐 Global Validation Strategy"
    log_warning "Global validation strategy is not yet implemented"
    log_info "This would install all runtimes first, then validate everything at once"
    log_info "Benefits: Faster execution, simpler structure"
    log_info "Trade-offs: Harder to pinpoint specific runtime failures"
    
    log_info "For now, falling back to per-runtime strategy..."
    run_per_runtime_validation
}

# Main execution function
main() {
    # Handle cleanup-only mode
    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        log_info "Cleanup mode: removing temporary files"
        cleanup
        exit 0
    fi
    
    # Setup environment
    if ! setup_environment; then
        log_error "Environment setup failed"
        exit 3
    fi
    
    # Display banner
    cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║           Runtime Validation Suite             ║
║                                                   ║
║  Validates Python, Java, Node.js, PostgreSQL     ║
║  Per-Runtime Strategy: Immediate Failure Detection║
╚═══════════════════════════════════════════════════╝
EOF

    log_info "Starting validation with strategy: $STRATEGY"
    
    # Run validation based on strategy
    local validation_result=0
    case "$STRATEGY" in
        "per-runtime")
            run_per_runtime_validation || validation_result=$?
            ;;
        "global")
            run_global_validation || validation_result=$?
            ;;
        *)
            log_error "Unknown validation strategy: $STRATEGY"
            exit 2
            ;;
    esac
    
    # Final summary
    echo "" | tee -a "$VALIDATION_LOG"
    if [[ $validation_result -eq 0 ]]; then
        log_success "🎉 ALL RUNTIME VALIDATIONS COMPLETED SUCCESSFULLY!"
        log_info "Golden image is ready for production use"
        log_info "Validation log saved to: $VALIDATION_LOG"
    else
        log_error "❌ RUNTIME VALIDATION FAILED"
        log_error "One or more runtime validations failed"
        log_error "Review the validation log for details: $VALIDATION_LOG"
        log_info ""
        log_info "🔧 Troubleshooting Tips:"
        log_info "  1. Run individual runtime validation: $0 --runtime <runtime_name>"
        log_info "  2. Use verbose mode for detailed output: $0 --verbose"
        log_info "  3. Continue validation after failures: $0 --continue"
        log_info "  4. Review individual runtime installation steps"
    fi
    
    return $validation_result
}

# Parse arguments and run main function
parse_arguments "$@"
main
