//
//  NativeBrowserWindow.swift
//  Nova
//
//  Created by Kevin Perez on 7/8/25.
//

import Cocoa
import WebKit

class NativeBrowserWindow: NSWindowController {
    
    // Toggle between WKWebView and CustomWebKitView
    private var useCustomWebKit: Bool = true
    
    // Web views
    private var wkWebView: WKWebView?
    private var customWebKitView: CustomWebKitView?
    
    // UI elements
    private var addressField: NSTextField!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!
    private var debugButton: NSButton!
    private var webKitToggleButton: NSButton!
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupWebView()
        setupToolbar()
        setupConstraints()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Nova Browser - Custom WebKit"
        window.center()
        window.setFrameAutosaveName("NovaBrowserWindow")
        window.contentView = NSView()
        window.contentView?.wantsLayer = true
    }
    
    private func setupWebView() {
        guard let contentView = window?.contentView else { return }
        
        if useCustomWebKit {
            // Use custom WebKit implementation
            customWebKitView = CustomWebKitView(frame: .zero)
            customWebKitView!.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(customWebKitView!)
            
            // Load initial page
            if let url = URL(string: "https://apple.com") {
                customWebKitView!.load(URLRequest(url: url))
            }
        } else {
            // Use standard WKWebView
            let configuration = WKWebViewConfiguration()
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.allowsAirPlayForMediaPlayback = true
            
            wkWebView = WKWebView(frame: .zero, configuration: configuration)
            wkWebView!.translatesAutoresizingMaskIntoConstraints = false
            wkWebView!.navigationDelegate = self
            wkWebView!.uiDelegate = self
            wkWebView!.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
            
            contentView.addSubview(wkWebView!)
            
            if let url = URL(string: "https://apple.com") {
                wkWebView!.load(URLRequest(url: url))
            }
        }
    }
    
    private func setupToolbar() {
        guard let contentView = window?.contentView else { return }
        
        // Create toolbar container
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.addSubview(toolbar)
        
        // Back button
        backButton = NSButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        backButton.bezelStyle = .regularSquare
        backButton.target = self
        backButton.action = #selector(goBack)
        toolbar.addSubview(backButton)
        
        // Forward button
        forwardButton = NSButton()
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.bezelStyle = .regularSquare
        forwardButton.target = self
        forwardButton.action = #selector(goForward)
        toolbar.addSubview(forwardButton)
        
        // Reload button
        reloadButton = NSButton()
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
        reloadButton.bezelStyle = .regularSquare
        reloadButton.target = self
        reloadButton.action = #selector(reload)
        toolbar.addSubview(reloadButton)
        
        // Address field
        addressField = NSTextField()
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.placeholderString = "Enter URL..."
        addressField.delegate = self
        toolbar.addSubview(addressField)
        
        // WebKit toggle button
        webKitToggleButton = NSButton()
        webKitToggleButton.translatesAutoresizingMaskIntoConstraints = false
        webKitToggleButton.title = useCustomWebKit ? "Custom" : "Apple"
        webKitToggleButton.bezelStyle = .regularSquare
        webKitToggleButton.target = self
        webKitToggleButton.action = #selector(toggleWebKitImplementation)
        toolbar.addSubview(webKitToggleButton)
        
        // Debug button
        debugButton = NSButton()
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        debugButton.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "Debug Tools")
        debugButton.bezelStyle = .regularSquare
        debugButton.target = self
        debugButton.action = #selector(openDebugTools)
        toolbar.addSubview(debugButton)
        
        // Set toolbar height constraint
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Setup button constraints
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),
            
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 32),
            forwardButton.heightAnchor.constraint(equalToConstant: 32),
            
            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 4),
            reloadButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 32),
            reloadButton.heightAnchor.constraint(equalToConstant: 32),
            
            addressField.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 8),
            addressField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            addressField.trailingAnchor.constraint(equalTo: webKitToggleButton.leadingAnchor, constant: -8),
            addressField.heightAnchor.constraint(equalToConstant: 28),
            
            webKitToggleButton.trailingAnchor.constraint(equalTo: debugButton.leadingAnchor, constant: -4),
            webKitToggleButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            webKitToggleButton.widthAnchor.constraint(equalToConstant: 60),
            webKitToggleButton.heightAnchor.constraint(equalToConstant: 28),
            
            debugButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            debugButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            debugButton.widthAnchor.constraint(equalToConstant: 32),
            debugButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupConstraints() {
        guard let contentView = window?.contentView,
              let toolbar = contentView.subviews.first(where: { $0.subviews.contains(addressField) }) else { return }
        
        let webView = useCustomWebKit ? customWebKitView! : wkWebView!
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc public func goBack() {
        if useCustomWebKit {
            customWebKitView?.goBack()
        } else {
            wkWebView?.goBack()
        }
    }
    
    @objc public func goForward() {
        if useCustomWebKit {
            customWebKitView?.goForward()
        } else {
            wkWebView?.goForward()
        }
    }
    
    @objc public func reload() {
        if useCustomWebKit {
            customWebKitView?.reload()
        } else {
            wkWebView?.reload()
        }
    }
    
    @objc public func toggleWebKitImplementation() {
        useCustomWebKit.toggle()
        webKitToggleButton.title = useCustomWebKit ? "Custom" : "Apple"
        
        // Remove current web view
        if let wkView = wkWebView {
            wkView.removeFromSuperview()
            wkWebView = nil
        }
        if let customView = customWebKitView {
            customView.removeFromSuperview()
            customWebKitView = nil
        }
        
        // Update window title
        window?.title = "Nova Browser - \(useCustomWebKit ? "Custom WebKit" : "Apple WebKit")"
        
        // Setup new web view
        setupWebView()
        setupConstraints()
        
        print("Switched to \(useCustomWebKit ? "Custom" : "Apple") WebKit implementation")
    }
    
    @objc public func openDebugTools() {
        if useCustomWebKit {
            customWebKitView?.showInspector()
        } else {
            // Show message about Apple WebKit limitations
            let alert = NSAlert()
            alert.messageText = "Inspector Not Available"
            alert.informativeText = "The Apple WebKit inspector causes ViewBridge conflicts in this environment. Switch to Custom WebKit for full debugging capabilities."
            alert.addButton(withTitle: "Switch to Custom WebKit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                toggleWebKitImplementation()
                // Try to open inspector again after switch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openDebugTools()
                }
            }
        }
    }
    
    @objc public func toggleInspector() {
        openDebugTools()
    }
    
    private func updateButtons() {
        if useCustomWebKit {
            backButton.isEnabled = customWebKitView?.canGoBack ?? false
            forwardButton.isEnabled = customWebKitView?.canGoForward ?? false
        } else {
            backButton.isEnabled = wkWebView?.canGoBack ?? false
            forwardButton.isEnabled = wkWebView?.canGoForward ?? false
        }
    }
    
    private func updateAddressField() {
        let urlString: String?
        if useCustomWebKit {
            urlString = customWebKitView?.url?.absoluteString
        } else {
            urlString = wkWebView?.url?.absoluteString
        }
        
        if let url = urlString {
            addressField.stringValue = url
        }
    }
}

// MARK: - WKNavigationDelegate (for Apple WebKit)

extension NativeBrowserWindow: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("WKWebView: Started loading")
        updateButtons()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WKWebView: Finished loading")
        updateButtons()
        updateAddressField()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WKWebView: Navigation failed")
        updateButtons()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WKWebView: Provisional navigation failed")
        updateButtons()
    }
}

// MARK: - WKUIDelegate (for Apple WebKit)

extension NativeBrowserWindow: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("WKWebView: Media capture permission requested")
        decisionHandler(.grant)
    }
}

// MARK: - NSTextFieldDelegate

extension NativeBrowserWindow: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == addressField else { return }
        
        var urlString = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        if let url = URL(string: urlString) {
            if useCustomWebKit {
                customWebKitView?.load(URLRequest(url: url))
            } else {
                wkWebView?.load(URLRequest(url: url))
            }
        }
    }
}
