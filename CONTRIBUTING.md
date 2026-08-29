# 参与开发

感谢关注 Ledge。

## 开发流程

1. Fork 仓库并创建功能分支。
2. 新功能或错误修复先补测试。
3. 保持实现小而清晰，不引入不必要的第三方依赖。
4. 提交前运行完整验证。

```sh
swift test --disable-sandbox --jobs 1
./scripts/build-app.sh
```

测试必须全部通过；核心逻辑覆盖率目标不低于 80%。涉及文件移动时，必须覆盖失败回滚、路径逃逸、符号链接和重名文件场景。

提交信息使用 Conventional Commits，例如：

```text
fix: dismiss main panel with escape
feat: add a new wake sensitivity option
```

提交 Pull Request 时，请说明用户行为变化、测试结果和可能的数据迁移影响。
