//
//  SwiftUISidebarView.swift
//  Nova
//
//  SwiftUI-based sidebar using NavigationSplitView for Arc-like interface
//

import SwiftUI
import SwiftData
import WebKit

struct NovaNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared
    
    @State private var selectedSpace: Space?
    @State private var selectedItem: SidebarItem?
    @State private var showingProfileSheet = false
    @State private var showingSpaceSheet = false
    @State private var editingSpace: Space?
    @State private var sidebarVisible = true
    
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
                    sidebarVisible: $sidebarVisible
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
                    sidebarVisible: $sidebarVisible
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
                                        onTap: { selectedItem = .bookmark(bookmark) }
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
                            
                            // Tabs
                            let tabs = dataManager.loadTabs(for: currentSpace)
                            ForEach(tabs, id: \.id) { tab in
                                TabRow(
                                    tab: tab, 
                                    isSelected: selectedItem == .tab(tab),
                                    onTap: { selectedItem = .tab(tab) },
                                    onClose: { selectedItem = nil }
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
            let tab = await dataManager.addTab(title: "New Tab", url: "https://google.com", to: space)
            selectedItem = .tab(tab)
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
    
    @State private var currentURL = ""
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
                        TextField("Enter URL", text: $editingURL)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                navigateToURL(editingURL)
                                isEditingURL = false
                            }
                            .onExitCommand {
                                editingURL = currentURL
                                isEditingURL = false
                            }
                        
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
            
            // Web content
            if let selectedItem = selectedItem {
                switch selectedItem {
                case .bookmark(let bookmark):
                    WebViewRepresentable(
                        url: URL(string: bookmark.url),
                        profile: bookmark.space?.profile,
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .id(bookmark.id) // Force new instance when switching items
                    .onAppear {
                        currentURL = bookmark.url
                    }
                case .tab(let tab):
                    WebViewRepresentable(
                        url: URL(string: tab.url),
                        profile: tab.space?.profile,
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .id(tab.id) // Force new instance when switching items
                    .onAppear {
                        currentURL = tab.url
                    }
                case .pinnedTab(let pinnedTab):
                    WebViewRepresentable(
                        url: URL(string: pinnedTab.url),
                        profile: pinnedTab.profile,
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .id(pinnedTab.id) // Force new instance when switching items
                    .onAppear {
                        currentURL = pinnedTab.url
                    }
                }
            } else {
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

struct WebViewRepresentable: NSViewRepresentable {
    let url: URL?
    let profile: Profile?
    @Binding var webView: CustomWebKitView?
    @Binding var currentURL: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> CustomWebKitView {
        let webView = CustomWebKitView(frame: .zero, profile: profile)
        
        // Store reference to webView immediately
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // Load URL only on initial creation
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        
        // Start polling for navigation state updates
        context.coordinator.startPolling(webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: CustomWebKitView, context: Context) {
        // Don't reload on updates - the web view should maintain its own navigation state
        // This prevents the reload loop when clicking links
    }
    
    class Coordinator: NSObject {
        var parent: WebViewRepresentable
        var timer: Timer?
        weak var webView: CustomWebKitView?
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func startPolling(_ webView: CustomWebKitView) {
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