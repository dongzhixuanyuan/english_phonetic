import SwiftUI

struct ReaderView: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbook: Textbook
    let unit: TextbookUnit
    @State var page: TextbookPage
    
    @State private var isEditMode = false
    @State private var selectedAnnotationId: UUID?
    @State private var showingEditSheet = false
    @State private var editWord = ""
    @State private var editPhonetic = ""
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedPopoverAnnotation: WordAnnotation?
    
    private let speechService = SpeechService.shared
    
    var body: some View {
        ZStack {
            if let image = DataStoreService.shared.loadImage(filename: page.imagePath) {
                GeometryReader { geometry in
                    let imageSize = calculateImageSize(container: geometry.size, image: image)
                    let xOffset = (geometry.size.width - imageSize.width) / 2
                    let yOffset = (geometry.size.height - imageSize.height) / 2
                    
                    ZStack {
                        let pixelSize = CGSize(width: CGFloat(image.cgImage?.width ?? Int(image.size.width)), height: CGFloat(image.cgImage?.height ?? Int(image.size.height)))
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .scaleEffect(scale)
                            .offset(offset)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPopoverAnnotation = nil
                            }
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        
                        ForEach(page.annotations) { annotation in
                            let frame = annotationFrame(
                                annotation: annotation,
                                pixelImageSize: pixelSize,
                                displayImageSize: imageSize,
                                xOffset: xOffset,
                                yOffset: yOffset
                            )
                            let isPopoverVisible = selectedPopoverAnnotation?.id == annotation.id
                            
                            WordBoundingBox(
                                annotation: annotation,
                                frame: frame,
                                isPopoverVisible: isPopoverVisible,
                                isSpeaking: speechService.currentWord?.lowercased() == annotation.word.lowercased(),
                                isEditMode: isEditMode,
                                isSelected: selectedAnnotationId == annotation.id
                            )
                            .position(x: frame.midX, y: frame.midY)
                            .scaleEffect(scale)
                            .offset(offset)
                            .onTapGesture {
                                handleAnnotationTap(annotation)
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if isEditMode {
                                            moveAnnotation(annotation, by: value.translation, in: imageSize)
                                        }
                                    }
                                    .onEnded { _ in
                                        if isEditMode {
                                            saveAnnotations()
                                        }
                                    }
                            )
                        }
                        
                        // 浮层显示
                        if let popoverAnnotation = selectedPopoverAnnotation {
                            let popoverFrame = annotationFrame(
                                annotation: popoverAnnotation,
                                pixelImageSize: pixelSize,
                                displayImageSize: imageSize,
                                xOffset: xOffset,
                                yOffset: yOffset
                            )
                            
                            WordPopoverView(
                                annotation: popoverAnnotation,
                                onSpeak: {
                                    speechService.speak(popoverAnnotation.word)
                                },
                                onClose: {
                                    selectedPopoverAnnotation = nil
                                }
                            )
                            .position(
                                x: popoverFrame.midX,
                                y: max(popoverFrame.minY - 60, 40)
                            )
                            .scaleEffect(scale)
                            .offset(offset)
                        }
                    }
                }
            } else {
                Text("无法加载图片")
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Spacer()
                bottomToolbar
            }
        }
        .navigationTitle(page.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            AnnotationEditSheet(
                word: $editWord,
                phonetic: $editPhonetic,
                onSave: saveEditedAnnotation,
                onDelete: deleteSelectedAnnotation
            )
        }
    }
    
    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation {
                    isEditMode.toggle()
                    selectedAnnotationId = nil
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.title2)
                    Text(isEditMode ? "完成" : "编辑")
                        .font(.caption)
                }
                .foregroundColor(isEditMode ? .green : .blue)
            }
            
            if isEditMode {
                Button {
                    reprocessPage()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                        Text("重识")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if scale > 1.0 {
                Button {
                    withAnimation {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title2)
                        Text("重置")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func handleAnnotationTap(_ annotation: WordAnnotation) {
        if isEditMode {
            selectedAnnotationId = annotation.id
            editWord = annotation.word
            editPhonetic = annotation.phonetic
            showingEditSheet = true
            selectedPopoverAnnotation = nil
        } else {
            selectedPopoverAnnotation = annotation
        }
    }
    
    private func calculateImageSize(container: CGSize, image: UIImage) -> CGSize {
        let aspectRatio = image.size.width / image.size.height
        let containerAspectRatio = container.width / container.height
        
        if aspectRatio > containerAspectRatio {
            let width = container.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        } else {
            let height = container.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        }
    }
    
    private func annotationFrame(annotation: WordAnnotation, pixelImageSize: CGSize, displayImageSize: CGSize, xOffset: CGFloat, yOffset: CGFloat) -> CGRect {
        let scaleX = displayImageSize.width / pixelImageSize.width
        let scaleY = displayImageSize.height / pixelImageSize.height
        
        let x = xOffset + CGFloat(annotation.normalizedX) * pixelImageSize.width * scaleX
        let y = yOffset + (1.0 - CGFloat(annotation.normalizedY) - CGFloat(annotation.normalizedHeight)) * pixelImageSize.height * scaleY
        let width = CGFloat(annotation.normalizedWidth) * pixelImageSize.width * scaleX
        let height = CGFloat(annotation.normalizedHeight) * pixelImageSize.height * scaleY
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func moveAnnotation(_ annotation: WordAnnotation, by translation: CGSize, in imageSize: CGSize) {
        guard let index = page.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        
        let deltaX = Double(translation.width / imageSize.width)
        let deltaY = Double(-translation.height / imageSize.height)
        
        page.annotations[index].normalizedX += deltaX
        page.annotations[index].normalizedY += deltaY
    }
    
    private func saveAnnotations() {
        viewModel.updateAnnotations(for: page.id, in: textbook.id, unitId: unit.id, annotations: page.annotations)
    }
    
    private func saveEditedAnnotation() {
        if let selectedId = selectedAnnotationId,
           let index = page.annotations.firstIndex(where: { $0.id == selectedId }) {
            page.annotations[index].word = editWord
            
            if editPhonetic.isEmpty {
                if let phonetic = PhoneticDictionaryService.shared.lookup(editWord) {
                    page.annotations[index].phonetic = phonetic
                }
            } else {
                page.annotations[index].phonetic = editPhonetic
                PhoneticDictionaryService.shared.addCustomPhonetic(word: editWord, phonetic: editPhonetic)
            }
        } else {
            let newAnnotation = WordAnnotation(
                word: editWord,
                phonetic: editPhonetic.isEmpty ? (PhoneticDictionaryService.shared.lookup(editWord) ?? "") : editPhonetic,
                normalizedX: 0.4,
                normalizedY: 0.4,
                normalizedWidth: 0.2,
                normalizedHeight: 0.05
            )
            page.annotations.append(newAnnotation)
        }
        
        saveAnnotations()
        showingEditSheet = false
        selectedAnnotationId = nil
    }
    
    private func deleteSelectedAnnotation() {
        if let selectedId = selectedAnnotationId {
            page.annotations.removeAll { $0.id == selectedId }
            saveAnnotations()
        }
        showingEditSheet = false
        selectedAnnotationId = nil
    }
    
    private func reprocessPage() {
        guard let image = DataStoreService.shared.loadImage(filename: page.imagePath) else { return }
        
        viewModel.isProcessing = true
        viewModel.processingProgress = "重新识别中..."
        
        OCRService().recognizeText(in: image) {  results in
            DispatchQueue.main.async {
                //                guard let self = self else { return }
                
                var annotations: [WordAnnotation] = []
                for result in results {
                    let annotation = WordAnnotation(
                        word: result.text,
                        phonetic: PhoneticDictionaryService.shared.lookup(result.text) ?? "",
                        normalizedX: Double(result.boundingBox.origin.x),
                        normalizedY: Double(result.boundingBox.origin.y),
                        normalizedWidth: Double(result.boundingBox.width),
                        normalizedHeight: Double(result.boundingBox.height)
                    )
                    annotations.append(annotation)
                }
                
                self.page.annotations = annotations
                self.saveAnnotations()
                
                self.viewModel.isProcessing = false
                self.viewModel.processingProgress = ""
            }
        }
    }
}
struct WordBoundingBox: View {
    let annotation: WordAnnotation
    let frame: CGRect
    let isPopoverVisible: Bool
    let isSpeaking: Bool
    let isEditMode: Bool
    let isSelected: Bool
    
    var body: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [4]))
            .foregroundColor(borderColor)
            .frame(width: frame.width, height: frame.height)
            .background(backgroundColor)
            .contentShape(Rectangle())
            .scaleEffect(isSpeaking ? 1.05 : 1.0)
            .animation(.spring(response: 0.2), value: isSpeaking)
    }
    
    private var backgroundColor: Color {
        if isPopoverVisible {
            return .blue.opacity(0.15)
        }
        if isSpeaking {
            return .blue.opacity(0.2)
        }
        if isSelected {
            return .yellow.opacity(0.25)
        }
        return .clear
    }
    
    private var borderColor: Color {
        if isPopoverVisible {
            return .blue
        }
        if isSpeaking {
            return .blue
        }
        if isSelected {
            return .orange
        }
        if annotation.phonetic.isEmpty {
            return .red.opacity(0.6)
        }
        return .gray.opacity(0.5)
    }
}

struct WordPopoverView: View {
    let annotation: WordAnnotation
    let onSpeak: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(annotation.word)
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            
            if !annotation.phonetic.isEmpty {
                Text(annotation.phonetic)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            if let meaning = PhoneticDictionaryService.shared.lookupMeaning(annotation.word), !meaning.isEmpty {
                Text(meaning)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct AnnotationEditSheet: View {
    @Binding var word: String
    @Binding var phonetic: String
    let onSave: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("单词") {
                    TextField("输入单词", text: $word)
                        .autocapitalization(.none)
                }
                
                Section("音标") {
                    TextField("输入音标（可选）", text: $phonetic)
                        .autocapitalization(.none)
                    
                    if phonetic.isEmpty && !word.isEmpty {
                        if let autoPhonetic = PhoneticDictionaryService.shared.lookup(word) {
                            Text("自动匹配: \(autoPhonetic)")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("词库中未找到该单词，请手动输入音标")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle(word.isEmpty ? "添加标注" : "编辑标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave()
                    }
                    .disabled(word.isEmpty)
                }
                
                if !word.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("删除标注", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(
            viewModel: TextbookViewModel(),
            textbook: Textbook(name: "测试"),
            unit: TextbookUnit(name: "Unit 1", order: 0),
            page: TextbookPage(name: "Page 1", imagePath: "", order: 0)
        )
    }
}
