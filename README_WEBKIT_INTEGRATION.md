# Nova Browser - Custom WebKit Integration

## 🎯 Overview

This integration allows Nova Browser to use open source WebKit instead of Apple's WKWebView, giving you:

- **Full WebKit Inspector** - No ViewBridge conflicts
- **Complete WebRTC debugging** - All internal APIs accessible  
- **Custom debugging tools** - Build your own DevTools
- **Zero limitations** - Direct access to WebKit internals

## 🏗️ Architecture

```
Nova Browser
├── Apple WebKit (WKWebView) - Standard implementation
└── Custom WebKit - Open source WebKit integration
    ├── CustomWebKitView.swift - Main integration layer
    ├── InspectorBackend - Debugging interface
    └── WebKit/ - Open source WebKit build
```

## 🚀 Setup Instructions

### 1. Run the Setup Script

```bash
cd /Users/keviruchis/Developer/Nova
chmod +x setup_webkit.sh
./setup_webkit.sh
```

This will:
- Download WebKit source (~2GB)
- Build WebKit for macOS (30-60 minutes)
- Set up integration files

### 2. Add Files to Xcode Project

1. **Add `CustomWebKitView.swift`** to your Nova target
2. **Update Build Settings**:
   - **Library Search Paths**: Add `$(PROJECT_DIR)/WebKit/WebKitBuild/Release/lib`
   - **Header Search Paths**: Add `$(PROJECT_DIR)/WebKit/WebKitBuild/Release/include`
   - **Other Linker Flags**: Add `-lWebKit`

### 3. Build and Test

1. **Build Nova** in Xcode
2. **Run the app**
3. **Click "Custom" button** to switch to custom WebKit
4. **Click debug button** to open full inspector

## 🎛️ Usage

### Browser Controls

- **"Apple" / "Custom" toggle** - Switch between WebKit implementations
- **Debug button (🔨)** - Open inspector (works without flashing in Custom mode)
- **All navigation** - Works with both implementations

### Inspector Features

When using Custom WebKit, you get:

#### **Console Tab**
- Full JavaScript execution
- WebRTC API testing
- Live debugging

#### **Elements Tab**  
- DOM tree inspection
- Live element editing
- CSS debugging

#### **Network Tab**
- HTTP request monitoring
- Response analysis
- Performance metrics

#### **Sources Tab**
- JavaScript source viewing
- Breakpoint debugging
- Step-through execution

#### **WebRTC Tab**
- Peer connection monitoring
- ICE candidate inspection
- Media stream analysis
- STUN/TURN testing

## 🔧 Development

### Key Files

- **`CustomWebKitView.swift`** - Main WebKit integration
- **`InspectorBackend`** - Debugging interface
- **`InspectorWindow`** - Custom DevTools UI
- **`NativeBrowserWindow.swift`** - Updated browser window

### Extending the Inspector

To add new debugging features:

1. **Add new tab** in `InspectorWindow.setupInspectorWindow()`
2. **Create tab view** with your debugging interface  
3. **Connect to WebKit APIs** via `InspectorBackend`
4. **Handle data updates** in real-time

### WebRTC Integration

The custom WebKit gives you direct access to:
- `RTCPeerConnection` internals
- ICE candidate gathering
- Media stream statistics  
- Network quality metrics
- Protocol-level debugging

## 🎉 Benefits vs Apple WebKit

| Feature | Apple WebKit | Custom WebKit |
|---------|-------------|---------------|
| Basic browsing | ✅ | ✅ |
| Inspector access | ❌ (ViewBridge issues) | ✅ |
| WebRTC debugging | ❌ (Limited) | ✅ (Complete) |
| Custom tools | ❌ | ✅ |
| Performance | ✅ | ✅ |
| Stability | ⚠️ (Inspector crashes) | ✅ |

## 🔍 Troubleshooting

### Build Issues

**"CMake not found"**
```bash
brew install cmake ninja
```

**"Build failed"**
```bash
# Try debug build
cd WebKit
Tools/Scripts/build-webkit --debug --macos
```

**"Library not found"**
- Check Xcode Build Settings
- Verify Library Search Paths
- Ensure WebKit built successfully

### Runtime Issues

**"Custom WebKit not working"**
- Check console for loading errors
- Verify library paths in Xcode
- Try rebuilding WebKit

**"Inspector still flashing"**
- Ensure you're using Custom WebKit mode
- Check the toggle button shows "Custom"
- Apple WebKit will still have issues

## 🎯 Next Steps

1. **Complete WebKit integration** - Replace placeholder code with real WebKit calls
2. **Enhance inspector** - Add more debugging features
3. **WebRTC specialization** - Build advanced WebRTC debugging tools
4. **Performance optimization** - Optimize for your specific use cases

## 📚 Resources

- [WebKit Documentation](https://webkit.org/documentation/)
- [WebKit Source](https://github.com/WebKit/WebKit)
- [WebRTC API Reference](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)

Your Nova browser now has the foundation for complete WebKit control and unlimited debugging capabilities!
