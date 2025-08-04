#!/bin/bash

# Build WebKit for Nova Browser
# This script ensures WebKit is built and frameworks are available

set -e  # Exit on any error

echo "🚀 Building WebKit for Nova Browser..."

# Change to WebKit directory
cd "$(dirname "${BASH_SOURCE[0]}")/WebKit"

# Check if we already have a recent build
WEBKIT_BUILD_DIR="WebKitBuild/Release"
WEBKIT_FRAMEWORK="$WEBKIT_BUILD_DIR/WebKit.framework/WebKit"
JAVASCRIPTCORE_FRAMEWORK="$WEBKIT_BUILD_DIR/JavaScriptCore.framework/JavaScriptCore"
WEBCORE_FRAMEWORK="$WEBKIT_BUILD_DIR/WebCore.framework/WebCore"

# Function to check if frameworks exist and are recent
frameworks_exist() {
    if [[ -f "$WEBKIT_FRAMEWORK" && -f "$JAVASCRIPTCORE_FRAMEWORK" && -f "$WEBCORE_FRAMEWORK" ]]; then
        # Check if frameworks are less than 1 hour old
        if [[ $(find "$WEBKIT_BUILD_DIR" -name "*.framework" -mtime -1h | wc -l) -gt 0 ]]; then
            return 0  # Frameworks exist and are recent
        fi
    fi
    return 1  # Need to build
}

# Build WebKit if needed
if frameworks_exist; then
    echo "✅ WebKit frameworks are already built and recent"
else
    echo "🔨 Building WebKit (this may take a while)..."
    
    # Build WebKit for macOS Release configuration (Universal Binary)
    if [[ -f "Tools/Scripts/build-webkit" ]]; then
        # Build for arm64 architecture only (matching current system)
        Tools/Scripts/build-webkit --release
    else
        # Fallback to make if build-webkit script doesn't exist
        make release
    fi
    
    echo "✅ WebKit build completed"
fi

# Verify frameworks were built successfully
if frameworks_exist; then
    echo "✅ WebKit frameworks verified:"
    echo "   - WebKit.framework"
    echo "   - JavaScriptCore.framework" 
    echo "   - WebCore.framework"
else
    echo "❌ WebKit build failed - frameworks not found"
    exit 1
fi

# Create symlinks in Nova project for easy access
cd ..
NOVA_WEBKIT_DIR="Nova/WebKitFrameworks"
mkdir -p "$NOVA_WEBKIT_DIR"

echo "🔗 Creating framework symlinks..."
ln -sfn "../../WebKit/$WEBKIT_BUILD_DIR/WebKit.framework" "$NOVA_WEBKIT_DIR/WebKit.framework"
ln -sfn "../../WebKit/$WEBKIT_BUILD_DIR/JavaScriptCore.framework" "$NOVA_WEBKIT_DIR/JavaScriptCore.framework"
ln -sfn "../../WebKit/$WEBKIT_BUILD_DIR/WebCore.framework" "$NOVA_WEBKIT_DIR/WebCore.framework"

echo "🎉 WebKit build process completed successfully!"
echo "   Frameworks are available at: $NOVA_WEBKIT_DIR"