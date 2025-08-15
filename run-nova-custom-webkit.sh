#!/bin/bash

# Script to run Nova with custom WebKit framework
# This sets the DYLD environment variables before launching Nova

# First, let's find where the app is actually being built
DERIVED_DATA_PATH="/Users/keviruchis/Library/Developer/Xcode/DerivedData/Nova-dvuqacyqkvkgrxalyylkubmumojo/Build/Products/Debug/Nova.app"
MANUAL_BUILD_PATH="/Users/keviruchis/Developer/Nova/build/Debug/Nova.app"

# Check both possible locations (prioritize DerivedData for Xcode development)
if [ -d "$DERIVED_DATA_PATH" ]; then
    APP_PATH="$DERIVED_DATA_PATH"
    echo "Found Nova app in DerivedData: $APP_PATH"
elif [ -d "$MANUAL_BUILD_PATH" ]; then
    APP_PATH="$MANUAL_BUILD_PATH" 
    echo "Found Nova app in manual build: $APP_PATH"
else
    echo "Nova app not found in either location!"
    echo "Expected locations:"
    echo "  DerivedData: $DERIVED_DATA_PATH"
    echo "  Manual build: $MANUAL_BUILD_PATH"
    exit 1
fi

FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"

# Copy custom WebKit to the actual app location if it's not there
if [ ! -d "$FRAMEWORKS_PATH/WebKit.framework" ]; then
    echo "Copying custom WebKit framework to app bundle..."
    mkdir -p "$FRAMEWORKS_PATH"
    if [ -d "/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release/WebKit.framework" ]; then
        cp -R "/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release/WebKit.framework" "$FRAMEWORKS_PATH/"
        echo "Custom WebKit framework copied successfully"
    else
        echo "ERROR: Custom WebKit framework not found at /Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release/WebKit.framework"
        exit 1
    fi
fi

if [ -d "$FRAMEWORKS_PATH/WebKit.framework" ]; then
    echo "Launching Nova with custom WebKit framework..."
    export DYLD_FRAMEWORK_PATH="$FRAMEWORKS_PATH"
    export DYLD_LIBRARY_PATH="$FRAMEWORKS_PATH"
    # Create a wrapper script to preserve environment
    cat > /tmp/launch-nova.sh << EOF
#!/bin/bash
export DYLD_FRAMEWORK_PATH="$FRAMEWORKS_PATH"
export DYLD_LIBRARY_PATH="$FRAMEWORKS_PATH"
exec "$APP_PATH/Contents/MacOS/Nova"
EOF
    chmod +x /tmp/launch-nova.sh
    /tmp/launch-nova.sh &
    echo "Nova launched with PID $!"
else
    echo "Custom WebKit framework not found. Launching with system WebKit..."
    open "$APP_PATH"
fi