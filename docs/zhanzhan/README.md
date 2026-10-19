# 沾沾 0.2

Maccy 的本地定制分支：底部磨砂浮窗、横向复制卡片、独立收藏与一级文件夹。

## 使用

安装包位于 `dist/沾沾.app`。默认 **三指向下滑动并抬起** 唤起，保留 **⌘⇧V** 作为备用，点击菜单栏双卡片图标也可打开。

- 单击历史卡片或收藏：选中并复制，保持面板打开。亮色背景、蓝色描边、勾选标记显示选中状态。双击或回车粘贴；未授权辅助功能时只复制。
- 右上角 × 删除，底部提供 10 秒撤销。
- 把卡片拖到目标左半边/右半边，分别插到其前面/后面；搜索和历史类型筛选期间暂停排序。
- 常用收藏：点文件夹加号新建，右键文件夹重命名/删除。删除文件夹把内容移入未分类。
- 收藏右键可编辑、移动到文件夹；把历史拖到文件夹可收藏。点击收藏正文复制，网址右侧箭头在浏览器打开。
- 收藏内容独立保存，删除历史不会删除收藏。文件路径收藏不复制文件本体；原文件移动或删除后路径可能失效。
- 更多 → 设置可以开关三指下滑、更换备用快捷键、切换磨砂/更通透玻璃、暂停记录和调整历史条数。
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

## 0.2 交互与手势

- macOS 26 使用 NSGlassEffectView，内容通过 contentView 嵌入玻璃；默认 regular，设置可切换 clear。macOS 14/15 回退 NSVisualEffectView popover。
- 内部复制重复条目时保留原 HistoryItem 和 Decorator 对象，防止选中高亮丢失及旧对象内容清空。
- NativeTouch 使用 dlopen 加载系统 MultitouchSupport 私有框架，ABI 声明参考 OpenMultitouchSupport（MIT，来源与许可证见 NativeTouch）。不依赖下载的预编译二进制。
- 仅监听默认触控板；三指向下移动达到阈值，在抬手时触发，过滤两指、四指、上滑、横滑、轻触和短时间连续触发。不会屏蔽系统事件或自动修改系统触控板设置。睡眠停止，唤醒恢复。
- 非公开触控接口可能受系统升级影响；不可用时显示状态并保留快捷键。不是 Mac App Store 兼容性承诺。
- 若系统 App Exposé 已使用三指下滑，用户需将其改为四指或关闭。2026-10-19 本机设置实查 App Exposé 为“关”，无需调整。

验证：10 项核心检查通过，Release 构建/签名通过；实际 UI 点击后选中与网址内容保持，设置显示三指监听已启用。硬件接口探测启动返回 0；探测窗口未收到触摸帧，不作为实际手势验收。用户物理三指滑动和跨应用粘贴仍需实机验证。
