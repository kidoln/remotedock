# Remote Dock Localization Design

更新时间: 2026-05-09

## 背景

Remote Dock 需要在 macOS 端和 iOS 端同时支持多语言。一期只支持简体中文和英文，后续可以扩展更多语言。

产品决策:

1. macOS 端提供语言设置。
2. macOS 端首次启动时读取系统首选语言，中文系统默认简体中文，其他语言默认英文。
3. iOS 端不提供语言设置。
4. iOS 端通过连接握手获取 macOS 端语言，并自动跟随 macOS 端。
5. iOS 端底部 tab menu 保持英文，不参与本地化。

## 资源组织

每个 App target 使用独立的 `Localizable.xcstrings`:

1. `apps/mac/RemoteDockMac/Localizable.xcstrings`
2. `apps/ios/RemoteDockiOS/Localizable.xcstrings`

文案 key 采用语义化命名，例如:

1. `settings.pane.general`
2. `settings.general.language.title`
3. `ios.pairing.title`
4. `connection.connected`

代码中不直接硬编码用户可见文案，应通过 `RemoteDockLanguage.localizedString(_:)` 或 `formattedLocalizedString(_:)` 查表。

## 共享语言模型

共享层 `RemoteDockCore` 定义 `RemoteDockLanguage`:

1. `en`
2. `zh-Hans`

语言解析规则:

1. `zh` 开头解析为 `zh-Hans`。
2. `en` 开头解析为 `en`。
3. 其他语言默认英文。

## macOS 端

macOS 端通过 `LanguageSettingsService` 持久化用户选择:

```text
remoteDock.mac.language
```

首次没有用户选择时，读取 `Locale.preferredLanguages`。首选语言为中文时使用 `zh-Hans`，否则使用 `en`。

设置页新增 `General` tab，包含语言 Picker。用户切换语言后:

1. 更新 `MacAppModel.language`。
2. 保存到 `UserDefaults`。
3. 立即发送新的 `.hello` 给已连接 iOS 端。

## iOS 端

iOS 端保存上一次从 Mac 收到的语言:

```text
remoteDock.iOS.remoteLanguage
```

启动时优先使用上次语言，没有历史值时使用英文。连接 Mac 后，收到 macOS 端 `.hello.languageCode` 即更新本地语言状态并刷新 UI。

## 协议

`HelloPayload` 增加可选字段:

```swift
languageCode: String?
```

该字段是可选字段，不影响旧版本 hello 消息解码。未来如果需要同步更多远端设置，可以再增加独立的 settings snapshot 消息；当前一期只同步语言，复用 hello 足够简单。
