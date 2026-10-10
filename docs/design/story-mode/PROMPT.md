# 依頼：osimono「ストーリーモード」をSwiftUIで実装

既存のiOSアプリ osimono（SwiftUI / Firebase / OpenAI API）に「ストーリーモード」のUIを追加します。
デザインは確定済みで、`docs/design/story-mode/` にあります。

- `SPEC.md`：デザイントークン、画面一覧、画面ごとの実装メモ（最優先で読む）
- `screens/*.html`：画面ごとのモック。見た目・寸法・色・文言の「正」
  - HTMLはデザインツール形式のモックで、繰り返しデータや状態は末尾 `<script type="text/x-dc">` の `renderVals()` にあります
  - HTMLをそのまま使うのではなく、SwiftUIで忠実に再現してください

## 進め方（重要）
- 最初に既存コード（推しのモデル、チャット一覧、Firebase・OpenAIの呼び出し、画面遷移）を調べ、実装計画を提示してから着手してください。
- 次の順に1段階ずつ進め、各段階の終わりでビルドが通ることを確認して止まってください。
  1. デザイントークン＋共通コンポーネント
  2. ライブラリ／空状態／チャット一覧の入口カード（screens 01〜04）
  3. 新しい物語（screens 05〜06）
  4. 物語の扉／読む画面／章間トランジション／完結（screens 07〜09, 11）
  5. 非同期処理の状態：生成中・保存中・生成エラー・保存エラー・AI利用上限（screens 10）
- 仕様にない機能は追加しないでください（シェア・評価・いいね・削除・続編生成など）。
- 既存のデータモデルやAPI処理を大きく変える場合は、先に相談してください。
- 各画面に #Preview を付け、主要な状態（空・進行中・完結・生成中・各エラー）をプレビューで切り替えられるようにしてください。
- `screens/12_EpisodeList_Early.html` は初期案なので、実装対象外です（参考のみ）。

## 共通コンポーネント（ステップ1）
- DesignTokens：色・角丸・影・フォント（値は SPEC.md のトークン表のとおり）
- OshiAvatar：円形、グラデのリングあり／なし、選択順バッジ、画像未設定時は person.fill
- AvatarStack：1〜3人、白フチ、重ね表示
- PrimaryButton：56pt・グラデ・無効状態（#ECE6EF／#A69DB0・影なし）
- SecondaryTextButton：44pt
- SceneProgressBar：3話×3場面の9本（読了／現在／未読）
- NarrationCard：Soft purple、15pt、行間1.8
- DialogueCard：アバター40＋名前＋白カード（角丸 4/18/18/18）
- UserActionCard：右寄せ、Soft pink、「あなたの行動」ラベル
- SceneDivider：細線＋「場面 n」
- StatusCard：生成中・保存中・エラー・上限
- 固定ボトムバー：.ultraThinMaterial 相当＋上0.5ptの線

## 守ること
- ライトモード専用、Safe Area・Dynamic Type 対応、タップ領域44pt以上、SF Symbols を使用
- 装飾は accessibilityHidden、アイコンだけのボタンにはラベルを付ける
- 状態が変わったら読み上げる。アニメーションは Reduce Motion に対応する
- エラーの赤（#D93A55）はエラー箇所だけに使う

今回はステップ1（トークンと共通コンポーネント）だけお願いします。
