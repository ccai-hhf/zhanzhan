# 开发与发布

## 工具链与命令

- macOS；Swift 6.3+；macOS 26 SDK；Python 3。
- 推荐 Xcode 26.5+，或对应 Command Line Tools。`bash scripts/doctor.sh` 检查本机版本。
- GitHub 依赖固定在 `Package.resolved`；构建脚本使用 `--force-resolved-versions`。
- 上游 Xcode 工程与 XCTest 保留供参考；本分支采用 SwiftPM 与独立核心检查执行器。

```sh
bash scripts/doctor.sh
bash scripts/check-core.sh
bash scripts/build-app.sh release
bash scripts/install-app.sh      # 已运行沾沾时会提示先退出；可用 INSTALL_DIR 指定安装目录
bash scripts/package-release.sh  # 原生架构 ZIP 与 SHA-256
```

安装脚本只写应用安装目录及旧应用备份目录，不授予辅助功能权限、不修改系统触控板设置、不上传数据。首次启动的授权与登录启动选项由使用者设置。

## 架构

`Clipboard` 轮询 NSPasteboard → `History` 去重与排序 → `HistoryArchive` 写入版本化 JSON → SwiftUI 卡片展示。
`ShelfLibrary` 单独存储收藏与文件夹。`ShelfState` 处理操作反馈和撤销。
`FloatingPanel` 承载 SwiftUI 与系统玻璃，负责鼠标附近定位、开合动画和焦点交还。
`NativeTouch` 动态读取默认触控板 → `ThreeFingerSwipe` 检查触点数量、方向与时长 → 打开/收起面板。

数据模型已从上游 SwiftData 改为 Codable JSON；不能直接导入原版 Maccy 数据库。私有触控接口可能因系统更新失效，需保留快捷键与状态提示。

## 发布流程

1. 更新 `scripts/build-app.sh` 中的版本和构建号，并更新说明。
2. 运行完整核心检查，并从干净 checkout 构建，验证资源 bundle 能随应用迁移。
3. Push 到 main，等待 `.github/workflows/build.yml` 的 Apple Silicon / Intel 两个 job 通过。
4. 下载对应 Actions artifacts，将其中的 ZIP 和 `.sha256` 上传到同一版本的 GitHub Release。
5. 在 Release 明确列出构建、运行和硬件手势验证的不同范围。

CI 使用 GitHub 官方 `macos-26` 和 `macos-26-intel`，选择 Xcode 26.5。构建产物使用 ad-hoc 签名；这里没有 Developer ID 私钥和公证凭据。今后如需无开发者警告的分发，应由维护者配置自己的 Developer ID 签名及 Apple notarization，不要在仓库提交证书或密钥。

## 测试边界

核心检查覆盖持久化、文件夹删除保留内容、图片快照、重启、排序、失败写入回滚、损坏/未来版本保护、编辑混合内容与三指方向/抬手/冷却/四指排除。

CI 编译通过不能替代：首次运行 Gatekeeper 流程、系统辅助功能授权、真实跨应用粘贴、真实触控板、多个显示器、macOS 14/15 和超大图片性能验证。历史检查记录位于 `docs/zhanzhan/`，其中旧版本行为以最新 README 为准。
