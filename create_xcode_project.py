import os

project_dir = "/Users/dongliu/dongLiu/ios_learning/english_phonetic/EnglishPhoneticApp"

# Write updated TextbookDetailView.swift with PhotosPicker
textbookdetail = '''import SwiftUI
import PhotosUI

struct TextbookDetailView: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbook: Textbook
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingAddUnit = false
    @State private var newUnitName = ""
    @State private var selectedUnitId: UUID?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.15))
                        
                        if let coverPath = textbook.coverImagePath,
                           let image = DataStoreService.shared.loadImage(filename: coverPath) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                        }
                    }
                    .frame(width: 80, height: 100)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(textbook.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\\(totalPages) 页 · \\(textbook.units.count) 个单元")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Button {
                    showingAddUnit = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("添加单元")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                
                if textbook.units.isEmpty {
                    EmptyUnitView()
                        .padding(.horizontal)
                } else {
                    ForEach(textbook.units.sorted(by: { $0.order < $1.order })) { unit in
                        UnitSection(
                            viewModel: viewModel,
                            textbook: textbook,
                            unit: unit,
                            onAddPage: {
                                selectedUnitId = unit.id
                                showingImagePicker = true
                            }
                        )
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("课本详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerSheet(
                selectedImage: $selectedImage,
                showingCamera: $showingCamera,
                selectedPhotoItem: $selectedPhotoItem
            )
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .photosPicker(
            isPresented: .constant(selectedPhotoItem != nil || false),
            selection: $selectedPhotoItem,
            matching: .images
        )
        .alert("添加单元", isPresented: $showingAddUnit) {
            TextField("单元名称", text: $newUnitName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newUnitName.isEmpty {
                    viewModel.addUnit(to: textbook.id, name: newUnitName)
                    newUnitName = ""
                }
            }
        } message: {
            Text("例如：Unit 1 Hello")
        }
        .overlay {
            if viewModel.isProcessing {
                ProcessingOverlay(message: viewModel.processingProgress)
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage, let unitId = selectedUnitId {
                addPage(image: image, unitId: unitId)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }
    
    private var totalPages: Int {
        textbook.units.reduce(0) { $0 + $1.pages.count }
    }
    
    private func addPage(image: UIImage, unitId: UUID) {
        let pageName = "Page \\(totalPages + 1)"
        viewModel.addPage(to: textbook.id, unitId: unitId, image: image, pageName: pageName) { page in
            selectedImage = nil
            selectedUnitId = nil
        }
    }
}

struct UnitSection: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbook: Textbook
    let unit: TextbookUnit
    let onAddPage: () -> Void
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(unit.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\\(unit.pages.count) 页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
            }
            .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(unit.pages.sorted(by: { $0.order < $1.order })) { page in
                            NavigationLink {
                                ReaderView(
                                    viewModel: viewModel,
                                    textbook: textbook,
                                    unit: unit,
                                    page: page
                                )
                            } label: {
                                PageThumbnail(page: page)
                            }
                        }
                    }
                    
                    Button {
                        onAddPage()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("添加页面")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct PageThumbnail: View {
    let page: TextbookPage
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                
                if let image = DataStoreService.shared.loadImage(filename: page.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 100, height: 130)
            .clipped()
            
            Text(page.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct EmptyUnitView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("还没有单元")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("先添加一个单元，再拍照导入课本页面")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

struct ImagePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingCamera: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Environment(\\.dismiss) private var dismiss
    @State private var showingPhotosPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button {
                    showingCamera = true
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("拍照")
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                
                Button {
                    showingPhotosPicker = true
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                        Text("从相册选择")
                            .font(.title3)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("选择图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .photosPicker(
                isPresented: $showingPhotosPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
        }
    }
}

struct ProcessingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}

#Preview {
    NavigationStack {
        TextbookDetailView(viewModel: TextbookViewModel(), textbook: Textbook(name: "测试课本"))
    }
}
'''

with open(os.path.join(project_dir, "EnglishPhoneticApp/Views/TextbookDetailView.swift"), "w") as f:
    f.write(textbookdetail)

print("Updated TextbookDetailView.swift with PhotosPicker")
