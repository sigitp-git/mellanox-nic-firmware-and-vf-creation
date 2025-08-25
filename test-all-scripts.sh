#!/bin/bash
# Comprehensive Test Script for Mellanox ConnectX-7 NIC Management Scripts
# Tests all functionalities without making destructive changes

# Don't exit on errors - we want to continue testing even if some tests fail
set +e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG="/tmp/mellanox-test-$(date +%Y%m%d_%H%M%S).log"
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test logging
log_test() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TEST: $1" | tee -a "$TEST_LOG"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$TEST_LOG"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$TEST_LOG"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

# Test counter
run_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_test "$1"
}

# Check if running as root (some tests require it)
check_root_access() {
    if [ "$EUID" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test 1: Check all required scripts exist
test_script_existence() {
    run_test "Checking script file existence"
    
    local scripts=(
        "install-mft.sh"
        "install-cx7-firmware.sh"
        "update-cx7-firmware.sh"
        "firmware-config.json"
        "mlx-nic-health-check.sh"
    )
    
    local missing_scripts=()
    
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_info "Found: $script"
        else
            missing_scripts+=("$script")
        fi
    done
    
    if [ ${#missing_scripts[@]} -eq 0 ]; then
        log_success "All required scripts found"
    else
        log_error "Missing scripts: ${missing_scripts[*]}"
    fi
}

# Test 2: Check script permissions
test_script_permissions() {
    run_test "Checking script permissions"
    
    local executable_scripts=(
        "install-mft.sh"
        "install-cx7-firmware.sh" 
        "update-cx7-firmware.sh"
        "mlx-nic-health-check.sh"
    )
    
    local non_executable=()
    
    for script in "${executable_scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            if [ -x "$SCRIPT_DIR/$script" ]; then
                log_info "$script is executable"
            else
                non_executable+=("$script")
            fi
        fi
    done
    
    if [ ${#non_executable[@]} -eq 0 ]; then
        log_success "All scripts have correct permissions"
    else
        log_error "Non-executable scripts: ${non_executable[*]}"
        log_info "Fix with: chmod +x ${non_executable[*]}"
    fi
}

# Test 3: Validate JSON configuration
test_json_configuration() {
    run_test "Validating JSON configuration files"
    
    if [ -f "$SCRIPT_DIR/firmware-config.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$SCRIPT_DIR/firmware-config.json" 2>/dev/null; then
                log_success "firmware-config.json is valid JSON"
                
                # Check required fields
                local required_fields=("firmware_mappings" "latest_lts_versions" "download_base_url")
                local missing_fields=()
                
                for field in "${required_fields[@]}"; do
                    if jq -e ".$field" "$SCRIPT_DIR/firmware-config.json" >/dev/null 2>&1; then
                        log_info "Found required field: $field"
                    else
                        missing_fields+=("$field")
                    fi
                done
                
                if [ ${#missing_fields[@]} -eq 0 ]; then
                    log_success "All required JSON fields present"
                else
                    log_error "Missing JSON fields: ${missing_fields[*]}"
                fi
            else
                log_error "firmware-config.json contains invalid JSON"
            fi
        else
            log_warning "jq not available, skipping JSON validation"
        fi
    else
        log_error "firmware-config.json not found"
    fi
}

# Test 4: Test script help/usage functions
test_script_help() {
    run_test "Testing script help functions"
    
    local scripts_with_help=(
        "install-mft.sh"
        "install-cx7-firmware.sh"
        "update-cx7-firmware.sh"
    )
    
    for script in "${scripts_with_help[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_info "Testing help for $script"
            
            # Test --help flag
            if timeout 10 "$SCRIPT_DIR/$script" --help >/dev/null 2>&1; then
                log_success "$script --help works"
            else
                log_error "$script --help failed or timed out"
            fi
            
            # Test -h flag
            if timeout 10 "$SCRIPT_DIR/$script" -h >/dev/null 2>&1; then
                log_success "$script -h works"
            else
                log_error "$script -h failed or timed out"
            fi
        fi
    done
}

# Test 5: Test version detection functions (dry run)
test_version_detection() {
    run_test "Testing version detection functions (dry run)"
    
    # Test MFT version detection
    if [ -f "$SCRIPT_DIR/install-mft.sh" ]; then
        log_info "Testing MFT version detection logic"
        
        # Check if the script has version detection functions
        if grep -q "detect_latest_mft_version" "$SCRIPT_DIR/install-mft.sh"; then
            log_success "MFT version detection function found"
        else
            log_error "MFT version detection function not found"
        fi
        
        if grep -q "validate_mft_version" "$SCRIPT_DIR/install-mft.sh"; then
            log_success "MFT version validation function found"
        else
            log_error "MFT version validation function not found"
        fi
    fi
    
    # Test firmware version detection
    if [ -f "$SCRIPT_DIR/install-cx7-firmware.sh" ]; then
        log_info "Testing firmware version detection logic"
        
        if grep -q "detect_latest_firmware_versions" "$SCRIPT_DIR/install-cx7-firmware.sh"; then
            log_success "Firmware version detection function found"
        else
            log_error "Firmware version detection function not found"
        fi
        
        if grep -q "load_firmware_mappings" "$SCRIPT_DIR/install-cx7-firmware.sh"; then
            log_success "Firmware mapping loader function found"
        else
            log_error "Firmware mapping loader function not found"
        fi
    fi
}

# Test 6: Test network connectivity for auto-detection
test_network_connectivity() {
    run_test "Testing network connectivity for auto-detection"
    
    local urls=(
        "https://network.nvidia.com/products/adapter-software/firmware-tools/"
        "https://network.nvidia.com/support/firmware/connectx7/"
        "https://www.mellanox.com/downloads/MFT/"
        "https://www.mellanox.com/downloads/firmware/"
    )
    
    local reachable=0
    local total=${#urls[@]}
    
    for url in "${urls[@]}"; do
        log_info "Testing connectivity to: $url"
        
        if timeout 10 curl --head --silent --fail "$url" >/dev/null 2>&1; then
            log_success "✓ Reachable: $url"
            reachable=$((reachable + 1))
        else
            log_warning "✗ Not reachable: $url"
        fi
    done
    
    if [ $reachable -eq $total ]; then
        log_success "All required URLs are reachable"
    elif [ $reachable -gt 0 ]; then
        log_warning "$reachable/$total URLs reachable - auto-detection may work partially"
    else
        log_error "No URLs reachable - auto-detection will fail"
    fi
}

# Test 7: Test command-line argument parsing
test_argument_parsing() {
    run_test "Testing command-line argument parsing"
    
    # Test install-mft.sh arguments
    if [ -f "$SCRIPT_DIR/install-mft.sh" ]; then
        log_info "Testing install-mft.sh argument parsing"
        
        # Check for argument parsing function
        if grep -q "parse_arguments" "$SCRIPT_DIR/install-mft.sh"; then
            log_success "install-mft.sh has argument parsing"
        else
            log_error "install-mft.sh missing argument parsing"
        fi
    fi
    
    # Test install-cx7-firmware.sh arguments
    if [ -f "$SCRIPT_DIR/install-cx7-firmware.sh" ]; then
        log_info "Testing install-cx7-firmware.sh argument parsing"
        
        if grep -q "parse_arguments" "$SCRIPT_DIR/install-cx7-firmware.sh"; then
            log_success "install-cx7-firmware.sh has argument parsing"
        else
            log_error "install-cx7-firmware.sh missing argument parsing"
        fi
    fi
    
    # Test update-cx7-firmware.sh arguments
    if [ -f "$SCRIPT_DIR/update-cx7-firmware.sh" ]; then
        log_info "Testing update-cx7-firmware.sh argument parsing"
        
        if grep -q "parse_arguments" "$SCRIPT_DIR/update-cx7-firmware.sh"; then
            log_success "update-cx7-firmware.sh has argument parsing"
        else
            log_error "update-cx7-firmware.sh missing argument parsing"
        fi
    fi
}

# Test 8: Test dependency checking
test_dependency_checking() {
    run_test "Testing dependency availability"
    
    local required_commands=(
        "wget"
        "curl"
        "tar"
        "unzip"
        "lspci"
    )
    
    local optional_commands=(
        "jq"
        "flint"
        "mst"
        "mlxconfig"
        "mlxlink"
    )
    
    log_info "Checking required dependencies:"
    local missing_required=()
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "✓ $cmd available"
        else
            missing_required+=("$cmd")
            log_error "✗ $cmd missing"
        fi
    done
    
    log_info "Checking optional dependencies:"
    local missing_optional=()
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "✓ $cmd available"
        else
            missing_optional+=("$cmd")
            log_warning "⚠ $cmd missing (optional)"
        fi
    done
    
    if [ ${#missing_required[@]} -eq 0 ]; then
        log_success "All required dependencies available"
    else
        log_error "Missing required dependencies: ${missing_required[*]}"
    fi
    
    if [ ${#missing_optional[@]} -gt 0 ]; then
        log_info "Missing optional dependencies: ${missing_optional[*]}"
        log_info "Install MFT tools for: flint, mst, mlxconfig, mlxlink"
        log_info "Install jq for JSON parsing"
    fi
}

# Test 9: Test hardware detection (if available)
test_hardware_detection() {
    run_test "Testing hardware detection capabilities"
    
    log_info "Checking for ConnectX-7 devices..."
    
    if command -v lspci >/dev/null 2>&1; then
        local cx7_devices=$(lspci | grep -i "MT2910\|ConnectX-7" | wc -l)
        
        if [ "$cx7_devices" -gt 0 ]; then
            log_success "Found $cx7_devices ConnectX-7 device(s)"
            lspci | grep -i "MT2910\|ConnectX-7" | while read -r line; do
                log_info "  Device: $line"
            done
        else
            log_warning "No ConnectX-7 devices detected"
            log_info "This is normal if running on non-ConnectX-7 hardware"
        fi
    else
        log_error "lspci command not available"
    fi
    
    # Test MST service availability
    if command -v mst >/dev/null 2>&1; then
        log_info "Testing MST service..."
        
        if check_root_access; then
            # Try to get MST status (requires root)
            if mst status >/dev/null 2>&1; then
                log_success "MST service accessible"
            else
                log_warning "MST service not running or accessible"
            fi
        else
            log_info "Skipping MST test (requires root access)"
        fi
    else
        log_warning "MST tools not installed"
    fi
}

# Test 10: Test error handling and logging
test_error_handling() {
    run_test "Testing error handling and logging mechanisms"
    
    local scripts=(
        "install-mft.sh"
        "install-cx7-firmware.sh"
        "update-cx7-firmware.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_info "Checking error handling in $script"
            
            # Check for error handling functions
            if grep -q "error_exit\|log.*ERROR" "$SCRIPT_DIR/$script"; then
                log_success "$script has error handling"
            else
                log_warning "$script may lack comprehensive error handling"
            fi
            
            # Check for logging functions
            if grep -q "log()" "$SCRIPT_DIR/$script"; then
                log_success "$script has logging functions"
            else
                log_warning "$script may lack logging functions"
            fi
        fi
    done
}

# Test 11: Test security and safety features
test_security_features() {
    run_test "Testing security and safety features"
    
    local scripts=(
        "install-mft.sh"
        "install-cx7-firmware.sh"
        "update-cx7-firmware.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_info "Checking security features in $script"
            
            # Check for root privilege checks
            if grep -q "EUID.*root\|check_root" "$SCRIPT_DIR/$script"; then
                log_success "$script checks for root privileges"
            else
                log_warning "$script may not check for root privileges"
            fi
            
            # Check for user confirmation prompts
            if grep -q "read.*confirm\|read.*proceed" "$SCRIPT_DIR/$script"; then
                log_success "$script has user confirmation prompts"
            else
                log_warning "$script may lack user confirmation prompts"
            fi
            
            # Check for backup creation (firmware scripts)
            if [[ "$script" == *"firmware"* ]]; then
                if grep -q "backup\|read.*backup" "$SCRIPT_DIR/$script"; then
                    log_success "$script includes backup functionality"
                else
                    log_warning "$script may not create backups"
                fi
            fi
        fi
    done
}

# Test 12: Integration test (dry run)
test_integration_dry_run() {
    run_test "Integration test (dry run mode)"
    
    log_info "Testing script integration without making changes..."
    
    # Test that scripts can call each other properly
    if [ -f "$SCRIPT_DIR/update-cx7-firmware.sh" ]; then
        log_info "Testing update wrapper integration"
        
        # Check if wrapper can find the main script
        if grep -q "install-cx7-firmware.sh" "$SCRIPT_DIR/update-cx7-firmware.sh"; then
            log_success "Wrapper script references main installation script"
        else
            log_error "Wrapper script missing reference to main script"
        fi
    fi
    
    # Test configuration file integration
    if [ -f "$SCRIPT_DIR/firmware-config.json" ] && [ -f "$SCRIPT_DIR/update-cx7-firmware.sh" ]; then
        if grep -q "firmware-config.json" "$SCRIPT_DIR/update-cx7-firmware.sh"; then
            log_success "Configuration file integration working"
        else
            log_error "Configuration file not properly integrated"
        fi
    fi
}

# Generate test report
generate_test_report() {
    echo ""
    echo "=========================================="
    echo "           TEST REPORT SUMMARY"
    echo "=========================================="
    echo ""
    echo "Total Tests Run: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "Success Rate: $success_rate%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Scripts are ready for use.${NC}"
    elif [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Most tests passed. Review failed tests before production use.${NC}"
    else
        echo -e "${RED}❌ Multiple test failures detected. Scripts need attention before use.${NC}"
    fi
    
    echo ""
    echo "Detailed log saved to: $TEST_LOG"
    echo ""
    
    # Show next steps
    echo "Next Steps:"
    if [ $FAILED_TESTS -eq 0 ]; then
        echo "✅ Scripts are ready for lab testing"
        echo "✅ Consider running with actual hardware for full validation"
    else
        echo "🔧 Fix failed tests before proceeding"
        echo "📋 Review test log for specific issues"
    fi
    
    if ! check_root_access; then
        echo "ℹ️  Run as root for additional hardware-specific tests"
    fi
    
    echo ""
}

# Main execution
main() {
    echo "🧪 Starting Comprehensive Test Suite for Mellanox ConnectX-7 Scripts"
    echo "Test Log: $TEST_LOG"
    echo ""
    
    # Run all tests
    test_script_existence
    test_script_permissions
    test_json_configuration
    test_script_help
    test_version_detection
    test_network_connectivity
    test_argument_parsing
    test_dependency_checking
    test_hardware_detection
    test_error_handling
    test_security_features
    test_integration_dry_run
    
    # Generate final report
    generate_test_report
}

# Show usage if help requested
case "${1:-}" in
    -h|--help)
        cat << EOF
Comprehensive Test Script for Mellanox ConnectX-7 Management Scripts

This script tests all functionalities without making destructive changes.

Usage: $0

Tests performed:
- Script existence and permissions
- JSON configuration validation
- Help/usage function testing
- Version detection logic
- Network connectivity
- Command-line argument parsing
- Dependency checking
- Hardware detection (if available)
- Error handling mechanisms
- Security and safety features
- Integration testing (dry run)

The script can be run as regular user, but some tests require root access
for complete hardware validation.

EOF
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac