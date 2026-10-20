import Defaults
import SwiftUI
import QuartzCore

// An NSPanel subclass that implements floating panel traits.
// https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
class FloatingPanel: NSPanel, NSWindowDelegate {
  var isPresented: Bool = false
  var statusBarButton: NSStatusBarButton?
  let onClose: () -> Void
  private var transitionID = UUID()
  private var isClosing = false
  private var closeCompletions: [() -> Void] = []

  override var isMovable: Bool {
    get { Defaults[.popupPosition] != .statusItem }
    set {}
  }

  init<Content: View>(
    contentRect: NSRect,
    identifier: String = "",
    statusBarButton: NSStatusBarButton? = nil,
    onClose: @escaping () -> Void,
    view: () -> Content
  ) {
    self.onClose = onClose

    super.init(
        contentRect: contentRect,
        styleMask: [.nonactivatingPanel, .resizable, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    self.statusBarButton = statusBarButton
    self.identifier = NSUserInterfaceItemIdentifier(identifier)

    Defaults[.windowSize] = contentRect.size
    delegate = self

    animationBehavior = .none
    isFloatingPanel = true
    // TODO: Automatically detect Chrome autofill that uses window layer 999 and set to screenSaver (1000). See #1403.
    level = .statusBar
    collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
    title = "沾沾"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    backgroundColor = .clear
    isOpaque = false
    titlebarSeparatorStyle = .none

    // Hide all traffic light buttons
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    let hostingView = NSHostingView(rootView: view().ignoresSafeArea())
    hostingView.sizingOptions = []
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView()
      glass.style = Defaults[.clearGlass] ? .clear : .regular
      glass.cornerRadius = 24
      glass.contentView = hostingView
      contentView = glass
    } else {
      let material = NSVisualEffectView()
      material.material = .popover
      material.blendingMode = .behindWindow
      material.state = .active
      hostingView.translatesAutoresizingMaskIntoConstraints = false
      material.addSubview(hostingView)
      NSLayoutConstraint.activate([
        hostingView.leadingAnchor.constraint(equalTo: material.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: material.trailingAnchor),
        hostingView.topAnchor.constraint(equalTo: material.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: material.bottomAnchor)
      ])
      contentView = material
    }
    contentMinSize = NSSize(width: 900, height: 450)
    applyRoundedCorners()
  }

  func updateGlassStyle() {
    if #available(macOS 26.0, *), let glass = contentView as? NSGlassEffectView {
      glass.style = Defaults[.clearGlass] ? .clear : .regular
    }
  }

  private func applyRoundedCorners() {
    let radius: CGFloat = 24

    for view in [contentView, contentView?.superview].compactMap({ $0 }) {
      view.wantsLayer = true
      view.layer?.cornerRadius = radius
      view.layer?.cornerCurve = .continuous
      view.layer?.masksToBounds = true
    }
  }

  func toggle(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    if isPresented {
      close()
    } else {
      open(height: height, at: popupPosition)
    }
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    guard !isPresented else { makeKey(); return }
    let wasClosing = isClosing
    transitionID = UUID()
    isClosing = false
    closeCompletions.removeAll()
    ignoresMouseEvents = false
    let size = Defaults[.windowSize]
    let miniumHeight: CGFloat = AppState.shared.popup.minimumHeight
    let activeScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
    let visible = activeScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let finalWidth = min(max(size.width, 960), visible.width - 32)
    let finalHeight = min(max(min(height, size.height), miniumHeight), visible.height - 24)
    setContentSize(NSSize(width: finalWidth, height: finalHeight))
    setFrameOrigin(popupPosition.origin(size: frame.size, statusBarButton: statusBarButton))
    let destination = frame
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if !wasClosing {
      setFrame(destination.offsetBy(dx: 0, dy: reduceMotion ? 0 : -28), display: false)
      alphaValue = 0
    }
    isPresented = true
    orderFrontRegardless()
    makeKey()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = reduceMotion ? 0.12 : 0.28
      context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
      animator().setFrame(destination, display: true)
      animator().alphaValue = 1
    }

    if popupPosition == .statusItem {
      DispatchQueue.main.async {
        self.statusBarButton?.isHighlighted = true
      }
    }
  }

  func verticallyResize(to newHeight: CGFloat) {
    var newSize = frame.size
    newSize.height = newHeight
    var newOrigin = frame.origin
    newOrigin.y += (frame.height - newSize.height)

    NSAnimationContext.runAnimationGroup { (context) in
      context.duration = 0.2
      animator().setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
  }

  func determinePreviewPlacement() {
    let preview = AppState.shared.preview
    guard !preview.state.isOpen else { return }
    let newSize = preview.computeSizeWithPreview(frame.size, state: .open)
    preview.placement = preview.computePlacement(window: self, for: newSize)
  }

  func saveWindowPosition() {
    if let screenFrame = screen?.visibleFrame {
      // Only store the size of the window without the preview
      let width = AppState.shared.preview.contentWidth

      let anchorX = frame.minX + width / 2 - screenFrame.minX
      let anchorY = frame.maxY - screenFrame.minY
      Defaults[.windowPosition] = NSPoint(x: anchorX / screenFrame.width, y: anchorY / screenFrame.height)
    }
  }

  func saveWindowFrame(frame: NSRect) {
    Defaults[.windowSize] = frame.size
    saveWindowPosition()
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let preview = AppState.shared.preview

    if inLiveResize && preview.resizingMode == .none {
      let screenPoint = NSEvent.mouseLocation
      let windowPoint = convertPoint(fromScreen: screenPoint)
      let location: SlideoutPlacement = windowPoint.x <= frame.width / 2 ? .left : .right
      if (location == preview.placement) && preview.state == .open {
        preview.startResize(mode: .slideout)
      } else {
        preview.startResize(mode: .content)
      }
    }

    var finalFrameSize = frameSize
    var minContent = preview.minimumContentWidth
    var minPreview = 0.0

    if inLiveResize && preview.resizingMode != .none {
      if preview.resizingMode == .content && preview.state == .open {
        minPreview = preview.slideoutWidth
      }
      if preview.resizingMode == .slideout {
        minPreview = preview.minimumSlideoutWidth
        minContent = preview.contentWidth
      }
    }
    finalFrameSize.width = max(finalFrameSize.width, minContent + minPreview)

    if !AppState.shared.preview.state.isAnimating {
      var size = frame.size
      // Only store the size of the window without the preview
      size.width = AppState.shared.preview.contentWidth
      saveWindowFrame(frame: NSRect(origin: frame.origin, size: size))
    }

    let minimumHeight = AppState.shared.popup.minimumHeight
    finalFrameSize.height = max(finalFrameSize.height, minimumHeight)

    return finalFrameSize
  }

  func windowWillMove(_ notification: Notification) {
    determinePreviewPlacement()
  }

  func windowDidMove(_ notification: Notification) {
    determinePreviewPlacement()
  }

  func windowWillStartLiveResize(_ notification: Notification) {
    AppState.shared.preview.cancelAutoOpen()
  }

  func windowDidEndLiveResize(_ notification: Notification) {
    AppState.shared.preview.startAutoOpen()
    AppState.shared.preview.endResize()
  }

  func windowDidBecomeKey(_ notification: Notification) {
    AppState.shared.preview.enableAutoOpen()

    if AppState.shared.navigator.leadHistoryItem != nil {
      AppState.shared.preview.startAutoOpen()
    }
  }

  func windowDidResignKey(_ notification: Notification) {
    AppState.shared.preview.disableAutoOpen()
  }

  // Close automatically when out of focus, e.g. outside click.
  override func resignKey() {
    super.resignKey()
    // Don't hide while a modal interaction from this panel is active.
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.isKeyWindow, self.attachedSheet == nil,
            NSApp.alertWindow == nil, !AppState.shared.suppressPopupAutoClose else { return }
      self.close()
    }
  }

  /// Run paste only after the panel has relinquished keyboard focus.
  func close(completion: @escaping () -> Void) {
    if !isPresented && !isClosing { completion(); return }
    closeCompletions.append(completion)
    close()
  }

  override func close() {
    guard isPresented, !isClosing else { return }
    isClosing = true
    isPresented = false
    ignoresMouseEvents = true
    transitionID = UUID()
    let token = transitionID
    let destination = frame
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let appState = AppState.shared
    appState.preview.state = .closed
    appState.isEditingItem = false
    appState.navigator.isDragAndDropInProgress = false
    appState.navigator.isManualMultiSelect = false
    statusBarButton?.isHighlighted = false
    onClose()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = reduceMotion ? 0.1 : 0.20
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      animator().setFrame(destination.offsetBy(dx: 0, dy: reduceMotion ? 0 : -22), display: true)
      animator().alphaValue = 0
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.transitionID == token, self.isClosing else { return }
        self.finishClosing(restoring: destination)
      }
    }
  }

  private func finishClosing(restoring destination: NSRect) {
    super.close()
    setFrame(destination, display: false)
    alphaValue = 1
    isClosing = false
    ignoresMouseEvents = false
    let completions = closeCompletions
    closeCompletions.removeAll()
    completions.forEach { $0() }
  }

  // Allow text inputs inside the panel can receive focus
  override var canBecomeKey: Bool {
    return !isClosing
  }
}
