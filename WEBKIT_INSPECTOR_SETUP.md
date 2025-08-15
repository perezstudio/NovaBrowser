# WebKit Inspector Setup for Nova Browser

## Overview
This document describes the setup for enabling WebKit Inspector in the Nova browser using a custom WebKit build.

## What Has Been Implemented

### 1. WebKit Build Configuration
- Building WebKit with release configuration including inspector support
- Location: `/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release/`

### 2. Nova Application Updates

#### CustomWebKitView.swift
- Added developer extras configuration in `setupWebView()`
- Enabled inspector preferences via UserDefaults
- Set up proper WebKit configuration for inspector access

#### Info.plist
- Added security entitlements for library validation
- Added environment variables for WebKit inspector
- Configured inspector server on localhost:9999

#### Nova.entitlements
- Disabled app sandbox for development
- Allowed unsigned executable memory
- Disabled library validation
- Enabled DYLD environment variables

### 3. Launch Scripts

#### run-nova-webkit.sh
- Uses WebKit's official `run-webkit-app` tool
- Automatically sets DYLD_FRAMEWORK_PATH
- Handles all framework dependencies
- Enables inspector server

#### run-nova-direct.sh
- Direct DYLD_FRAMEWORK_PATH method
- Copies frameworks to app bundle
- Sets environment variables manually
- Alternative approach if official tool has issues

## How to Use

### Step 1: Wait for WebKit Build
The WebKit build is currently in progress. This typically takes 10-30 minutes on first build.

### Step 2: Build Nova in Xcode
1. Open Nova.xcodeproj in Xcode
2. Select the Nova target
3. Build (⌘B)

### Step 3: Launch Nova with Custom WebKit
Use one of these methods:

**Method A: Official WebKit Tool (Recommended)**
```bash
./run-nova-webkit.sh
```

**Method B: Direct Launch**
```bash
./run-nova-direct.sh
```

### Step 4: Access the Inspector
1. Navigate to any webpage in Nova
2. Right-click on the page
3. Select "Inspect Element" from the context menu

## Troubleshooting

### Inspector Not Showing
1. Ensure WebKit build completed successfully
2. Check that developer extras are enabled
3. Verify frameworks are properly loaded

### Code Signing Issues
1. The entitlements file disables library validation
2. You may need to run with reduced security: `codesign --deep --force --sign - /path/to/Nova.app`

### Framework Loading Issues
Check that DYLD_FRAMEWORK_PATH is set correctly:
```bash
echo $DYLD_FRAMEWORK_PATH
```

### Build Errors
If WebKit build fails:
```bash
cd WebKit
rm -rf WebKitBuild
Tools/Scripts/build-webkit --release
```

## Environment Variables
The following environment variables are set by the launch scripts:
- `DYLD_FRAMEWORK_PATH`: Points to custom WebKit frameworks
- `WEBKIT_INSPECTOR_SERVER`: localhost:9999
- `WEBKIT_SHOW_INSPECTOR`: 1

## File Locations
- Custom WebKit: `/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release/`
- Nova App: Check both:
  - Xcode DerivedData: `~/Library/Developer/Xcode/DerivedData/Nova-*/Build/Products/Debug/Nova.app`
  - Manual Build: `/Users/keviruchis/Developer/Nova/build/Debug/Nova.app`

## Next Steps
Once the WebKit build completes and you've tested the inspector:
1. The inspector should provide full debugging capabilities
2. You can inspect elements, view console, debug JavaScript, analyze network traffic
3. The inspector UI comes from the custom WebKit build

## Notes
- The WebKit build includes WebInspectorUI.framework by default
- No special build flags are needed for inspector support
- The inspector works with both debug and release builds