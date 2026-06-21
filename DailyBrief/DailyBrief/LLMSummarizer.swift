import Foundation

/// ローカル LLM による整形。`WeatherDigest` の数値だけを使って文章化する。
/// 数値の正確性を担保するため、生成文に「入力に無い数値」が現れたら
/// テンプレ文言にフォールバックする。ランタイム未導入時も同様。
struct LLMSummarizer: Summarizer {
    private let runtime: LLMRuntime
    private let fallback: Summarizer

    init(runtime: LLMRuntime = LLMRuntime(), fallback: Summarizer = TemplateSummarizer()) {
        self.runtime = runtime
        self.fallback = fallback
    }

    func summarize(_ digest: WeatherDigest) async -> String {
        await runtime.loadModelIfNeeded()
        guard await runtime.isAvailable else {
            return await fallback.summarize(digest)
        }

        let prompt = Self.buildPrompt(digest)
        guard let output = await runtime.generate(prompt: prompt),
              Self.passesNumericGuard(output: output, digest: digest) else {
            // 生成失敗 or 数値の捏造 → テンプレへフォールバック
            return await fallback.summarize(digest)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - プロンプト

    static func buildPrompt(_ digest: WeatherDigest) -> String {
        """
        あなたは天気予報を簡潔な日本語にまとめるアシスタントです。
        以下のデータだけを使い、新しい数値を作らず、2〜3文でまとめてください。

        地域: \(digest.area)
        天気: \(digest.todayWeather)
        降水確率: \(digest.pop ?? "不明")%
        最低気温: \(digest.minTemp ?? "不明")℃
        最高気温: \(digest.maxTemp ?? "不明")℃
        """
    }

    // MARK: - 数値ガード

    /// 生成文中の数値が、すべて入力(digest)に含まれる数値であることを検証する。
    /// 入力に無い数値が1つでもあれば false（捏造とみなす）。
    static func passesNumericGuard(output: String, digest: WeatherDigest) -> Bool {
        let allowed = Set([digest.pop, digest.minTemp, digest.maxTemp]
            .compactMap { $0 }
            .flatMap(numbers(in:)))
        let produced = numbers(in: output)
        return produced.allSatisfy { allowed.contains($0) }
    }

    /// 文字列中の数値（整数・小数）を抽出する。
    private static func numbers(in text: String) -> [String] {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
