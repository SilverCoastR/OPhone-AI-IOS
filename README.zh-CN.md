<div align="center">
<img src="OPhoneAI/Resources/Assets.xcassets/OPhoneLogo.imageset/logo-256.png" width="128" height="128" alt="OPhone AI">

# OPhone AI iOS 版

**面向 iPhone 和 iPad 的开源、应用内 AI Agent 运行时。**

[English](README.md) · **简体中文** · [한국어](README.ko-KR.md) · [日本語](README.ja-JP.md)
</div>

OPhone AI iOS 版用 SwiftUI 原生重写 Android 版中适合 iOS 的部分。模型可以使用持久任务、结构化事件、内置浏览器、受限 HTTPS 请求、应用私有文件、JavaScript 小程序、用户可见记忆和审计记录。

## 主要功能

- DeepSeek、OpenAI 兼容 Chat Completions，以及 Claude 原生 Messages API；均支持流式输出和工具调用。
- API 对话保存在本机，切换 API 平台后仍可读取；密钥分别保存在 iOS Keychain。
- 持久任务、检查点、终止、事件反馈、幂等执行回执和基于证据的完成判定。
- 多标签内置浏览器，支持页面结构读取、DOM 操作、JavaScript、截图、正确的页面适配和手势缩放。
- 公网 HTTPS、私有工作区文件、受限 JavaScript、AI 记忆和审计日志。
- 可选的服务器模型厂商列表、Cloudflare 匿名启动上报与更新地址查询。
- 英文、简体中文、韩文和日文资源。

## iOS 功能边界

按照项目决定，iOS 版不实现无障碍全机控制、Root 和任意 Shell，代码、工具协议、设置与权限声明中均没有这些功能。Agent 的自动化范围是 OPhone AI 自身的浏览器、网络、文件、小程序、记忆和任务系统。

GitHub Actions 默认生成无签名 IPA，用于验证真机目标能成功编译。要安装到设备，需要 Apple Developer 证书和 Provisioning Profile。详见[构建与签名](docs/BUILD_AND_SIGNING.md)。

## 构建

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project OPhoneAI.xcodeproj -scheme OPhoneAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

更多信息见[架构](docs/ARCHITECTURE.md)、[迁移对应表](docs/PORTING.md)、[模型列表格式](docs/PROVIDER_CATALOG.md)和[隐私说明](PRIVACY.md)。
