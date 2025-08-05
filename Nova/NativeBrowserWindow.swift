//
//  NativeBrowserWindow.swift
//  Nova
//
//  Created by Kevin Perez on 7/8/25.
//

import Cocoa
import SwiftData
import SwiftUI

class NativeBrowserWindow: NSWindowController {
    
    // SwiftUI-based Arc-like interface
    private var hostingView: NSHostingView<AnyView>!
    private var customWebKitView: CustomWebKitView?
    
    // UI elements
    private var addressField: NSTextField!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!
    private var debugButton: NSButton!
    private var addBookmarkButton: NSButton!
    private var newTabButton: NSButton!
    
    // Data  
    private lazy var dataManager = DataManager.shared
    private var currentTab: Tab?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupSwiftUIInterface()
        loadInitialData()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Immediately remove toolbar capability
        window.toolbar = nil
        
        self.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = ""
        window.center()
        window.setFrameAutosaveName("NovaBrowserWindow")
        window.contentView = NSView()
        window.contentView?.wantsLayer = true
        
        // Make title bar transparent and hide title while keeping window draggable
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Hide standard window buttons - we have custom ones in sidebar
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Remove toolbar completely
        window.toolbar = nil
        
        window.hasShadow = true
    }
    
    private func setupSwiftUIInterface() {
        guard let windowContentView = window?.contentView else { return }
        
        // Create SwiftUI hosting view with proper edge-to-edge layout
        let navigationView = NovaNavigationView()
            .modelContainer(dataManager.modelContainer)
            .ignoresSafeArea(.all)  // Ignore all safe areas to extend into title bar
        
        hostingView = NSHostingView(rootView: AnyView(navigationView))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        windowContentView.addSubview(hostingView)
        
        // Fill the entire window content area - extend into title bar
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: windowContentView.topAnchor, constant: -28), // Negative offset to extend into title bar
            hostingView.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor)
        ])
        
        // Force remove toolbar after SwiftUI setup
        DispatchQueue.main.async { [weak self] in
            self?.window?.toolbar = nil
        }
    }
    
    private func loadInitialData() {
        // Initialize data for SwiftUI views
        Task { @MainActor in
            await dataManager.loadProfiles()
            await dataManager.loadSpaces()
        }
        
        // Add observers to ensure toolbar stays hidden
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidUpdate),
            name: NSWindow.didUpdateNotification,
            object: window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }
    
    // MARK: - Public Interface
    
    @objc public func toggleInspector() {
        customWebKitView?.showInspector()
    }
    
    @objc public func showInspectorConsole() {
        customWebKitView?.showInspectorConsole()
    }
    
    @objc public func showInspectorElements() {
        customWebKitView?.showInspectorElements()
    }
    
    @objc public func showInspectorSources() {
        customWebKitView?.showInspectorSources()
    }
    
    // MARK: - Toolbar Management
    
    private func ensureToolbarHidden() {
        guard let window = window else { return }
        
        // Simple and direct - just remove the toolbar
        window.toolbar = nil
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        ensureToolbarHidden()
    }
    
    @objc private func windowDidUpdate() {
        ensureToolbarHidden()
    }
    
    @objc private func windowDidBecomeKey() {
        ensureToolbarHidden()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
