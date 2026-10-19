import AppKit
import Observation

/// Local builds must not install an upstream release over the fork.
@Observable
class SoftwareUpdater {
  var automaticallyChecksForUpdates = false
  func checkForUpdates() {
    let alert = NSAlert()
    alert.messageText = "沾沾 · 本地构建"
    alert.informativeText = "此版本通过本地构建更新，不连接 Maccy 的自动更新服务。"
    alert.runModal()
  }
}
