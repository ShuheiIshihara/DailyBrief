import Foundation

/// llama.cpp をラップするローカル LLM ランタイム。
/// llama.cpp はスレッド非安全のため actor で直列化し、ロードは1回だけ行う。
///
/// 現状は **設計のみ**。実バインディング（llama.cpp の C API 呼び出し）は
/// `loadModel()` / `generate(prompt:)` 内の TODO 箇所に差し込む。
/// バインディング未導入の間は `isAvailable == false` となり、
/// 上位の `LLMSummarizer` がテンプレ文言へフォールバックする。
actor LLMRuntime {
    /// Bundle に配置する GGUF のリソース名（拡張子なし）。git 除外・手動配置。
    static let modelResourceName = "gemma-4-e2b"
    static let modelResourceExtension = "gguf"

    private var isLoaded = false

    /// 推論が実行可能か。モデル未配置／バインディング未導入なら false。
    var isAvailable: Bool { isLoaded }

    /// モデルを一度だけロードする。失敗しても投げずに false 状態を維持する。
    func loadModelIfNeeded() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(
            forResource: Self.modelResourceName,
            withExtension: Self.modelResourceExtension
        ) else {
            // モデル未配置。テンプレにフォールバックする。
            return
        }

        // TODO: llama.cpp バインディング差し込み箇所。
        //   - llama_backend_init()
        //   - llama_model_load_from_file(url.path, params)
        //   - llama_init_from_model(...) で context 生成
        //   ロード成功時のみ isLoaded = true にする。
        _ = url
        // 実バインディング未導入のため、現状はロード未完了のまま。
        isLoaded = false
    }

    /// プロンプトから生成。バインディング未導入のうちは nil を返す（呼び出し側でフォールバック）。
    func generate(prompt: String) -> String? {
        guard isLoaded else { return nil }

        // TODO: llama.cpp バインディング差し込み箇所。
        //   - トークナイズ → デコードループ → デトークナイズ
        //   - 生成文字列を返す。
        return nil
    }
}
