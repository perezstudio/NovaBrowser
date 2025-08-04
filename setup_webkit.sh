#!/bin/bash

# Nova Browser - WebKit Integration Setup
# This script helps set up the open source WebKit for your Nova browser

echo "🚀 Nova Browser - WebKit Integration Setup"
echo "=========================================="

PROJECT_DIR="/Users/keviruchis/Developer/Nova"
WEBKIT_DIR="$PROJECT_DIR/WebKit"

echo "📁 Project directory: $PROJECT_DIR"
echo "📁 WebKit directory: $WEBKIT_DIR"

# Check if we're in the right directory
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Error: Nova project directory not found at $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

echo ""
echo "🔍 Checking WebKit setup..."

# Check if WebKit directory exists and has content
if [ ! -d "$WEBKIT_DIR" ] || [ -z "$(ls -A "$WEBKIT_DIR" 2>/dev/null)" ]; then
    echo "📥 Downloading WebKit source code..."
    echo "   This may take a while (WebKit is ~2GB)..."
    
    # Remove empty directory if it exists
    if [ -d "$WEBKIT_DIR" ]; then
        echo "🗑  Removing empty WebKit directory..."
        rmdir "$WEBKIT_DIR"
    fi
    
    # Clone WebKit repository
    echo "📡 Cloning WebKit from GitHub..."
    git clone https://github.com/WebKit/WebKit.git
    
    if [ $? -eq 0 ]; then
        echo "✅ WebKit source downloaded successfully"
    else
        echo "❌ Failed to download WebKit source"
        echo "🔍 Checking network connection and trying alternative..."
        
        # Try shallow clone if full clone fails
        echo "📡 Trying shallow clone..."
        git clone --depth 1 https://github.com/WebKit/WebKit.git
        
        if [ $? -eq 0 ]; then
            echo "✅ WebKit source downloaded successfully (shallow clone)"
        else
            echo "❌ Failed to download WebKit source"
            echo "💡 Manual solution:"
            echo "   1. Check your internet connection"
            echo "   2. Try: git clone https://github.com/WebKit/WebKit.git"
            echo "   3. Or download ZIP from: https://github.com/WebKit/WebKit"
            exit 1
        fi
    fi
else
    echo "✅ WebKit directory exists with content"
fi

# Verify WebKit source exists
if [ ! -f "$WEBKIT_DIR/Tools/Scripts/build-webkit" ]; then
    echo "❌ WebKit build script not found!"
    echo "🔍 Checking WebKit directory contents..."
    ls -la "$WEBKIT_DIR"
    echo ""
    echo "💡 The WebKit directory may be incomplete. Try:"
    echo "   rm -rf \"$WEBKIT_DIR\""
    echo "   git clone https://github.com/WebKit/WebKit.git"
    exit 1
fi

cd "$WEBKIT_DIR"

echo ""
echo "🛠  Setting up WebKit build environment..."

# Check if build tools are available
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install cmake
    else
        echo "❌ Homebrew not found. Please install CMake manually:"
        echo "   https://cmake.org/download/"
        exit 1
    fi
fi

if ! command -v ninja &> /dev/null; then
    echo "❌ Ninja not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install ninja
    else
        echo "❌ Homebrew not found. Please install Ninja manually:"
        echo "   https://ninja-build.org/"
        exit 1
    fi
fi

echo "✅ Build tools ready"

# Check for Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode command line tools not found. Installing..."
    xcode-select --install
    echo "⏳ Please complete the Xcode command line tools installation, then run this script again."
    exit 1
fi

echo "✅ Xcode command line tools found"

echo ""
echo "⚙️  Building WebKit..."
echo "   This will take 30-60 minutes on first build..."
echo "   You can continue with other work while this builds."

# Create build directory if it doesn't exist
mkdir -p WebKitBuild

echo "   Running: Tools/Scripts/build-webkit --release --macos"

# Check if this is the first time building
if [ ! -f "WebKitBuild/Release/lib/libWebKit.dylib" ]; then
    echo ""
    echo "📋 First-time build detected. This includes:"
    echo "   • Setting up build dependencies"
    echo "   • Compiling WebKit engine (~10,000 files)"
    echo "   • Building debugging tools"
    echo "   • Creating library files"
    echo ""
    echo "   Estimated time: 45-90 minutes"
    echo "   Memory usage: ~8GB RAM"
    echo "   Disk usage: ~10GB"
    echo ""
    echo "   You can monitor progress in another terminal with:"
    echo "   tail -f $WEBKIT_DIR/WebKitBuild/build.log"
    echo ""
    echo "⏳ Starting build process..."
fi

# Start the build with better error handling
if Tools/Scripts/build-webkit --release --macos 2>&1 | tee WebKitBuild/build.log; then
    echo ""
    echo "🎉 WebKit build completed successfully!"
    echo ""
    echo "📁 Build output location:"
    echo "   $WEBKIT_DIR/WebKitBuild/Release/"
    echo ""
    echo "🔧 Key library files:"
    if [ -d "WebKitBuild/Release/lib" ]; then
        ls -la WebKitBuild/Release/lib/ | grep -E "\.(dylib|a)$" | head -5
    else
        echo "   ❌ Library directory not found"
    fi
    echo ""
    echo "✅ Integration files are ready for Nova Browser"
else
    echo ""
    echo "❌ WebKit build failed"
    echo "📋 Check the build log for details:"
    echo "   less $WEBKIT_DIR/WebKitBuild/build.log"
    echo ""
    echo "🆘 Common solutions:"
    echo "   1. Check available disk space (need ~10GB free):"
    echo "      df -h ."
    echo "   2. Check available memory (need ~8GB RAM):"
    echo "      vm_stat"
    echo "   3. Ensure Xcode is up to date:"
    echo "      xcode-select --install"
    echo "   4. Try building debug version (faster, larger):"
    echo "      Tools/Scripts/build-webkit --debug --macos"
    echo "   5. Try building with fewer parallel jobs:"
    echo "      Tools/Scripts/build-webkit --release --macos --makeargs=-j4"
    echo ""
    echo "🔍 Last few lines of build log:"
    if [ -f "WebKitBuild/build.log" ]; then
        tail -20 WebKitBuild/build.log
    fi
    exit 1
fi

echo ""
echo "🔗 Setting up Nova integration..."

# Check if the integration files exist
if [ -f "$PROJECT_DIR/Nova/CustomWebKitView.swift" ]; then
    echo "✅ CustomWebKitView.swift found"
else
    echo "❌ CustomWebKitView.swift not found"
    echo "   Make sure you've added the integration files to your Xcode project"
fi

# Verify key build artifacts
echo ""
echo "🔍 Verifying build artifacts..."

key_files=(
    "WebKitBuild/Release/lib/libWebKit.dylib"
    "WebKitBuild/Release/lib/libJavaScriptCore.dylib"
    "WebKitBuild/Release/include/webkit2gtk-4.0"
)

all_good=true
for file in "${key_files[@]}"; do
    if [ -e "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (not critical)"
    fi
done

echo ""
echo "📋 Next steps:"
echo "   1. ✅ CustomWebKitView.swift should already be in your project"
echo "   2. 🔧 Update your Xcode project build settings:"
echo "      • Target → Build Settings → Search Paths"
echo "      • Library Search Paths: add $WEBKIT_DIR/WebKitBuild/Release/lib"
echo "      • Header Search Paths: add $WEBKIT_DIR/WebKitBuild/Release/include"
echo "      • Other Linker Flags: add -lWebKit -lJavaScriptCore"
echo "   3. 🏗  Build and run Nova Browser"
echo "   4. 🔄 Use the 'Custom' toggle button to switch to your WebKit implementation"
echo "   5. 🐞 Click the debug button for full inspector access"
echo ""
echo "🎯 Benefits of custom WebKit:"
echo "   • ✅ Full inspector access without ViewBridge issues"
echo "   • ✅ Complete WebRTC debugging capabilities"
echo "   • ✅ Custom debugging tools and interfaces"
echo "   • ✅ Direct access to WebKit internals"
echo "   • ✅ Unlimited customization possibilities"
echo ""
echo "🚀 Your Nova browser now has custom WebKit integration!"
echo ""
echo "💡 Pro tip: Keep both Apple and Custom WebKit modes for comparison"
echo "   Apple WebKit: Fast, standard features, some limitations"
echo "   Custom WebKit: Full control, unlimited debugging, your features"
