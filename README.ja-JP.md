<div align="center">
<img src="OPhoneAI/Resources/Assets.xcassets/OPhoneLogo.imageset/logo-256.png" width="128" height="128" alt="OPhone AI">

# OPhone AI for iOS

**iPhone と iPad 向けのオープンソース・アプリ内 AI エージェントランタイム。**

[English](README.md) · [简体中文](README.zh-CN.md) · [한국어](README.ko-KR.md) · **日本語**
</div>

OPhone AI for iOS は、Android 版の移植可能な機能を SwiftUI でネイティブに書き直したものです。DeepSeek、OpenAI 互換 API、Claude Messages API、ChatGPT Web、ローカル会話、永続タスク、イベント、内蔵ブラウザ、HTTPS、プライベートファイル、JavaScript ユーティリティ、メモリ、監査ログに対応します。

iOS 版には、他アプリを操作する Accessibility、自動 Root、任意の Shell は含まれません。エージェントは OPhone AI 自身のブラウザ、ネットワーク、ファイル、プログラム、メモリ、タスクだけを操作します。

GitHub Actions は macOS 上でテストを行い、未署名 IPA をアーティファクトとして作成します。インストール可能な IPA には Apple Developer の証明書と Provisioning Profile が必要です。詳細は [Build and signing](docs/BUILD_AND_SIGNING.md) を参照してください。
