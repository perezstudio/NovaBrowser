//
//  NovaApp.swift
//  Nova
//
//  Created by Kevin Perez on 7/8/25.
//

import Cocoa
import SwiftData
import SwiftUI

@main
class NovaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var browserWindows: [NativeBrowserWindow] = []
    private lazy var dataManager = DataManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Nova Browser starting...")
        
        // Set up custom WebKit framework loading
        setupCustomWebKitFramework()
        
        // Create and show the first browser window
        createNewBrowserWindow()
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupCustomWebKitFramework() {
        let appPath = Bundle.main.bundlePath
        let frameworksPath = "\(appPath)/Contents/Frameworks"
        let customWebKitPath = "\(frameworksPath)/WebKit.framework"
        
        if FileManager.default.fileExists(atPath: customWebKitPath) {
            print("Found custom WebKit framework at: \(customWebKitPath)")
            
            // Try to load the custom WebKit framework explicitly
            if let bundle = Bundle(path: customWebKitPath) {
                if bundle.load() {
                    print("Successfully loaded custom WebKit framework")
                } else {
                    print("Failed to load custom WebKit framework bundle")
                }
            } else {
                print("Could not create bundle for custom WebKit framework")
            }
        } else {
            print("Custom WebKit framework not found at: \(customWebKitPath)")
            print("Using system WebKit")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }
    
    @objc func createNewBrowserWindow() {
        print("Creating new browser window...")
        let browserWindow = NativeBrowserWindow()
        browserWindows.append(browserWindow)
        browserWindow.showWindow(nil)
        
        // Set up window delegate to remove from array when closed
        browserWindow.window?.delegate = self
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Remove closed windows from our array
        browserWindows.removeAll { browserWindow in
            browserWindow.window == notification.object as? NSWindow
        }
        
        print("Browser window closed. Remaining windows: \(browserWindows.count)")
    }
}

// MARK: - Menu Setup

extension AppDelegate {
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // Nova menu
        let novaMenu = NSMenuItem()
        mainMenu.addItem(novaMenu)
        let novaSubmenu = NSMenu(title: "Nova")
        novaMenu.submenu = novaSubmenu
        
        novaSubmenu.addItem(NSMenuItem(title: "About Nova", action: #selector(showAbout), keyEquivalent: ""))
        novaSubmenu.addItem(NSMenuItem.separator())
        novaSubmenu.addItem(NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ","))
        novaSubmenu.addItem(NSMenuItem.separator())
        novaSubmenu.addItem(NSMenuItem(title: "Hide Nova", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        novaSubmenu.addItem(hideOthersItem)
        
        novaSubmenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        novaSubmenu.addItem(NSMenuItem.separator())
        novaSubmenu.addItem(NSMenuItem(title: "Quit Nova", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // File menu
        let fileMenu = NSMenuItem()
        mainMenu.addItem(fileMenu)
        let fileSubmenu = NSMenu(title: "File")
        fileMenu.submenu = fileSubmenu
        
        fileSubmenu.addItem(NSMenuItem(title: "New Window", action: #selector(createNewBrowserWindow), keyEquivalent: "n"))
        fileSubmenu.addItem(NSMenuItem(title: "New Tab", action: #selector(createNewBrowserWindow), keyEquivalent: "t"))
        fileSubmenu.addItem(NSMenuItem.separator())
        fileSubmenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        
        // View menu
        let viewMenu = NSMenuItem()
        mainMenu.addItem(viewMenu)
        let viewSubmenu = NSMenu(title: "View")
        viewMenu.submenu = viewSubmenu
        
        viewSubmenu.addItem(NSMenuItem(title: "Reload Page", action: #selector(reloadCurrentPage), keyEquivalent: "r"))
        viewSubmenu.addItem(NSMenuItem.separator())
        viewSubmenu.addItem(NSMenuItem(title: "Actual Size", action: nil, keyEquivalent: "0"))
        viewSubmenu.addItem(NSMenuItem(title: "Zoom In", action: nil, keyEquivalent: "+"))
        viewSubmenu.addItem(NSMenuItem(title: "Zoom Out", action: nil, keyEquivalent: "-"))
        
        // Developer menu
        let developerMenu = NSMenuItem()
        mainMenu.addItem(developerMenu)
        let developerSubmenu = NSMenu(title: "Developer")
        developerMenu.submenu = developerSubmenu
        
        let inspectorItem = NSMenuItem(title: "Web Inspector", action: #selector(showWebInspector), keyEquivalent: "i")
        inspectorItem.keyEquivalentModifierMask = [.command, .option]
        developerSubmenu.addItem(inspectorItem)
        
        let consoleItem = NSMenuItem(title: "JavaScript Console", action: #selector(showJavaScriptConsole), keyEquivalent: "j")
        consoleItem.keyEquivalentModifierMask = [.command, .option]
        developerSubmenu.addItem(consoleItem)
        
        // Window menu
        let windowMenu = NSMenuItem()
        mainMenu.addItem(windowMenu)
        let windowSubmenu = NSMenu(title: "Window")
        windowMenu.submenu = windowSubmenu
        
        windowSubmenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowSubmenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowSubmenu.addItem(NSMenuItem.separator())
        windowSubmenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Nova Browser"
        alert.informativeText = "A native WebKit-based browser for macOS with full developer tools support.\n\nBuilt with pure AppKit and WebKit for maximum compatibility and performance.\n\nVersion 1.0"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func reloadCurrentPage() {
        // Reload is now handled within SwiftUI NavigationSplitView
        print("Reload current page - handled by SwiftUI interface")
    }
    
    @objc func showWebInspector() {
        // Get the current web view from WebViewManager
        Task { @MainActor in
            if let currentWebView = WebViewManager.shared.getCurrentWebView() {
                currentWebView.showInspector()
            }
        }
    }
    
    @objc func showJavaScriptConsole() {
        // Get the current web view from WebViewManager
        Task { @MainActor in
            if let currentWebView = WebViewManager.shared.getCurrentWebView() {
                currentWebView.showInspectorConsole()
            }
        }
    }
}
