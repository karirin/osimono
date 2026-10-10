# ストーリーモード

## 実装

個別チャットタブの「ストーリーモード」から一覧に入り、1〜3人の登録済み推しを選んで作成します。既存の5タブは維持しています。学園・シェアハウス・ファンタジー、3種類の雰囲気、恋愛有無、主人公／一員、名前・役柄・主役・出演者の配役・推し同士の関係を保存します。

`StoryModels` が全3話×3場面の進行と構造化応答の検証を担当します。`StorySession` が生成・保存の状態を管理し、`StoryRepository` が Firebase Realtime Database、`StoryAIService` と `StoryPrompt` が既存の `AIClient` を担当します。SwiftUIは一覧・作成・本文表示を分離しています。日本語と英語を既存の Localizable.strings に追加しています。

保存先は `stories/{uid}/{storyID}`。開始時の推しプロフィール・画像URL・配役と関係を複製し、設定・全本文・選択履歴をJSONに保存します。元プロフィール全体も `sourceProfileJSON` に保管します。通常チャット、ロールプレイ、親密度、元の推しへの書き込みはありません。AI用のプロフィールは各項目600文字までを保持し、送信時は各200文字に制限します。自由入力300文字、全本文は最大9場面、入力コンテキストは30,000文字以内、保存データは120,000バイト以内です。画像は既存URLを参照するため、画像ファイルが消えた場合は代替アイコンを表示します。

進行番号と完結判定はアプリ側で確定します。最終場面の選択肢は空配列のみ受け付け、画面にも次の行動欄を表示しません。章の末尾で行動を選ぶと「次の話へ」を表示します。本文が保存済みの物語を開いただけでは生成しません。

設定の作成を保存した後に最初の場面を生成します。場面と直前の選択は一つのトランザクションで保存し、サーバーの成功通知まで表示を進めません。保存失敗時は候補・操作IDを保持し、再生成せず保存だけ再試行します。同じ操作IDと内容は冪等に処理し、古いリビジョンは競合として拒否します。競合時は一覧を更新して開き直します。画面を閉じた場合や認証ユーザーが変わった場合、遅延したAI応答は保存しません。既に送信済みの保存は固定の元ユーザー・物語のパスで処理されます。

トランザクションの成功通知は30秒でタイムアウトとして扱い、保存候補を保持します。Firebaseが後から元の書き込みを確定しても同じ操作IDで判定できるため、再試行による二重進行はありません。タイムアウトと遅延した成功通知が競合しても、継続処理は一度だけ実行します。

AIは既存の `asia-northeast1/aiChat` にJSON modeで要求します。返答が形式検証に失敗したときだけ、形式を明示して1回再生成します。通信・認証エラーは自動再試行しません。既存のアプリ側 `MessageLimitManager` の通常利用枠を1場面につき1回消費し、読み返しや保存だけの再試行では消費しません。生成失敗はアプリ側の消費を戻しますが、バックエンドの日次API呼び出し枠は呼び出し回数に応じて消費されます。

## 画面（docs/design/story-mode/ のデザインを反映）

- `Story/Design/`：デザイントークン（`StoryTheme`）、共通部品（`StoryComponents`）、空状態のイラスト（`StoryIllustrations`）
- `StoryEntryCard`：チャット一覧の2行目のあとに置く入口。並び替え中・検索中は出さない
- `StoryLibraryView`：ライブラリと空状態（推し未登録／物語なし）。物語が0件で推しも0人なら推し未登録を優先する
- `StoryCreationView`：新しい物語。入力内容は `StoryDraft`。空欄のあらすじ・名前・役柄は、保存時に従来の初期値で補う
- `StoryPrologueView` / `StoryReaderView` / `StoryReaderBlocks`：扉・読む画面・章間トランジション・完結。表示専用の `StoryReaderScreen` が状態（`StoryReaderStatus`）を受け取るので、#Preview で各状態を確認できる
- `StorySession` の読み取り専用プロパティ `failure`（生成／保存／上限／開き直しが必要）と `pendingScene`（保存待ちの場面）で表示を分ける。保存中・保存エラーの場面は表示するだけで、`record` はサーバーの成功通知まで進めない
- 競合・ユーザー不一致・保存データの不整合は再試行しても成功しないため、理由と「ストーリー一覧へ戻る」だけを出す
- 生成エラーで選んだ行動は端末内（画面を開いている間）だけ保持する。文言もそのとおりに案内する

## バックエンド反映（本番未実施）

1. 管理中のRealtime Databaseルールの **rules直下** に `story-database.rules.fragment.json` の `stories` ブロックをマージしてください。これは断片であり、ファイル全体で既存ルールを置き換えないでください。
2. 上位に全ユーザーを許可する `.read` / `.write` があると子ルールでは制限できません。既存のルール体系で、`stories/{uid}` が所有者以外から読書きできないことを確認してください。
3. Emulator Suiteなどで所有者の作成・読取り・進行・冪等再試行と、別ユーザー拒否・古いリビジョン拒否を検証してから、管理中の手順でルールを反映してください。本リポジトリには既存のDatabaseルールがないため、firebase.jsonのDatabase設定やルール全体は追加していません。
4. `functions/index.js` の `aiChat` は OpenAI の認証エラーを安全な文言に変換します。関数を更新する場合は既存のSecret Manager設定とデプロイ手順に従ってください。ストーリー専用の新エンドポイントはありません。バックエンドの出力上限は2,400トークンで、ストーリーは初回1,600・形式エラー時の再生成2,000トークンを指定します。

ルールは所有者とリビジョンを検証します。JSON内の場面や物語設定の検証はアプリ側です。物語の意味内容（口調、未選択の感情、恋愛成立）はプロンプトで制御しているため、実際の生成品質は実APIで別途確認が必要です。

## 自動テスト

`osimonoTests/StoryTests.swift` はAI・保存をプロトコルで差し替え、1人／3人×両参加モードの完結・保存復元、選択肢／自由入力の受渡し、再開時に生成しないこと、保存前／保存後の失敗に対する重複防止、生成失敗時の状態保持、連打、閉じた画面／別認証ユーザーへの遅延応答、利用制限、競合、不正なJSON・話者ID・空本文・最終場面の形式を検証します。

Xcodeでは `xcodebuild test -project osimono.xcodeproj -scheme osimono -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:osimonoTests/StoryTests CODE_SIGNING_ALLOWED=NO` で実行できます。`scripts/test-story-core.sh` でも同じ中核テストをmacOS上で独立実行できます（Xcode 16以降のSwift Testingが必要）。

`StoryNavigationUITests` は既存の匿名認証を利用して、個別チャットの入口→ストーリー一覧→個別チャットへの復帰を確認する任意のUIテストです。AI要求やストーリーの書き込みは行いません。`TEST_RUNNER_STORY_UI_SMOKE=1 xcodebuild test ... -only-testing:osimonoUITests/StoryNavigationUITests` で実行し、一覧のスクリーンショットをxcresultに残します。通常はスキップします。Firebase AuthのKeychainを利用するUI確認では、シミュレーターでも `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` で署名してください。

## 手動確認

- 個別チャットタブ → ストーリー一覧 → 新規作成。推し未登録時は登録画面へ。
- 推し1人／3人、各舞台、両参加モードで開始。初期値と変更した配役・関係を確認。
- 選択肢と自由入力で進行し、章末の「次の話へ」と第3話最終場面の完結を確認。
- 保存成功後に終了／再起動し、一覧から同じ本文を再開・読み返す。
- AIの通信失敗、JSON不正、保存失敗、競合、ユーザー切替、生成中に閉じる操作を確認。
- 実APIで口調・推し同士の掛け合い・全員の見せ場・過去選択の反映・恋愛なし・一員モードの主体性を確認。
- 個別チャット、グループチャット、ロールプレイ、既存の課金導線を確認。

テスト結果と未検証項目は作業完了時の報告を参照してください。モックAIの成功は実APIの成功を意味しません。

## 今回の検証結果

- iPhone 16 Pro / iOS 26.5 Simulator向けビルド成功。
- 中核の `StoryTests` 17テスト成功（macOS独立実行とiOS実行）。
- 最終xcresultは100テスト成功、失敗0、スキップ5。パラメータを展開した実行件数では104成功。既存の課金・関係進行・ロールプレイ応答なども含みます。スキップ5は既定で無効の実API評価です。
- 自動UIテストで既存の個別チャット→ストーリー一覧→個別チャットへの復帰を確認。認証済みの実Databaseからの一覧読取りも実行されました。`story-mode-library.png` はそのスクリーンショットです。
- 並行追加された `RoleplayMemoryTests` は全体実行中にクラッシュ／再起動したため、最終実行では `-skip-testing:osimonoTests/RoleplayMemoryTests` で除外しました。この別機能の未検証を、ストーリーの成功と混同しないでください。
- 実AIでのストーリー生成・品質、実Databaseへの書込みとアプリ再起動後の再開、DatabaseルールのEmulator検証、StoreKit購入と各チャットの手動操作は未検証です。作成・進行・復元・失敗の自動テストは差替えAIと保存実装による検証です。本番デプロイは行っていません。

最終結果: `/tmp/osimono-story-final-qa.xcresult`。実行は `TEST_RUNNER_STORY_UI_SMOKE=1 xcodebuild test ... -only-testing:osimonoTests -skip-testing:osimonoTests/RoleplayMemoryTests -only-testing:osimonoUITests/StoryNavigationUITests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`。

## 実機での保存競合の修正（2026-09-27）

Firebaseの `getData()` だけでは、トランザクション初回コールバックが参照するイベントキャッシュは保持されません。既存レコードでも空のキャッシュから開始し、ローカルで競合として中断するケースをDatabase Emulatorと実Firebase SDKで再現しました。保存対象に `.value` リスナーを付けた状態で読取り、保存の成功・失敗・タイムアウトまで保持し、終了時に解除します。実際のリビジョン競合や同一操作の再試行の判定は維持します。

回帰テストは `StoryFirebaseTests/coldCacheAdvanceRetryAndConflict`。ローカルDatabase Emulatorを `127.0.0.1:19000` で起動し、専用namespace `demo-story-cache` にテスト用読書きルールを設定したうえで、`TEST_RUNNER_STORY_DATABASE_EMULATOR_TEST=1 xcodebuild test ... -only-testing:osimonoTests/StoryFirebaseTests` で実行します。専用FirebaseAppを使い、RESTで初期レコードを作成してSDKキャッシュがない状態から保存・同一操作の再試行・競合拒否・保存内容を確認します。フラグ未設定時はスキップします。

検証結果: 修正前はEmulator回帰テストが `.conflict` で失敗し、修正後は同テストと既存中核テストの計18テストが成功。実機向けDebugビルドも成功。実AI生成を含む実機画面の確認はユーザーの再操作で確認します。

## AI生成が開始しない場合（2026-10-01）

日本時間3:25前後の `aiChat` 関数ログでOpenAIから401が返り、Secret Managerの `OPENAI_API_KEY` が無効になっていることを確認しました。この場合、場面の再試行やアプリ再インストールでは解消しません。有効な新しいキーを安全に `firebase functions:secrets:set OPENAI_API_KEY` で登録し、`firebase deploy --only functions:aiChat` で関数を更新した後、保存済み物語の「再試行」で生成を確認します。キーはソースコードやチャットに貼り付けません。

同時に、関数は401時の応答とログからキーを推測できる断片を除き、アプリは接続設定の問題を表示するよう変更しました。AIの応答がJSON形式の検証に失敗した場合だけ1回再生成します。
