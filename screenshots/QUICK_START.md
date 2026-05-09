# iOS 截图快速指南

## 方法一：使用自动化脚本（推荐）

### 步骤：

1. **打开终端，进入截图目录**

   ```bash
   cd /Users/kido/code/e_remote_dock/screenshots
   ./capture_ios_screenshots.sh
   ```

2. **按照提示操作**
   - 脚本会自动启动模拟器
   - 自动构建和安装应用
   - 自动切换页面并截图

3. **查看截图**
   - 截图保存在 `screenshots/ios/source/` 目录
   - 脚本会自动打开 Finder

---

## 方法二：手动截图（更灵活）

### 准备工作：

1. **启动模拟器**

   ```bash
   open -a Simulator
   ```

2. **在 Xcode 中运行应用**
   - 打开 `RemoteDock.xcworkspace`
   - 选择 `RemoteDockiOS` scheme
   - 选择 iPhone 17 Pro 模拟器
   - 点击 Run (⌘R)

3. **创建截图目录**
   ```bash
   mkdir -p ~/Desktop/RemoteDock_Screenshots
   cd ~/Desktop/RemoteDock_Screenshots
   ```

### 截图步骤：

#### 1. Dock 页面截图

```bash
# 应用默认显示 Dock 页面
xcrun simctl io "iPhone 17 Pro" screenshot dock_1.png
```

#### 2. Running 页面截图

```bash
# 在模拟器中点击 Running 标签
# 等待页面加载完成
xcrun simctl io "iPhone 17 Pro" screenshot running_1.png
```

#### 3. Clipboard 页面截图

```bash
# 在模拟器中点击 Clipboard 标签
# 等待页面加载完成
xcrun simctl io "iPhone 17 Pro" screenshot clipboard_1.png
```

#### 4. Settings 页面截图

```bash
# 在模拟器中点击 Settings 标签
# 等待页面加载完成
xcrun simctl io "iPhone 17 Pro" screenshot settings_1.png
```

---

## 方法三：使用快捷键（最简单）

### 在模拟器中：

1. **运行应用**
2. **切换到要截图的页面**
3. **使用快捷键截图**：
   - `⌘ + S`（在模拟器中）
   - 或 `⌘ + Shift + 4` 选择区域

### 在真机中：

1. **安装应用到 iPhone**
2. **运行应用**
3. **使用快捷键截图**：
   - **iPhone X 及更新机型**：同时按住电源键和音量加键
   - **iPhone 8 及更早机型**：同时按住电源键和 Home 键
4. **使用 AirDrop 传输到 Mac**

---

## 截图优化建议

### 1. 移除状态栏（可选）

使用 ImageMagick：

```bash
# 裁剪掉顶部状态栏（约 54px）
convert input.png -gravity North -chop 0x54 output.png
```

### 2. 添加设备边框

使用在线工具：

- [Screener](https://screener.com) - 免费，简单易用
- [Mockuphone](https://mockuphone.com) - 支持多种设备

或使用 Fastlane 的 frameit：

```bash
# 安装 fastlane
brew install fastlane

# 添加边框
fastlane frameit path:./screenshots
```

### 3. 统一尺寸

确保所有截图尺寸一致：

```bash
# 调整为 iPhone 6.7" 尺寸 (1290x2796)
sips -z 2796 1290 input.png --out output.png
```

---

## 截图检查清单

上传到 App Store 之前，确保：

- [ ] 所有截图清晰无模糊
- [ ] 所有截图分辨率正确
- [ ] 所有截图无测试数据
- [ ] 所有截图无个人敏感信息
- [ ] 所有截图展示真实功能
- [ ] 所有截图内容完整无截断
- [ ] 所有截图命名清晰

---

## 常见问题

### Q: 模拟器显示配对界面，怎么办？

A: 有两种方案：

**方案 1：使用模拟数据（推荐）**

- 在代码中添加模拟数据模式
- 截图时显示假数据

**方案 2：连接真实 Mac**

- 在 Mac 上运行 RemoteDockMac
- 确保 iPhone 和 Mac 在同一网络
- 完成配对后再截图

### Q: 截图尺寸不对？

A: 检查模拟器型号：

- iPhone 6.7" → 1290x2796 ✓
- iPhone 6.5" → 1242x2688
- iPhone 6.1" → 1170x2532

### Q: 截图有状态栏时间？

A: App Store 允许状态栏，但建议使用统一时间（如 9:41）

---

## 推荐的截图文件名

```
screenshots/ios/
├── 1_Dock_常用应用.png
├── 2_Running_运行中应用.png
├── 3_Clipboard_剪贴板历史.png
├── 4_Settings_设置与配对.png
└── 5_Pairing_配对流程.png
```

---

**提示**：建议先手动截图几张，确保效果满意后再使用自动化脚本批量处理。
