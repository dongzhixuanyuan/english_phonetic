import Foundation
import SwiftUI

struct WordAnnotation: Identifiable, Codable, Equatable {
    let id: UUID
    var word: String
    var phonetic: String
    var normalizedX: Double
    var normalizedY: Double
    var normalizedWidth: Double
    var normalizedHeight: Double
    
    init(id: UUID = UUID(), word: String, phonetic: String, normalizedX: Double, normalizedY: Double, normalizedWidth: Double, normalizedHeight: Double) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.normalizedWidth = normalizedWidth
        self.normalizedHeight = normalizedHeight
    }
}

struct TextbookPage: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var imagePath: String
    var order: Int
    var annotations: [WordAnnotation]
    
    init(id: UUID = UUID(), name: String, imagePath: String, order: Int, annotations: [WordAnnotation] = []) {
        self.id = id
        self.name = name
        self.imagePath = imagePath
        self.order = order
        self.annotations = annotations
    }
}

struct TextbookUnit: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var order: Int
    var pages: [TextbookPage]
    
    init(id: UUID = UUID(), name: String, order: Int, pages: [TextbookPage] = []) {
        self.id = id
        self.name = name
        self.order = order
        self.pages = pages
    }
}

struct Textbook: Identifiable, Codable, Equatable,Hashable{
    let id: UUID
    var name: String
    var coverImagePath: String?
    var createdAt: Date
    var units: [TextbookUnit]
    
    init(id: UUID = UUID(), name: String, coverImagePath: String? = nil, createdAt: Date = Date(), units: [TextbookUnit] = []) {
        self.id = id
        self.name = name
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
        self.units = units
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coverImagePath)
        hasher.combine(createdAt)
        hasher.combine(units.count)
    }
}
