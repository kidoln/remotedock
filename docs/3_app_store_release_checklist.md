# App Store 发布前 Checklist

文档版本: v0.1
更新时间: 2026-05-09
适用范围: App Store 发布准备阶段

> 说明：本文档用于追踪 Remote Dock iOS 和 macOS 应用发布到 App Store 的准备工作。已完成的项用 `[x]` 标记，待完成的项用 `[ ]` 标记，需要用户提供信息的项用 `[ ] TODO:` 标记。

---

## 1️⃣ App Store Connect 基础配置

### iOS 应用信息

- [ ] 创建 App Store Connect 应用记录
- [x] Bundle ID: `com.kido.RemoteDockiOS`
- [x] 开发团队: QSZ6C2FCXK
- [x] App 名称: `Remote Dock`
- [x] SKU: `remotedock-ios-001`
- [x] 副标题: `iPhone 控制 Mac 伴侣` / `Your Mac, From Your iPhone`
- [x] 隐私政策 URL: `https://kidoln.github.io/remotedock/privacy-policy.html` ✅

### macOS 应用信息

- [ ] 创建 App Store Connect 应用记录
- [x] Bundle ID: `com.kido.RemoteDockMac`
- [x] 开发团队: QSZ6C2FCXK
- [x] App 名称: `Remote Dock for Mac`
- [x] SKU: `remotedock-mac-001`
- [x] 副标题: `剪贴板管理器 + iPhone 控制` / `Clipboard Manager & iPhone Control`
- [x] 隐私政策 URL: `https://kidoln.github.io/remotedock/privacy-policy.html` ✅

### 定价与销售范围

- [x] macOS 应用: 免费
- [x] iOS 应用: 一次性买断（基础功能免费，高级功能付费）
  - [ ] TODO: 设计并实现内购功能
- [x] 销售地区: 全球所有市场
- [ ] 可用性设置为手动发布

---

## 2️⃣ App 类别与审核信息

### iOS 应用

- [x] 主类别: 工具类 (Utilities)
- [ ] 副类别（可选）
- [x] 内容版权信息: `© 2026 Kido Apps`

### macOS 应用

- [x] 主类别: 工具类 (Utilities)
- [ ] 副类别（可选）
- [x] 内容版权信息: `© 2026 Kido Apps`

---

## 3️⃣ 宣传素材与文案

### 应用图标

- [x] iOS App Icon（已存在）
- [x] 确认 iOS 图标质量（1024x1024 用于 App Store）✅ 已检查
- [x] macOS App Icon（已存在）
- [ ] TODO: 确认 macOS 图标质量

### 屏幕截图

#### iOS 端截图

- [x] iPhone 6.7" 截图（1290x2796 像素）✅ 已完成 6 张
  - [x] Dock 页面截图
  - [x] Running 页面截图
  - [x] Clipboard 页面截图
  - [x] Settings/配对页面截图
  - [x] 应用切换演示截图
  - [x] 剪贴板粘贴演示截图
- [x] iPhone 5.4" (13 mini) 截图 ✅ 已完成 6 张
- [ ] iPad Pro 12.9" 截图（2048x2732 像素，如果支持 iPad）
- [ ] 添加设备边框（可选）
  - [ ] 使用在线工具（如 Screener.com）或 Fastlane frameit

> ✅ 截图保存在：`/screenshots/ios/`（共 12 张）

#### macOS 端截图

- [x] MacBook Pro 16" 截图 ✅ 已完成（用户手动截图）
  - [x] 菜单栏图标截图
  - [x] 设置窗口截图
  - [x] 常用应用管理截图
  - [x] 剪贴板历史查看截图
  - [x] 权限引导截图
  - [x] 配对码显示截图
- [ ] MacBook Air 13" 截图（可选）

### App 预览视频（强烈推荐）

- [ ] TODO: iOS 端 15-30 秒演示视频
  - 展示配对流程
  - 展示应用切换
  - 展示剪贴板同步和粘贴
- [ ] TODO: macOS 端 15-30 秒演示视频
  - 展示菜单栏操作
  - 展示设置界面

---

## 4️⃣ App Store 文案

### 简体中文

#### iOS 应用

- [x] 简短描述（最多 80 字符）
- [x] 详细描述（突出核心功能）
- [x] 关键词（最多 100 字符，用逗号分隔）
- [x] 推广文本（170 字符）
- [ ] 在 App Store Connect 中填写以上内容

> ✅ 已准备好的文案: 见 `/docs/app_store_descriptions.md`

#### macOS 应用

- [x] 简短描述（最多 80 字符）
- [x] 详细描述
- [x] 关键词
- [x] 推广文本（170 字符）
- [ ] 在 App Store Connect 中填写以上内容

> ✅ 已准备好的文案: 见 `/docs/app_store_descriptions.md`

### 英文

#### iOS Application

- [x] Short Description (80 characters max)
- [x] Detailed Description
- [x] Keywords (100 characters max, comma-separated)
- [x] Promotional Text (170 characters max)
- [ ] 在 App Store Connect 中填写以上内容

> ✅ 已准备好的文案: 见 `/docs/app_store_descriptions.md`

#### macOS Application

- [x] Short Description (80 characters max)
- [x] Detailed Description
- [x] Keywords
- [x] Promotional Text (170 characters max)
- [ ] 在 App Store Connect 中填写以上内容

> ✅ 已准备好的文案: 见 `/docs/app_store_descriptions.md`

---

## 5️⃣ 应用内配置检查

### iOS Info.plist

- [x] NSBluetoothAlwaysUsageDescription 已配置
- [x] NSLocalNetworkUsageDescription 已配置
- [x] 支持的设备方向已配置
- [x] 最小系统版本: iOS 17.6

### macOS Info.plist

- [x] NSBluetoothAlwaysUsageDescription 已配置
- [x] NSLocalNetworkUsageDescription 已配置
- [x] LSUIElement = true（菜单栏应用）
- [x] 最小系统版本: macOS 15.6（需确认）

### 权限描述文案审核

- [ ] TODO: 确认所有权限描述文案清晰易懂
- [ ] TODO: 确认权限描述在 Info.plist 和 Localizable.xcstrings 中一致

---

## 6️⃣ 多语言资源检查

- [x] 简体中文本地化已完成
- [x] 英文本地化已完成
- [ ] TODO: App Store Connect 上传对应语言的截图和文案
- [ ] TODO: 确认所有 UI 文案都通过 Localizable.xcstrings 管理

---

## 7️⃣ 测试与质量保证

### 功能测试

- [ ] TODO: 配对流程测试（首次配对、重新配对）
- [ ] TODO: 应用切换测试（已运行应用、未运行应用）
- [ ] TODO: 剪贴板同步测试（文本、特殊字符、长文本）
- [ ] TODO: 剪贴板粘贴测试（不同应用、中文输入法）
- [ ] TODO: 重连机制测试（网络断开、应用重启）

### 权限测试

- [ ] TODO: Accessibility 未授予时的行为
- [ ] TODO: Local Network 未授予时的行为
- [ ] TODO: 权限引导流程测试

### 边缘情况测试

- [ ] TODO: iOS 进入后台后的连接状态
- [ ] TODO: Mac 锁屏后的行为
- [ ] TODO: 版本不匹配时的提示
- [ ] TODO: 网络切换（WiFi <-> 蜂窝）时的行为
- [ ] TODO: 剪贴板为空时的行为

### 稳定性测试

- [ ] TODO: 长时间运行测试（至少 1 小时）
- [ ] TODO: 连续快速操作测试
- [ ] TODO: 剪贴板高频变化测试

### 设备兼容性测试

- [ ] TODO: iPhone 测试（至少 2 个机型，建议：iPhone 15 Pro、iPhone 13）
- [ ] TODO: iPad 测试（如果支持）
- [ ] TODO: Mac 测试（至少 2 个机型，建议：MacBook Pro、Mac mini）
- [ ] TODO: 不同 macOS 版本测试（14.x、15.x）

---

## 8️⃣ 法律与合规

### 必需文档

- [x] 隐私政策 HTML 文件已生成: `/privacy-policy.html`
- [x] 托管隐私政策到在线 URL ✅ 已完成
  - [x] 创建 GitHub Pages 仓库
  - [x] 上传 `privacy-policy.html`
  - [x] 获取公开 URL: `https://kidoln.github.io/remotedock/privacy-policy.html`
  - [ ] 将 URL 填入 App Store Connect（在创建应用记录后填写）

- [ ] 服务条款（可选但推荐）
- [ ] 最终用户许可协议 EULA（可选）

### App 隐私

- [x] 已确认收集的数据：无
- [x] 已确认第三方 SDK：无
- [ ] 在 App Store Connect 中填写隐私标签（全部选择"否"）

### 其他合规

- [ ] 出口合规声明（在 App Store Connect 中确认）
- [x] 广告标识符：不使用 IDFA（在 App Store Connect 中选择"否"）
- [x] 年龄等级：4+（最低等级）

---

## 9️⃣ 版本号与构建号

- [x] iOS 版本号：1.0.0 (MARKETING_VERSION)
- [x] iOS 构建号：1 (CURRENT_PROJECT_VERSION)
- [x] macOS 版本号：1.0.0 (MARKETING_VERSION)
- [x] macOS 构建号：1 (CURRENT_PROJECT_VERSION)
- [ ] TODO: 规划未来版本号策略

---

## 🔟 TestFlight 准备

### 内部测试

- [ ] TODO: 添加内部测试人员（最多 100 人）
- [ ] TODO: 准备内部测试反馈收集表单

### Beta 测试

- [ ] TODO: 准备 Beta 测试招募文案
- [ ] TODO: 设置 Beta 测试期限（建议至少 1 周）
- [ ] TODO: 准备 Beta 测试反馈收集渠道

---

## 1️⃣1️⃣ 技术准备

### 证书与配置文件

- [ ] TODO: iOS Distribution Certificate 已创建
- [ ] TODO: macOS Distribution Certificate 已创建
- [ ] TODO: iOS Provisioning Profiles 已配置
- [ ] TODO: macOS Provisioning Profiles 已配置

### 构建与上传

- [ ] TODO: iOS 应用归档（Archive）成功
- [ ] TODO: macOS 应用归档（Archive）成功
- [ ] TODO: 上传到 App Store Connect
- [ ] TODO: 在 App Store Connect 中选择构建版本

### 沙盒与权限（macOS 特有）

- [x] Entitlements 文件已创建: `RemoteDockMac.entitlements`
- [x] 包含权限:
  - [x] App Sandbox（强制）
  - [x] Network Client/Server
  - [x] Bonjour/mDNS
  - [x] Bluetooth
  - [x] Apple Events（用于应用切换）
- [ ] TODO: 在 Xcode 中配置 Code Signing Entitlements
  - Build Settings → Code Signing Entitlements = `RemoteDockMac/RemoteDockMac.entitlements`
- [ ] TODO: 测试构建验证沙盒配置正确

---

## 1️⃣2️⃣ 文档准备

### 用户文档

- [ ] TODO: 用户使用指南（可放在 GitHub Wiki 或单独网站）
- [ ] TODO: 常见问题 FAQ
- [ ] TODO: 故障排除指南
- [ ] TODO: 版本更新日志（首次发布可为空）

### 支持渠道

- [ ] TODO: 支持邮箱（在 App Store Connect 中填写）
- [ ] TODO: 反馈渠道（GitHub Issues、邮箱等）
- [ ] TODO: 网站/着陆页（可选但推荐）

---

## 1️⃣3️⃣ 上传前最终检查

### 构建检查清单

- [ ] TODO: 所有 TODO 项已完成
- [ ] TODO: 版本号正确
- [ ] TODO: Bundle ID 正确
- [ ] TODO: 所有图标和截图已上传
- [ ] TODO: 所有文案已填写（中英文）
- [ ] TODO: 隐私政策 URL 有效
- [ ] TODO: 至少在一台真机上测试通过
- [ ] TODO: 无已知的崩溃或严重 Bug

### App Review 准备

- [ ] TODO: 准备审核账号（如果需要特殊权限演示）
- [ ] TODO: 准备测试说明（如果有特殊功能需要演示）
- [ ] TODO: 检查是否符合 App Store 审核指南

---

## 进度追踪

| 类别                   | 完成度 | 说明                              |
| ---------------------- | ------ | --------------------------------- |
| App Store Connect 配置 | 35%    | 基础信息已确定，待创建应用记录    |
| 宣传素材               | 80%    | ✅ 截图已完成，待准备视频（可选） |
| 文案撰写               | 80%    | 中英文文案已准备好，待上传到 ASC  |
| 应用内配置             | 95%    | 基础配置完成，待最终确认          |
| 多语言                 | 100%   | ✅ 已完成中英文本地化             |
| 测试与质量保证         | 0%     | 需要进行全面测试                  |
| 法律与合规             | 85%    | ✅ 隐私政策已托管到 GitHub Pages  |
| 技术准备               | 0%     | 需要配置证书和构建                |

---

## 🎯 下一步行动建议

### 本周必做（高优先级）

1. ~~**准备应用截图**~~ ⭐⭐⭐
   - ✅ iOS: 已完成 12 张（iPhone 17 Pro + iPhone 13 mini）
   - ✅ macOS: 已完成

2. ~~**托管隐私政策**~~ ⭐⭐⭐
   - ✅ 已托管到 GitHub Pages
   - ✅ URL: https://kidoln.github.io/remotedock/privacy-policy.html

3. **创建 App Store Connect 应用记录** ⭐⭐
   - iOS 应用
   - macOS 应用

4. **设计并实现内购功能** ⭐⭐
   - 基础功能免费
   - 高级功能一次性买断

### 本周可做（中优先级）

1. 开始全面功能测试
2. 准备 App 预览视频（可选但推荐）
3. 准备 TestFlight 测试

### 下周进行

1. 完成所有测试
2. 代码签名和归档构建
3. 上传到 App Store Connect
4. 提交审核

---

## 📁 已准备好的文档

- ✅ `/docs/3_app_store_release_checklist.md` - 本 checklist
- ✅ `/docs/app_store_descriptions.md` - App Store 文案（中英文）
- ✅ `/privacy-policy.html` - 隐私政策页面（中英文双语）
- ✅ `/docs/1_development-spec.md` - 开发规范
- ✅ `/docs/2_localization-design.md` - 本地化设计

---

**文档维护者：** 李楠
**最后更新：** 2026-05-09
**版本：** v0.2
