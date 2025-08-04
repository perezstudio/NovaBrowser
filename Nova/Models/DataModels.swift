//
//  DataModels.swift
//  Nova
//
//  SwiftData models for Arc-like browsing experience
//

import Foundation
import SwiftData
import AppKit

@Model
class Profile: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Space.profile)
    var spaces: [Space] = []
    
    @Relationship(deleteRule: .cascade, inverse: \PinnedTab.profile)
    var pinnedTabs: [PinnedTab] = []
    
    init(name: String, colorHex: String = "#007AFF", isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
class Space: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var profile: Profile?
    
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.space)
    var bookmarks: [Bookmark] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Tab.space)
    var tabs: [Tab] = []
    
    init(name: String, iconName: String = "folder", colorHex: String = "#34C759", profile: Profile? = nil) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = 0
        self.profile = profile
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
class Bookmark: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var faviconData: Data?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date?
    
    @Relationship(deleteRule: .nullify)
    var space: Space?
    
    init(title: String, url: String, space: Space? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.sortOrder = 0
        self.space = space
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
class Tab: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var faviconData: Data?
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var space: Space?
    
    init(title: String, url: String, space: Space? = nil, isActive: Bool = false) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.sortOrder = 0
        self.isActive = isActive
        self.space = space
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastAccessedAt = Date()
    }
}

@Model
class PinnedTab: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var faviconData: Data?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var profile: Profile?
    
    init(title: String, url: String, profile: Profile? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.sortOrder = 0
        self.profile = profile
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastAccessedAt = Date()
    }
}

// MARK: - Model Extensions

extension Profile {
    static var defaultProfile: Profile {
        Profile(name: "Default", colorHex: "#007AFF", isDefault: true)
    }
    
    var displayColor: NSColor {
        return NSColor(hex: colorHex) ?? NSColor.systemBlue
    }
}

extension Space {
    var displayColor: NSColor {
        return NSColor(hex: colorHex) ?? NSColor.systemGreen
    }
    
    var displayIcon: NSImage? {
        return NSImage(systemSymbolName: iconName, accessibilityDescription: name)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        
        return nil
    }
    
    var hexString: String {
        let components = cgColor.components
        let r = components?[0] ?? 0.0
        let g = components?[1] ?? 0.0
        let b = components?[2] ?? 0.0
        
        return String(format: "#%02X%02X%02X", 
                     Int(r * 255), 
                     Int(g * 255), 
                     Int(b * 255))
    }
}