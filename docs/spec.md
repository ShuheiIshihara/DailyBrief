# DailyBrief 設計仕様（spec）

個人用の「朝の出発前ブリーフィング」アプリ（愛知・名古屋圏）。
本書は壁打ちで収束した **v1 スコープと実装方針** を記す。背景規約は `../CLAUDE.md`、外部APIの詳細は `external-apis.md`（未作成）を参照。

> ステータス: 設計確定 / 実装未着手（リポジトリは Xcode テンプレートのまま）。

---

## 1. コンセプト

毎朝、出発前に **3秒見れば出発判断ができる** 1画面ブリーフ。
数値（気温・降水など）は API から取得し、**LLM は文章化（整形）だけ**を担当する。

---

## 2. v1 スコープ

### v1 ゴール
**天気 + LLM要約** が 1 画面で動く。

| 項目 | 決定 |
|---|---|
| データ | 気象庁 詳細予報 `forecast`（愛知県予報区 `230000`、キー不要・無料・非公式JSON）。数値を `WeatherDigest` に集約 |
| 要約 | `Summarizer` プロトコル。`TemplateSummarizer`（先・恒久フォールバック）→ LLM 実装（後）で差し替え |
| LLM | llama.cpp 同梱。モデルは **Gemma 4 E2B（Q4 量子化 GGUF）** |
| 並行性 | `actor LLMRuntime`（llama.cpp のスレッド非安全性対応）。遅延ロード、ロード中はテンプレを即表示 |
| 正確性ガード | LLM 出力に「入力に存在しない数値」が現れたらテンプレ文言にフォールバック |
| 更新 | 起動時フェッチ ＋ 引っ張って更新（操作ゼロで成立させる） |

### v1 では作らない（後回し）
- **ODPT 電車遅延**: トークン未取得、名古屋圏事業者の有無も未確認。
  `Config.isTrainEnabled` が空トークン時に `false` を返す段階フォールバック前提で、**v1 は UI 枠のみ／中身は後乗せ**。
- **LLM のマルチモーダル**: Gemma 4 E2B は画像・音声入力対応だが、本アプリは **テキスト→テキストのみ** 使用。vision/audio 用 mmproj は同梱しない。

---

## 3. アーキテクチャ規約

CLAUDE.md §アーキテクチャ規約を本 v1 に具体化したもの。

- **View は表示専念**。HTTP 通信は Service 層（`WeatherService`、将来の `TrainService`）に隔離し、UI 非依存・単体テスト可能に保つ。ViewModel は Service を呼ぶだけで HTTP の詳細を知らない。
- **環境依存値は `Config.swift` に集約**（エリアコード・APIトークン等）。
- **新機能は Service 層と Config への変更に閉じ込める**。既存 View/ViewModel への影響を最小化。
- **段階的フォールバック**: トークン未設定なら機能を自動スキップ。LLM 未ロード／非対応時はテンプレ文言にフォールバック。

### 要約レイヤの構造

```
Summarizer（プロトコル）
  ├─ TemplateSummarizer        ← 先に実装。恒久フォールバック
  └─ LLMSummarizer             ← 後に実装。裏に LLMRuntime を持つ
        └─ actor LLMRuntime    ← llama.cpp をラップ。ロード1回・推論直列化
```

- View / ViewModel は `Summarizer` プロトコルにのみ依存し、テンプレ/LLM の差し替えで手戻りが出ない。
- 入力は `WeatherDigest`（API 数値を集約した構造体）、出力は「短い日本語の朝ブリーフ文（2〜3文）」。
- `WeatherDigest` が「数値はAPI／LLMは整形」の境界面。`WeatherService` が `forecast` JSON から組み立て、`Summarizer` はこれを文章化するだけで数値を生成しない。

---

## 4. 外部API（要点）

詳細は `external-apis.md`（未作成）にて整備予定。

### 気象庁 詳細予報 forecast（v1 で使用）
- 無料・キー不要・非公式 JSON。エンドポイント: `forecast/{府県予報区コード}.json`
- 愛知県は **`230000`** 固定。
- レスポンスは **2要素配列**（`[0]`=短期/3日、`[1]`=週間＋`tempAverage`/`precipAverage`）。本アプリは **`[0]` のみ使用**。
- 各要素の `timeSeries` は **要素ごとに時間軸（`timeDefines`）が別**で、概ね次の並び:
  - `timeSeries[0]`: 天気（`weathers`/`weatherCodes`/`winds`/`waves`）。**一次細分区（西部/東部）単位**＝ここで西部/東部を区別できる。
  - `timeSeries[1]`: 降水確率 `pops`。
  - `timeSeries[2]`: 気温 `temps`（**観測点単位**、例: 名古屋）。
- 現状は最小確認のため、各 `timeSeries` の `areas.first`・配列先頭/末尾を「今日の代表値」として採用している。
  気温・降水確率は時間軸が天気と異なるため、**「今日の代表値」の取り出し位置は今後精緻化の余地あり**（後回し可）。
- 旧 `overview_forecast` は府県予報区単位の散文（西部/東部の区別なし）。散文ではなく数値が必要なため `forecast` を採用した。

### ODPT 電車遅延（v1.1 以降）
- 要 consumerKey（`acl:consumerKey`）。現状トークン未設定で機能オフ。
- `odptOperator` は東京メトロのプレースホルダのまま。**名古屋圏事業者の有無はトークン取得後に要確認**。

---

## 5. LLM 実装メモ（llama.cpp ルート）

### モデル: Gemma 4 E2B
- 実効 2.3B / 生 5.1B、PLE（Per-Layer Embeddings）アーキ、**ライセンス Apache 2.0**（同梱に適する）。
- 量子化: **Q4 で概ね ~3GB**（生 5.1B のため。PLE の重みが効く）。容量が問題なら Q3（~2GB前後）に圧縮する逃げ道あり。
- 配布: **アプリ同梱（Bundle Resources）。GGUF は git に入れない**（後述 §7）。

### ビルド上のリスク（要対応）
- **llama.cpp のバージョン依存**: PLE は新しめのアーキ。xcframework をビルドする llama.cpp は **Gemma 4 / PLE 対応済みの版にピン留め**すること。ここが工程最大の地雷。
- 推論はメインスレッドを塞がない（`actor` ＋バックグラウンド実行）。モデルロードは数秒かかる前提で、初回は必ずテンプレ表示で即応答。

### 正確性ガード
- LLM は「整形のみ」。生成文に対し、**入力に無い数値トークンが出現したらテンプレ文言にフォールバック**する後段チェックを入れ、数値の正確性を機械的に担保する。
- 実装: `LLMSummarizer.passesNumericGuard(output:digest:)`。`digest` の `pop`/`minTemp`/`maxTemp` から許容数値集合を作り、生成文の数値（正規表現抽出）が全て含まれるかを検証。1つでも外れたらフォールバック。

### 実装状況（設計のみ完了 / 実バインディング未差し込み）

- `LLMRuntime`（actor）と `LLMSummarizer` の**骨組みは実装済み**。`BriefCheckView` は `LLMSummarizer` 経由。
- llama.cpp の実バインディングは**未導入**。`LLMRuntime.isAvailable == false` のため、現状は `LLMSummarizer` が静かに `TemplateSummarizer` へフォールバックする（＝今もビルド・動作する）。
- 実バインディング差し込み時の作業:
  1. Gemma 4 E2B の Q4 GGUF を取得し、ファイル名 **`gemma-4-e2b.gguf`**（`LLMRuntime.modelResourceName`）で Xcode の Bundle Resources に追加（`.gitignore` 済）。
  2. llama.cpp を **Gemma 4 / PLE 対応版**で SwiftPM 依存追加 or xcframework リンク。
  3. `LLMRuntime` の2つの TODO を実装:
     - `loadModelIfNeeded()`: backend 初期化 → モデル/コンテキスト生成 → 成功時に `isLoaded = true`。
     - `generate(prompt:)`: トークナイズ → デコードループ → デトークナイズして文字列返却。
  4. 実機で実行確認（Metal/メモリの都合でシミュレータより実機推奨）。

---

## 6. 推奨ビルド順（手戻り最小）

1. ✅ **`WeatherService` ＋ `Config.swift` 雛形** — 気象庁 `forecast` JSON を取得し `WeatherDigest` に集約。
2. ✅ **`TemplateSummarizer` ＋ 確認用 View** — 動作確認画面（`BriefCheckView`）で「天気 + 要約」がテンプレで成立。
3. 🔶 **`LLMRuntime`（actor）＋ `LLMSummarizer`** — 骨組み実装済み。**実バインディングは未差し込み**（§5「実装状況」参照）。
4. ✅ **数値ガード ＆ フォールバック** — `LLMSummarizer` に実装済み。

Xcode テンプレートの SwiftData 部品（`Item` / `ContentView` の CRUD）は**破棄済み**。

> 表示用のメイン画面デザインは別工程。現状は `ContentView` → ボタン → `BriefCheckView`（簡易確認画面）の構成。

---

## 7. シークレット / 大容量ファイルの扱い（整備済み）

`.gitignore` 整備済み:
- ✅ `DailyBrief/DailyBrief/Config.swift` を除外。雛形 `Config.swift.example`（ダミー値）を追跡。初回は `cp Config.swift.example Config.swift` で作る。
  - 注: 雛形は `Config.swift.example`（`.swift` ではない）。Xcode 16 のファイルシステム同期グループでは同フォルダ内の `*.swift` が全てビルド対象になり、`enum Config` が二重定義されるため、コンパイルされない拡張子にしている。
- ✅ `*.gguf` / `*.ggml` を除外。**数GB級をリポジトリに載せない**。手元ビルド時に Bundle へ配置する運用。
- 対象シークレット: ODPT `acl:consumerKey` 等。履歴に載せない。

---

## 8. 環境前提

- iOS Deployment Target **26.5**（最小サポートも 26.5 = 下位互換なし）。
- Swift 言語モード 5.0（Swift 6 strict concurrency ではない）。
- Simulator: iPhone 17 Pro / iOS 26.5。
- 補足: 26.5 ターゲットは Apple Foundation Models（端末内蔵 LLM）も選択可能だが、v1 は **llama.cpp 同梱ルートを採用**（モデルを自前で選べる利点を優先）。
