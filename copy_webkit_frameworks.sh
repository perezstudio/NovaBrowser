#!/bin/bash

# Script to copy custom WebKit frameworks to the app bundle

# Define paths
WEBKIT_BUILD_PATH="/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release"
APP_FRAMEWORKS_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

echo "Copying custom WebKit frameworks to app bundle..."
echo "Source: ${WEBKIT_BUILD_PATH}"
echo "Destination: ${APP_FRAMEWORKS_PATH}"

# Create the Frameworks directory if it doesn't exist
mkdir -p "${APP_FRAMEWORKS_PATH}"

# Copy the frameworks
if [ -d "${WEBKIT_BUILD_PATH}/JavaScriptCore.framework" ]; then
    echo "Copying JavaScriptCore.framework..."
    cp -R "${WEBKIT_BUILD_PATH}/JavaScriptCore.framework" "${APP_FRAMEWORKS_PATH}/"
else
    echo "Warning: JavaScriptCore.framework not found at ${WEBKIT_BUILD_PATH}/JavaScriptCore.framework"
fi

if [ -d "${WEBKIT_BUILD_PATH}/WebCore.framework" ]; then
    echo "Copying WebCore.framework..."
    cp -R "${WEBKIT_BUILD_PATH}/WebCore.framework" "${APP_FRAMEWORKS_PATH}/"
else
    echo "Warning: WebCore.framework not found at ${WEBKIT_BUILD_PATH}/WebCore.framework"
fi

if [ -d "${WEBKIT_BUILD_PATH}/WebKit.framework" ]; then
    echo "Copying WebKit.framework..."
    cp -R "${WEBKIT_BUILD_PATH}/WebKit.framework" "${APP_FRAMEWORKS_PATH}/"
else
    echo "Warning: WebKit.framework not found at ${WEBKIT_BUILD_PATH}/WebKit.framework"
fi

echo "Custom WebKit frameworks copied successfully!"

# Update the install names to use @rpath
if [ -f "${APP_FRAMEWORKS_PATH}/JavaScriptCore.framework/JavaScriptCore" ]; then
    install_name_tool -id "@rpath/JavaScriptCore.framework/JavaScriptCore" "${APP_FRAMEWORKS_PATH}/JavaScriptCore.framework/JavaScriptCore"
fi

if [ -f "${APP_FRAMEWORKS_PATH}/WebCore.framework/WebCore" ]; then
    install_name_tool -id "@rpath/WebCore.framework/WebCore" "${APP_FRAMEWORKS_PATH}/WebCore.framework/WebCore"
    install_name_tool -change "${WEBKIT_BUILD_PATH}/JavaScriptCore.framework/JavaScriptCore" "@rpath/JavaScriptCore.framework/JavaScriptCore" "${APP_FRAMEWORKS_PATH}/WebCore.framework/WebCore"
fi

if [ -f "${APP_FRAMEWORKS_PATH}/WebKit.framework/WebKit" ]; then
    install_name_tool -id "@rpath/WebKit.framework/WebKit" "${APP_FRAMEWORKS_PATH}/WebKit.framework/WebKit"
    install_name_tool -change "${WEBKIT_BUILD_PATH}/JavaScriptCore.framework/JavaScriptCore" "@rpath/JavaScriptCore.framework/JavaScriptCore" "${APP_FRAMEWORKS_PATH}/WebKit.framework/WebKit"
    install_name_tool -change "${WEBKIT_BUILD_PATH}/WebCore.framework/WebCore" "@rpath/WebCore.framework/WebCore" "${APP_FRAMEWORKS_PATH}/WebKit.framework/WebKit"
fi

echo "Framework install names updated!"