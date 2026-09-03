# Android MVP

`android/` には `Kotlin + Jetpack Compose + Firebase` ベースの MVP Android 版を追加しています。

## 含めた機能

- 匿名ログイン
- `users/{uid}` のプロフィール読込と保存
- `oshis/{uid}/{oshiId}` の一覧、追加、編集、選択
- `oshiItems/{uid}/{oshiId}/{itemId}` の一覧、追加、編集
- `locations/{uid}/{oshiId}/{locationId}` の一覧、追加、編集
- Firebase Storage への画像アップロード

## 初回セットアップ

1. Firebase Console で Android アプリを追加する
2. `google-services.json` を取得する
3. そのファイルを `android/app/google-services.json` に配置する
4. JDK 17 と Android SDK を入れる
5. Android Studio で `android/` を開く

## メモ

- このMVPは iOS と Android の UID 共通化を前提にしていません
- iOS の Realtime Database パス構造に合わせています
- AIチャット、広告、サブスク、グループチャットは今回のMVP対象外です
