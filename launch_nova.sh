#!/bin/bash

# Script to launch Nova with custom WebKit frameworks

# Set the path to the app
APP_PATH="/Users/keviruchis/Library/Developer/Xcode/DerivedData/Nova-dvuqacyqkvkgrxalyylkubmumojo/Build/Products/Debug/Nova.app"

# Set DYLD_FRAMEWORK_PATH to prioritize our custom frameworks
export DYLD_FRAMEWORK_PATH="$APP_PATH/Contents/Frameworks:$DYLD_FRAMEWORK_PATH"

# Disable library validation to allow loading of unsigned frameworks
export DYLD_DISABLE_LIBRARY_VALIDATION=1

echo "Launching Nova with custom WebKit frameworks..."
echo "DYLD_FRAMEWORK_PATH=$DYLD_FRAMEWORK_PATH"

# Launch the app
"$APP_PATH/Contents/MacOS/Nova"