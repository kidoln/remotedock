这是一个仅服务苹果生态的软件，它由运行在macos系统中的app和一个运行在ios系统中的app配合使用。

它实现的功能是在ios系统中展示macos系统中的常用应用、已打开程序列表、剪贴板历史等信息。用户可以操作ios中的app，以快速切换macos系统中的应用程序，粘贴信息等。

## 多语言支持

本项目支持简体中文和英文，相关规范如下：

### 文案规范

1. **禁止硬编码**：代码中不直接硬编码用户可见的文案，应通过 `RemoteDockLanguage.localizedString(_:)` 或 `formattedLocalizedString(_:)` 查表。

2. **Key 命名**：文案 key 采用语义化命名，使用点号分隔层级：
   - `settings.pane.general`
   - `settings.general.language.title`
   - `ios.pairing.title`
   - `connection.connected`

3. **资源组织**：每个 App target 使用独立的 `Localizable.xcstrings`：
   - `apps/mac/RemoteDockMac/Localizable.xcstrings`
   - `apps/ios/RemoteDockiOS/Localizable.xcstrings`

4. **iOS 特殊规则**：iOS 端底部 tab menu 保持英文，不参与本地化。

## 通用规范

- 不要对 git 执行任何写操作，除非用户明确要求
- 有重大的设计决策或架构决策，应该在 docs 目录中添加新的文件以记录说明
