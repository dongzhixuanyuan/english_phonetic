import Foundation
import SwiftUI
import Combine

class TextbookViewModel: ObservableObject {
    @Published var textbooks: [Textbook] = []
    @Published var isProcessing = false
    @Published var processingProgress: String = ""
    
    private let dataStore = DataStoreService.shared
    private let ocrService = OCRService()
    private let phoneticService = PhoneticDictionaryService.shared
    
    init() {
        loadTextbooks()
        setupSamplePages()
    }
    
    func loadTextbooks() {
        textbooks = dataStore.loadTextbooks()
    }
    
    private func saveTextbooks() {
        dataStore.saveTextbooks(textbooks)
    }
    
    private func setupSamplePages() {
        guard !textbooks.contains(where: { $0.name == "示例课本" }) else { return }
        
        let sampleUnit = TextbookUnit(name: "Unit 1 Hello", order: 0)
        let sampleTextbook = Textbook(
            name: "示例课本",
            coverImagePath: nil,
            units: [sampleUnit]
        )
        
        textbooks.insert(sampleTextbook, at: 0)
        saveTextbooks()
    }
    
    func addTextbook(name: String) -> Textbook {
        let textbook = Textbook(name: name)
        textbooks.append(textbook)
        saveTextbooks()
        return textbook
    }
    
    func deleteTextbook(_ textbook: Textbook) {
        for unit in textbook.units {
            for page in unit.pages {
                dataStore.deleteImage(filename: page.imagePath)
            }
        }
        
        textbooks.removeAll { $0.id == textbook.id }
        saveTextbooks()
    }
    
    func addPage(to textbookId: UUID, unitId: UUID, image: UIImage, pageName: String, completion: @escaping (TextbookPage?) -> Void) {
        isProcessing = true
        processingProgress = "正在识别文字..."
        
        let pageId = UUID()
        
        guard let imageFilename = dataStore.saveImage(image, forPageId: pageId) else {
            isProcessing = false
            completion(nil)
            return
        }
        
        ocrService.recognizeText(in: image) { [weak self] results in
            guard let self = self else {
                completion(nil)
                return
            }
            
            self.processingProgress = "正在生成音标..."
            
            var annotations: [WordAnnotation] = []
            for result in results {
                let phonetic = self.phoneticService.lookup(result.text) ?? ""
                let annotation = WordAnnotation(
                    word: result.text,
                    phonetic: phonetic,
                    normalizedX: Double(result.boundingBox.origin.x),
                    normalizedY: Double(result.boundingBox.origin.y),
                    normalizedWidth: Double(result.boundingBox.width),
                    normalizedHeight: Double(result.boundingBox.height)
                )
                annotations.append(annotation)
            }
            
            let page = TextbookPage(
                id: pageId,
                name: pageName,
                imagePath: imageFilename,
                order: 0,
                annotations: annotations
            )
            
            if let textbookIndex = self.textbooks.firstIndex(where: { $0.id == textbookId }),
               let unitIndex = self.textbooks[textbookIndex].units.firstIndex(where: { $0.id == unitId }) {
                
                self.textbooks[textbookIndex].units[unitIndex].pages.append(page)
                self.saveTextbooks()
            }
            
            self.isProcessing = false
            self.processingProgress = ""
            
            DispatchQueue.main.async {
                completion(page)
            }
        }
    }
    
    func updateAnnotations(for pageId: UUID, in textbookId: UUID, unitId: UUID, annotations: [WordAnnotation]) {
        guard let textbookIndex = textbooks.firstIndex(where: { $0.id == textbookId }),
              let unitIndex = textbooks[textbookIndex].units.firstIndex(where: { $0.id == unitId }),
              let pageIndex = textbooks[textbookIndex].units[unitIndex].pages.firstIndex(where: { $0.id == pageId }) else {
            return
        }
        
        textbooks[textbookIndex].units[unitIndex].pages[pageIndex].annotations = annotations
        saveTextbooks()
    }
    
    func deletePage(_ page: TextbookPage, from textbookId: UUID, unitId: UUID) {
        dataStore.deleteImage(filename: page.imagePath)
        
        guard let textbookIndex = textbooks.firstIndex(where: { $0.id == textbookId }),
              let unitIndex = textbooks[textbookIndex].units.firstIndex(where: { $0.id == unitId }) else {
            return
        }
        
        textbooks[textbookIndex].units[unitIndex].pages.removeAll { $0.id == page.id }
        saveTextbooks()
    }
    
    func renamePage(_ page: TextbookPage, to newName: String, in textbookId: UUID, unitId: UUID) {
        guard let textbookIndex = textbooks.firstIndex(where: { $0.id == textbookId }),
              let unitIndex = textbooks[textbookIndex].units.firstIndex(where: { $0.id == unitId }),
              let pageIndex = textbooks[textbookIndex].units[unitIndex].pages.firstIndex(where: { $0.id == page.id }) else {
            return
        }
        
        textbooks[textbookIndex].units[unitIndex].pages[pageIndex].name = newName
        saveTextbooks()
        
        // 触发 Published 更新，确保视图刷新
        objectWillChange.send()
    }
    
    func addUnit(to textbookId: UUID, name: String) -> TextbookUnit? {
        guard let textbookIndex = textbooks.firstIndex(where: { $0.id == textbookId }) else {
            return nil
        }
        
        let order = textbooks[textbookIndex].units.count
        let unit = TextbookUnit(name: name, order: order)
        textbooks[textbookIndex].units.append(unit)
        saveTextbooks()
        return unit
    }
}
