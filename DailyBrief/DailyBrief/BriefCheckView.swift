import SwiftUI

/// 動作確認用の簡易画面（デザインは別工程）。
/// 天気取得 → Summarizer 整形 の経路を実機で確認する。
struct BriefCheckView: View {
    private let weatherService = WeatherService()
    private let summarizer: Summarizer = TemplateSummarizer()

    @State private var summary = ""
    @State private var rawText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(isLoading ? "取得中…" : "取得して要約") {
                    Task { await run() }
                }
                .disabled(isLoading)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                if !summary.isEmpty {
                    Text("要約").font(.headline)
                    Text(summary)
                }

                if !rawText.isEmpty {
                    Text("生データ").font(.headline)
                    Text(rawText).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("動作確認")
    }

    private func run() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let digest = try await weatherService.fetchForecast()
            summary = await summarizer.summarize(digest)
            rawText = """
            地域: \(digest.area)
            発表: \(digest.reportDatetime)
            天気: \(digest.todayWeather)
            降水確率: \(digest.pop ?? "—")%
            気温: \(digest.minTemp ?? "—")〜\(digest.maxTemp ?? "—")℃
            """
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
