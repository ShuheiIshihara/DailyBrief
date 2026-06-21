import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink("動作確認画面へ") {
                    BriefCheckView()
                }
            }
            .navigationTitle("DailyBrief")
        }
    }
}

#Preview {
    ContentView()
}
