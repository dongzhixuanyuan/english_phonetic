import Foundation
import UIKit

class DataStoreService {
    static let shared = DataStoreService()
    
    private let textbooksKey = "saved_textbooks"
    
    private init() {}
    
    func saveTextbooks(_ textbooks: [Textbook]) {
        if let data = try? JSONEncoder().encode(textbooks) {
            UserDefaults.standard.set(data, forKey: textbooksKey)
        }
    }
    
    func loadTextbooks() -> [Textbook] {
        guard let data = UserDefaults.standard.data(forKey: textbooksKey),
              let textbooks = try? JSONDecoder().decode([Textbook].self, from: data) else {
            return []
        }
        return textbooks
    }
    
    func saveImage(_ image: UIImage, forPageId pageId: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let filename = "\(pageId.uuidString).jpg"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("保存图片失败: \(error)")
            return nil
        }
    }
    
    func loadImage(filename: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteImage(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
