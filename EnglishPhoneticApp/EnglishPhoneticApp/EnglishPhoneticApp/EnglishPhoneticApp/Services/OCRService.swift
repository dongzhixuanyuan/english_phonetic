import Foundation
import Vision
import UIKit

struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

class OCRService {
    
    func recognizeText(in image: UIImage, completion: @escaping ([OCRResult]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            var results: [OCRResult] = []
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard self.shouldKeep(text: text) else { continue }
                
                // 按空格拆分为独立单词，尝试获取每个单词的精确位置
                let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if words.count > 1 {
                    var searchStart = candidate.string.startIndex
                    var hasAddedWord = false
                    
                    for word in words {
                        guard let range = candidate.string[searchStart...].range(of: word) else { continue }
                        
                        do {
                            let boxObservation = try candidate.boundingBox(for: range)
                            let wordBoundingBox = boxObservation?.boundingBox ?? observation.boundingBox
                            
                            if self.shouldKeep(text: word) {
                                results.append(OCRResult(text: word, boundingBox: wordBoundingBox))
                                hasAddedWord = true
                            }
                        } catch {
                            if self.shouldKeep(text: word) {
                                results.append(OCRResult(text: word, boundingBox: observation.boundingBox))
                                hasAddedWord = true
                            }
                        }
                        
                        searchStart = range.upperBound
                    }
                    
                    // 如果所有单词都未能成功拆分定位，fallback 到整体文本
                    if !hasAddedWord {
                        results.append(OCRResult(text: text, boundingBox: observation.boundingBox))
                    }
                } else {
                    do {
                        let stringRange = candidate.string.startIndex..<candidate.string.endIndex
                        let boxObservation = try candidate.boundingBox(for: stringRange)
                        let boundingBox = boxObservation?.boundingBox ?? observation.boundingBox
                        
                        results.append(OCRResult(text: text, boundingBox: boundingBox))
                    } catch {
                        results.append(OCRResult(text: text, boundingBox: observation.boundingBox))
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.imageOrientation.cgImagePropertyOrientation, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR 识别失败: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    private func shouldKeep(text: String) -> Bool {
        if text.allSatisfy({ $0.isNumber }) { return false }
        if text.count < 2 && text != "I" && text != "a" { return false }
        let letters = text.filter { $0.isLetter }
        if letters.isEmpty { return false }
        return true
    }
}
