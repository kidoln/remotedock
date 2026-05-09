# Remote Dock 用户指南 / User Guide

**Remote Dock** 是一款专为 Apple 生态设计的效率工具，让你的 iPhone 成为 macOS 的完美伴侣。

**Remote Dock** is an efficiency tool designed for the Apple ecosystem, making your iPhone the perfect companion for your Mac.

---

## 📱 快速开始 / Quick Start

### 系统要求 / System Requirements

- **Mac**: macOS 14.0 或更高版本
- **iPhone**: iOS 17.6 或更高版本
- 双端设备需在同一局域网或开启 Apple 近距连接

---

## 🔗 配对流程 / Pairing Process

### 步骤 / Steps

1. **在 Mac 上启动 Remote Dock for Mac**
2. **查看配对码**
   - Mac 菜单栏会显示 4 位配对码
   - 记住这个配对码

3. **在 iPhone 上打开 Remote Dock**
4. **输入配对码**
   - 输入 Mac 上显示的 4 位数字
   - 输入完成后自动连接

5. **连接成功**
   - iPhone 显示"已连接"状态
   - 开始使用远程控制功能

### 重新配对 / Re-pairing

如果需要更换配对设备或重新配对：

- **Mac 端**：设置 → 关于 → 重新生成配对码
- **iPhone 端**：设置 → 配对 → 输入新的配对码

---

## ⚡ 主要功能 / Features

### Dock - 常用应用

快速切换 Mac 上常用的应用。

Quickly switch between your frequently used Mac apps.

**使用方法 / How to use**:

- 点击应用图标即可切换到 Mac 上的对应应用
- Tap an app icon to switch to that app on your Mac

---

### Running - 运行中的应用

查看并切换 Mac 上当前运行的应用。

View and switch between currently running apps on your Mac.

**使用方法 / How to use**:

- 查看所有运行中的应用
- 点击应用图标将其切换到前台
- 绿色高亮表示当前活跃应用
- View all running apps
- Tap an app to bring it to the foreground
- Green highlight indicates the currently active app

---

### Clipboard - 剪贴板历史

查看 Mac 剪贴板历史，一键粘贴到 Mac。

View Mac clipboard history and paste with one tap.

**使用方法 / How to use**:

1. 查看剪贴板历史列表
2. 点击任意条目将其粘贴到 Mac 的当前应用
3. 已粘贴的条目会有标记
4. 支持搜索剪贴板内容
5. View clipboard history list
6. Tap any item to paste it to the current Mac app
7. Pasted items are marked
8. Support for searching clipboard content

---

## ⚙️ 设置 / Settings

### 配对 / Pairing

- 查看连接状态
- 查看已配对的 Mac 设备
- 查看配对码
- View connection status
- View paired Mac devices
- View pairing code

### 应用控制 / App Control

- **点击后移到第一位**：点击应用后将其移到列表首位
- **Move to top after tap**: Move tapped app to the top of the list

### 图标大小 / Icon Size

调整应用图标显示大小：小、中、大

Adjust app icon display size: Small, Medium, Large

### 剪贴板 / Clipboard

- **字号**：调整剪贴板文本显示大小
- **清除历史**：清空所有剪贴板历史记录
- **Font Size**: Adjust clipboard text display size
- **Clear History**: Clear all clipboard history

### 语言 / Language

选择应用界面语言（简体中文或 English）

Select app interface language (Simplified Chinese or English)

---

## 🔧 故障排除 / Troubleshooting

### 无法发现 Mac？

**可能原因 / Possible causes**:

1. Mac 和 iPhone 不在同一网络
2. Mac 上的 Remote Dock 未运行
3. Mac 的防火墙阻止了连接

**解决方法 / Solutions**:

1. 确保双端设备在同一 Wi-Fi 网络
2. 在 Mac 上启动 Remote Dock for Mac
3. 检查 Mac 系统设置中的防火墙设置
4. Ensure both devices are on the same Wi-Fi network
5. Launch Remote Dock for Mac on your Mac
6. Check firewall settings in Mac System Preferences

---

### 连接后断开？

**可能原因 / Possible causes**:

1. iPhone 切换到了后台
2. Mac 进入休眠状态
3. 网络连接中断

**解决方法 / Solutions**:

- iPhone 会自动尝试重连
- 确保应用在后台运行
- 唤醒 Mac 并检查连接状态
- iPhone will automatically attempt to reconnect
- Ensure the app is running in the background
- Wake up your Mac and check connection status

---

### 无法粘贴到 Mac？

**可能原因 / Possible causes**:

1. Mac 未授予辅助功能权限
2. 目标应用不支持模拟粘贴

**解决方法 / Solutions**:

1. 在 Mac 系统设置中授予辅助功能权限
   - 系统设置 → 隐私与安全性 → 辅助功能
   - 找到 Remote Dock 并启用
2. 某些应用可能不支持模拟粘贴，尝试手动 Cmd+V
3. Grant Accessibility permission on Mac
   - System Settings → Privacy & Security → Accessibility
   - Find Remote Dock and enable it
4. Some apps may not support simulated pasting, try manual Cmd+V

---

### 剪贴板不同步？

**可能原因 / Possible causes**:

1. Mac 端剪贴板同步未开启
2. 连接不稳定

**解决方法 / Solutions**:

1. 在 Mac 设置中确认剪贴板同步已启用
2. 检查连接状态
3. 尝试重新连接
4. Confirm clipboard sync is enabled in Mac Settings
5. Check connection status
6. Try reconnecting

---

## 🔐 隐私与权限 / Privacy & Permissions

### 我们如何保护你的隐私 / How We Protect Your Privacy

- **所有数据仅在本地网络传输**，不经过云端服务器
- **不收集任何用户数据**
- **剪贴板内容仅在本地存储**
- All data is transmitted only on local network, no cloud servers
- No user data collection
- Clipboard content stored locally only

### 需要的权限 / Required Permissions

#### iOS 端 / iOS

- **本地网络**：用于发现和连接 Mac
- **蓝牙**：用于 Apple 近距连接
- **Local Network**: To discover and connect to Mac
- **Bluetooth**: For Apple Peer-to-Peer connection

#### Mac 端 / Mac

- **辅助功能**：用于切换应用和模拟粘贴操作
- **本地网络**：用于发现和连接 iPhone
- **蓝牙**：用于 Apple 近距连接
- **Accessibility**: For app switching and paste simulation
- **Local Network**: To discover and connect to iPhone
- **Bluetooth**: For Apple Peer-to-Peer connection

---

## ❓ 常见问题 / FAQ

### Remote Dock 是免费的吗？/ Is Remote Dock Free?

**Mac 版本完全免费** / **Mac version is completely free**

**iOS 版本**：基础功能免费，高级功能需一次性购买

- **iOS Version**: Basic features are free, advanced features require one-time purchase

---

### 需要互联网连接吗？/ Is Internet Connection Required?

不需要。只需要 Mac 和 iPhone 在同一局域网即可。

No. Just need Mac and iPhone on the same local network.

---

### 可以同时连接多个 Mac 吗？/ Can I Connect to Multiple Macs?

目前版本一次只能连接一个 Mac。如需切换，请先断开当前连接。

Currently, only one Mac can be connected at a time. To switch, disconnect the current connection first.

---

### 支持哪些 Mac 应用？/ Which Mac Apps Are Supported?

支持所有标准 macOS 应用。某些需要特殊权限的应用可能无法切换。

Supports all standard macOS apps. Some apps requiring special permissions may not be switchable.

---

### 数据会通过互联网传输吗？/ Is Data Transmitted Over Internet?

不会。所有数据都在本地网络传输，不会上传到任何服务器。

No. All data is transmitted on the local network and will not be uploaded to any server.

---

## 📧 联系我们 / Contact Us

**邮箱 / Email**: [kido.ln@gmail.com](mailto:kido.ln@gmail.com)

**GitHub**: [https://github.com/kidoln/remotedock](https://github.com/kidoln/remotedock)

---

## 📄 隐私政策 / Privacy Policy

完整的隐私政策请查看：/ Complete privacy policy:

[https://kidoln.github.io/remotedock/privacy-policy.html](https://kidoln.github.io/remotedock/privacy-policy.html)

---

**感谢使用 Remote Dock！/ Thank you for using Remote Dock!**
