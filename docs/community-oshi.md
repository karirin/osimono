# みんなの推し

調査・実装日: 2026-10-10。iOS 16以上。既存の推し・会話は自動公開しない。

## 調査と採用した機能

| 公式情報 | 確認した仕組み | このアプリでの採用 |
| --- | --- | --- |
| [Character.AI: Sharing and Community](https://support.character.ai/hc/en-us/articles/50609437175195-8-Sharing-and-Community-%E3%81%A3-%E1%B5%94-%E1%B5%94-%E3%81%A3) | 公開・限定公開・非公開。公開キャラクターは検索・発見画面から利用する | 明示的な公開操作、公開停止、公開カタログの分離 |
| [Character.AI: Quickstart](https://support.character.ai/hc/en-us/articles/50608869548699-2-Creating-a-Character-Quickstart-Guide-%CF%89) | 名前・画像・挨拶・タグ・説明によるキャラクター作成 | 一覧から詳細を確認して選ぶ。性格・話し方・会話サンプルを表示 |
| [PolyBuzz: Quick Creation](https://book.polybuzz.ai/quick-creation) | 紹介文、挨拶、公開設定、最大5タグ、話し方 | 紹介文必須、5タグまで、公開前プレビュー |
| [Talkie公式](https://www.talkie-ai.com/) | Discover/Search、カテゴリ、人物紹介からチャットへ進む導線 | チャット画面と新規登録画面に検索入口、カテゴリ選択 |

以下は調査を踏まえた本アプリ独自の設計判断。競合と同じ保存方式という意味ではない。

- 「探す → プロフィール確認 → 自分の推しに登録」。初回は作成不要で始められる。
- 登録時の公開プロフィールを自分の `oshis/{uid}` に保存する。登録後の性格・話し方は編集可能。公開元の更新は自動反映しない。
- 作成者の表示名を残す。インポートした推しの再公開は不可。
- 人気ランキング・フォロー・いいね数・限定リンク・外部サービスからの取り込みは今回の範囲外。利用実績のない人気順位は表示しない。

## 使い方

- チャットの個人タブ、または推しの新規登録画面の「みんなの推しから選ぶ」。
- 名前の先頭一致検索と6カテゴリ。大文字小文字、全角英数、ひらがな／カタカナを正規化。検索中は名前順、通常は新着順。30件ずつ読み込む。タグはプロフィール表示用で全文検索ではない。
- 詳細で紹介、作成者、性格、話し方、口癖、会話サンプルを確認。「自分の推しに登録」後にチャット一覧へ戻る。
- 自分の推しの編集 →「公開・作成者情報」。保存済み設定を読み込み、公開する表示名・紹介文等を入力。画像の公開は初期オフ。公開用の文章を確認し、共有の確認をオンにして公開する。
- 元の推しの編集と公開プロフィールの更新は別操作。公開中の文章は同じ画面で更新できる。
- 不適切な推しは詳細メニューから通報・非表示。非表示はそのアカウントで持続する。

## データ境界と保存

`communityOshi` callable（asia-northeast1）が公開データを扱う。Firebase認証必須。

- `communityOshi/profiles/{hash}`: 公開専用スナップショット。ownerID/sourceOshiIDはサーバー内部のみ。返却データはホワイトリストで再構成する。
- `communityOshi/hidden/{uid}/{id}`: 個人の非表示。
- `communityOshi/reports/{id}/{uid}`: 運営向け通報理由・通報時点のプロフィール。
- `communityOshi/usage/{uid}/{day}`: 公開20回/日・通報20回/日の制限。
- `communityOshi/disabled/{id}`: 運営による再公開禁止。
- `communityOshiAssets/{publicID}/{version}`: サーバーでコピーした公開用画像。
- 個人の登録先は `oshis/{uid}/community_{publicID}`。`communitySourceID` / `communityCreatorName` で出典を保持する。

公開・登録する設定は名前、画像（任意）、性格、話し方、口癖のみ。紹介文・カテゴリ・タグ・会話サンプルは発見画面用。メモ、背景画像、ユーザーの呼び名、関係性、共有エピソード、ロールプレイの記憶、チャット履歴は読取り・コピー対象にしない。公開文章に個人情報を書いた場合はその文章自体が公開されるため、フォームで全項目を確認できる。

公開画像は自分のFirebase Storage内の画像だけを許可し、任意URL取得は行わない。別のオブジェクトにコピーするので、元の画像の編集・削除が登録済みコピーに影響しない。公開停止は検索と新規登録を停止するもので、取得済み画像や個人コピーの回収は行わない。画像は既存コピーのため保持される。公開更新でできた未参照画像の定期回収は別途運用が必要。

登録前に公開状態を再取得する。`oshis/{uid}` 全体のトランザクション内で件数と出典を再チェックし、重複操作では既存の個人設定を上書きしない。選択中IDの更新だけが失敗した場合も、再試行で同じ推しを選択できる。

無料5人／プレミアム無制限・Debug開発者モードの既存 `OshiLimitManager` に従う。これは既存アプリと同じクライアントのStoreKit判定であり、購入状態のサーバー検証や改造クライアントへの課金強制を新たに提供するものではない。

## 配信前に必要な設定

**本番で確認した前提条件:** 2026-10-10にルールのみを読取り確認したところ、ルートが `.read: "true"` / `.write: "true"` で、ノード別の制限がなかった。既存の個人データも含めたアクセス権の移行が必要。公開ノードの断片を追加するだけでは保護されない。

callableは実際のルールと検索インデックスを毎回検査し、親階層・ワイルドカード・公開ノードの直接アクセス許可が残る間は「準備中」として処理を拒否する。安全なルールへの移行前に新機能を誤って配信しても公開データを書き込まない。

この変更では本番デプロイを行っていない。新しい関数とルールを配信するまでは、アプリの公開・検索操作は利用できない。

1. 本番の現在のRealtime Databaseルールを確認し、`community-oshi-database.rules.fragment.json` を `rules` 直下へ統合する。これは差分用の断片で、既存ルール全体の置換用ではない。
2. `communityOshi` とその祖先にはクライアント向けのread/write許可を置かない。親階層の許可は子のfalseで取り消せない。特にルートに `.read: true` / `.write: true` や認証者全許可がある場合は、既存アプリの各ノードへ権限を分けてから有効化する。個人の `oshis/{uid}` と `users/{uid}` は本人だけ読書きできる必要がある。[Firebaseのルール継承](https://firebase.google.com/docs/database/security/core-syntax)
3. Storageルールでも `communityOshiAssets/**` にクライアントの書込みを許可しない。Admin SDKだけがコピーする。ダウンロードは発行した画像トークンを使用する。広域のallow writeルールにも注意する。
4. 統合済みルールを確認して配信し、`firebase deploy --only functions:communityOshi,functions:unpublishDeletedOshi` で新関数を配信する。既存 `aiChat` 関数の配信は不要。実DBを読取り確認した結果、`osimono-default-rtdb` は `us-central1`。削除トリガーは同リージョン・同インスタンスに固定し、callableは既存AI関数と同じ `asia-northeast1` に配置する。
5. テスト用の2アカウントで公開→検索→登録→編集→再登録→公開停止を確認する。画像付き公開のStorage Emulator検証も実施。配信後は実Storageとの接続も確認する。

通報は運営が上記reportsを確認する。非表示対応は `profiles/{id}/disabled = true` と `disabled/{id} = true` を管理者権限で設定する。自動モデレーションや運営用管理画面は今回含まない。通報内容を一般ユーザーから読めるようにしない。

## 検証

- Swiftモデル: 公開設定から既存Oshiへの互換性、個人情報を含めないこと、重複・既存編集の保持、上限と再試行時の件数判定、公開入力の検証。
- Node単体: 公開データのホワイトリスト、入力検証、日本語検索の正規化、IDの分離、画像の所有権。
- Database Emulator: callableを実DBに接続し、所有者認可、公開停止、再公開拒否、通報・非表示、新着／名前／カテゴリ検索のページ送り、削除トリガー、カタログへの直接アクセス拒否を確認。
- Firebase iOS SDK + 専用Database Emulator: キャッシュのない状態からの同時登録、上限、個人編集の保持、公開停止エラー、削除後の再登録、選択中IDの保存。
- Storage Emulator: 画像コピー、ダウンロードトークン、元画像削除・公開停止後の既存コピーの保持。
- SwiftUI画像: ライト／ダークと大きな文字のカード・導線を確認。

再実行:

```sh
npm --prefix functions ci
bash scripts/test-community-oshis.sh
# iOSモデル・画面・Firebase SDKの検証も含める場合
COMMUNITY_RUN_IOS_TESTS=1 bash scripts/test-community-oshis.sh
```

EmulatorはJavaが必要。`demo-community`専用に固定し、本番データを使用しない。

最終検証: Swiftのモデル4件・実Firebase SDK1件・画面1件が成功（`/tmp/osimono-community-final.xcresult`）。Nodeの境界テストとDatabase/Storage Emulator検証の8件が成功（画像テスト含む）。本番と同じ全体公開ルールをローカルで設定した場合に、公開処理を拒否することも確認した。ライト・ダークの画像を目視確認済み。本番関数の配信・実サービスを使った2アカウントの通し操作は未実施。
