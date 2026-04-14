import Foundation
import Vision
import UIKit

struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
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
                
                do {
                    let stringRange = candidate.string.startIndex..<candidate.string.endIndex
                    let boxObservation = try candidate.boundingBox(for: stringRange)
                    let boundingBox = boxObservation?.boundingBox ?? observation.boundingBox
                    
                    results.append(OCRResult(text: text, boundingBox: boundingBox))
                } catch {
                    results.append(OCRResult(text: text, boundingBox: observation.boundingBox))
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
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
