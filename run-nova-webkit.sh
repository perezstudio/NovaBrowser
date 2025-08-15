#!/bin/bash

# Script to run Nova with custom WebKit framework using WebKit's official tools
# This ensures proper inspector functionality and framework loading

WEBKIT_DIR="/Users/keviruchis/Developer/Nova/WebKit"
NOVA_PROJECT_DIR="/Users/keviruchis/Developer/Nova"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Nova WebKit Launcher${NC}"
echo "========================================="

# Function to find Nova app
find_nova_app() {
    # Check multiple possible locations
    local DERIVED_DATA_PATH="/Users/keviruchis/Library/Developer/Xcode/DerivedData"
    local MANUAL_BUILD_PATH="$NOVA_PROJECT_DIR/build/Debug/Nova.app"
    
    # Check DerivedData for most recent build
    if [ -d "$DERIVED_DATA_PATH" ]; then
        local NOVA_APP=$(find "$DERIVED_DATA_PATH" -name "Nova.app" -path "*/Build/Products/Debug/*" 2>/dev/null | head -1)
        if [ -n "$NOVA_APP" ] && [ -d "$NOVA_APP" ]; then
            echo "$NOVA_APP"
            return 0
        fi
    fi
    
    # Check manual build location
    if [ -d "$MANUAL_BUILD_PATH" ]; then
        echo "$MANUAL_BUILD_PATH"
        return 0
    fi
    
    return 1
}

# Check if WebKit is built
check_webkit_build() {
    if [ ! -d "$WEBKIT_DIR/WebKitBuild/Release/WebKit.framework" ]; then
        echo -e "${YELLOW}WebKit framework not found. Building WebKit...${NC}"
        echo "This may take 10-30 minutes on first build."
        
        cd "$WEBKIT_DIR"
        Tools/Scripts/build-webkit --release
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}WebKit build failed!${NC}"
            exit 1
        fi
        echo -e "${GREEN}WebKit build completed successfully!${NC}"
    else
        echo -e "${GREEN}✓ WebKit framework found${NC}"
    fi
}

# Main execution
main() {
    # Find Nova app
    echo "Looking for Nova app..."
    NOVA_APP=$(find_nova_app)
    
    if [ -z "$NOVA_APP" ]; then
        echo -e "${RED}Error: Nova.app not found!${NC}"
        echo "Please build Nova in Xcode first."
        exit 1
    fi
    
    echo -e "${GREEN}✓ Found Nova app:${NC} $NOVA_APP"
    
    # Check WebKit build
    check_webkit_build
    
    # Launch Nova with custom WebKit using official WebKit tools
    echo ""
    echo -e "${GREEN}Launching Nova with custom WebKit...${NC}"
    echo "========================================="
    echo "Inspector should be available via right-click → Inspect Element"
    echo ""
    
    # Set environment for inspector
    export WEBKIT_INSPECTOR_SERVER=127.0.0.1:9999
    export WEBKIT_SHOW_INSPECTOR=1
    
    # Use WebKit's run-webkit-app script
    cd "$WEBKIT_DIR"
    Tools/Scripts/run-webkit-app "$NOVA_APP"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Interrupted by user${NC}"; exit 1' INT

# Run main function
main