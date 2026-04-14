import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TextbookViewModel()
    
    var body: some View {
        NavigationStack {
            HomeView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
