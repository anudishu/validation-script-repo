# Scripts Directory

This directory contains helper scripts and utilities for Ansible automation.

## 📁 Script Categories

### Deployment Scripts
- `deploy.sh` - Main deployment script
- `rollback.sh` - Rollback to previous version
- `health-check.sh` - Post-deployment health checks

### Utility Scripts
- `setup-environment.sh` - Environment setup
- `generate-inventory.sh` - Dynamic inventory generation
- `backup-configs.sh` - Configuration backup

### Testing Scripts
- `test-connectivity.sh` - Test SSH connectivity to hosts
- `validate-playbook.sh` - Playbook syntax validation
- `run-tests.sh` - Automated testing suite

## 🎯 Script Best Practices

1. **Make scripts executable**
   ```bash
   chmod +x script-name.sh
   ```

2. **Include proper shebang**
   ```bash
   #!/bin/bash
   ```

3. **Add error handling**
   ```bash
   set -e  # Exit on error
   set -u  # Exit on undefined variable
   ```

4. **Document usage**
   ```bash
   # Include usage information at the top
   # Usage: ./script.sh [options]
   ```

5. **Use meaningful exit codes**
   ```bash
   exit 0  # Success
   exit 1  # Error
   ```

## 📝 Example Script Structure

```bash
#!/bin/bash
# Description: What this script does
# Usage: ./script.sh [options]
# Author: Your Name

set -e

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/script.log"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Main execution
main() {
    log "Starting script execution"
    # Your script logic here
    log "Script completed successfully"
}

# Execute main function
main "$@"
```

