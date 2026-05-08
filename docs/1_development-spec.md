# E Remote Dock 软件开发 Spec

文档版本: v0.2
更新时间: 2026-05-08
适用范围: 项目初始化阶段

## 1. 项目背景

根据仓库内 [AGENTS.md](/Users/kido/code/e_remote_dock/AGENTS.md:1) 的定义，本项目是一个仅服务苹果生态的软件，由一个运行在 macOS 的宿主端应用和一个运行在 iOS 的控制端应用组成。

产品目标是:

1. 在 iOS 设备上展示 macOS 设备中的常用应用。
2. 在 iOS 设备上展示 macOS 当前已打开程序列表。
3. 在 iOS 设备上展示 macOS 的剪贴板历史。
4. 允许用户从 iOS 端触发 macOS 端的切换应用、打开应用、粘贴内容等操作。

该产品本质上是一个面向个人效率场景的 Apple-only remote companion。

## 2. 产品目标与非目标

### 2.1 目标

MVP 阶段的目标是做出一个稳定可用的本地局域网版本，完成以下闭环:

1. macOS 端可发现并与 iOS 端配对。
2. iOS 端可实时看到 macOS 的常用应用、运行中应用和文本剪贴板历史。
3. iOS 端点击应用后，可在 macOS 端切换到目标应用。
4. iOS 端点击剪贴板条目后，可在 macOS 端将该条目粘贴到当前前台应用。
5. 用户可以在 macOS 端显式管理哪些应用属于“常用应用”。

### 2.2 非目标

以下内容不进入 MVP:

1. 跨公网远程连接。
2. Windows、Android 或 Web 客户端支持。
3. 图片、文件、富文本剪贴板的完整同步。
4. 多台 macOS 主机同时在线协同。
5. 云端账号体系、云同步、多人共享。
6. 完整的桌面镜像、屏幕控制、键鼠远控。

## 3. MVP 范围定义

### 3.1 macOS 端

macOS 端建议做成菜单栏常驻应用，包含以下能力:

1. 设备配对与连接管理。
2. 常用应用配置管理。
3. 运行中应用列表采集。
4. 剪贴板历史采集与本地存储。
5. 执行来自 iOS 的命令:
   - 激活已运行应用
   - 启动未运行但已配置的应用
   - 将目标文本写入系统剪贴板并触发粘贴
6. 权限检查与引导:
   - Accessibility
   - Local Network
   - Notifications 可选

### 3.2 iOS 端

iOS 端建议做成单窗口应用，包含以下页面:

1. `Dock`
   - 展示常用应用
   - 支持点击激活或打开应用
2. `Running`
   - 展示当前 macOS 运行中应用
   - 支持快速切换
3. `Clipboard`
   - 展示文本剪贴板历史
   - 支持搜索、复制、发送到 Mac 粘贴
4. `Settings`
   - 配对状态
   - 目标 Mac 选择
   - 同步开关
   - 隐私说明

### 3.3 剪贴板功能边界

MVP 只支持文本内容，原因如下:

1. 文本剪贴板是高频核心场景。
2. 图片和文件会显著增加传输、存储和权限复杂度。
3. 富文本会带来格式保真问题，容易拖慢首版交付。

建议限制:

1. 默认只保留最近 50 到 100 条历史。
2. 单条文本长度做上限截断，例如 8 KB 到 32 KB。
3. 支持从历史中删除单条，支持一键清空。
4. 支持配置排除应用，例如密码管理器、终端、银行类应用。

## 4. 用户场景

### 4.1 场景一: 快速切换应用

用户在 iPhone 上打开 `Dock`，点击 `Safari` 或 `Xcode`，macOS 端立即切换到对应应用。

### 4.2 场景二: 从手机选取历史文本并粘贴到 Mac

用户在 iPhone 上打开 `Clipboard`，选中一条文本并点击“粘贴到当前应用”，macOS 端把文本写入系统剪贴板，并向当前前台应用发送 `Cmd+V`。

### 4.3 场景三: 查看当前正在运行的程序

用户在 iPhone 上打开 `Running`，快速查看当前 Mac 上已运行的软件，并点击切换。

### 4.4 场景四: 常用应用管理

用户在 macOS 菜单栏设置中把常用应用固定为 `Finder`、`Safari`、`WeChat`、`Xcode` 等，iOS 端自动同步该列表。

## 5. 核心产品决策

### 5.1 连接范围

首版仅支持同一局域网或 Apple 近距连接环境，不做公网穿透。

### 5.2 传输方案

MVP 建议使用 `MultipeerConnectivity` 作为首版传输实现，但不应把它当成最终架构边界。

原因如下:

1. Apple-only，适配本项目边界。
2. 自带设备发现、会话管理和加密连接能力。
3. 相比自建 `Network.framework + Bonjour + TLS`，首版实现成本更低。
4. 首版可以更快验证产品核心闭环。

同时必须从第一天就定义清晰的传输抽象，避免后续替换成本失控:

1. 共享层定义 `TransportSession` 协议，而不是让业务代码直接依赖 `MultipeerConnectivity`。
2. 明确连接状态机，例如:
   - `idle`
   - `discovering`
   - `connecting`
   - `connected`
   - `reconnecting`
   - `disconnected`
   - `failed`
3. 把设备发现、建连、断连、重连、会话回执都收敛在传输层。
4. 默认假设 iOS 前后台切换会导致连接失活，重连逻辑需要自行管理。
5. 从 Phase 1 开始就安排真机测试，不能依赖模拟器验证 MPC 可靠性。

### 5.3 macOS 分发策略

macOS 端首发建议优先采用 `Developer ID + Notarization` 的直发路线，而不是一开始就把 `Mac App Store` 作为硬约束。

原因:

1. 应用切换和模拟粘贴强依赖 Accessibility。
2. 菜单栏常驻和跨应用控制在沙盒约束下更容易遇到限制。
3. 首版目标是先跑通稳定可用的效率工具，而不是先满足商店合规。

但架构上必须保留后续进入 `Mac App Store` 的可能性，避免把非沙盒能力写死在系统里:

1. 将跨应用控制能力集中在 `MacCommandExecutor` 或等价的系统集成层中。
2. 明确区分两个能力:
   - `copyToMacClipboard`
   - `pasteIntoFrontmostApp`
3. 协议层、共享模型层、UI 层不得直接依赖非沙盒能力。
4. 如果未来商店版无法保留自动粘贴能力，可降级为“仅同步到 Mac 剪贴板，不自动触发粘贴”。

这意味着未来如果要上架，通常不需要重写整个项目，但很可能需要调整 macOS 系统集成层和功能矩阵。

### 5.4 iOS 分发策略

iOS 端可先按 `TestFlight` 内测路径推进，待协议和交互稳定后再考虑正式发布。

## 6. 技术栈建议

### 6.1 平台与语言

1. 语言: `Swift`
2. UI: `SwiftUI`
3. macOS 端补充: `AppKit`
4. 并发模型: `Swift Concurrency`
5. 日志: `OSLog`
6. 测试: `XCTest`

### 6.2 最低系统版本

建议:

1. macOS 14+
2. iOS 17+

这样可以减少兼容性负担，并使用较新的 SwiftUI 与并发能力。

### 6.3 工程组织

建议使用一个 Xcode Workspace，目录上明确分成 `mac`、`ios` 和 `shared` 三层，而不是把两个 App 做成完全独立的平行项目。

推荐目录结构:

```text
docs/
apps/
  mac/
    RemoteDockMac/
  ios/
    RemoteDockiOS/
packages/
  shared/
    RemoteDockCore/
    RemoteDockProtocol/
    RemoteDockTransport/
tests/
  RemoteDockCoreTests/
  RemoteDockProtocolTests/
  RemoteDockTransportTests/
scripts/
```

模块职责:

1. `RemoteDockCore`
   - 共享数据模型
   - 平台无关的纯逻辑
   - 数据校验、去重规则、错误类型
2. `RemoteDockProtocol`
   - 消息 envelope
   - 消息类型定义
   - 编解码与协议版本管理
3. `RemoteDockTransport`
   - `TransportSession` 抽象
   - 会话状态机
   - `MultipeerConnectivity` 适配器
   - Mock transport
4. `RemoteDockMac`
   - 菜单栏 UI
   - 权限与系统集成
   - macOS 专属服务
   - 命令执行
5. `RemoteDockiOS`
   - 交互界面
   - Store 与视图状态
   - 图标缓存与本地展示逻辑

说明:

1. 不再设置一个胖的跨平台 `Features` 包。
2. 平台强相关逻辑留在各自 App target 或未来的平台专属 package 中。
3. 如果后续 macOS 侧逻辑膨胀，可再拆出 `packages/mac/RemoteDockMacFeatures/`，但不在项目起步阶段提前过度抽象。

## 7. 系统架构

### 7.1 总体架构

系统采用一个宿主端、一个控制端的双端架构:

1. macOS 端负责采集状态和执行命令。
2. iOS 端负责展示状态和发起操作。
3. 双端通过共享协议通信。
4. 共享协议独立于具体传输实现。
5. 共享层只放平台无关内容，不承载 `NSWorkspace`、`NSPasteboard`、`Accessibility` 这类平台 API。
6. 平台能力留在 App target 或平台专属模块中。

### 7.1.1 TransportSession 生命周期

传输层建议从第一版开始就采用显式生命周期协议:

1. `TransportSession` 负责对外暴露:
   - 当前连接状态
   - 可发现设备列表
   - 收到的协议消息流
   - 发送消息接口
   - 重连接口
2. 状态机至少覆盖:
   - `idle`
   - `discovering`
   - `connecting`
   - `connected`
   - `reconnecting`
   - `disconnected`
   - `failed`
3. 业务层不得直接依赖 `MCPeerID`、`MCSession` 等具体类型。
4. 所有前后台切换、断连重连、错误回执都必须先在 `RemoteDockTransport` 层封装，再向上层暴露稳定事件。

### 7.2 macOS 端模块设计

建议拆分为以下服务:

1. `PermissionCenter`
   - 检查并引导 Accessibility、Local Network 等权限
2. `PeerSessionManager`
   - 管理设备发现、配对、连接、重连
3. `PinnedAppsService`
   - 维护用户配置的常用应用列表
4. `RunningAppsService`
   - 监听和获取当前运行中应用列表
5. `ClipboardHistoryService`
   - 监听系统剪贴板变化
   - 去重、截断、过滤、持久化
   - 默认使用 `NSPasteboard.changeCount` 轮询，起始间隔设为 `500ms`
6. `AppIconCatalogService`
   - 读取应用图标
   - 生成固定尺寸缓存资源
   - 根据 `iconAssetHash` 提供按需同步
7. `CommandInbox`
   - 校验命令格式
   - 基于 `commandId` 去重
   - 缓存近期命令执行结果
8. `MacCommandExecutor`
   - 激活应用
   - 打开应用
   - 写入 Mac 剪贴板
   - 触发粘贴动作
9. `SnapshotPublisher`
   - 将应用列表、运行中应用、剪贴板历史变更推送给 iOS

### 7.3 iOS 端模块设计

建议拆分为以下模块:

1. `DiscoveryStore`
   - 管理目标 Mac 列表和当前连接状态
2. `DockStore`
   - 管理常用应用列表
3. `RunningAppsStore`
   - 管理运行中应用列表
4. `ClipboardStore`
   - 管理剪贴板历史和搜索
5. `IconCacheStore`
   - 本地图标缓存
   - 基于 `iconAssetHash` 命中与失效
6. `CommandDispatcher`
   - 发送切换应用、粘贴等命令
   - 生成 `commandId`
   - 管理超时、重试和结果回执
7. `SettingsStore`
   - 持久化用户偏好和配对信息

### 7.4 本地存储

本地存储层建议先抽象，再决定底层技术。

建议先定义以下接口:

1. `ClipboardHistoryStore`
2. `PairedDeviceStore`
3. `IconCacheStore`

实现建议:

1. 轻量配置使用 `UserDefaults`。
2. 如果团队更熟悉文件存储，MVP 可采用 JSON 文件或本地文件缓存。
3. 如果团队对 `SwiftData` 有把握，也可以作为其中一种具体实现。
4. 无论底层选哪种实现，业务代码都不能直接读写文件或直接耦合 `SwiftData` 模型。
5. 剪贴板历史、配对元数据、图标缓存都应通过统一存储接口访问。

## 8. 数据模型建议

### 8.1 常用应用

```text
PinnedApp
- id
- bundleIdentifier
- displayName
- appPath
- iconAssetHash
- sortOrder
```

### 8.2 运行中应用

```text
RunningApp
- id
- bundleIdentifier
- displayName
- pid
- isActive
- launchedAt
```

### 8.3 剪贴板条目

```text
ClipboardItem
- id
- contentType            // MVP 固定为 text
- plainText
- sourceAppBundleId
- createdAt
- contentHash
```

### 8.4 已配对设备

```text
PairedDevice
- id
- displayName
- createdAt
- lastSeenAt
- trustState
```

### 8.5 图标资源

```text
AppIconAsset
- hash
- format                 // MVP 建议为 png
- pixelWidth
- pixelHeight
- bytesLength
```

### 8.6 命令请求

```text
CommandRequest
- commandId
- commandType
- issuedAt
- payload
```

## 9. 通信协议建议

### 9.1 协议原则

1. 协议层不直接绑定 UI。
2. 使用明确的消息类型，而不是模糊的自由文本事件。
3. 支持全量快照和增量更新两种模式。
4. 所有命令都要有结果回执。
5. 所有带副作用的命令必须支持幂等处理。
6. 所有消息必须使用统一的 envelope，便于版本兼容。

### 9.2 消息封装

首版建议所有消息统一使用如下 envelope:

```json
{
  "type": "clipboardDelta",
  "version": 1,
  "payload": {}
}
```

约束:

1. `type` 标识消息语义。
2. `version` 标识协议版本。
3. `payload` 承载具体业务内容。
4. 所有双端解码逻辑都先处理 envelope，再分发到具体消息模型。

### 9.3 消息类型

建议至少定义以下消息:

1. `hello`
   - 双端握手
   - 版本号、设备名、能力声明
2. `pairRequest`
   - 发起配对
3. `pairApprove`
   - macOS 用户确认配对
4. `appsSnapshot`
   - 常用应用全量列表
5. `runningAppsSnapshot`
   - 运行中应用全量列表
6. `clipboardSnapshot`
   - 剪贴板历史全量列表
7. `clipboardDelta`
   - 剪贴板新增或删除
8. `iconManifest`
   - 当前图标哈希列表
9. `iconRequest`
   - iOS 按需请求缺失图标
10. `iconPayload`
   - 传输指定哈希对应的图标资源
11. `activateAppCommand`
   - 请求激活或打开应用
12. `pasteClipboardItemCommand`
   - 请求粘贴指定历史项
13. `commandResult`
   - 命令执行结果
14. `error`
   - 协议级错误

### 9.4 图标同步策略

应用图标不应跟随主快照在每次重连时全量同步。

建议策略:

1. `PinnedApp` 和 `RunningApp` 主数据里只携带 `iconAssetHash`。
2. iOS 端先查本地图标缓存。
3. 只有缓存缺失时，才通过 `iconRequest` 拉取对应资源。
4. macOS 端统一输出固定尺寸 PNG，例如 `128x128`。
5. iOS 端按 `iconAssetHash` 落盘缓存，重连后直接复用。

### 9.5 命令幂等性

所有会产生副作用的命令至少包含 `commandId`。

处理规则:

1. iOS 端发送命令时生成全局唯一 `commandId`。
2. macOS 端在 `CommandInbox` 中维护近期命令缓存。
3. 对于重复的 `commandId`，不得重复执行副作用操作。
4. 若已执行过，应直接返回上一次的 `commandResult`。
5. `pasteClipboardItemCommand` 必须严格执行此约束，避免重复粘贴。

### 9.6 序列化格式

首版建议使用 `JSON`，原因是开发调试成本低。后续如果性能成为问题，再切换到更紧凑的二进制编码。

## 10. 权限与系统能力

### 10.1 macOS 权限

macOS 端至少需要:

1. `Accessibility`
   - 用于切换应用后的输入模拟和粘贴动作
2. `Local Network`
   - 如果使用局域网发现或相关底层能力

可选:

1. `Notifications`
   - 用于连接成功、权限缺失、错误提醒

### 10.2 权限引导策略

权限引导必须前置，不能等用户点击失败后才解释。

建议首次启动流程:

1. 欢迎页
2. 功能说明
3. 权限说明
4. 一键跳转系统设置
5. 权限状态实时校验
6. 进入配对流程

### 10.3 系统集成实现建议

1. 应用列表:
   - 通过 `NSWorkspace` 获取安装和运行中的应用信息
2. 前台应用切换:
   - 优先使用 `NSRunningApplication.activate`
   - 若应用未运行，则通过 `NSWorkspace` 打开
3. 剪贴板监听:
   - 轮询 `NSPasteboard.changeCount` 或构建轻量监听器
   - MVP 默认轮询间隔为 `500ms`
4. 粘贴动作:
   - 将目标文本写入系统剪贴板
   - 切换目标应用到前台
   - 稍作延迟后发送 `Cmd+V` 键盘事件

## 11. 安全与隐私

### 11.1 配对策略

必须要求显式配对，不能自动信任局域网内任何设备。

建议流程:

1. iOS 发起连接请求。
2. macOS 弹出确认框，显示设备名和一次性配对码。
3. iOS 输入或确认配对码。
4. 成功后在双方本地保存信任关系。

### 11.2 数据边界

1. 剪贴板历史默认只在已配对设备间同步。
2. 文本内容只保留最近有限条数。
3. 支持用户关闭剪贴板同步，只保留应用切换能力。
4. 支持用户手动清空 Mac 本地历史。
5. 支持排除敏感应用来源。

### 11.3 日志边界

日志中不得直接打印完整剪贴板文本，最多输出:

1. 条目长度
2. 哈希
3. 来源应用
4. 状态码

## 12. 交互与 UI 建议

### 12.1 macOS 端

建议采用菜单栏形态:

1. 状态项显示连接状态
2. 菜单中提供:
   - 当前配对设备
   - 权限状态
   - 常用应用管理入口
   - 剪贴板历史开关
   - 退出
3. 提供一个设置窗口，用于:
   - 常用应用排序和增删
   - 配对设备管理
   - 隐私配置

### 12.2 iOS 端

建议首页直接进入 `Dock`，避免过重的信息架构。

推荐底部 Tab:

1. `Dock`
2. `Running`
3. `Clipboard`
4. `Settings`

交互要点:

1. 应用卡片支持图标、名称、状态。
2. 剪贴板列表默认显示首行摘要和时间。
3. 粘贴操作需要有明确反馈。
4. 断连状态需要明确展示，并支持重连。

## 13. 开发阶段规划

### 13.1 Phase 0: 项目初始化

目标:

1. 建立 Xcode Workspace
2. 创建 macOS / iOS 双 target
3. 创建共享 packages
4. 定义 `TransportSession`、协议 envelope、持久化接口
5. 接入基础日志、错误处理、配置体系

交付物:

1. 可编译的双端空壳应用
2. 共享模型和基础目录结构
3. 可运行的 Mock transport 和基础状态机

### 13.2 Phase 1: 连接与配对

目标:

1. 跑通设备发现
2. 跑通连接与重连
3. 完成首版配对流程
4. 验证前后台切换后的重连行为

交付物:

1. iOS 可发现 Mac
2. Mac 可确认配对
3. 双端可维持稳定会话
4. 形成真机连接测试清单

### 13.3 Phase 2: 应用列表与运行中应用

目标:

1. macOS 端采集常用应用
2. macOS 端采集运行中应用
3. 完成图标按需同步和本地缓存
4. iOS 端可展示并点击切换

交付物:

1. `Dock` 页面可用
2. `Running` 页面可用
3. 激活应用命令闭环可用
4. 图标重连后无需重复全量传输

### 13.4 Phase 3: 剪贴板历史与远程粘贴

目标:

1. 建立文本剪贴板历史
2. 支持增量同步
3. 支持从 iOS 端触发 Mac 粘贴
4. 完成 `commandId` 幂等处理

交付物:

1. `Clipboard` 页面可用
2. 历史同步稳定
3. 远程粘贴成功率达到可接受水平
4. 命令重试不导致重复粘贴

### 13.5 Phase 4: 打磨与发布准备

目标:

1. 完成异常处理与空状态
2. 完成权限引导优化
3. 补齐测试与日志
4. 完成签名、打包、内测说明

交付物:

1. 可用于内测的安装包
2. 基础测试报告
3. 已知问题列表

## 14. 验收标准

MVP 建议以以下标准验收:

1. iOS 首次打开后，能在 10 秒内发现同网络下的目标 Mac。
2. 配对成功后，常用应用和运行中应用能在 2 秒内完成首次展示。
3. macOS 剪贴板新增文本后，iOS 端能在 2 秒内看到更新。
4. iOS 从后台回到前台后，应用能在可接受时间内恢复会话或明确提示重连。
5. iOS 点击常用应用后，macOS 能成功切到目标应用。
6. iOS 点击剪贴板条目后，macOS 能在当前前台应用中完成粘贴。
7. 同一 `commandId` 被重复发送时，macOS 不会重复执行粘贴动作。
8. 权限缺失时，macOS 端能明确提示具体缺失项和解决路径。
9. 断网或断连后，系统不会崩溃，且能自动或手动恢复连接。

## 15. 测试策略

### 15.1 单元测试

覆盖:

1. 数据模型编解码
2. 协议 envelope 编解码
3. 剪贴板去重与截断逻辑
4. 配对状态机
5. 传输状态机
6. 命令结果映射与幂等去重逻辑

### 15.2 集成测试

覆盖:

1. 双端握手
2. 快照同步
3. 命令发送与回执
4. 图标按需拉取与缓存命中
5. 重试场景下的重复命令处理

建议为传输层提供 Mock，以便在不依赖真实设备时验证状态流转。

### 15.3 手工测试

重点覆盖:

1. 首次安装
2. 首次配对
3. 权限未授权
4. Mac 锁屏
5. 目标应用未运行
6. 目标应用已运行但不在前台
7. 断连重连
8. iOS 前后台切换
9. 剪贴板连续高频变化
10. 图标缓存清空后的重新拉取

## 16. 主要风险

### 16.1 粘贴动作稳定性

不同应用对模拟输入的响应可能不同，必须尽早验证:

1. 原生应用
2. Electron 应用
3. 浏览器
4. IDE

### 16.2 权限与系统限制

Accessibility 权限如果未正确授予，会直接影响核心闭环，因此权限检测和引导是首版高优先级能力，不是附属功能。

### 16.3 连接可靠性

`MultipeerConnectivity` 虽然适合 MVP，但在重连、后台状态和设备可发现性方面风险较高，尤其要重点验证:

1. iOS 前后台切换后的会话恢复
2. 长时间空闲后的重连
3. 真机与模拟器行为差异

因此必须把传输层抽象独立，避免后续难以替换。

### 16.4 隐私风险

剪贴板天然敏感，必须提供:

1. 总开关
2. 清空能力
3. 排除规则
4. 已配对设备管理

### 16.5 图标资源同步

如果图标跟随主快照全量同步，会直接拉高首屏耗时和重连耗时，因此图标必须采用哈希缓存和按需同步策略。

## 17. 开发建议顺序

建议按以下顺序开发，而不是先做完整 UI:

1. 先完成共享模型与传输抽象。
2. 再完成双端配对和连接稳定性。
3. 再完成应用列表与运行中应用同步。
4. 最后做剪贴板历史与远程粘贴。
5. 同步推进真机测试，不要把验证压到最后。
6. UI 在每个阶段只做刚够验证闭环的最小界面。

原因:

1. 连接和权限是最容易卡死项目的部分。
2. 应用切换比剪贴板粘贴更容易稳定落地。
3. 图标同步和命令幂等如果不提前设计，后面返工成本较高。
4. 先跑通轻闭环，能更快验证产品价值和技术风险。

## 18. 建议的首个迭代目标

第一个可执行迭代不要直接做全量功能，建议只交付以下最小闭环:

1. iOS 发现 Mac
2. iOS 展示固定的常用应用列表
3. iOS 点击应用后，Mac 切换到对应应用

这一迭代完成后，再追加:

1. 运行中应用列表
2. 剪贴板历史
3. 远程粘贴

这样可以显著降低项目起步阶段的不确定性。

## 19. 待确认问题

以下问题建议在正式编码前尽快拍板:

1. 产品是否只面向个人使用，还是未来需要多设备多用户。
2. 首发是否接受 `Developer ID + Notarization` 直发，以及未来是否明确要支持 `Mac App Store` 功能降级版本。
3. iOS 端是否需要支持 iPad 独立布局。
4. 剪贴板历史是否允许持久化落盘，还是只保留内存缓存。
5. “常用应用”是纯手动配置，还是允许根据使用频率自动推荐。

## 20. 结论

这个项目适合采用“本地优先、权限优先、闭环优先”的开发策略。

最务实的路线是:

1. 先做 Apple-only 的局域网 MVP。
2. 先把应用切换闭环跑通。
3. 再做剪贴板历史与粘贴。
4. 全程把传输层和系统集成层解耦，避免后续重写。

如果按此 spec 执行，项目可以在较低复杂度下快速完成第一版验证，并为后续扩展到更强的远程能力保留空间。
