//
//  DataManager.swift
//  Nova
//
//  SwiftData persistence manager for Nova Browser
//

import Foundation
import SwiftData
import AppKit
import Combine

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    let modelContainer: ModelContainer
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    @Published var profiles: [Profile] = []
    @Published var currentProfile: Profile?
    @Published var spaces: [Space] = []
    @Published var currentSpace: Space?
    
    private init() {
        do {
            let schema = Schema([
                Profile.self,
                Space.self,
                Bookmark.self,
                Tab.self,
                PinnedTab.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // Can be changed to .automatic for CloudKit sync
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("DataManager: SwiftData model container initialized successfully")
            
        } catch {
            print("DataManager: Failed to initialize model container: \(error)")
            fatalError("Failed to initialize SwiftData model container: \(error)")
        }
        
        Task {
            await setupInitialData()
        }
    }
    
    // MARK: - Initial Data Setup
    
    private func setupInitialData() async {
        await loadProfiles()
        
        if profiles.isEmpty {
            await createDefaultProfile()
        }
        
        if currentProfile == nil {
            currentProfile = profiles.first { $0.isDefault } ?? profiles.first
        }
        
        await loadSpaces()
        
        if spaces.isEmpty {
            await createDefaultSpaces()
        }
        
        if currentSpace == nil {
            currentSpace = spaces.first
        }
    }
    
    private func createDefaultProfile() async {
        let defaultProfile = Profile(name: "Default", colorHex: "#007AFF", isDefault: true)
        modelContext.insert(defaultProfile)
        
        do {
            try modelContext.save()
            await loadProfiles()
            print("DataManager: Created default profile")
        } catch {
            print("DataManager: Failed to create default profile: \(error)")
        }
    }
    
    private func createDefaultSpaces() async {
        guard let profile = currentProfile else { return }
        
        let personalSpace = Space(name: "Personal", iconName: "person.fill", colorHex: "#34C759", profile: profile)
        let workSpace = Space(name: "Work", iconName: "briefcase.fill", colorHex: "#FF9500", profile: profile)
        let developmentSpace = Space(name: "Development", iconName: "hammer.fill", colorHex: "#5856D6", profile: profile)
        
        personalSpace.sortOrder = 0
        workSpace.sortOrder = 1
        developmentSpace.sortOrder = 2
        
        modelContext.insert(personalSpace)
        modelContext.insert(workSpace)
        modelContext.insert(developmentSpace)
        
        // Add some default bookmarks to Personal space
        let appleBookmark = Bookmark(title: "Apple", url: "https://apple.com", space: personalSpace)
        let googleBookmark = Bookmark(title: "Google", url: "https://google.com", space: personalSpace)
        
        appleBookmark.sortOrder = 0
        googleBookmark.sortOrder = 1
        
        modelContext.insert(appleBookmark)
        modelContext.insert(googleBookmark)
        
        // Add default pinned tabs
        let gmailPinned = PinnedTab(title: "Gmail", url: "https://mail.google.com", profile: profile)
        let calendarPinned = PinnedTab(title: "Calendar", url: "https://calendar.google.com", profile: profile)
        
        gmailPinned.sortOrder = 0
        calendarPinned.sortOrder = 1
        
        modelContext.insert(gmailPinned)
        modelContext.insert(calendarPinned)
        
        do {
            try modelContext.save()
            await loadSpaces()
            print("DataManager: Created default spaces and bookmarks")
        } catch {
            print("DataManager: Failed to create default spaces: \(error)")
        }
    }
    
    // MARK: - Data Loading
    
    func loadProfiles() async {
        let descriptor = FetchDescriptor<Profile>(
            sortBy: [SortDescriptor(\Profile.name)]
        )
        
        do {
            profiles = try modelContext.fetch(descriptor)
        } catch {
            print("DataManager: Failed to load profiles: \(error)")
            profiles = []
        }
    }
    
    func loadSpaces() async {
        let descriptor = FetchDescriptor<Space>(
            sortBy: [SortDescriptor(\Space.sortOrder)]
        )
        
        do {
            spaces = try modelContext.fetch(descriptor)
        } catch {
            print("DataManager: Failed to load spaces: \(error)")
            spaces = []
        }
    }
    
    func loadBookmarks(for space: Space) -> [Bookmark] {
        let spaceId = space.id
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.space?.id == spaceId
            },
            sortBy: [SortDescriptor(\Bookmark.sortOrder)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("DataManager: Failed to load bookmarks for space \(space.name): \(error)")
            return []
        }
    }
    
    func loadTabs(for space: Space) -> [Tab] {
        let spaceId = space.id
        let descriptor = FetchDescriptor<Tab>(
            predicate: #Predicate<Tab> { tab in
                tab.space?.id == spaceId
            },
            sortBy: [SortDescriptor(\Tab.lastAccessedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("DataManager: Failed to load tabs for space \(space.name): \(error)")
            return []
        }
    }
    
    func loadPinnedTabs(for profile: Profile) -> [PinnedTab] {
        let profileId = profile.id
        let descriptor = FetchDescriptor<PinnedTab>(
            predicate: #Predicate<PinnedTab> { pinnedTab in
                pinnedTab.profile?.id == profileId
            },
            sortBy: [SortDescriptor(\PinnedTab.sortOrder)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("DataManager: Failed to load pinned tabs for profile \(profile.name): \(error)")
            return []
        }
    }
    
    // MARK: - Profile Management
    
    func createProfile(name: String, colorHex: String) async {
        let profile = Profile(name: name, colorHex: colorHex)
        modelContext.insert(profile)
        
        do {
            try modelContext.save()
            await loadProfiles()
            print("DataManager: Created profile: \(name)")
        } catch {
            print("DataManager: Failed to create profile: \(error)")
        }
    }
    
    func switchProfile(_ profile: Profile) async {
        currentProfile = profile
        await loadSpaces()
        currentSpace = spaces.first
        print("DataManager: Switched to profile: \(profile.name)")
    }
    
    // MARK: - Space Management
    
    func createSpace(name: String, iconName: String, colorHex: String, profile: Profile? = nil) async {
        let targetProfile = profile ?? currentProfile
        guard let targetProfile = targetProfile else { return }
        
        let space = Space(name: name, iconName: iconName, colorHex: colorHex, profile: targetProfile)
        space.sortOrder = spaces.count
        
        modelContext.insert(space)
        
        do {
            try modelContext.save()
            await loadSpaces()
            print("DataManager: Created space: \(name) for profile: \(targetProfile.name)")
        } catch {
            print("DataManager: Failed to create space: \(error)")
        }
    }
    
    func switchSpace(_ space: Space) {
        currentSpace = space
        print("DataManager: Switched to space: \(space.name)")
    }
    
    func updateSpace(_ space: Space, name: String, iconName: String, colorHex: String, profile: Profile?) async {
        space.name = name
        space.iconName = iconName
        space.colorHex = colorHex
        if let profile = profile {
            space.profile = profile
        }
        
        do {
            try modelContext.save()
            await loadSpaces()
            print("DataManager: Updated space: \(name)")
        } catch {
            print("DataManager: Failed to update space: \(error)")
        }
    }
    
    func deleteSpace(_ space: Space) async {
        modelContext.delete(space)
        
        do {
            try modelContext.save()
            await loadSpaces()
            
            if currentSpace?.id == space.id {
                currentSpace = spaces.first
            }
            
            print("DataManager: Deleted space: \(space.name)")
        } catch {
            print("DataManager: Failed to delete space: \(error)")
        }
    }
    
    // MARK: - Bookmark Management
    
    func addBookmark(title: String, url: String, to space: Space) async {
        let bookmark = Bookmark(title: title, url: url, space: space)
        let existingBookmarks = loadBookmarks(for: space)
        bookmark.sortOrder = existingBookmarks.count
        
        modelContext.insert(bookmark)
        
        do {
            try modelContext.save()
            print("DataManager: Added bookmark: \(title) to \(space.name)")
        } catch {
            print("DataManager: Failed to add bookmark: \(error)")
        }
    }
    
    func deleteBookmark(_ bookmark: Bookmark) async {
        modelContext.delete(bookmark)
        
        do {
            try modelContext.save()
            print("DataManager: Deleted bookmark: \(bookmark.title)")
        } catch {
            print("DataManager: Failed to delete bookmark: \(error)")
        }
    }
    
    // MARK: - Tab Management
    
    func addTab(title: String, url: String, to space: Space, makeActive: Bool = true) async -> Tab {
        // Deactivate all tabs if making this one active
        if makeActive {
            let existingTabs = loadTabs(for: space)
            for tab in existingTabs {
                tab.isActive = false
            }
        }
        
        let tab = Tab(title: title, url: url, space: space, isActive: makeActive)
        let existingTabs = loadTabs(for: space)
        tab.sortOrder = existingTabs.count
        
        modelContext.insert(tab)
        
        do {
            try modelContext.save()
            print("DataManager: Added tab: \(title) to \(space.name)")
        } catch {
            print("DataManager: Failed to add tab: \(error)")
        }
        
        return tab
    }
    
    func activateTab(_ tab: Tab) async {
        guard let space = tab.space else { return }
        
        // Deactivate all other tabs in the space
        let existingTabs = loadTabs(for: space)
        for existingTab in existingTabs {
            existingTab.isActive = false
        }
        
        // Activate the selected tab
        tab.isActive = true
        tab.lastAccessedAt = Date()
        
        do {
            try modelContext.save()
            print("DataManager: Activated tab: \(tab.title)")
        } catch {
            print("DataManager: Failed to activate tab: \(error)")
        }
    }
    
    func closeTab(_ tab: Tab) async {
        modelContext.delete(tab)
        
        do {
            try modelContext.save()
            print("DataManager: Closed tab: \(tab.title)")
        } catch {
            print("DataManager: Failed to close tab: \(error)")
        }
    }
    
    // MARK: - Pinned Tab Management
    
    func addPinnedTab(title: String, url: String) async {
        guard let profile = currentProfile else { return }
        
        let pinnedTab = PinnedTab(title: title, url: url, profile: profile)
        let existingPinnedTabs = loadPinnedTabs(for: profile)
        pinnedTab.sortOrder = existingPinnedTabs.count
        
        modelContext.insert(pinnedTab)
        
        do {
            try modelContext.save()
            print("DataManager: Added pinned tab: \(title)")
        } catch {
            print("DataManager: Failed to add pinned tab: \(error)")
        }
    }
    
    func removePinnedTab(_ pinnedTab: PinnedTab) async {
        modelContext.delete(pinnedTab)
        
        do {
            try modelContext.save()
            print("DataManager: Removed pinned tab: \(pinnedTab.title)")
        } catch {
            print("DataManager: Failed to remove pinned tab: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func save() async {
        do {
            try modelContext.save()
        } catch {
            print("DataManager: Failed to save context: \(error)")
        }
    }
    
    func updateFavicon(for bookmark: Bookmark, with data: Data) async {
        bookmark.faviconData = data
        await save()
    }
    
    func updateFavicon(for tab: Tab, with data: Data) async {
        tab.faviconData = data
        await save()
    }
    
    func updateFavicon(for pinnedTab: PinnedTab, with data: Data) async {
        pinnedTab.faviconData = data
        await save()
    }
}