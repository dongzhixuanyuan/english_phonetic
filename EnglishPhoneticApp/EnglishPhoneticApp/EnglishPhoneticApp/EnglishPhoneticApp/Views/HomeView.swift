import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: TextbookViewModel
    @State private var showingAddTextbook = false
    @State private var newTextbookName = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("英语音标点读")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("给课本拍张照，秒变会说话的音标点读机")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if let sampleTextbook = viewModel.textbooks.first(where: { $0.name == "示例课本" }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\u{1F44B} 先试试示例")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        SamplePagesRow(viewModel: viewModel, textbook: sampleTextbook)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\u{1F4DA} 我的课本")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button {
                            showingAddTextbook = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    let userTextbooks = viewModel.textbooks.filter { $0.name != "示例课本" }
                    
                    if userTextbooks.isEmpty {
                        EmptyTextbooksView()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(userTextbooks) { textbook in
                                NavigationLink(value: textbook) {
                                    TextbookCard(textbook: textbook)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationDestination(for: Textbook.self) { textbook in
            TextbookDetailView(viewModel: viewModel, textbookId: textbook.id)
        }
        .alert("添加课本", isPresented: $showingAddTextbook) {
            TextField("课本名称", text: $newTextbookName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newTextbookName.isEmpty {
                    viewModel.addTextbook(name: newTextbookName)
                    newTextbookName = ""
                }
            }
        } message: {
            Text("请输入课本名称，例如：人教版三年级上册")
        }
    }
}

struct SamplePagesRow: View {
    @ObservedObject var viewModel: TextbookViewModel
    let textbook: Textbook
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(textbook.units) { unit in
                    ForEach(unit.pages) { page in
                        SamplePageCard(unit: unit, page: page)
                    }
                }
                
                if textbook.units.allSatisfy({ $0.pages.isEmpty }) {
                    SamplePlaceholderCard()
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SamplePageCard: View {
    let unit: TextbookUnit
    let page: TextbookPage
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
            
            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text(unit.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(page.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 200)
    }
}

struct SamplePlaceholderCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("示例页")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("点击添加示例")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 200)
    }
}

struct EmptyTextbooksView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("还没有课本")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 号，添加孩子的英语课本")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

struct TextbookCard: View {
    let textbook: Textbook
    
    var totalPages: Int {
        textbook.units.reduce(0) { $0 + $1.pages.count }
    }
    
    var body: some View {
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
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 70, height: 90)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(textbook.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(totalPages) 页 · \(textbook.units.count) 个单元")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("最近学习: \(formatDate(textbook.createdAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: TextbookViewModel())
    }
}
