import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct ShelfSettingsView: View {
  @Default(.clearGlass) private var clearGlass
  @Default(.threeFingerSwipe) private var threeFingerSwipe
  @State private var gestures = TrackpadGesture.shared
  @Default(.size) private var historySize
  @Default(.pasteByDefault) private var pasteByDefault
  @Default(.removeFormattingByDefault) private var removeFormatting
  @Default(.ignoreEvents) private var paused
  @Default(.searchMode) private var searchMode
  @State private var shelf = ShelfState.shared

  var body: some View {
    Form {
      Section("启动与唤起") {
        LaunchAtLogin.Toggle("登录后自动启动")
        Toggle("三指下滑唤起、上滑收起", isOn: $threeFingerSwipe)
        Text(gestures.status).font(.caption).foregroundStyle(.secondary)
        Text("若与系统手势冲突，在触控板 → 更多手势中，将“调度中心”改为四指上滑、“应用程序窗口”改为四指下滑或关闭。")
          .font(.caption).foregroundStyle(.secondary)
        Button("打开触控板设置") {
          if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") { NSWorkspace.shared.open(url) }
        }
        KeyboardShortcuts.Recorder("备用快捷键", name: .popup)
      }
      if #available(macOS 26.0, *) {
        Section("外观") {
          Toggle("更通透的玻璃", isOn: $clearGlass)
          Text("关闭时加强磨砂与文字对比；开启时更多透出桌面背景。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("复制与粘贴") {
        Toggle("暂停记录剪贴板", isOn: $paused)
        Toggle("双击卡片或按回车时自动粘贴", isOn: $pasteByDefault)
        Toggle("粘贴时移除文字格式", isOn: $removeFormatting)
        Button("打开辅助功能授权设置") { shelf.requestPastePermission() }
        Text("允许辅助功能后，沾沾才能向当前应用自动粘贴。也可只复制，再手动按 ⌘V。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("本地存储") {
        Picker("保留历史条数", selection: $historySize) {
          ForEach([50, 100, 200, 500], id: \.self) { Text("\($0) 条").tag($0) }
        }
        .onChange(of: historySize) { _, _ in Task { try? await History.shared.load() } }
        Picker("搜索方式", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { Text($0.description).tag($0) }
        }
        Text("收藏独立保存，不受历史条数限制。数据保存在本机，沾沾不会上传剪贴板。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped).padding(8).frame(width: 500, height: 620)
  }
}
