# Remote Dock 网站文档目录

本目录包含托管在 GitHub Pages 上的网站内容。

## 📁 目录结构

```
docs/website/
├── README.md              # 用户文档和产品介绍
├── privacy-policy.html    # 隐私政策页面（中英文）
└── .git/                  # Git 仓库
```

## 🔄 同步方法

### 查看当前状态

```bash
cd docs/website
git status
```

### 更新文档后推送到 GitHub

```bash
cd docs/website
git add .
git commit -m "Update documentation"
git push
```

### 从 GitHub 拉取最新更改

```bash
cd docs/website
git pull
```

## 🌐 在线访问

- **GitHub 仓库**: https://github.com/kidoln/remotedock
- **GitHub Pages**: https://kidoln.github.io/remotedock/

## 📝 编辑文档

### 1. 直接在本目录编辑

编辑 `README.md` 或 `privacy-policy.html`

### 2. 提交更改

```bash
git add .
git commit -m "描述你的更改"
git push
```

### 3. 等待 GitHub Pages 自动部署

通常需要 1-5 分钟

## ⚠️ 注意事项

- 本目录是一个独立的 Git 仓库
- 不要在这里存放源代码
- 只存放网站相关的文档

## 🔗 相关链接

- 项目源代码: `/Users/kido/code/e_remote_dock/`
- App Store 文案: `/Users/kido/code/e_remote_dock/docs/app_store_descriptions.md`
- 发布 Checklist: `/Users/kido/code/e_remote_dock/docs/3_app_store_release_checklist.md`
