//
//  MessageHistory.swift
//  VoiceBoard
//
//  Model for storing message history items
//

import Foundation

/// Represents a single message history item
struct MessageHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let sentAt: Date
    
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.sentAt = Date()
    }
    
    /// Returns a formatted time string for display
    var formattedTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(sentAt) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: sentAt)
        } else if calendar.isDateInYesterday(sentAt) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: sentAt)
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: sentAt)
        }
    }
    
    /// Returns a truncated preview of the content
    var contentPreview: String {
        let maxLength = 50
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
}
