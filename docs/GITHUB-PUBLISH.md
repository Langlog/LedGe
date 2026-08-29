# GitHub 上传与发布指南

当前仓库已经准备好 README、隐私与安全说明、贡献指南、更新记录、发布说明、Issue/PR 模板和 macOS CI。`dist/` 已被忽略，DMG 应上传到 GitHub Release，不要提交进 Git 历史。

## 1. 上传前唯一需要决定的事项

选择许可证：

- 想允许他人自由使用和修改：通常选择 MIT。
- 希望衍生项目也必须开源：可考虑 GPL-3.0。
- 暂时不允许他人复制和再发布：保持当前无 `LICENSE` 的状态。

在没有许可证时，GitHub 上的源码可被查看，但默认不授予复制、修改或分发权限。

## 2. 创建 GitHub 仓库

1. 登录 GitHub，点击右上角 `+` → `New repository`。
2. 仓库名建议填写 `Ledge`。
3. 选择 Public 或 Private。
4. 不要勾选初始化 README、`.gitignore` 或 License，因为本地仓库已有文件。
5. 点击 `Create repository`。

## 3. 推送本地源码

在终端执行，把 `<YOUR_USERNAME>` 换成你的 GitHub 用户名：

```sh
cd "/Users/lang/Documents/一个小程序"
git status
git add .
git commit -m "feat: release Ledge 0.1.3"
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/Ledge.git
git push -u origin main
```

如果仓库已有 `origin`，不要重复添加，改用：

```sh
git remote set-url origin https://github.com/<YOUR_USERNAME>/Ledge.git
git push -u origin main
```

## 4. 发布 DMG

1. 确保公开发布包已完成 Developer ID 签名和 Apple 公证。
2. 在仓库主页点击 `Releases` → `Draft a new release`。
3. 创建标签 `v0.1.3`，标题填写 `Ledge 0.1.3`。
4. 粘贴 `RELEASE_NOTES.md` 的内容。
5. 上传 `dist/Ledge-0.1.3.dmg`。
6. 确认不是测试包后再点击 `Publish release`。

## 5. 正式签名与 Apple 公证

本机当前没有有效的 Developer ID Application 证书。加入 Apple Developer Program 并安装证书后，执行：

```sh
cd "/Users/lang/Documents/一个小程序"
LEDGE_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" ./scripts/build-dmg.sh
xcrun notarytool store-credentials "ledge-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
xcrun notarytool submit "dist/Ledge-0.1.3.dmg" \
  --keychain-profile "ledge-notary" \
  --wait
xcrun stapler staple "dist/Ledge-0.1.3.dmg"
xcrun stapler validate "dist/Ledge-0.1.3.dmg"
```

上面的命令会安全地提示输入 App 专用密码，避免把密码写进 shell 历史。不要把 Apple ID、专用密码、证书私钥或 keychain 内容写入仓库。

## 6. 最终检查清单

- [ ] 已选择或明确不使用开源许可证
- [ ] `swift test --disable-sandbox --jobs 1` 全部通过
- [ ] DMG 在一台干净的 Mac 上可打开并拖入 Applications
- [ ] `codesign --verify --deep --strict dist/Ledge.app` 通过
- [ ] `notarytool` 返回 Accepted
- [ ] `stapler validate` 通过
- [ ] Release 附件是公证后的 DMG，而不是本地测试包
- [ ] 仓库中没有密钥、密码、个人测试文件或本地中转数据
