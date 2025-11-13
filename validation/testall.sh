#!/bin/bash
# Master Runtime Validation Script
# Orchestrates all runtime validation scripts with per-runtime strategy
# Exit Codes: 0 = All validations passed, 1 = One or more validations failed

# Note: Removed 'set -e' so script continues even after errors
set -uo pipefail

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

# Runtime validation scripts
VALIDATION_SCRIPTS=(
    "validate_python.sh:Python Runtime:🐍"
    "validate_java.sh:Java SDK:☕"
    "validate_node.sh:Node.js Runtime:🟢"
    "validate_postgresql.sh:PostgreSQL Client:🐘"
)

# Logging functions - Always print to terminal
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
                        Options: python, java, node, postgresql
    -v, --verbose       Enable verbose output
    -l, --log-file      Custom log file path (default: auto-generated)
    --skip-setup        Skip environment setup checks
    --cleanup           Clean up temporary files and exit

EXAMPLES:
    # Run all validations (default - continues through all, shows output)
    $0

    # Run specific runtime validation
    $0 --runtime python

    # Run with verbose output
    $0 --verbose

    # Run specific runtime with verbose output
    $0 --runtime java --verbose

VALIDATION STRATEGY:
    Per-Runtime Strategy (Default):
    • Validates Python → Java → Node.js → PostgreSQL
    • Continues through all validations regardless of failures
    • Shows real-time output in terminal
    • Generates log file for later review

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
                if [[ "$SPECIFIC_RUNTIME" != "python" && "$SPECIFIC_RUNTIME" != "java" && "$SPECIFIC_RUNTIME" != "node" && "$SPECIFIC_RUNTIME" != "postgresql" ]]; then
                    log_error "Invalid runtime: $SPECIFIC_RUNTIME. Use 'python', 'java', 'node', or 'postgresql'"
                    exit 2
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -l|--log-file)
                VALIDATION_LOG="$2"
                shift 2
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
    mkdir -p "$TEMP_DIR" || true
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
Host: $(hostname)
User: $(whoami)
Working Directory: $(pwd)
Log File: $VALIDATION_LOG

EOF

    log_info "Validation log initialized: $VALIDATION_LOG"
    
    # Check that validation scripts exist
    local missing_scripts=()
    for script_info in "${VALIDATION_SCRIPTS[@]}"; do
        local script_name=$(echo "$script_info" | cut -d: -f1)
        if [[ ! -f "$SCRIPT_DIR/$script_name" ]]; then
            missing_scripts+=("$script_name")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_warning "Missing validation scripts: ${missing_scripts[*]}"
        log_warning "Continuing with available scripts only"
    else
        log_success "All validation scripts found"
    fi
    
    # Make scripts executable
    for script_info in "${VALIDATION_SCRIPTS[@]}"; do
        local script_name=$(echo "$script_info" | cut -d: -f1)
        if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
            chmod +x "$SCRIPT_DIR/$script_name" || true
        fi
    done
    
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
    local script_name="$1"
    local runtime_name="$2"
    local emoji="$3"
    local runtime_lower=$(echo "$runtime_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    local output_file="$TEMP_DIR/${runtime_lower}_validation.log"
    
    log_step "$emoji $runtime_name Validation"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_DIR/$script_name" ]]; then
        log_error "Validation script not found: $SCRIPT_DIR/$script_name"
        log_error "Skipping $runtime_name validation"
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Executing: $SCRIPT_DIR/$script_name"
        log_info "Output will be saved to: $output_file"
    fi
    
    # Run the validation script and show output in real-time
    local start_time=$(date +%s)
    local exit_code=0
    
    # Run script and show output to terminal AND save to file
    if "$SCRIPT_DIR/$script_name" 2>&1 | tee "$output_file"; then
        exit_code=0
    else
        exit_code=${PIPESTATUS[0]}
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Process results
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_success "$emoji $runtime_name validation PASSED (${duration}s)"
    else
        log_error "$emoji $runtime_name validation FAILED (${duration}s, exit code: $exit_code)"
        log_warning "Continuing with next validation..."
    fi
    
    return $exit_code
}

# Per-runtime validation strategy
run_per_runtime_validation() {
    log_header "🎯 Per-Runtime Validation Strategy"
    log_info "Strategy: Sequential validation with continuous execution"
    log_info "All validations will run regardless of individual failures"
    echo ""
    
    local failed_runtimes=()
    local passed_runtimes=()
    local skipped_runtimes=()
    local total_start_time=$(date +%s)
    
    for script_info in "${VALIDATION_SCRIPTS[@]}"; do
        local script_name=$(echo "$script_info" | cut -d: -f1)
        local runtime_name=$(echo "$script_info" | cut -d: -f2)
        local emoji=$(echo "$script_info" | cut -d: -f3)
        
        # Skip if specific runtime requested and this isn't it
        if [[ -n "$SPECIFIC_RUNTIME" ]]; then
            local runtime_key=$(echo "$runtime_name" | tr '[:upper:]' '[:lower:]')
            runtime_key="${runtime_key// */}"  # Take first word, lowercase
            if [[ "$runtime_key" != "$SPECIFIC_RUNTIME" ]]; then
                skipped_runtimes+=("$emoji $runtime_name")
                continue
            fi
        fi
        
        # Always continue regardless of result
        if run_validation "$script_name" "$runtime_name" "$emoji"; then
            passed_runtimes+=("$emoji $runtime_name")
        else
            failed_runtimes+=("$emoji $runtime_name")
        fi
        
        echo ""
    done
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    # Display summary
    log_step "🏁 Validation Summary"
    log_info "Total Duration: ${total_duration}s"
    echo ""
    
    if [[ ${#passed_runtimes[@]} -gt 0 ]]; then
        log_success "✅ Passed Runtimes (${#passed_runtimes[@]}):"
        for runtime in "${passed_runtimes[@]}"; do
            echo -e "${GREEN}  ✓ $runtime${NC}"
        done
        echo ""
    fi
    
    if [[ ${#failed_runtimes[@]} -gt 0 ]]; then
        log_error "❌ Failed Runtimes (${#failed_runtimes[@]}):"
        for runtime in "${failed_runtimes[@]}"; do
            echo -e "${RED}  ✗ $runtime${NC}"
        done
        echo ""
    fi
    
    if [[ ${#skipped_runtimes[@]} -gt 0 ]]; then
        log_info "⊝ Skipped Runtimes (${#skipped_runtimes[@]}):"
        for runtime in "${skipped_runtimes[@]}"; do
            echo -e "${BLUE}  - $runtime${NC}"
        done
        echo ""
    fi
    
    if [[ ${#failed_runtimes[@]} -eq 0 ]]; then
        log_success "🎉 All runtime validations PASSED!"
        return 0
    else
        log_warning "Some validations failed, but all validations completed"
        return 1
    fi
}

# Global validation strategy (placeholder for future implementation)
run_global_validation() {
    log_header "🌐 Global Validation Strategy"
    log_warning "Global validation strategy is not yet implemented"
    log_info "Falling back to per-runtime strategy..."
    echo ""
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
        log_warning "Environment setup had issues, but continuing..."
    fi
    
    # Display banner
    echo ""
    cat << 'EOF'
╔═══════════════════════════════════════════════════╗
║         Runtime Validation Suite               ║
║                                                   ║
║  Validates: Python, Java, Node.js, PostgreSQL    ║
║  Mode: Continuous (runs all validations)         ║
╚═══════════════════════════════════════════════════╝
EOF
    echo ""

    log_info "Starting validation with strategy: $STRATEGY"
    log_info "Output will be shown in real-time and saved to: $VALIDATION_LOG"
    echo ""
    
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
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $validation_result -eq 0 ]]; then
        log_success "🎉 ALL RUNTIME VALIDATIONS COMPLETED SUCCESSFULLY!"
        log_info "Golden image is ready for production use"
    else
        log_warning "⚠️  VALIDATION COMPLETED WITH SOME FAILURES"
        log_info "Review the output above for details on failed validations"
        log_info ""
        log_info "🔧 Troubleshooting Tips:"
        log_info "  1. Run individual runtime validation: $0 --runtime <runtime_name>"
        log_info "  2. Use verbose mode for detailed output: $0 --verbose"
        log_info "  3. Check individual validation scripts in: $SCRIPT_DIR"
    fi
    log_info ""
    log_info "📄 Full validation log saved to: $VALIDATION_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    return $validation_result
}

# Parse arguments and run main function
parse_arguments "$@"
main