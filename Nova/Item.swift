//
//  Item.swift
//  Nova
//
//  Created by Kevin Perez on 7/8/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
