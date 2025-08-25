#!/bin/bash
# Quick Test Script - Basic validation of all scripts
# Runs essential tests without requiring root or hardware

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 Quick Test - Mellanox ConnectX-7 Scripts"
echo "==========================================="
echo ""

# Test 1: Check files exist
echo "📁 Checking required files..."
files=(
    "install-mft.sh"
    "install-cx7-firmware.sh"
    "update-cx7-firmware.sh"
    "firmware-config.json"
    "mlx-nic-health-check.sh"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (missing)"
    fi
done

echo ""

# Test 2: Check executability
echo "🔧 Checking script permissions..."
scripts=(
    "install-mft.sh"
    "install-cx7-firmware.sh"
    "update-cx7-firmware.sh"
    "mlx-nic-health-check.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo -e "  ${GREEN}✓${NC} $script (executable)"
    else
        echo -e "  ${YELLOW}⚠${NC} $script (not executable - run: chmod +x $script)"
    fi
done

echo ""

# Test 3: Test help functions
echo "❓ Testing help functions..."
for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        if timeout 5 "./$script" --help >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $script --help works"
        else
            echo -e "  ${RED}✗${NC} $script --help failed"
        fi
    fi
done

echo ""

# Test 4: JSON validation
echo "📋 Validating JSON configuration..."
if command -v jq >/dev/null 2>&1; then
    if [ -f "firmware-config.json" ]; then
        if jq empty firmware-config.json 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} firmware-config.json is valid"
        else
            echo -e "  ${RED}✗${NC} firmware-config.json is invalid"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} jq not installed - skipping JSON validation"
fi

echo ""

# Test 5: Basic connectivity
echo "🌐 Testing network connectivity..."
if timeout 5 curl -s --head https://network.nvidia.com >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} NVIDIA website reachable"
else
    echo -e "  ${YELLOW}⚠${NC} NVIDIA website not reachable (auto-detection may fail)"
fi

echo ""

# Test 6: Check for ConnectX-7 hardware
echo "🔍 Checking for ConnectX-7 hardware..."
if command -v lspci >/dev/null 2>&1; then
    cx7_count=$(lspci | grep -i "MT2910\|ConnectX-7" | wc -l)
    if [ "$cx7_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Found $cx7_count ConnectX-7 device(s)"
    else
        echo -e "  ${YELLOW}ℹ${NC} No ConnectX-7 devices found (normal if not on CX-7 hardware)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} lspci not available"
fi

echo ""
echo "✅ Quick test completed!"
echo ""
echo "Next steps:"
echo "  • Run './test-all-scripts.sh' for comprehensive testing"
echo "  • Test with actual hardware if available"
echo "  • Run as root for full hardware validation"
echo ""