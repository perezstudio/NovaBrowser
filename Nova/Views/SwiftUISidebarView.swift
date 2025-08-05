//
//  SwiftUISidebarView.swift
//  Nova
//
//  SwiftUI-based sidebar using NavigationSplitView for Arc-like interface
//

import SwiftUI
import SwiftData
import WebKit

// MARK: - WebView Container Delegate Protocol
protocol WebViewContainerDelegate: AnyObject {
    func webViewContainer(_ container: WebViewContainer, didUpdateTitle title: String?, for itemID: String)
    func webViewContainer(_ container: WebViewContainer, didUpdateFavicon faviconData: Data?, for itemID: String)
    func webViewContainer(_ container: WebViewContainer, didUpdateURL url: URL?, for itemID: String)
}

// MARK: - WebView Container for Managing Multiple WebViews
@MainActor
class WebViewContainer: NSView {
    private var webViews: [String: CustomWebKitView] = [:]
    private var webViewToItemMapping: [String: SidebarItem] = [:]
    private var currentWebViewID: String?
    
    // Delegate to notify about title/favicon updates
    weak var delegate: WebViewContainerDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupContainer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContainer()
    }
    
    private func setupContainer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    func getOrCreateWebView(for id: String, url: URL?, profile: Profile?, sidebarItem: SidebarItem? = nil) -> CustomWebKitView {
        if let existingWebView = webViews[id] {
            return existingWebView
        }
        
        // Create new webview for this ID
        let webView = CustomWebKitView(frame: bounds, profile: profile)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViews[id] = webView
        
        // Store the mapping between webview and sidebar item for updates
        if let sidebarItem = sidebarItem {
            webViewToItemMapping[id] = sidebarItem
        }
        
        // Add to container but keep hidden initially
        addSubview(webView)
        
        // Set constraints to fill container
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        webView.isHidden = true // Start hidden
        
        // Set up a custom delegate wrapper to intercept title/favicon updates
        let delegateInterceptor = WebKitViewDelegateInterceptor(container: self, itemID: id)
        objc_setAssociatedObject(webView, "delegateInterceptor", delegateInterceptor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Replace the existing delegate with our interceptor that forwards calls
        if let customWebView = webView.webView {
            // Store the original delegate
            delegateInterceptor.originalDelegate = customWebView.navigationDelegate
            // Set our interceptor as the delegate
            customWebView.navigationDelegate = delegateInterceptor
            print("WebViewContainer: Set up delegate interceptor for \(id)")
        } else {
            print("WebViewContainer: Could not access CustomWebView for delegate setup")
        }
        
        // Load initial URL only on creation
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        
        print("WebViewContainer: Created new webview for ID: \(id)")
        return webView
    }
    
    func showWebView(for id: String) {
        // Hide all webviews first
        for webView in webViews.values {
            webView.isHidden = true
        }
        
        // Show the requested webview
        if let webView = webViews[id] {
            webView.isHidden = false
            currentWebViewID = id
            print("WebViewContainer: Showing webview for ID: \(id)")
        }
    }
    
    func getCurrentWebView() -> CustomWebKitView? {
        guard let currentID = currentWebViewID else { return nil }
        return webViews[currentID]
    }
    
    func getWebView(for id: String) -> CustomWebKitView? {
        return webViews[id]
    }
    
    func removeWebView(for id: String) {
        if let webView = webViews[id] {
            webView.removeFromSuperview()
            webViews.removeValue(forKey: id)
            webViewToItemMapping.removeValue(forKey: id)
            
            if currentWebViewID == id {
                currentWebViewID = nil
            }
            
            print("WebViewContainer: Removed webview for ID: \(id)")
        }
    }
    
    func updateTitleAndFavicon(for itemID: String) {
        guard let webView = webViews[itemID] else { return }
        
        // Get the current title from the webview
        if webView.subviews.first(where: { $0 is CustomWebView }) != nil {
            // For now, we'll implement a simple polling mechanism
            // In a real implementation, you'd want proper delegation
            print("WebViewContainer: updateTitleAndFavicon called for \(itemID)")
        }
    }
    
    override func layout() {
        super.layout()
        // Ensure all webviews match the container size
        for webView in webViews.values {
            webView.frame = bounds
        }
    }
}

// MARK: - WebKit View Delegate Interceptor
@MainActor
class WebKitViewDelegateInterceptor: NSObject, @preconcurrency CustomWebViewDelegate {
    weak var container: WebViewContainer?
    let itemID: String
    weak var originalDelegate: CustomWebViewDelegate?
    
    init(container: WebViewContainer, itemID: String) {
        self.container = container
        self.itemID = itemID
        super.init()
    }
    
    // Forward all delegate calls to the original delegate first, then handle our custom logic
    
    nonisolated func customWebView(_ webView: CustomWebView, didStartProvisionalNavigation navigation: Any?) {
        Task { @MainActor in
            originalDelegate?.customWebView(webView, didStartProvisionalNavigation: navigation)
        }
    }
    
    nonisolated func customWebView(_ webView: CustomWebView, didFinish navigation: Any?) {
        Task { @MainActor in
            originalDelegate?.customWebView(webView, didFinish: navigation)
        }
    }
    
    nonisolated func customWebView(_ webView: CustomWebView, didFail navigation: Any?, withError error: Error) {
        Task { @MainActor in
            originalDelegate?.customWebView(webView, didFail: navigation, withError: error)
        }
    }
    
    nonisolated func customWebView(_ webView: CustomWebView, didUpdateTitle title: String?) {
        Task { @MainActor in
            // Forward to original delegate first
            originalDelegate?.customWebView(webView, didUpdateTitle: title)
            
            // Then notify our container
            container?.delegate?.webViewContainer(container!, didUpdateTitle: title, for: itemID)
        }
    }
    
    nonisolated func customWebView(_ webView: CustomWebView, didUpdateFavicon faviconData: Data?) {
        Task { @MainActor in
            // Forward to original delegate first
            originalDelegate?.customWebView(webView, didUpdateFavicon: faviconData)
            
            // Then notify our container
            container?.delegate?.webViewContainer(container!, didUpdateFavicon: faviconData, for: itemID)
        }
    }
    
    nonisolated func customWebView(_ webView: CustomWebView, didUpdateURL url: URL?) {
        Task { @MainActor in
            // Forward to original delegate first
            originalDelegate?.customWebView(webView, didUpdateURL: url)
            
            // Then notify our container
            container?.delegate?.webViewContainer(container!, didUpdateURL: url, for: itemID)
        }
    }
}

// MARK: - WebView Manager Singleton
@MainActor
class WebViewManager {
    static let shared = WebViewManager()
    private var container: WebViewContainer?
    
    private init() {}
    
    func setContainer(_ container: WebViewContainer) {
        self.container = container
    }
    
    func getOrCreateWebView(for id: String, url: URL?, profile: Profile?, sidebarItem: SidebarItem? = nil) -> CustomWebKitView? {
        return container?.getOrCreateWebView(for: id, url: url, profile: profile, sidebarItem: sidebarItem)
    }
    
    func showWebView(for id: String) {
        container?.showWebView(for: id)
    }
    
    func getCurrentWebView() -> CustomWebKitView? {
        return container?.getCurrentWebView()
    }
    
    func getWebView(for id: String) -> CustomWebKitView? {
        return container?.getWebView(for: id)
    }
    
    func removeWebView(for id: String) {
        container?.removeWebView(for: id)
    }
}

struct NovaNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared
    
    @State private var selectedSpace: Space?
    @State private var selectedItem: SidebarItem?
    @State private var showingProfileSheet = false
    @State private var showingSpaceSheet = false
    @State private var editingSpace: Space?
    @State private var sidebarVisible = true
    @State private var currentURL = ""
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background material sidebar
            if sidebarVisible {
                SidebarContentView(
                    selectedSpace: $selectedSpace,
                    selectedItem: $selectedItem,
                    showingProfileSheet: $showingProfileSheet,
                    showingSpaceSheet: $showingSpaceSheet,
                    editingSpace: $editingSpace,
                    sidebarVisible: $sidebarVisible,
                    currentURL: $currentURL
                )
                .frame(width: 280)
                .background(
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                )
                .transition(.move(edge: .leading))
            }
            
            // Main web content area
            HStack(spacing: 0) {
                if sidebarVisible {
                    Color.clear
                        .frame(width: 280)
                }
                
                // Floating web view with custom URL bar
                FloatingWebContentView(
                    selectedItem: selectedItem,
                    sidebarVisible: $sidebarVisible,
                    currentURL: $currentURL
                )
            }
        }
        .toolbar(.hidden)  // Hide the toolbar completely
        .animation(.easeInOut(duration: 0.3), value: sidebarVisible)
        .sheet(isPresented: $showingSpaceSheet) {
            SpaceCreationView(editingSpace: editingSpace)
        }
        .onChange(of: showingSpaceSheet) { isShowing in
            if !isShowing {
                editingSpace = nil
            }
        }
    }
}

struct SidebarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared
    
    @Query private var profiles: [Profile]
    @Query private var spaces: [Space]
    
    @Binding var selectedSpace: Space?
    @Binding var selectedItem: SidebarItem?
    @Binding var showingProfileSheet: Bool
    @Binding var showingSpaceSheet: Bool
    @Binding var editingSpace: Space?
    @Binding var sidebarVisible: Bool
    @Binding var currentURL: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Traffic lights header - same height as URL bar
            HStack(spacing: 0) {
                // Custom traffic light buttons
                HStack(spacing: 8) {
                    // Close button
                    Button(action: { 
                        if let window = NSApp.keyWindow {
                            window.performClose(nil)
                        }
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.black.opacity(0.6))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Minimize button
                    Button(action: {
                        if let window = NSApp.keyWindow {
                            window.performMiniaturize(nil)
                        }
                    }) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 6, height: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Zoom button
                    Button(action: {
                        if let window = NSApp.keyWindow {
                            window.performZoom(nil)
                        }
                    }) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.black.opacity(0.6))
                                    .rotationEffect(.degrees(45))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Hide sidebar button
                Button(action: { sidebarVisible.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor))
                    .opacity(0.5),
                alignment: .bottom
            )
            
            // Main content area with custom scroll view
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Pinned Tabs Section
                    if let currentProfile = dataManager.currentProfile {
                        let pinnedTabs = getPinnedTabs(for: currentProfile)
                        if !pinnedTabs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pinned")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                
                                ForEach(pinnedTabs) { pinnedTab in
                                    PinnedTabRow(
                                        pinnedTab: pinnedTab,
                                        isSelected: selectedItem == .pinnedTab(pinnedTab),
                                        onTap: { selectedItem = .pinnedTab(pinnedTab) },
                                        onClose: { selectedItem = nil }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Bookmarks Section (for current space)
                    if let currentSpace = selectedSpace ?? spaces.first {
                        let bookmarks = dataManager.loadBookmarks(for: currentSpace)
                        if !bookmarks.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bookmarks")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                
                                ForEach(bookmarks, id: \.id) { bookmark in
                                    BookmarkRow(
                                        bookmark: bookmark,
                                        isSelected: selectedItem == .bookmark(bookmark),
                                        onTap: { handleBookmarkTap(bookmark) }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Current Space Tabs Section
                    if let currentSpace = selectedSpace ?? spaces.first {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(currentSpace.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                // Show profile indicator if space has a profile
                                if let profile = currentSpace.profile {
                                    Circle()
                                        .fill(profile.displayColor.swiftUIColor)
                                        .frame(width: 8, height: 8)
                                        .help("Profile: \(profile.name)")
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Tabs section - show all regular tabs
                            let allTabs = dataManager.loadTabs(for: currentSpace)
                            ForEach(allTabs, id: \.id) { tab in
                                TabRow(
                                    tab: tab, 
                                    isSelected: selectedItem == .tab(tab),
                                    onTap: { selectedItem = .tab(tab) },
                                    onClose: { selectedItem = nil },
                                    onBookmark: { bookmarkTab(tab) }
                                )
                            }
                            
                            // Add Tab Button
                            Button(action: { createNewTab(in: currentSpace) }) {
                                Label("New Tab", systemImage: "plus")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            
            // Bottom spaces bar
            SpacesBottomBar(
                spaces: spaces.sorted { $0.sortOrder < $1.sortOrder },
                selectedSpace: $selectedSpace,
                showingSpaceSheet: $showingSpaceSheet,
                editingSpace: $editingSpace
            )
        }
    }
    
    private func getPinnedTabs(for profile: Profile) -> [PinnedTab] {
        return dataManager.loadPinnedTabs(for: profile)
    }
    
    private func createNewTab(in space: Space) {
        Task { @MainActor in
            let tab = await dataManager.addTab(title: "New Tab", url: "about:blank", to: space)
            selectedItem = .tab(tab)
        }
    }
    
    private func handleBookmarkTap(_ bookmark: Bookmark) {
        // Simply select the bookmark - the webview will be rendered for this bookmark
        selectedItem = .bookmark(bookmark)
    }
    
    private func bookmarkTab(_ tab: Tab) {
        guard let space = tab.space else { return }
        
        Task { @MainActor in
            // Use the current URL from the webview, not the original tab URL
            let urlToBookmark = currentURL.isEmpty ? tab.url : currentURL
            
            // Get current page title - for now use descriptive title from URL
            let titleToBookmark: String
            // Create a descriptive title from the URL
            if let url = URL(string: urlToBookmark) {
                titleToBookmark = url.host ?? url.absoluteString
            } else {
                titleToBookmark = tab.title
            }
            
            // Create bookmark from tab with current URL and title
            await dataManager.addBookmark(title: titleToBookmark, url: urlToBookmark, to: space)
            
            // If this tab is currently selected, switch selection to the new bookmark
            if selectedItem == .tab(tab) {
                // Find the newly created bookmark
                let bookmarks = dataManager.loadBookmarks(for: space)
                if let newBookmark = bookmarks.first(where: { $0.url == urlToBookmark }) {
                    selectedItem = .bookmark(newBookmark)
                } else {
                    selectedItem = nil
                }
            }
            
            // Remove the tab since it's now a bookmark
            // Clean up the webview for this tab
            WebViewManager.shared.removeWebView(for: "tab-\(tab.id)")
            await dataManager.closeTab(tab)
        }
    }
    
    private func showAddBookmarkDialog(for space: Space) {
        // TODO: Implement bookmark dialog
    }
}


struct SpacesBottomBar: View {
    let spaces: [Space]
    @Binding var selectedSpace: Space?
    @Binding var showingSpaceSheet: Bool
    @Binding var editingSpace: Space?
    
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            
            // Center the buttons and only scroll if needed
            HStack {
                if needsScrolling {
                    ScrollView(.horizontal, showsIndicators: false) {
                        buttonRow
                    }
                } else {
                    Spacer()
                    buttonRow
                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
        }
    }
    
    private var needsScrolling: Bool {
        // Calculate if we need scrolling based on number of items and available width
        let buttonWidth: CGFloat = 36
        let spacing: CGFloat = 8
        let addButtonWidth: CGFloat = 36
        let padding: CGFloat = 24 // 12 on each side
        let sidebarWidth: CGFloat = 280
        
        let totalWidth = CGFloat(spaces.count) * buttonWidth + 
                        CGFloat(spaces.count - 1) * spacing + 
                        addButtonWidth + spacing + padding
        
        return totalWidth > sidebarWidth
    }
    
    private var buttonRow: some View {
        HStack(spacing: 8) {
            ForEach(spaces) { space in
                SpaceButton(
                    space: space,
                    isSelected: selectedSpace?.id == space.id,
                    onTap: { selectedSpace = space },
                    editingSpace: $editingSpace,
                    showingSpaceSheet: $showingSpaceSheet
                )
            }
            
            // Add Space Button
            Button(action: { showingSpaceSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct SpaceButton: View {
    let space: Space
    let isSelected: Bool
    let onTap: () -> Void
    @Binding var editingSpace: Space?
    @Binding var showingSpaceSheet: Bool
    
    @State private var showingContextMenu = false
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: space.iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : space.displayColor.swiftUIColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? space.displayColor.swiftUIColor : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(space.displayColor.swiftUIColor.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(space.name) // Show name as tooltip on hover
        .contextMenu {
            Button("Edit Space") {
                editSpace(space)
            }
            Button("Delete Space", role: .destructive) {
                deleteSpace(space)
            }
        }
    }
    
    private func editSpace(_ space: Space) {
        editingSpace = space
        showingSpaceSheet = true
    }
    
    private func deleteSpace(_ space: Space) {
        Task { @MainActor in
            await dataManager.deleteSpace(space)
        }
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovering = false
    @StateObject private var dataManager = DataManager.shared
    
    // Check if bookmark is currently open as a tab
    private var isOpenAsTab: Bool {
        guard let space = bookmark.space else { return false }
        let tabs = dataManager.loadTabs(for: space)
        return tabs.contains { $0.url == bookmark.url }
    }
    
    // Find the matching tab if it exists
    private var matchingTab: Tab? {
        guard let space = bookmark.space else { return nil }
        let tabs = dataManager.loadTabs(for: space)
        return tabs.first { $0.url == bookmark.url }
    }
    
    var body: some View {
        HStack {
            if let faviconData = bookmark.faviconData,
               let nsImage = NSImage(data: faviconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            Text(bookmark.title)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            if isHovering {
                if isOpenAsTab {
                    // Show minimize icon to close the tab but keep bookmark
                    Button(action: {
                        Task { @MainActor in
                            if let tab = matchingTab {
                                await DataManager.shared.closeTab(tab)
                            }
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 16, height: 16)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close Tab (Keep Bookmark)")
                } else {
                    // Show delete icon to remove bookmark
                    Button(action: {
                        Task { @MainActor in
                            await DataManager.shared.deleteBookmark(bookmark)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .background(Color.black.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Remove Bookmark")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.2) : 
                    (isHovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Open in New Tab") { 
                // TODO: Open bookmark in new tab
            }
            Divider()
            Button("Delete", role: .destructive) { 
                Task { @MainActor in
                    await DataManager.shared.deleteBookmark(bookmark)
                }
            }
        }
    }
}

struct TabRow: View {
    let tab: Tab
    let isSelected: Bool
    let onTap: () -> Void
    var onClose: (() -> Void)? = nil
    var onBookmark: (() -> Void)? = nil
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            if let faviconData = tab.faviconData,
               let nsImage = NSImage(data: faviconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            Text(tab.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(tab.isActive ? Color.accentColor : Color.primary)
            
            Spacer()
            
            if isHovering {
                Button(action: {
                    Task { @MainActor in
                        // Clear selection if this is the selected tab
                        if isSelected {
                            onClose?()
                        }
                        await DataManager.shared.closeTab(tab)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Color.black.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close Tab")
            } else if tab.isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.2) : 
                    (isHovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Close Tab") { 
                Task { @MainActor in
                    // Clear selection if this is the selected tab
                    if isSelected {
                        onClose?()
                    }
                    await DataManager.shared.closeTab(tab)
                }
            }
            Button("Pin Tab") { 
                Task { @MainActor in
                    await DataManager.shared.addPinnedTab(title: tab.title, url: tab.url)
                    // Clear selection if this is the selected tab
                    if isSelected {
                        onClose?()
                    }
                    await DataManager.shared.closeTab(tab)
                }
            }
            Button("Bookmark Tab") { 
                onBookmark?()
            }
        }
    }
}

struct PinnedTabRow: View {
    let pinnedTab: PinnedTab
    let isSelected: Bool
    let onTap: () -> Void
    var onClose: (() -> Void)? = nil
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            if let faviconData = pinnedTab.faviconData,
               let nsImage = NSImage(data: faviconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "pin")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            Text(pinnedTab.title)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            if isHovering {
                Button(action: {
                    Task { @MainActor in
                        // Clear selection if this is the selected tab
                        if isSelected {
                            onClose?()
                        }
                        await DataManager.shared.removePinnedTab(pinnedTab)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Color.black.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Unpin Tab")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.2) : 
                    (isHovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Unpin Tab") { 
                Task { @MainActor in
                    // Clear selection if this is the selected tab
                    if isSelected {
                        onClose?()
                    }
                    await DataManager.shared.removePinnedTab(pinnedTab)
                }
            }
        }
    }
}

struct FloatingWebContentView: View {
    let selectedItem: SidebarItem?
    @Binding var sidebarVisible: Bool
    @Binding var currentURL: String
    @State private var editingURL = ""
    @State private var isEditingURL = false
    @State private var webView: CustomWebKitView?
    @State private var canGoBack = false
    @State private var canGoForward = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom URL bar
            HStack(spacing: 12) {
                // Sidebar toggle button - only show when sidebar is closed
                if !sidebarVisible {
                    Button(action: { sidebarVisible.toggle() }) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Navigation buttons
                HStack(spacing: 8) {
                    Button(action: { webView?.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .disabled(!canGoBack)
                    
                    Button(action: { webView?.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .disabled(!canGoForward)
                    
                    Button(action: { webView?.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(.secondary)
                .buttonStyle(PlainButtonStyle())
                
                // URL field
                HStack {
                    Image(systemName: currentURL.hasPrefix("https") ? "lock.fill" : "lock.open")
                        .font(.system(size: 12))
                        .foregroundColor(currentURL.hasPrefix("https") ? .green : .orange)
                    
                    if isEditingURL {
                        SelectAllTextField(
                            placeholder: "Enter URL", 
                            text: $editingURL,
                            onSubmit: {
                                navigateToURL(editingURL)
                                isEditingURL = false
                            },
                            onEscape: {
                                editingURL = currentURL
                                isEditingURL = false
                            }
                        )
                        
                        // Go button when editing
                        Button(action: {
                            navigateToURL(editingURL)
                            isEditingURL = false
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text(currentURL.isEmpty ? "Enter URL or search" : currentURL)
                            .foregroundColor(currentURL.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingURL = currentURL
                                isEditingURL = true
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Action buttons (removed plus button)
                Menu {
                    Button("Add Bookmark") { /* TODO */ }
                    Button("Developer Tools") { 
                        webView?.showInspector()
                    }
                    Divider()
                    Button("Settings") { /* TODO */ }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.secondary)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor))
                    .opacity(0.5),
                alignment: .bottom
            )
            
            // Web content - single container manages all webviews
            WebViewContainerRepresentable(
                selectedItem: selectedItem,
                webView: $webView,
                currentURL: $currentURL,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward
            )
            .overlay {
                // Show empty state when no item is selected
                if selectedItem == nil {
                    // Empty state with material background
                    ZStack {
                        // Material background
                        VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                            .opacity(0.8)
                        
                        VStack(spacing: 16) {
                            Spacer()
                            
                            // Icon with subtle animation
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 72, weight: .thin))
                                .foregroundColor(.secondary.opacity(0.3))
                                .symbolEffect(.pulse, options: .repeating.speed(0.5))
                            
                            VStack(spacing: 8) {
                                Text("No Tab Selected")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary.opacity(0.9))
                                
                                Text("Select a tab from the sidebar or create a new one")
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12, corners: [.topLeft, .bottomLeft])
        .shadow(color: .black.opacity(0.1), radius: 10, x: -2, y: 0)
    }
    
    private func navigateToURL(_ urlString: String) {
        var finalURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no protocol is specified
        if !finalURL.contains("://") {
            // Check if it looks like a search query
            if !finalURL.contains(".") || finalURL.contains(" ") {
                // Use search engine
                finalURL = "https://www.google.com/search?q=\(finalURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            } else {
                finalURL = "https://\(finalURL)"
            }
        }
        
        if let url = URL(string: finalURL) {
            webView?.load(URLRequest(url: url))
            currentURL = finalURL
        }
    }
}

struct WebViewContainerRepresentable: NSViewRepresentable {
    let selectedItem: SidebarItem?
    @Binding var webView: CustomWebKitView?
    @Binding var currentURL: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    private let webViewManager = WebViewManager.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WebViewContainer {
        let container = WebViewContainer(frame: .zero)
        container.delegate = context.coordinator
        webViewManager.setContainer(container)
        
        // If we have a selected item, create and show its webview
        if let item = selectedItem {
            print("WebViewContainer: makeNSView for item \(item.itemID) with URL: \(item.url?.absoluteString ?? "nil")")
            let webView = container.getOrCreateWebView(
                for: item.itemID,
                url: item.url,
                profile: item.profile,
                sidebarItem: item
            )
            container.showWebView(for: item.itemID)
            
            // Update binding
            DispatchQueue.main.async {
                self.webView = webView
            }
            
            // Start polling
            context.coordinator.startPolling(webView)
        }
        
        return container
    }
    
    func updateNSView(_ container: WebViewContainer, context: Context) {
        guard let item = selectedItem else {
            // No item selected, stop polling
            context.coordinator.stopPolling()
            
            DispatchQueue.main.async {
                self.webView = nil
            }
            return
        }
        
        // Get or create webview for this item
        print("WebViewContainer: Creating webview for item \(item.itemID) with URL: \(item.url?.absoluteString ?? "nil")")
        let webView = container.getOrCreateWebView(
            for: item.itemID,
            url: item.url,
            profile: item.profile,
            sidebarItem: item
        )
        
        // Show this webview
        container.showWebView(for: item.itemID)
        
        // Update binding
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // Start polling for the current webview
        context.coordinator.startPolling(webView)
    }
    
    class Coordinator: NSObject, WebViewContainerDelegate {
        var parent: WebViewContainerRepresentable
        var timer: Timer?
        weak var webView: CustomWebKitView?
        
        init(_ parent: WebViewContainerRepresentable) {
            self.parent = parent
        }
        
        func startPolling(_ webView: CustomWebKitView) {
            // Stop any existing timer
            timer?.invalidate()
            
            self.webView = webView
            
            // Poll every 0.5 seconds to update navigation state
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let webView = self.webView else { return }
                
                DispatchQueue.main.async {
                    // Update navigation state
                    self.parent.canGoBack = webView.canGoBack
                    self.parent.canGoForward = webView.canGoForward
                    
                    // Update URL if it changed (but don't trigger new loads)
                    if let currentURL = webView.url?.absoluteString {
                        self.parent.currentURL = currentURL
                    }
                }
            }
        }
        
        func stopPolling() {
            timer?.invalidate()
            timer = nil
            webView = nil
        }
        
        // MARK: - WebViewContainerDelegate
        
        func webViewContainer(_ container: WebViewContainer, didUpdateTitle title: String?, for itemID: String) {
            print("WebViewContainer: Title updated for \(itemID): \(title ?? "nil")")
            
            // Update the appropriate data model based on itemID
            Task { @MainActor in
                await self.updateTitleForItem(itemID: itemID, title: title)
            }
        }
        
        func webViewContainer(_ container: WebViewContainer, didUpdateFavicon faviconData: Data?, for itemID: String) {
            print("WebViewContainer: Favicon updated for \(itemID): \(faviconData?.count ?? 0) bytes")
            
            // Update the appropriate data model based on itemID
            Task { @MainActor in
                await self.updateFaviconForItem(itemID: itemID, faviconData: faviconData)
            }
        }
        
        func webViewContainer(_ container: WebViewContainer, didUpdateURL url: URL?, for itemID: String) {
            print("WebViewContainer: URL updated for \(itemID): \(url?.absoluteString ?? "nil")")
            
            // Update the appropriate data model based on itemID
            Task { @MainActor in
                await self.updateURLForItem(itemID: itemID, url: url)
            }
        }
        
        private func updateTitleForItem(itemID: String, title: String?) async {
            guard let title = title, !title.isEmpty else { return }
            
            print("WebViewContainer: Updating title for \(itemID) to: \(title)")
            
            let dataManager = DataManager.shared
            
            if itemID.hasPrefix("bookmark-") {
                let bookmarkIdString = String(itemID.dropFirst(9))
                if let bookmarkId = UUID(uuidString: bookmarkIdString) {
                    // Find the bookmark and update its title
                    await updateBookmarkTitle(bookmarkId: bookmarkId, title: title)
                }
            } else if itemID.hasPrefix("tab-") {
                let tabIdString = String(itemID.dropFirst(4))
                if let tabId = UUID(uuidString: tabIdString) {
                    // Find the tab and update its title
                    await updateTabTitle(tabId: tabId, title: title)
                }
            } else if itemID.hasPrefix("pinnedTab-") {
                let pinnedTabIdString = String(itemID.dropFirst(10))
                if let pinnedTabId = UUID(uuidString: pinnedTabIdString) {
                    // Find the pinned tab and update its title
                    await updatePinnedTabTitle(pinnedTabId: pinnedTabId, title: title)
                }
            }
        }
        
        private func updateFaviconForItem(itemID: String, faviconData: Data?) async {
            guard let faviconData = faviconData else { return }
            
            print("WebViewContainer: Updating favicon for \(itemID) (\(faviconData.count) bytes)")
            
            if itemID.hasPrefix("bookmark-") {
                let bookmarkIdString = String(itemID.dropFirst(9))
                if let bookmarkId = UUID(uuidString: bookmarkIdString) {
                    await updateBookmarkFavicon(bookmarkId: bookmarkId, faviconData: faviconData)
                }
            } else if itemID.hasPrefix("tab-") {
                let tabIdString = String(itemID.dropFirst(4))
                if let tabId = UUID(uuidString: tabIdString) {
                    await updateTabFavicon(tabId: tabId, faviconData: faviconData)
                }
            } else if itemID.hasPrefix("pinnedTab-") {
                let pinnedTabIdString = String(itemID.dropFirst(10))
                if let pinnedTabId = UUID(uuidString: pinnedTabIdString) {
                    await updatePinnedTabFavicon(pinnedTabId: pinnedTabId, faviconData: faviconData)
                }
            }
        }
        
        // Helper methods to update specific data model types
        private func updateBookmarkTitle(bookmarkId: UUID, title: String) async {
            let dataManager = await DataManager.shared
            
            // Load all bookmarks and find the one with matching ID
            for space in await dataManager.spaces {
                let bookmarks = await dataManager.loadBookmarks(for: space)
                if let bookmark = bookmarks.first(where: { $0.id == bookmarkId }) {
                    bookmark.title = title
                    await dataManager.save()
                    print("Updated bookmark title: \(title)")
                    return
                }
            }
        }
        
        private func updateTabTitle(tabId: UUID, title: String) async {
            let dataManager = await DataManager.shared
            
            // Load all tabs and find the one with matching ID
            for space in await dataManager.spaces {
                let tabs = await dataManager.loadTabs(for: space)
                if let tab = tabs.first(where: { $0.id == tabId }) {
                    tab.title = title
                    await dataManager.save()
                    print("Updated tab title: \(title)")
                    return
                }
            }
        }
        
        private func updateTabURL(tabId: UUID, url: String) async {
            let dataManager = await DataManager.shared
            
            // Load all tabs and find the one with matching ID
            for space in await dataManager.spaces {
                let tabs = await dataManager.loadTabs(for: space)
                if let tab = tabs.first(where: { $0.id == tabId }) {
                    tab.url = url
                    await dataManager.save()
                    print("Updated tab URL: \(url)")
                    return
                }
            }
        }
        
        private func updateURLForItem(itemID: String, url: URL?) async {
            guard let url = url, url.absoluteString != "about:blank" else { 
                // Don't update URLs to about:blank unless it's a new tab
                print("WebViewContainer: Skipping URL update to about:blank for \(itemID)")
                return 
            }
            
            print("WebViewContainer: Updating URL for \(itemID) to: \(url.absoluteString)")
            
            if itemID.hasPrefix("tab-") {
                let tabIdString = String(itemID.dropFirst(4))
                if let tabId = UUID(uuidString: tabIdString) {
                    await updateTabURL(tabId: tabId, url: url.absoluteString)
                }
            } else if itemID.hasPrefix("pinnedTab-") {
                let pinnedTabIdString = String(itemID.dropFirst(10))
                if let pinnedTabId = UUID(uuidString: pinnedTabIdString) {
                    await updatePinnedTabURL(pinnedTabId: pinnedTabId, url: url.absoluteString)
                }
            }
            // Note: We don't update bookmark URLs here as they should remain static
        }
        
        private func updatePinnedTabTitle(pinnedTabId: UUID, title: String) async {
            let dataManager = await DataManager.shared
            
            // Load all pinned tabs and find the one with matching ID
            for profile in await dataManager.profiles {
                let pinnedTabs = await dataManager.loadPinnedTabs(for: profile)
                if let pinnedTab = pinnedTabs.first(where: { $0.id == pinnedTabId }) {
                    pinnedTab.title = title
                    await dataManager.save()
                    print("Updated pinned tab title: \(title)")
                    return
                }
            }
        }
        
        private func updatePinnedTabURL(pinnedTabId: UUID, url: String) async {
            let dataManager = await DataManager.shared
            
            // Load all pinned tabs and find the one with matching ID
            for profile in await dataManager.profiles {
                let pinnedTabs = await dataManager.loadPinnedTabs(for: profile)
                if let pinnedTab = pinnedTabs.first(where: { $0.id == pinnedTabId }) {
                    pinnedTab.url = url
                    await dataManager.save()
                    print("Updated pinned tab URL: \(url)")
                    return
                }
            }
        }
        
        private func updateBookmarkFavicon(bookmarkId: UUID, faviconData: Data) async {
            let dataManager = await DataManager.shared
            
            for space in await dataManager.spaces {
                let bookmarks = await dataManager.loadBookmarks(for: space)
                if let bookmark = bookmarks.first(where: { $0.id == bookmarkId }) {
                    await dataManager.updateFavicon(for: bookmark, with: faviconData)
                    print("Updated bookmark favicon")
                    return
                }
            }
        }
        
        private func updateTabFavicon(tabId: UUID, faviconData: Data) async {
            let dataManager = await DataManager.shared
            
            for space in await dataManager.spaces {
                let tabs = await dataManager.loadTabs(for: space)
                if let tab = tabs.first(where: { $0.id == tabId }) {
                    await dataManager.updateFavicon(for: tab, with: faviconData)
                    print("Updated tab favicon")
                    return
                }
            }
        }
        
        private func updatePinnedTabFavicon(pinnedTabId: UUID, faviconData: Data) async {
            let dataManager = await DataManager.shared
            
            for profile in await dataManager.profiles {
                let pinnedTabs = await dataManager.loadPinnedTabs(for: profile)
                if let pinnedTab = pinnedTabs.first(where: { $0.id == pinnedTabId }) {
                    await dataManager.updateFavicon(for: pinnedTab, with: faviconData)
                    print("Updated pinned tab favicon")
                    return
                }
            }
        }
        
        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - Supporting Types

enum SidebarItem: Hashable {
    case bookmark(Bookmark)
    case tab(Tab)
    case pinnedTab(PinnedTab)
    
    // Helper properties for the container approach
    var itemID: String {
        switch self {
        case .bookmark(let bookmark):
            return "bookmark-\(bookmark.id)"
        case .tab(let tab):
            return "tab-\(tab.id)"
        case .pinnedTab(let pinnedTab):
            return "pinnedTab-\(pinnedTab.id)"
        }
    }
    
    var url: URL? {
        switch self {
        case .bookmark(let bookmark):
            return URL(string: bookmark.url)
        case .tab(let tab):
            // Fix corrupted tab URLs that have "about:blank" when they should have proper URLs
            if tab.url == "about:blank" && !tab.title.isEmpty && tab.title != "New Tab" {
                print("WARNING: Fixing corrupted tab '\(tab.title)' with about:blank URL")
                // Try to infer URL from title or provide a reasonable default
                let inferredURL = inferURLFromTitle(tab.title)
                
                // Update the tab's URL in the database
                Task { @MainActor in
                    await fixCorruptedTabURL(tab: tab, newURL: inferredURL)
                }
                
                return URL(string: inferredURL)
            }
            return URL(string: tab.url)
        case .pinnedTab(let pinnedTab):
            return URL(string: pinnedTab.url)
        }
    }
    
    var profile: Profile? {
        switch self {
        case .bookmark(let bookmark):
            return bookmark.space?.profile
        case .tab(let tab):
            return tab.space?.profile
        case .pinnedTab(let pinnedTab):
            return pinnedTab.profile
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .bookmark(let bookmark):
            hasher.combine("bookmark")
            hasher.combine(bookmark.id)
        case .tab(let tab):
            hasher.combine("tab")
            hasher.combine(tab.id)
        case .pinnedTab(let pinnedTab):
            hasher.combine("pinnedTab")
            hasher.combine(pinnedTab.id)
        }
    }
    
    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        switch (lhs, rhs) {
        case (.bookmark(let lhsBookmark), .bookmark(let rhsBookmark)):
            return lhsBookmark.id == rhsBookmark.id
        case (.tab(let lhsTab), .tab(let rhsTab)):
            return lhsTab.id == rhsTab.id
        case (.pinnedTab(let lhsPinnedTab), .pinnedTab(let rhsPinnedTab)):
            return lhsPinnedTab.id == rhsPinnedTab.id
        default:
            return false
        }
    }
}

// MARK: - Tab URL Recovery Functions

func inferURLFromTitle(_ title: String) -> String {
    let lowercaseTitle = title.lowercased()
    
    // Common website patterns based on title content
    if lowercaseTitle.contains("youtube") {
        return "https://youtube.com"
    } else if lowercaseTitle.contains("webflow") {
        return "https://webflow.com"
    } else if lowercaseTitle.contains("google") {
        return "https://google.com"
    } else if lowercaseTitle.contains("github") {
        return "https://github.com"
    } else if lowercaseTitle.contains("stackoverflow") || lowercaseTitle.contains("stack overflow") {
        return "https://stackoverflow.com"
    } else if lowercaseTitle.contains("reddit") {
        return "https://reddit.com"
    } else if lowercaseTitle.contains("twitter") {
        return "https://twitter.com"
    } else if lowercaseTitle.contains("facebook") {
        return "https://facebook.com"
    } else if lowercaseTitle.contains("amazon") {
        return "https://amazon.com"
    } else if lowercaseTitle.contains("netflix") {
        return "https://netflix.com"
    } else {
        // For unknown titles, use google search
        return "https://google.com"
    }
}

@MainActor
func fixCorruptedTabURL(tab: Tab, newURL: String) async {
    print("DataManager: Fixing corrupted tab '\(tab.title)' URL from 'about:blank' to '\(newURL)'")
    tab.url = newURL
    await DataManager.shared.save()
}

// MARK: - Custom Text Field with Select All

struct SelectAllTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.backgroundColor = NSColor.clear
        textField.focusRingType = .none
        
        // Select all text when the field is created
        DispatchQueue.main.async {
            textField.selectText(nil)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            // Select all text when text is updated
            DispatchQueue.main.async {
                nsView.selectText(nil)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SelectAllTextField
        
        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

// MARK: - Helper Extensions

extension NSColor {
    var swiftUIColor: Color {
        return Color(nsColor: self)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        }
        
        return path
    }
}

// MARK: - Visual Effect View for True Transparency

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Custom Button Style

struct SidebarItemButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Additional Views


struct ProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    
    @State private var newProfileName = ""
    @State private var selectedColor = Color.blue
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Manage Profiles")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .opacity(0)
                    .disabled(true)
            }
            .padding()
            .background(.regularMaterial)
            
            // Form content
            Form {
                Section("Create New Profile") {
                    TextField("Profile Name", text: $newProfileName)
                    ColorPicker("Profile Color", selection: $selectedColor)
                    
                    Button("Create Profile") {
                        createProfile()
                    }
                    .disabled(newProfileName.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                
                Section("Existing Profiles") {
                    ForEach(dataManager.profiles, id: \.id) { profile in
                        HStack {
                            Circle()
                                .fill(profile.displayColor.swiftUIColor)
                                .frame(width: 20, height: 20)
                            
                            Text(profile.name)
                            
                            Spacer()
                            
                            if profile.isDefault {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
    }
    
    private func createProfile() {
        Task { @MainActor in
            let colorHex = NSColor(selectedColor).hexString
            await dataManager.createProfile(name: newProfileName, colorHex: colorHex)
            newProfileName = ""
            selectedColor = .blue
        }
    }
}

struct SpaceCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    
    let editingSpace: Space?
    
    @State private var spaceName = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = Color.green
    @State private var selectedProfile: Profile?
    @State private var showingProfileSheet = false
    
    let iconOptions = ["folder", "briefcase", "hammer", "person", "gamecontroller", "music.note", "photo", "book"]
    
    init(editingSpace: Space? = nil) {
        self.editingSpace = editingSpace
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text(editingSpace != nil ? "Edit Space" : "New Space")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(editingSpace != nil ? "Save" : "Create") {
                    saveSpace()
                }
                .disabled(spaceName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)
            
            // Form content
            Form {
                Section("Space Details") {
                    TextField("Space Name", text: $spaceName)
                    
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label(icon.capitalized, systemImage: icon)
                                .tag(icon)
                        }
                    }
                    
                    ColorPicker("Space Color", selection: $selectedColor)
                }
                
                Section("Profile Assignment") {
                    HStack {
                        Picker("Profile", selection: $selectedProfile) {
                            Text("Select a profile").tag(nil as Profile?)
                            ForEach(dataManager.profiles, id: \.id) { profile in
                                HStack {
                                    Circle()
                                        .fill(profile.displayColor.swiftUIColor)
                                        .frame(width: 12, height: 12)
                                    Text(profile.name)
                                }
                                .tag(profile as Profile?)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button("Manage Profiles...") {
                            showingProfileSheet = true
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    
                    if selectedProfile != nil {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("This space will have its own isolated browsing environment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 300)
        .sheet(isPresented: $showingProfileSheet) {
            ProfileManagementView()
        }
        .onAppear {
            if let space = editingSpace {
                spaceName = space.name
                selectedIcon = space.iconName
                selectedColor = space.displayColor.swiftUIColor
                selectedProfile = space.profile
            }
        }
    }
    
    private func saveSpace() {
        Task { @MainActor in
            let colorHex = NSColor(selectedColor).hexString
            
            if let space = editingSpace {
                // Update existing space
                await dataManager.updateSpace(
                    space,
                    name: spaceName,
                    iconName: selectedIcon,
                    colorHex: colorHex,
                    profile: selectedProfile
                )
            } else {
                // Create new space
                await dataManager.createSpace(
                    name: spaceName, 
                    iconName: selectedIcon, 
                    colorHex: colorHex, 
                    profile: selectedProfile
                )
            }
            dismiss()
        }
    }
}