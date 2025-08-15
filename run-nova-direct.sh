#!/bin/bash

# Direct launch script for Nova with custom WebKit
# Uses DYLD_FRAMEWORK_PATH directly without WebKit tools

WEBKIT_DIR="/Users/keviruchis/Developer/Nova/WebKit"
NOVA_PROJECT_DIR="/Users/keviruchis/Developer/Nova"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Nova Direct WebKit Launcher${NC}"
echo "========================================="

# Find Nova app
find_nova_app() {
    local DERIVED_DATA_PATH="/Users/keviruchis/Library/Developer/Xcode/DerivedData"
    local MANUAL_BUILD_PATH="$NOVA_PROJECT_DIR/build/Debug/Nova.app"
    
    if [ -d "$DERIVED_DATA_PATH" ]; then
        local NOVA_APP=$(find "$DERIVED_DATA_PATH" -name "Nova.app" -path "*/Build/Products/Debug/*" 2>/dev/null | head -1)
        if [ -n "$NOVA_APP" ] && [ -d "$NOVA_APP" ]; then
            echo "$NOVA_APP"
            return 0
        fi
    fi
    
    if [ -d "$MANUAL_BUILD_PATH" ]; then
        echo "$MANUAL_BUILD_PATH"
        return 0
    fi
    
    return 1
}

# Copy frameworks to app bundle
copy_frameworks() {
    local APP_PATH=$1
    local FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"
    
    echo "Copying WebKit frameworks to app bundle..."
    mkdir -p "$FRAMEWORKS_PATH"
    
    # Copy main frameworks
    for framework in WebKit JavaScriptCore WebCore WTF PAL bmalloc; do
        if [ -d "$WEBKIT_DIR/WebKitBuild/Release/${framework}.framework" ]; then
            echo "  Copying ${framework}.framework..."
            rm -rf "$FRAMEWORKS_PATH/${framework}.framework"
            cp -R "$WEBKIT_DIR/WebKitBuild/Release/${framework}.framework" "$FRAMEWORKS_PATH/"
        fi
    done
    
    # Copy WebInspectorUI if it exists
    if [ -d "$WEBKIT_DIR/WebKitBuild/Release/WebInspectorUI.framework" ]; then
        echo "  Copying WebInspectorUI.framework..."
        rm -rf "$FRAMEWORKS_PATH/WebInspectorUI.framework"
        cp -R "$WEBKIT_DIR/WebKitBuild/Release/WebInspectorUI.framework" "$FRAMEWORKS_PATH/"
    fi
    
    echo -e "${GREEN}✓ Frameworks copied${NC}"
}

# Main execution
main() {
    NOVA_APP=$(find_nova_app)
    
    if [ -z "$NOVA_APP" ]; then
        echo -e "${RED}Error: Nova.app not found!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Found Nova app:${NC} $NOVA_APP"
    
    # Check if WebKit is built
    if [ ! -d "$WEBKIT_DIR/WebKitBuild/Release/WebKit.framework" ]; then
        echo -e "${RED}WebKit not built. Run: cd $WEBKIT_DIR && Tools/Scripts/build-webkit --release${NC}"
        exit 1
    fi
    
    # Copy frameworks
    copy_frameworks "$NOVA_APP"
    
    # Set up environment
    export DYLD_FRAMEWORK_PATH="$NOVA_APP/Contents/Frameworks:$WEBKIT_DIR/WebKitBuild/Release"
    export DYLD_LIBRARY_PATH="$NOVA_APP/Contents/Frameworks:$WEBKIT_DIR/WebKitBuild/Release"
    export WEBKIT_INSPECTOR_SERVER=127.0.0.1:9999
    export WEBKIT_SHOW_INSPECTOR=1
    
    # Enable developer extras via defaults
    defaults write com.nova.browser WebKitDeveloperExtras -bool true
    defaults write com.nova.browser WebKitDeveloperExtrasEnabledPreferenceKey -bool true
    
    echo ""
    echo -e "${GREEN}Launching Nova with custom WebKit (direct method)...${NC}"
    echo "DYLD_FRAMEWORK_PATH=$DYLD_FRAMEWORK_PATH"
    echo ""
    echo "Inspector: Right-click → Inspect Element"
    echo ""
    
    # Launch the app
    "$NOVA_APP/Contents/MacOS/Nova"
}

# Handle Ctrl+C
trap 'echo -e "\n${YELLOW}Interrupted${NC}"; exit 1' INT

main