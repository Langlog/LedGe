# Ledge

Ledge 是一个原生、轻量、完全本地运行的 macOS 底边工具。它把临时便签和文件中转站藏在屏幕底部，需要时出现，不用时完全不可见。

## 功能

- 鼠标靠近屏幕底部中央时，仅滑入一个贴边绿色小标签；点击确认后展开便签。
- 单一纯文本便签，自动保存在本机，支持中文恢复。
- 支持 `Ctrl+A`、`⌘A`、`⌘C`、`⌘V`；展开窗口可用 `Esc` 或点击窗口外部快速收回。
- 从 Finder 拖动真实文件或文件夹时自动展开文件中转站，支持一次拖入多个项目。
- 拖入后执行真实移动，源位置消失；从 Ledge 拖出后成为目标位置的普通文件。
- 便签和文件移动使用相同窗口尺寸，可在顶部左右切换。
- 无 Dock 图标，通过菜单栏图标打开 Settings。
- 可设置登录启动、多显示器和唤醒灵敏度；成功拖出后自动移除中转记录。
- 适配 macOS 深色模式，不联网，不包含账号、广告、遥测或云同步。

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac（请在目标架构的 Mac 上构建对应版本）

## 安装

打开 `Ledge-0.1.3.dmg`，把 `Ledge.app` 拖到 `Applications` 文件夹，然后从“应用程序”打开。Ledge 启动后不显示 Dock 图标，请在菜单栏寻找它的图标。

未使用 Developer ID 签名和 Apple 公证的测试包可能被 Gatekeeper 拦截；公开分发前请按 [GitHub 发布指南](docs/GITHUB-PUBLISH.md)完成正式签名和公证。

## 使用

1. 把指针移动到当前屏幕底部中央，绿色小标签会从屏外滑入。
2. 点击小标签确认展开，默认进入便签。
3. 按 `Esc` 或点击右上角叉号即可收回主窗口。
4. 从 Finder 拖动文件到底部时，Ledge 会直接展开“文件移动”。
5. 把文件放入窗口即移动到本地中转站；从文件卡片拖出即移动到目标位置。
6. 点击菜单栏图标打开 Settings。

## 本地开发

项目基于 Swift Package Manager，不依赖第三方运行库。

```sh
swift test --disable-sandbox --jobs 1
./scripts/build-app.sh
./scripts/build-dmg.sh
```

输出文件位于：

- `dist/Ledge.app`
- `dist/Ledge-0.1.3.dmg`

`build-app.sh` 默认使用 ad-hoc 签名。拥有 Developer ID 证书时，可以这样构建：

```sh
LEDGE_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" ./scripts/build-dmg.sh
```

## 数据与隐私

便签、设置和中转文件只保存在：

```text
~/Library/Application Support/Ledge/
```

详细说明见 [PRIVACY.md](PRIVACY.md)。安全问题请按 [SECURITY.md](SECURITY.md)联系。

## 发布资料

- [GitHub 上传与正式发布指南](docs/GITHUB-PUBLISH.md)
- [抖音宣传逐字稿](docs/DOUYIN-SCRIPT.md)
- [0.1.3 发布说明](RELEASE_NOTES.md)
- [参与开发](CONTRIBUTING.md)

## 授权

仓库目前没有附带开源许可证。在选择并加入 `LICENSE` 之前，代码默认保留全部权利，不代表允许复制、修改或再发布。

联系邮箱：`langziyu2025@gmail.com`
