# 沾沾 0.1

Maccy 的本地定制分支：底部磨砂浮窗、横向复制卡片、独立收藏与一级文件夹。

## 使用

安装包位于 `dist/沾沾.app`。默认 **⌘⇧V** 唤起，点击菜单栏双卡片图标也可打开。

- 历史卡片正文：复制并粘贴；⌥ 点击仅复制。未授权辅助功能时只复制。
- 右上角 × 删除，底部提供 10 秒撤销。
- 把卡片拖到目标左半边/右半边，分别插到其前面/后面；搜索和历史类型筛选期间暂停排序。
- 常用收藏：点文件夹加号新建，右键文件夹重命名/删除。删除文件夹把内容移入未分类。
- 收藏右键可编辑、移动到文件夹；把历史拖到文件夹可收藏。点击收藏正文复制，网址右侧箭头在浏览器打开。
- 收藏内容独立保存，删除历史不会删除收藏。文件路径收藏不复制文件本体；原文件移动或删除后路径可能失效。
- 更多 → 设置可以更换快捷键、暂停记录、调整历史条数。
- 自动粘贴需要在系统设置 → 隐私与安全性 → 辅助功能中允许“沾沾”。由用户自行开启。

## 开发与构建

当前分支使用 **SwiftPM**，系统 Swift 6.3、macOS 14+ SDK。原上游 Xcode 工程和 XCTest 仅作为上游参考，不是本分支构建入口。

```sh
bash scripts/check-core.sh
bash scripts/build-app.sh release
open dist/沾沾.app
```

依赖固定在 Package.resolved。KeyboardShortcuts 3.1.0 的本地补丁见 Vendor/KeyboardShortcuts/PATCHES.md。

## 架构

- `Clipboard.swift`：Maccy 的 NSPasteboard 轮询、类型处理、敏感类型忽略与复制/粘贴。
- `History` + `HistoryItem`：去重、搜索、条数限制、手动排名，@Observable 驱动界面。
- `Storage` + `ShelfCore.HistoryArchive`：历史内容、时间、来源与排名的版本化 JSON 原子快照。
- `ShelfCore.ShelfLibrary`：收藏内容快照、文件夹和顺序；每次事务先落盘成功再更新内存。
- `ShelfState`：界面操作、粘贴权限与错误提示、删除撤销。
- `ContentView` / `ShelfCards` / `ShelfEditorView`：SwiftUI；`FloatingPanel` 和 `NSVisualEffectView` 提供底部浮窗与原生磨砂。

数据目录 `~/Library/Application Support/ZhanZhan/`，`History.json` 与 `Favorites.json` 分开存储。用户偏好和快捷键归属 `local.zhanzhan.clipboard`。不读取官方 Maccy 的历史，不自动连接其升级源。日志不记录新捕获的剪贴板正文。

命令行工具没有 SwiftDataMacros，因此本分支把原 SwiftData 持久层替换为 @Observable + Codable；保留剪贴板处理逻辑。JSON 快照以同步原子写入保证一致性，尚未对大量超大图片做性能压力测试。

## 验证范围

独立核心检查覆盖文件夹操作、图片内容快照、重启恢复、删除撤销、排序、损坏/未来版本保护、失败写入不污染内存、编辑保留混合格式。原生 UI 的检查记录见 implementation.md。

本机 ad-hoc 签名构建，不是 Developer ID 公证分发版本。MIT 原始声明保留在仓库及应用 Resources 中。
