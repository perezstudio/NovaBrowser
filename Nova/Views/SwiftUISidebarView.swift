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
        .sheet(isPresented: $showingProfileSheet) {
            ProfileManagementView()
        }
        .sheet(isPresented: $showingSpaceSheet) {
            SpaceCreationView()
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
                                    Button(action: { selectedItem = .pinnedTab(pinnedTab) }) {
                                        PinnedTabRow(pinnedTab: pinnedTab)
                                    }
                                    .buttonStyle(SidebarItemButtonStyle(isSelected: selectedItem == .pinnedTab(pinnedTab)))
                                }
                            }
                        }
                    }
                    
                    // Current Space Tabs Section
                    if let currentSpace = selectedSpace ?? spaces.first {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentSpace.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            // Bookmarks
                            let bookmarks = dataManager.loadBookmarks(for: currentSpace)
                            ForEach(bookmarks, id: \.id) { bookmark in
                                Button(action: { selectedItem = .bookmark(bookmark) }) {
                                    BookmarkRow(bookmark: bookmark)
                                }
                                .buttonStyle(SidebarItemButtonStyle(isSelected: selectedItem == .bookmark(bookmark)))
                            }
                            
                            // Tabs
                            let tabs = dataManager.loadTabs(for: currentSpace)
                            ForEach(tabs, id: \.id) { tab in
                                Button(action: { selectedItem = .tab(tab) }) {
                                    TabRow(tab: tab)
                                }
                                .buttonStyle(SidebarItemButtonStyle(isSelected: selectedItem == .tab(tab)))
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
                showingSpaceSheet: $showingSpaceSheet
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
    
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(spaces) { space in
                        SpaceButton(
                            space: space,
                            isSelected: selectedSpace?.id == space.id,
                            onTap: { selectedSpace = space }
                        )
                    }
                    
                    // Add Space Button
                    Button(action: { showingSpaceSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 44)
        }
    }
}

struct SpaceButton: View {
    let space: Space
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var showingContextMenu = false
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: space.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : space.displayColor.swiftUIColor)
                    .frame(width: 32, height: 24)
                
                Text(space.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? space.displayColor.swiftUIColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Delete Space", role: .destructive) {
                deleteSpace(space)
            }
        }
    }
    
    private func deleteSpace(_ space: Space) {
        Task { @MainActor in
            await dataManager.deleteSpace(space)
        }
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        HStack {
            if let faviconData = bookmark.faviconData,
               let nsImage = NSImage(data: faviconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "bookmark")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            Text(bookmark.title)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open") { /* TODO */ }
            Button("Open in New Tab") { /* TODO */ }
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
            
            if tab.isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Close Tab") { 
                Task { @MainActor in
                    await DataManager.shared.closeTab(tab)
                }
            }
            Button("Pin Tab") { 
                Task { @MainActor in
                    await DataManager.shared.addPinnedTab(title: tab.title, url: tab.url)
                    await DataManager.shared.closeTab(tab)
                }
            }
        }
    }
}

struct PinnedTabRow: View {
    let pinnedTab: PinnedTab
    
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
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Unpin Tab") { 
                Task { @MainActor in
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
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .onAppear {
                        currentURL = bookmark.url
                    }
                case .tab(let tab):
                    WebViewRepresentable(
                        url: URL(string: tab.url),
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .onAppear {
                        currentURL = tab.url
                    }
                case .pinnedTab(let pinnedTab):
                    WebViewRepresentable(
                        url: URL(string: pinnedTab.url),
                        webView: $webView,
                        currentURL: $currentURL,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward
                    )
                    .onAppear {
                        currentURL = pinnedTab.url
                    }
                }
            } else {
                // Empty state that fills the entire area below the URL bar
                VStack {
                    Spacer()
                    
                    Image(systemName: "globe")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No Selection")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Text("Select an item from the sidebar to start browsing")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.top, 2)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
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
    @Binding var webView: CustomWebKitView?
    @Binding var currentURL: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> CustomWebKitView {
        let webView = CustomWebKitView()
        
        // Store reference to webView immediately
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // Load URL
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        
        // Start polling for navigation state updates
        context.coordinator.startPolling(webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: CustomWebKitView, context: Context) {
        if let url = url, nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
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
                    
                    // Update URL if it changed
                    if let currentURL = webView.url?.absoluteString,
                       currentURL != self.parent.currentURL {
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
        NavigationView {
            Form {
                Section("Create New Profile") {
                    TextField("Profile Name", text: $newProfileName)
                    ColorPicker("Profile Color", selection: $selectedColor)
                    
                    Button("Create Profile") {
                        createProfile()
                    }
                    .disabled(newProfileName.isEmpty)
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
            .navigationTitle("Manage Profiles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
    
    @State private var spaceName = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = Color.green
    
    let iconOptions = ["folder", "briefcase", "hammer", "person", "gamecontroller", "music.note", "photo", "book"]
    
    var body: some View {
        NavigationView {
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
                
                Section {
                    Button("Create Space") {
                        createSpace()
                    }
                    .disabled(spaceName.isEmpty)
                }
            }
            .navigationTitle("New Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createSpace() {
        Task { @MainActor in
            let colorHex = NSColor(selectedColor).hexString
            await dataManager.createSpace(name: spaceName, iconName: selectedIcon, colorHex: colorHex)
            dismiss()
        }
    }
}