import Foundation

class PhoneticDictionaryService {
    static let shared = PhoneticDictionaryService()
    
    private var phoneticDict: [String: String] = [:]
    private var meaningDict: [String: String] = [:]
    private let userDefaultsKey = "user_phonetic_extensions"
    
    private init() {
        loadDictionary()
    }
    
    private func loadDictionary() {
        if let url = Bundle.main.url(forResource: "phonetic_dictionary", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            for (word, info) in json {
                let key = word.lowercased()
                phoneticDict[key] = info["phonetic"]
                meaningDict[key] = info["meaning"]
            }
        }
        
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedDict = try? JSONDecoder().decode([String: String].self, from: savedData) {
            for (word, phonetic) in savedDict {
                phoneticDict[word.lowercased()] = phonetic
            }
        }
        
        print("📚 音标词库加载完成，共 \(phoneticDict.count) 个单词")
    }
    
    func lookup(_ word: String) -> String? {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return phoneticDict[cleanWord]
    }
    
    func lookupMeaning(_ word: String) -> String? {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return meaningDict[cleanWord]
    }
    
    func addCustomPhonetic(word: String, phonetic: String) {
        let key = word.lowercased()
        phoneticDict[key] = phonetic
        saveUserExtensions()
    }
    
    private func saveUserExtensions() {
        if let data = try? JSONEncoder().encode(phoneticDict) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
