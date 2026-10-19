# 沾沾实施记录

- [x] 收藏与文件夹存储：独立 ShelfCore，原子写入，失败保护，8 项核心检查。
- [x] SwiftPM 构建入口、独立应用身份/存储、移除官方更新源。
- [x] 原生磨砂卡片面板与文件夹 UI，历史手动顺序和删除撤销。
- [x] Release 构建、本机签名、安装及原生窗口检查。

## 决策

- 用户已批准原型并要求实施，在现有分支连续执行。
- 一级文件夹，不引入嵌套；删除文件夹不删内容。
- 系统只有 Swift 6.3 CLT，无完整 Xcode，缺少 SwiftDataMacros/PreviewsMacros。以 @Observable 和版本化 JSON 原子快照替换本分支持久层，继续保留 Maccy 剪贴板处理。代价：上游 SwiftData 数据不自动迁移，大量大图片的写入性能尚待压力测试。
- SwiftPM 为本分支构建入口，上游 Xcode/XCTest 不算已验证。
- 正式 Maccy 保留；独立 Bundle ID 和目录；默认 ⌘⇧V 避开原版 ⌘⇧C。
- 去除新复制内容的通知正文和日志正文；界面内反馈。
- SwiftPM resource bundles 放在 Contents/Resources，KeyboardShortcuts 加入相应查找路径；本机 ad-hoc 签名。

## 测试与审查

核心检查：`bash scripts/check-core.sh`，8 项通过。覆盖重启、文件夹删除保留内容、图片快照、排序、失败写入回滚、损坏/未来版本文件保护、历史与收藏独立、混合内容编辑保护。

真实原生 UI 已验证：新建“工作”文件夹；添加示例网址；右键移到未分类；复制收藏后捕获为历史；⌘⇧V 唤起；删除该测试历史并撤销。观察到用户新复制记录也被实时捕获，未删除该用户记录。

独立只读全分支审查发现并修复：
1. 修改收藏标题误清除非纯文本载荷：未改正文保留全部载荷，文件/图片混合内容禁用正文编辑；新增回归检查，先缺失 API 失败，再通过。
2. transferContents 丢弃内部复制标记导致历史顺序变化：转移前缓存 wasInternalCopy，内部复制保留排名及来源。
3. 只能向前插入，不能拖到末尾：目标左右半区分别插前/后；核心检查覆盖正向相邻移动和重启。

待用户授权：自动粘贴所需辅助功能。当前无权限时退化为复制，尚未验证跨应用自动粘贴。

## 最终验证（2026-10-19）

- `bash scripts/build-app.sh release` 成功；`codesign --verify --deep --strict /Applications/沾沾.app` 成功。
- 已安装 `/Applications/沾沾.app` 0.1.0。应用进程从该安装目录运行。重启后工作文件夹、示例收藏和之前历史均已在原生界面恢复。
- 修复 Swift 6.3 优化器对泛型 NSPanel 子类析构的崩溃：改为非泛型类与泛型初始化方法，Release 正常编译。
- 修复重新打开应用误切换关闭、NSHostingView 自动压窄窗口；设置独立内容尺寸，保持横向面板。
- UI 拖放实际鼠标验证受到窗口失焦/用户操作中断，未计作通过；排序核心回归检查通过。跨应用自动粘贴等待用户开启辅助功能后验收。
- 上游 Xcode UI 测试未运行；未宣称 macOS 14 实机、Intel 或大量图片压力测试通过。

## 0.2 更新（2026-10-19）

用户反馈：卡片选中不明显、需要三指下滑、希望增强苹果磨砂质感。

- 单击选择并复制，双击/回车粘贴；高亮、按下缩放、悬停反馈，尊重减少动态效果。
- 调查发现细线视觉不够明显，且复制去重重建 ID 丢失选择。尝试稳定 ID 后实机发现旧对象清空残留，最终改为内部复制保留同一个模型和装饰对象。实际截图确认链接预览与勾选高亮稳定。
- 默认原生 NSGlassEffectView regular，设置可切换 clear；系统旧版回退 popover 材质。
- 三指识别通过 Core 2 项新增检查（总计10项），NativeTouch 动态链接默认设备启动成功。真实三指下滑尚待用户滑动验收。
- 已只读查看系统触控板 → 更多手势：App Exposé 为关，未修改任何系统手势，无需此前询问的四指替换。
- 本机 Release 安装版本 0.2.0。0.1 安装包回退副本 dist/previous/沾沾-0.1.app。

参考资料：
- https://developer.apple.com/documentation/appkit/nsglasseffectview
- https://developer.apple.com/videos/play/wwdc2025/219/
- https://github.com/Kyome22/OpenMultitouchSupport （15c6bb0c6a2d2858559493a28ab23f7ac58648a3）
- https://support.apple.com/guide/mac-help/change-trackpad-settings-mchlp1226/mac
