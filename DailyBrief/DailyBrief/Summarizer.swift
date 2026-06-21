import Foundation

/// 天気ダイジェストを短い日本語ブリーフ文に整形する。
/// 実装は TemplateSummarizer（先）→ LLM 実装（後）で差し替える。
protocol Summarizer {
    func summarize(_ digest: WeatherDigest) async -> String
}

/// LLM 未導入時の恒久フォールバック。API の数値をそのまま組み立てる。
/// 数値を生成しないため、正確性は構造的に担保される。
struct TemplateSummarizer: Summarizer {
    func summarize(_ digest: WeatherDigest) async -> String {
        var s = "【\(digest.area)】今日は\(digest.todayWeather)。"
        if let min = digest.minTemp, let max = digest.maxTemp {
            s += " 気温は\(min)〜\(max)℃。"
        } else if let max = digest.maxTemp {
            s += " 最高気温\(max)℃。"
        }
        if let pop = digest.pop {
            s += " 降水確率\(pop)%。"
        }
        return s
    }
}
