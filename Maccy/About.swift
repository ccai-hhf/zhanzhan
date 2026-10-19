import AppKit

class About {
  @objc func openAbout(_ sender: NSMenuItem?) {
    AppState.shared.popup.close()
    NSApp.activate(ignoringOtherApps: true)
    let credits = NSMutableAttributedString(string: "沾沾 · 本地剪贴板与常用收藏\n基于 Maccy 开源项目修改，遵循 MIT 许可证。\nhttps://github.com/p0deje/Maccy")
    NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "沾沾", .credits: credits])
  }
}
