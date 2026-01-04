//
//  Item.swift
//  VoiceBoard
//
//  Created by zhb on 2026/1/4.
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
