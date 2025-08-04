//
//  SidebarView.swift
//  Nova
//
//  Arc-like sidebar with spaces, profiles, bookmarks and tabs
//

import AppKit
import SwiftData

protocol SidebarViewDelegate: AnyObject {
    func sidebarDidSelectBookmark(_ bookmark: Bookmark)
    func sidebarDidSelectTab(_ tab: Tab)
    func sidebarDidSelectPinnedTab(_ pinnedTab: PinnedTab)
    func sidebarDidRequestNewTab(in space: Space)
    func sidebarDidRequestAddBookmark(to space: Space)
}

class SidebarView: NSView {
    
    weak var delegate: SidebarViewDelegate?
    private lazy var dataManager = DataManager.shared
    
    // UI Components
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var profileButton: NSButton!
    private var pinnedTabsSection: NSView!
    private var spacesSection: NSView!
    
    // State
    private var expandedSpaces: Set<UUID> = []
    private var profileMenuPopover: NSPopover?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSidebar()
        setupObservers()
        refreshContent()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSidebar()
        setupObservers()
        refreshContent()
    }
    
    private func setupSidebar() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        addSubview(scrollView)
        
        // Create main stack view
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        scrollView.documentView = stackView
        
        // Setup constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataDidChange),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func dataDidChange() {
        DispatchQueue.main.async {
            self.refreshContent()
        }
    }
    
    private func refreshContent() {
        Task { @MainActor in
            await dataManager.loadProfiles()
            await dataManager.loadSpaces()
            rebuildSidebar()
        }
    }
    
    private func rebuildSidebar() {
        // Clear existing content
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add profile selector
        createProfileSection()
        
        // Add pinned tabs section
        createPinnedTabsSection()
        
        // Add separator
        let separator = createSeparator()
        stackView.addArrangedSubview(separator)
        
        // Add spaces section
        createSpacesSection()
        
        // Add new space button
        createNewSpaceButton()
    }
    
    // MARK: - Profile Section
    
    private func createProfileSection() {
        let profileContainer = NSView()
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        
        profileButton = NSButton()
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.isBordered = false
        profileButton.imagePosition = .imageLeading
        profileButton.contentTintColor = dataManager.currentProfile?.displayColor
        profileButton.target = self
        profileButton.action = #selector(showProfileMenu)
        
        updateProfileButton()
        
        profileContainer.addSubview(profileButton)
        NSLayoutConstraint.activate([
            profileButton.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileButton.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profileButton.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            profileButton.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileContainer.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        stackView.addArrangedSubview(profileContainer)
    }
    
    private func updateProfileButton() {
        guard let profile = dataManager.currentProfile else { return }
        
        profileButton.title = profile.name
        profileButton.image = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "Profile")
        profileButton.contentTintColor = profile.displayColor
    }
    
    @objc private func showProfileMenu() {
        let menu = NSMenu()
        
        // Current profiles
        for profile in dataManager.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(switchProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile
            item.state = profile.id == dataManager.currentProfile?.id ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add new profile
        let newProfileItem = NSMenuItem(title: "New Profile...", action: #selector(createNewProfile), keyEquivalent: "")
        newProfileItem.target = self
        menu.addItem(newProfileItem)
        
        // Manage profiles
        let manageItem = NSMenuItem(title: "Manage Profiles...", action: #selector(manageProfiles), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: profileButton.frame.height), in: profileButton)
    }
    
    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? Profile else { return }
        
        Task {
            await dataManager.switchProfile(profile)
            updateProfileButton()
            rebuildSidebar()
        }
    }
    
    @objc private func createNewProfile() {
        showProfileCreationDialog()
    }
    
    @objc private func manageProfiles() {
        // TODO: Open profile management window
        print("Manage profiles requested")
    }
    
    // MARK: - Pinned Tabs Section
    
    private func createPinnedTabsSection() {
        guard let profile = dataManager.currentProfile else { return }
        
        let pinnedTabs = dataManager.loadPinnedTabs(for: profile)
        
        if !pinnedTabs.isEmpty {
            let sectionLabel = createSectionLabel("Pinned")
            stackView.addArrangedSubview(sectionLabel)
            
            for pinnedTab in pinnedTabs {
                let tabView = createPinnedTabView(pinnedTab)
                stackView.addArrangedSubview(tabView)
            }
        }
    }
    
    private func createPinnedTabView(_ pinnedTab: PinnedTab) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.title = pinnedTab.title
        button.image = pinnedTab.faviconData != nil ? 
            NSImage(data: pinnedTab.faviconData!) : 
            NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")
        button.target = self
        button.action = #selector(selectPinnedTab(_:))
        button.tag = pinnedTab.hashValue
        
        // Context menu for pinned tabs
        let menu = NSMenu()
        let unpinItem = NSMenuItem(title: "Unpin Tab", action: #selector(unpinTab(_:)), keyEquivalent: "")
        unpinItem.target = self
        unpinItem.representedObject = pinnedTab
        menu.addItem(unpinItem)
        button.menu = menu
        
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return container
    }
    
    @objc private func selectPinnedTab(_ sender: NSButton) {
        guard let profile = dataManager.currentProfile else { return }
        let pinnedTabs = dataManager.loadPinnedTabs(for: profile)
        
        if let pinnedTab = pinnedTabs.first(where: { $0.hashValue == sender.tag }) {
            delegate?.sidebarDidSelectPinnedTab(pinnedTab)
        }
    }
    
    @objc private func unpinTab(_ sender: NSMenuItem) {
        guard let pinnedTab = sender.representedObject as? PinnedTab else { return }
        
        Task {
            await dataManager.removePinnedTab(pinnedTab)
            rebuildSidebar()
        }
    }
    
    // MARK: - Spaces Section
    
    private func createSpacesSection() {
        for space in dataManager.spaces {
            let spaceView = createSpaceView(space)
            stackView.addArrangedSubview(spaceView)
        }
    }
    
    private func createSpaceView(_ space: Space) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        
        // Space header
        let headerView = createSpaceHeaderView(space)
        stackView.addArrangedSubview(headerView)
        
        // Space content (bookmarks and tabs) - only if expanded
        if expandedSpaces.contains(space.id) {
            let contentView = createSpaceContentView(space)
            stackView.addArrangedSubview(contentView)
        }
        
        container.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createSpaceHeaderView(_ space: Space) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.title = space.name
        button.image = space.displayIcon
        button.contentTintColor = space.displayColor
        button.target = self
        button.action = #selector(toggleSpace(_:))
        button.tag = space.hashValue
        
        // Context menu for spaces
        let menu = NSMenu()
        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(newTabInSpace(_:)), keyEquivalent: "")
        newTabItem.target = self
        newTabItem.representedObject = space
        menu.addItem(newTabItem)
        
        let addBookmarkItem = NSMenuItem(title: "Add Bookmark", action: #selector(addBookmarkToSpace(_:)), keyEquivalent: "")
        addBookmarkItem.target = self
        addBookmarkItem.representedObject = space
        menu.addItem(addBookmarkItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let deleteSpaceItem = NSMenuItem(title: "Delete Space", action: #selector(deleteSpace(_:)), keyEquivalent: "")
        deleteSpaceItem.target = self
        deleteSpaceItem.representedObject = space
        menu.addItem(deleteSpaceItem)
        
        button.menu = menu
        
        // Expansion indicator
        let expandButton = NSButton()
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.isBordered = false
        expandButton.image = NSImage(systemSymbolName: 
            expandedSpaces.contains(space.id) ? "chevron.down" : "chevron.right", 
            accessibilityDescription: "Toggle")
        expandButton.target = self
        expandButton.action = #selector(toggleSpace(_:))
        expandButton.tag = space.hashValue
        
        container.addSubview(expandButton)
        container.addSubview(button)
        
        NSLayoutConstraint.activate([
            expandButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            expandButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 16),
            expandButton.heightAnchor.constraint(equalToConstant: 16),
            
            button.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 4),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return container
    }
    
    private func createSpaceContentView(_ space: Space) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 1
        
        // Bookmarks
        let bookmarks = dataManager.loadBookmarks(for: space)
        for bookmark in bookmarks {
            let bookmarkView = createBookmarkView(bookmark)
            stackView.addArrangedSubview(bookmarkView)
        }
        
        // Tabs
        let tabs = dataManager.loadTabs(for: space)
        for tab in tabs {
            let tabView = createTabView(tab)
            stackView.addArrangedSubview(tabView)
        }
        
        container.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createBookmarkView(_ bookmark: Bookmark) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.title = bookmark.title
        button.image = bookmark.faviconData != nil ? 
            NSImage(data: bookmark.faviconData!) : 
            NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Bookmark")
        button.target = self
        button.action = #selector(selectBookmark(_:))
        button.tag = bookmark.hashValue
        
        // Context menu
        let menu = NSMenu()
        let deleteItem = NSMenuItem(title: "Delete Bookmark", action: #selector(deleteBookmark(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = bookmark
        menu.addItem(deleteItem)
        button.menu = menu
        
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 22)
        ])
        
        return container
    }
    
    private func createTabView(_ tab: Tab) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.title = tab.title
        button.image = tab.faviconData != nil ? 
            NSImage(data: tab.faviconData!) : 
            NSImage(systemSymbolName: "doc", accessibilityDescription: "Tab")
        button.target = self
        button.action = #selector(selectTab(_:))
        button.tag = tab.hashValue
        
        // Highlight active tab
        if tab.isActive {
            button.contentTintColor = .controlAccentColor
        }
        
        // Context menu
        let menu = NSMenu()
        let closeItem = NSMenuItem(title: "Close Tab", action: #selector(closeTab(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.representedObject = tab
        menu.addItem(closeItem)
        
        let pinItem = NSMenuItem(title: "Pin Tab", action: #selector(pinTab(_:)), keyEquivalent: "")
        pinItem.target = self
        pinItem.representedObject = tab
        menu.addItem(pinItem)
        
        button.menu = menu
        
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 22)
        ])
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func toggleSpace(_ sender: NSButton) {
        let space = dataManager.spaces.first { $0.hashValue == sender.tag }
        guard let space = space else { return }
        
        if expandedSpaces.contains(space.id) {
            expandedSpaces.remove(space.id)
        } else {
            expandedSpaces.insert(space.id)
        }
        
        rebuildSidebar()
    }
    
    @objc private func selectBookmark(_ sender: NSButton) {
        let allBookmarks = dataManager.spaces.flatMap { dataManager.loadBookmarks(for: $0) }
        if let bookmark = allBookmarks.first(where: { $0.hashValue == sender.tag }) {
            delegate?.sidebarDidSelectBookmark(bookmark)
        }
    }
    
    @objc private func selectTab(_ sender: NSButton) {
        let allTabs = dataManager.spaces.flatMap { dataManager.loadTabs(for: $0) }
        if let tab = allTabs.first(where: { $0.hashValue == sender.tag }) {
            delegate?.sidebarDidSelectTab(tab)
        }
    }
    
    @objc private func newTabInSpace(_ sender: NSMenuItem) {
        guard let space = sender.representedObject as? Space else { return }
        delegate?.sidebarDidRequestNewTab(in: space)
    }
    
    @objc private func addBookmarkToSpace(_ sender: NSMenuItem) {
        guard let space = sender.representedObject as? Space else { return }
        delegate?.sidebarDidRequestAddBookmark(to: space)
    }
    
    @objc private func deleteSpace(_ sender: NSMenuItem) {
        guard let space = sender.representedObject as? Space else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Space"
        alert.informativeText = "Are you sure you want to delete \"\(space.name)\"? This will also delete all bookmarks and tabs in this space."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await dataManager.deleteSpace(space)
                rebuildSidebar()
            }
        }
    }
    
    @objc private func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        
        Task {
            await dataManager.deleteBookmark(bookmark)
            rebuildSidebar()
        }
    }
    
    @objc private func closeTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? Tab else { return }
        
        Task {
            await dataManager.closeTab(tab)
            rebuildSidebar()
        }
    }
    
    @objc private func pinTab(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? Tab else { return }
        
        Task {
            await dataManager.addPinnedTab(title: tab.title, url: tab.url)
            await dataManager.closeTab(tab)
            rebuildSidebar()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }
    
    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return separator
    }
    
    private func createNewSpaceButton() {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.title = "New Space"
        button.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Space")
        button.target = self
        button.action = #selector(createNewSpace)
        
        stackView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    @objc private func createNewSpace() {
        showSpaceCreationDialog()
    }
    
    // MARK: - Dialog Methods
    
    private func showProfileCreationDialog() {
        let alert = NSAlert()
        alert.messageText = "Create New Profile"
        alert.informativeText = "Enter a name for the new profile:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Profile name..."
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                Task {
                    await dataManager.createProfile(name: name, colorHex: "#007AFF")
                    rebuildSidebar()
                }
            }
        }
    }
    
    private func showSpaceCreationDialog() {
        let alert = NSAlert()
        alert.messageText = "Create New Space"
        alert.informativeText = "Enter a name for the new space:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Space name..."
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                Task {
                    await dataManager.createSpace(name: name, iconName: "folder", colorHex: "#34C759")
                    rebuildSidebar()
                }
            }
        }
    }
}

extension SidebarView {
    func expandSpace(_ space: Space) {
        expandedSpaces.insert(space.id)
        rebuildSidebar()
    }
    
    func refresh() {
        refreshContent()
    }
}