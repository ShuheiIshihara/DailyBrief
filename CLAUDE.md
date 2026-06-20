# CLAUDE.md

Claude Code（claude.ai/code）がこのリポジトリで作業する際のガイド。
設計の詳細・背景は `docs/spec.md`、外部APIの詳細は `docs/external-apis.md` を参照する。

## 最重要: 現状と実装方針

このリポジトリは **設計（handoff）と実コードに乖離** がある。着手前に必ず把握すること。

- 実コード `DailyBrief/DailyBrief/` は Xcode 標準の SwiftUI + Core Data **テンプレートのまま**。
  `ContentView.swift` は `Item` を CRUD するボイラープレート、`Persistence.swift` はデフォルトの Core Data スタック。
  handoff が記す `Services/` `Models/` `Views/` `Config.swift` の構成は **未実装**。
- 機能を実装する際は、このテンプレートの Core Data 部品を **流用せず**、
  handoff §3〜4 の View / Service / Config 分離方針に沿って **新規構築** する。
- アプリ名は実プロジェクト名の **DailyBrief** に統一する（handoff 内の "MorningBrief" は旧称）。

## ディレクトリ構成

リポジトリルート（= git ルート / この CLAUDE.md がある階層）を起点に記載する。

```
.                                # リポジトリルート（git ルート）
├── .claude/                     # Claude Code 設定
├── .gitignore                   # Config.swift 等を除外（後述）
├── CLAUDE.md
├── LICENSE
├── README.md
├── docs/
│   │── spec.md                  # 設計仕様
│   └── external-apis.md         # 外部API詳細メモ
└── DailyBrief/                  # Xcodeプロジェクトルート（ここで xcodebuild を実行）
    ├── DailyBrief.xcodeproj
    ├── DailyBrief/              # アプリ本体ソース
    ├── DailyBriefTests/         # ユニットテスト
    └── DailyBriefUITests/       # UIテスト
```

## ビルド・テストコマンド

すべてリポジトリルートから `DailyBrief/`（`.xcodeproj` のある Xcodeプロジェクトルート）へ移動して実行する。

```bash
cd DailyBrief   # リポジトリルートから Xcodeプロジェクトルートへ

# ビルド（Simulator向け。Simulator名は環境に合わせて調整）
xcodebuild build -scheme DailyBrief -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 全テスト
xcodebuild test -scheme DailyBrief -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 単体テストのみ（クラス／メソッド指定）
xcodebuild test -scheme DailyBrief -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DailyBriefTests/<ClassName>/<testMethod>

# 利用可能な Simulator / destination の確認
xcrun simctl list devices available
xcodebuild -showdestinations -scheme DailyBrief
```

- ターゲット: `DailyBrief`（アプリ）/ `DailyBriefTests`（ユニット）/ `DailyBriefUITests`（UI）
- 単一スキーム `DailyBrief`

## ツール環境

- iOS Deployment Target **26.5**（最小サポートも 26.5 = 下位互換なし。意図通りか要確認）
- Swift **言語モード 5.0**（Swift 6 モードではない＝strict concurrency 緩め）
- Simulator: iPhone 17 Pro / iOS 26.5
- 対応する Xcode が必要（`xcodebuild -version` で想定値を確認・記載すること）

## アーキテクチャ規約（必ず遵守。背景・全文は handoff §3〜4）

- **View は表示専念**。HTTP 通信は Service 層（`WeatherService` / `TrainService`）に隔離し、
  UI 非依存・単体テスト可能に保つ。ViewModel は Service を呼ぶだけで HTTP の詳細を知らない。
- **環境依存値は `Config.swift` に集約**（エリアコード・APIトークン等）。
- **新機能は Service 層と Config への変更に閉じ込める**。既存 View/ViewModel への影響を最小化（GPS化・LLM要約も同方針）。
- **段階的フォールバック**: トークン未設定なら機能を自動スキップ（例 `Config.isTrainEnabled` が空文字トークン時に `false`）。
  LLM 要約もモデル未導入時はテンプレート文言にフォールバック。
- **LLM の役割は「整形」のみ**: 数値の正確性担保のため生データは API から取得し、LLM は文章化だけを担当。
  実装順は `TemplateSummarizer`（先・アーキを通す）→ `LLMRuntime`（後・llama.cpp のスレッド非安全性対応で `actor` 実装）。

## シークレット / 環境値の扱い

- `Config.swift` は **`.gitignore` 対象**。APIトークン等を含むためコミットしない。
- 雛形 `Config.example.swift`（ダミー値）を追跡し、初回はこれを複製して `Config.swift` を作る。
- 対象シークレット: ODPT `acl:consumerKey` 等。**履歴に載せないこと**。

## 外部API（要点のみ。詳細は `docs/external-apis.md`）

- **気象庁 概況予報**（無料・キー不要・非公式JSON）:
  `overview_forecast/{府県予報区コード}.json`。愛知県は **`230000`** 固定。
  概況は府県予報区単位の発表のため、**愛知県内のどの地点でも同一JSON** が返る（仕様であってバグではない）。
  「西部/東部」の区別は詳細予報 `forecast` 側の一次細分の話で、overview には無い。
- **ODPT（電車遅延）**: 要 consumerKey。現状トークン未設定で機能オフ。
  `odptOperator` は東京メトロのプレースホルダのまま。名古屋圏事業者の有無はトークン取得後に要確認。

## 規約

- コミットメッセージは **日本語**（`動詞: 説明`、50字以内）。ユーザーへの応答も **日本語**。
- コード内コメントは日本語可（ビジネスロジック説明）、変数・関数名は英語。
- 個人用ツールのためエラーハンドリングは最低限（`APIError` での文言集約のみ想定）。リトライ等の本番品質は対象外。
- グローバル設定 `~/.claude/CLAUDE.md` に従う（うち ES module 等の JS 系一般規約は本 Swift プロジェクト対象外）。
