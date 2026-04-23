import SwiftUI
import PhotosUI

struct TextbookDetailView: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbookId: UUID
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingAddUnit = false
    @State private var newUnitName = ""
    @State private var selectedUnitId: UUID?
    @State private var showingEditPageName = false
    @State private var newPageName = ""
    @State private var pageToRename: TextbookPage?
    @State private var unitIdForRename: UUID?
    @State private var showingSettings = false
    @State private var navigateToNewPage = false
    @State private var newlyAddedPage: TextbookPage?
    @State private var newlyAddedUnitId: UUID?
    @AppStorage("reader_auto_speak_on_popover") private var autoSpeakOnPopover = true
    
    private var textbook: Textbook? {
        viewModel.textbooks.first(where: { $0.id == textbookId })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let textbook = textbook {
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
                            
                            Text("\(totalPages) 页 · \(textbook.units.count) 个单元")
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
                                },
                                pageToRename: $pageToRename,
                                newPageName: $newPageName,
                                showingEditPageName: $showingEditPageName,
                                unitIdForRename: $unitIdForRename
                            )
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("课本详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToNewPage) {
            if let textbook = textbook,
               let unitId = newlyAddedUnitId,
               let unit = textbook.units.first(where: { $0.id == unitId }),
               let page = newlyAddedPage {
                ReaderView(
                    viewModel: viewModel,
                    textbook: textbook,
                    unit: unit,
                    page: page
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                Form {
                    Section("点读设置") {
                        Toggle("点击浮层自动发音", isOn: $autoSpeakOnPopover)
                    }
                }
                .navigationTitle("设置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            showingSettings = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerSheet(
                selectedImage: $selectedImage,
                showingCamera: $showingCamera,
                showingPhotoLibrary: $showingPhotoLibrary
            )
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
        }
        .alert("添加单元", isPresented: $showingAddUnit) {
            TextField("单元名称", text: $newUnitName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newUnitName.isEmpty {
                    viewModel.addUnit(to: textbookId, name: newUnitName)
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
        .alert("重命名页面", isPresented: $showingEditPageName) {
            TextField("页面名称", text: $newPageName)
            Button("取消", role: .cancel) { }
            Button("保存") {
                if let page = pageToRename, let unitId = unitIdForRename, !newPageName.isEmpty {
                    viewModel.renamePage(page, to: newPageName, in: textbookId, unitId: unitId)
                }
                pageToRename = nil
                unitIdForRename = nil
            }
        } message: {
            Text("请输入新的页面名称")
        }
    }
    
    private var totalPages: Int {
        textbook?.units.reduce(0) { $0 + $1.pages.count } ?? 0
    }
    
    private func addPage(image: UIImage, unitId: UUID) {
        let pageName = "Page \(totalPages + 1)"
        viewModel.addPage(to: textbookId, unitId: unitId, image: image, pageName: pageName) { page in
            selectedImage = nil
            selectedUnitId = nil
            if let page = page {
                newlyAddedPage = page
                newlyAddedUnitId = unitId
                navigateToNewPage = true
            }
        }
    }
}

struct UnitSection: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbook: Textbook
    let unit: TextbookUnit
    let onAddPage: () -> Void
    @State private var isExpanded = true
    @Binding var pageToRename: TextbookPage?
    @Binding var newPageName: String
    @Binding var showingEditPageName: Bool
    @Binding var unitIdForRename: UUID?
    
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
                    
                    Text("\(unit.pages.count) 页")
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
                            ZStack(alignment: .topTrailing) {
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
                                
                                Menu {
                                    Button {
                                        pageToRename = page
                                        unitIdForRename = unit.id
                                        newPageName = page.name
                                        showingEditPageName = true
                                    } label: {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        viewModel.deletePage(page, from: textbook.id, unitId: unit.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(4)
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
    @Binding var showingPhotoLibrary: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingCamera = true
                    }
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
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingPhotoLibrary = true
                    }
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
        TextbookDetailView(viewModel: TextbookViewModel(), textbookId: UUID())
    }
}
