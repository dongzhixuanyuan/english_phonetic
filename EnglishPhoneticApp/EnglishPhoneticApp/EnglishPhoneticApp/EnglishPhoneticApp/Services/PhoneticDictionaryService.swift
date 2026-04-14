import Foundation

class PhoneticDictionaryService {
    static let shared = PhoneticDictionaryService()
    
    private var dictionary: [String: String] = [:]
    private let userDefaultsKey = "user_phonetic_extensions"
    
    private init() {
        loadDictionary()
    }
    
    private func loadDictionary() {
        if let url = Bundle.main.url(forResource: "phonetic_dictionary", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            for (word, info) in json {
                dictionary[word.lowercased()] = info["phonetic"]
            }
        }
        
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedDict = try? JSONDecoder().decode([String: String].self, from: savedData) {
            for (word, phonetic) in savedDict {
                dictionary[word.lowercased()] = phonetic
            }
        }
        
        print("\u{1F4DA} 音标词库加载完成，共 \(dictionary.count) 个单词")
    }
    
    func lookup(_ word: String) -> String? {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return dictionary[cleanWord]
    }
    
    func addCustomPhonetic(word: String, phonetic: String) {
        let key = word.lowercased()
        dictionary[key] = phonetic
        saveUserExtensions()
    }
    
    private func saveUserExtensions() {
        if let data = try? JSONEncoder().encode(dictionary) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
