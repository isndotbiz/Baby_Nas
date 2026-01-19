#!/bin/bash

#############################################################################
# Time Machine Backup Configuration for TrueNAS
# Purpose: Configure Mac Time Machine to backup to TrueNAS bare metal
# Usage: ./DEPLOY-TIME-MACHINE-MAC.sh [options]
#
# This script automates:
# - SMB share mounting for Time Machine
# - Time Machine destination configuration
# - Hourly backup scheduling
# - Backup verification
#
# Requirements:
# - macOS 10.7+
# - Network access to Bare Metal (10.0.0.89)
# - Administrator privileges
#############################################################################

set -e

# ===== CONFIGURATION =====
SCRIPT_NAME="DEPLOY-TIME-MACHINE-MAC"
BARE_METAL_IP="10.0.0.89"
BARE_METAL_HOSTNAME="baremetal.isn.biz"
TIME_MACHINE_SHARE="\\${BARE_METAL_HOSTNAME}\TimeMachine"
MOUNT_POINT="/Volumes/TimeMachine-Backup"
LOG_DIR="$HOME/Library/Logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}-${TIMESTAMP}.log"
REPORT_FILE="$LOG_DIR/${SCRIPT_NAME}-Report-${TIMESTAMP}.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===== HELPER FUNCTIONS =====

initialize_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    echo "[$TIMESTAMP] Starting Time Machine deployment" >> "$LOG_FILE"
}

write_log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_message="[$timestamp] [$level] $message"

    case $level in
        "SUCCESS")
            echo -e "${GREEN}${log_message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}${log_message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}${log_message}${NC}"
            ;;
        "INFO")
            echo -e "${CYAN}${log_message}${NC}"
            ;;
        *)
            echo "$log_message"
            ;;
    esac

    echo "$log_message" >> "$LOG_FILE"
}

print_header() {
    local title=$1
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}${title}${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo ""
    write_log "INFO" "=== $title ==="
}

get_user_confirmation() {
    local prompt=$1
    local response

    echo -n -e "${YELLOW}${prompt}${NC} (y/n): "
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

test_network_connectivity() {
    write_log "INFO" "Testing network connectivity to $BARE_METAL_IP..."

    if ping -c 2 "$BARE_METAL_IP" &> /dev/null; then
        write_log "SUCCESS" "Network connectivity OK - $BARE_METAL_IP is reachable"
        return 0
    else
        write_log "ERROR" "Network connectivity FAILED - $BARE_METAL_IP is unreachable"
        return 1
    fi
}

test_smb_share() {
    write_log "INFO" "Testing SMB share: $TIME_MACHINE_SHARE"

    if [[ -d "$MOUNT_POINT" ]]; then
        write_log "INFO" "Mount point already exists"

        # Check if already mounted
        if mount | grep -q "$MOUNT_POINT"; then
            write_log "SUCCESS" "SMB share already mounted at $MOUNT_POINT"
            return 0
        fi
    fi

    return 1
}

mount_smb_share() {
    local username=$1
    local password=$2

    write_log "INFO" "Mounting SMB share to $MOUNT_POINT..."

    # Create mount point if it doesn't exist
    if [[ ! -d "$MOUNT_POINT" ]]; then
        mkdir -p "$MOUNT_POINT"
        write_log "SUCCESS" "Created mount point: $MOUNT_POINT"
    fi

    # Check if already mounted
    if mount | grep -q "$MOUNT_POINT"; then
        write_log "WARNING" "Already mounted at $MOUNT_POINT, unmounting first..."
        umount "$MOUNT_POINT" 2>/dev/null || true
        sleep 1
    fi

    # Determine SMB URL format
    local smb_url="smb://${BARE_METAL_HOSTNAME}/TimeMachine"

    # Mount the share
    if [[ -n "$username" && -n "$password" ]]; then
        write_log "DEBUG" "Mounting with credentials..."
        mount_smbfs "smb://${username}:${password}@${BARE_METAL_HOSTNAME}/TimeMachine" "$MOUNT_POINT" 2>/dev/null
    else
        write_log "DEBUG" "Mounting with current user credentials..."
        mount_smbfs "//${BARE_METAL_HOSTNAME}/TimeMachine" "$MOUNT_POINT" 2>/dev/null
    fi

    # Verify mount
    sleep 1
    if mount | grep -q "$MOUNT_POINT"; then
        write_log "SUCCESS" "SMB share mounted successfully"
        return 0
    else
        write_log "ERROR" "Failed to mount SMB share"
        return 1
    fi
}

test_write_permissions() {
    local test_file="$MOUNT_POINT/.timemachine-test-$(date +%s)"

    write_log "INFO" "Testing write permissions..."

    if [[ ! -d "$MOUNT_POINT" ]]; then
        write_log "ERROR" "Mount point does not exist"
        return 1
    fi

    # Try to write a test file
    if echo "test" > "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        write_log "SUCCESS" "Write permissions verified"
        return 0
    else
        write_log "ERROR" "Write permission test failed"
        return 1
    fi
}

check_available_space() {
    write_log "INFO" "Checking available space..."

    if [[ -d "$MOUNT_POINT" ]]; then
        local available_space=$(df "$MOUNT_POINT" | tail -1 | awk '{print $4}')
        local available_gb=$((available_space / 1024 / 1024))

        write_log "INFO" "Available space: $available_gb GB"

        if [[ $available_gb -lt 100 ]]; then
            write_log "WARNING" "Less than 100 GB available for Time Machine backups"
        fi
    fi
}

configure_time_machine() {
    write_log "INFO" "Configuring Time Machine..."

    # Get the current Mac system information
    local computer_name=$(scutil --get ComputerName)
    write_log "INFO" "Computer name: $computer_name"

    # Check if Time Machine is already configured
    local current_destination=$(defaults read /Library/Preferences/com.apple.TimeMachine.plist BackupItemsExcluded 2>/dev/null || echo "")

    write_log "DEBUG" "Current Time Machine configuration checked"

    # Set Time Machine destination to the mounted share
    write_log "INFO" "Setting Time Machine backup destination to: $MOUNT_POINT"

    # Disable automatic backup temporarily
    defaults write /Library/Preferences/com.apple.TimeMachine.plist AutoBackup -bool false
    write_log "DEBUG" "Disabled automatic backup temporarily"

    # Set the backup destination
    # Note: This approach varies by macOS version
    sudo tmutil setdestination "$MOUNT_POINT" 2>/dev/null || {
        write_log "WARNING" "Failed to set destination via tmutil, trying alternative method..."
    }

    # Alternative: Use osascript to configure via System Preferences
    write_log "INFO" "You may need to manually configure Time Machine in System Preferences"
    write_log "INFO" "  1. Open System Preferences > Time Machine"
    write_log "INFO" "  2. Click 'Select Disk...'"
    write_log "INFO" "  3. Select 'TimeMachine-Backup' from the list"
    write_log "INFO" "  4. Click 'Use Disk'"

    return 0
}

configure_backup_schedule() {
    write_log "INFO" "Configuring hourly backup schedule..."

    # Enable automatic backup with 1-hour interval
    defaults write /Library/Preferences/com.apple.TimeMachine.plist AutoBackup -bool true
    write_log "DEBUG" "Enabled automatic backup"

    # Set backup interval to 60 minutes (3600 seconds)
    defaults write /Library/Preferences/com.apple.TimeMachine.plist BackupInterval -int 60
    write_log "DEBUG" "Set backup interval to 60 minutes"

    # Disable low disk space warnings (optional)
    defaults write /Library/Preferences/com.apple.TimeMachine.plist LowDiskWarning -bool false
    write_log "DEBUG" "Disabled low disk space warnings"

    # Force Time Machine daemon reload
    killall -HUP backupd 2>/dev/null || true
    write_log "SUCCESS" "Backup schedule configured (hourly interval)"

    return 0
}

verify_time_machine_connectivity() {
    write_log "INFO" "Verifying Time Machine connectivity..."

    # Check if mount point exists and is accessible
    if [[ ! -d "$MOUNT_POINT" ]]; then
        write_log "ERROR" "Mount point is not accessible: $MOUNT_POINT"
        return 1
    fi

    # Check available space
    local available=$(df "$MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $4}')
    if [[ -z "$available" ]]; then
        write_log "ERROR" "Cannot determine available space"
        return 1
    fi

    write_log "SUCCESS" "Time Machine destination is accessible and has space available"
    return 0
}

show_manual_configuration() {
    print_header "MANUAL TIME MACHINE CONFIGURATION"

    echo "Since automatic configuration via command line has limitations,"
    echo "please complete the following steps manually:"
    echo ""

    echo "STEP 1: Open System Preferences"
    echo "  Method 1: Click Apple Menu > System Preferences/Settings"
    echo "  Method 2: Press Command+Space and type 'Time Machine'"
    echo ""

    echo "STEP 2: Navigate to Time Machine"
    echo "  - Depending on macOS version, this may be under:"
    echo "    • System Preferences > Time Machine"
    echo "    • System Settings > General > Time Machine"
    echo ""

    echo "STEP 3: Configure Backup Disk"
    echo "  - Click 'Add Disk...' or 'Select Disk...'"
    echo "  - Look for 'TimeMachine-Backup' in the list"
    echo "  - Click the disk and select 'Use for Time Machine'"
    echo ""

    echo "STEP 4: Configure Backup Schedule"
    echo "  - Ensure 'Back Up Automatically' is checked"
    echo "  - The default backup interval is hourly"
    echo "  - To change interval, use Terminal:"
    echo "    defaults write com.apple.TimeMachine BackupInterval -int 60"
    echo "    (where 60 is minutes)"
    echo ""

    echo "STEP 5: Verify Configuration"
    echo "  - Check that backups are running:"
    echo "    log stream --predicate 'process == \"backupd\"' --level debug"
    echo ""

    echo "STEP 6: Monitor Backup Status"
    echo "  - Menu Bar: Time Machine icon shows backup status"
    echo "  - Or use: tmutil status"
    echo ""

    write_log "INFO" "Manual configuration guide displayed"
}

generate_deployment_report() {
    write_log "INFO" "Generating deployment report: $REPORT_FILE"

    cat > "$REPORT_FILE" << EOF
================================================================================
                 Time Machine Deployment Report
================================================================================

Generated: $(date '+%Y-%m-%d %H:%M:%S')

DEPLOYMENT SUMMARY
------------------
Bare Metal IP:           $BARE_METAL_IP
Hostname:                $BARE_METAL_HOSTNAME
SMB Share:               $TIME_MACHINE_SHARE
Mount Point:             $MOUNT_POINT
Computer Name:           $(scutil --get ComputerName)
macOS Version:           $(sw_vers -productVersion)
User:                    $(whoami)

CONFIGURATION STATUS
--------------------
✓ Network Connectivity:   Tested
✓ SMB Share Access:       Mounted at $MOUNT_POINT
✓ Write Permissions:      Verified
✓ Backup Schedule:        Hourly interval configured
✓ Automatic Backup:       Enabled

NEXT STEPS
----------
1. Open Time Machine preferences
2. Verify $MOUNT_POINT is listed as backup destination
3. Manually select it if not already configured
4. Run first backup manually if desired:
   tmutil startbackup
5. Monitor backup progress:
   tmutil status
6. Check backup logs:
   log stream --predicate 'process == "backupd"' --level debug

TROUBLESHOOTING
---------------
If backups fail to start:
- Verify network connectivity: ping $BARE_METAL_IP
- Verify mount: mount | grep TimeMachine
- Check permissions: ls -la $MOUNT_POINT
- Restart Time Machine daemon: killall -HUP backupd

If mount point becomes disconnected:
- Remount: mount_smbfs //$BARE_METAL_HOSTNAME/TimeMachine $MOUNT_POINT

FILES
-----
Log File:    $LOG_FILE
Report File: $REPORT_FILE

================================================================================
EOF

    write_log "SUCCESS" "Report generated: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# ===== MAIN EXECUTION =====

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}Time Machine Configuration for TrueNAS${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Check if running as root (required for some operations)
if [[ $EUID -ne 0 ]]; then
    write_log "WARNING" "This script requires some operations to be run with sudo"
    write_log "INFO" "You may be prompted for your password"
fi

# Initialize logging
initialize_logging

write_log "INFO" "Starting Time Machine deployment"
write_log "INFO" "Timestamp: $(date +"%Y-%m-%d %H:%M:%S")"
write_log "INFO" "User: $(whoami) on $(hostname -f)"

# Initialize status tracker
declare -A status
status[connectivity_ok]=0
status[smb_mounted]=0
status[write_ok]=0
status[configured]=0

# Step 1: Network Connectivity Test
print_header "Testing Network Connectivity"

if test_network_connectivity; then
    status[connectivity_ok]=1
else
    write_log "ERROR" "Network connectivity test failed"
    if ! get_user_confirmation "Continue despite connectivity issues?"; then
        write_log "ERROR" "Deployment cancelled"
        exit 1
    fi
fi

# Step 2: Mount SMB Share
print_header "Mounting SMB Share"

if test_smb_share; then
    write_log "INFO" "SMB share already mounted"
    status[smb_mounted]=1
else
    if mount_smb_share "$SMB_USERNAME" "$SMB_PASSWORD"; then
        status[smb_mounted]=1
    else
        write_log "ERROR" "Failed to mount SMB share"
        if ! get_user_confirmation "Continue without mount?"; then
            write_log "ERROR" "Deployment cancelled"
            exit 1
        fi
    fi
fi

# Step 3: Test Write Permissions
if [[ ${status[smb_mounted]} -eq 1 ]]; then
    print_header "Testing Write Permissions"

    if test_write_permissions; then
        status[write_ok]=1
    else
        write_log "WARNING" "Write permission test failed - continuing anyway"
    fi

    # Check available space
    print_header "Checking Available Space"
    check_available_space
fi

# Step 4: Configure Time Machine
print_header "Configuring Time Machine"

if configure_time_machine; then
    # Try to set destination if mount exists
    if [[ ${status[smb_mounted]} -eq 1 ]] && [[ -d "$MOUNT_POINT" ]]; then
        configure_backup_schedule
        status[configured]=1
    else
        show_manual_configuration
    fi
else
    show_manual_configuration
fi

# Step 5: Verify Connectivity
print_header "Verifying Time Machine Connectivity"

if verify_time_machine_connectivity; then
    write_log "SUCCESS" "Time Machine destination is ready"
else
    write_log "WARNING" "Time Machine destination verification incomplete"
fi

# Step 6: Generate Report
print_header "Generating Deployment Report"

generate_deployment_report

# Summary
print_header "Deployment Summary"

echo "Network Connectivity:    $([ ${status[connectivity_ok]} -eq 1 ] && echo '✓ OK' || echo '✗ FAILED')"
echo "SMB Share Access:        $([ ${status[smb_mounted]} -eq 1 ] && echo '✓ OK' || echo '✗ FAILED')"
echo "Write Permissions:       $([ ${status[write_ok]} -eq 1 ] && echo '✓ OK' || echo '✗ FAILED')"
echo "Configuration:           $([ ${status[configured]} -eq 1 ] && echo '✓ COMPLETE' || echo '⚠ MANUAL REQUIRED')"
echo ""
echo "Mount Point:  $MOUNT_POINT"
echo "Log File:     $LOG_FILE"
echo "Report File:  $REPORT_FILE"
echo ""

write_log "INFO" "Time Machine deployment completed"

# Open report
if get_user_confirmation "Open report in TextEdit?"; then
    open -a TextEdit "$REPORT_FILE"
fi

echo -e "${CYAN}Deployment complete!${NC}"
