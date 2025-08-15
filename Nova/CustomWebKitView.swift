//
//  CustomWebKitView.swift
//  Nova
//
//  Created by Kevin Perez on 7/8/25.
//

import Cocoa
import AVFoundation
// IMPORTANT: This WebKit import will use our custom WebKit framework when launched via run-nova-webkit.sh
import WebKit

// Custom WebKit View that uses our custom-built WebKit framework with full inspector access
class CustomWebKitView: NSView {
    
    // MARK: - Properties
    private var webView: WKWebView?
    private var inspectorEnabled: Bool = true
    private var currentURL: URL?
    private var profile: Profile? // Associated profile for isolated browsing
    
    // Public access to the web view
    var currentWebView: WKWebView? {
        return webView
    }
    
    // MARK: - Custom WebKit Integration Points
    private var webKitLibraryPath: String?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCustomWebKit()
    }
    
    convenience init(frame frameRect: NSRect, profile: Profile?) {
        self.init(frame: frameRect)
        self.profile = profile
        setupCustomWebKit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCustomWebKit()
    }
    
    private func setupCustomWebKit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        
        // Initialize custom WebKit integration
        setupWebKitLibrary()
        setupWebView()
    }
    
    private func setupWebKitLibrary() {
        // Check if custom WebKit build exists
        let webkitPath = findWebKitBuild()
        if let path = webkitPath {
            webKitLibraryPath = path
            print("Found custom WebKit library at: \(path)")
        } else {
            print("WebKit library not found - ensure WebKit is built first")
        }
    }
    
    private func findWebKitBuild() -> String? {
        // Look for WebKit build in common locations
        let possiblePaths = [
            "/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Release",
            "/Users/keviruchis/Developer/Nova/WebKit/WebKitBuild/Debug",
            "./WebKit/WebKitBuild/Release",
            "./WebKit/WebKitBuild/Debug"
        ]
        
        for path in possiblePaths {
            let webkitFrameworkPath = "\(path)/WebKit.framework"
            if FileManager.default.fileExists(atPath: webkitFrameworkPath) {
                return path
            }
        }
        
        return nil
    }
    
    private func setupWebView() {
        // Create WKWebView configuration with custom WebKit support
        let configuration = WKWebViewConfiguration()
        
        // Enable developer extras for WebKit Inspector - this works with our custom WebKit
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Additional inspector configuration that works with custom WebKit
        UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtrasEnabledPreferenceKey")
        UserDefaults.standard.synchronize()
        
        // Create the web view - when launched with run-nova-webkit.sh, this will use our custom WebKit
        webView = WKWebView(frame: bounds, configuration: configuration)
        guard let webView = webView else { return }
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15 NovaCustomWebKit/1.0"
        
        // Setup WebRTC support
        setupWebRTCSupport()
        
        addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        print("Custom WebKit view setup complete")
    }
    
    private func setupWebRTCSupport() {
        // WebRTC script injection for enhanced compatibility
        guard let webView = webView else { return }
        
        let webRTCScript = """
        // Enhanced WebRTC support for Custom WebKit
        (function() {
            'use strict';
            
            console.log('Nova Custom WebKit: Initializing WebRTC support...');
            
            // Ensure mediaDevices exists
            if (!navigator.mediaDevices) {
                navigator.mediaDevices = {};
            }
            
            // Enhanced getUserMedia with proper error handling
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            if (originalGetUserMedia) {
                navigator.mediaDevices.getUserMedia = function(constraints) {
                    console.log('Nova Custom WebKit: getUserMedia called with:', constraints);
                    return originalGetUserMedia.call(navigator.mediaDevices, constraints)
                        .then(stream => {
                            console.log('Nova Custom WebKit: getUserMedia success, tracks:', stream.getTracks().length);
                            return stream;
                        })
                        .catch(error => {
                            console.error('Nova Custom WebKit: getUserMedia error:', error);
                            throw error;
                        });
                };
            }
            
            console.log('Nova Custom WebKit: WebRTC enhancement complete');
        })();
        """
        
        let userScript = WKUserScript(source: webRTCScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    // MARK: - Public Methods
    
    func loadURL(_ url: URL) {
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    func loadURLString(_ urlString: String) {
        if let url = URL(string: urlString) {
            loadURL(url)
        }
    }
    
    func showInspector() {
        print("Custom WebKit: Showing inspector...")
        
        // With our custom WebKit build, we can access the inspector directly
        guard let webView = webView else { return }
        
        // Try to show the inspector using custom WebKit's capabilities
        if webView.responds(to: Selector("_inspector")) {
            if let inspector = webView.perform(Selector("_inspector"))?.takeUnretainedValue() {
                if inspector.responds(to: Selector("show")) {
                    inspector.perform(Selector("show"))
                    print("Custom WebKit: Inspector shown successfully")
                    return
                }
            }
        }
        
        // Fallback method for inspector
        if webView.responds(to: Selector("_showInspector")) {
            webView.perform(Selector("_showInspector"))
            print("Custom WebKit: Inspector shown via _showInspector")
        } else {
            print("Custom WebKit: Inspector methods not available - ensure you're using the custom WebKit build")
        }
    }
    
    func executeJavaScript(_ script: String, completion: @escaping (Any?, Error?) -> Void) {
        webView?.evaluateJavaScript(script, completionHandler: completion)
    }
    
    func showInspectorConsole() {
        showInspector()
    }
    
    func showInspectorElements() {
        showInspector()
    }
    
    func showInspectorSources() {
        showInspector()
    }
    
    func load(_ request: URLRequest) {
        webView?.load(request)
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    var canGoBack: Bool {
        return webView?.canGoBack ?? false
    }
    
    var canGoForward: Bool {
        return webView?.canGoForward ?? false
    }
    
    func reload() {
        webView?.reload()
    }
    
    var url: URL? {
        return webView?.url
    }
}

// MARK: - WKNavigationDelegate

extension CustomWebKitView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Custom WebKit: Started loading")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Custom WebKit: Finished loading")
        currentURL = webView.url
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Custom WebKit: Navigation failed - \(error.localizedDescription)")
    }
}

// MARK: - WKUIDelegate

extension CustomWebKitView: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("Custom WebKit: Media capture permission requested for: \(origin.host)")
        
        // Grant permission for WebRTC - our custom WebKit supports this properly
        decisionHandler(.grant)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle popup windows
        webView.load(navigationAction.request)
        return nil
    }
}