// swift-tools-version: 6.3
import PackageDescription
let package = Package(
  name: "ZhanZhan",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "ZhanZhan", targets: ["Maccy"])],
  dependencies: [
    .package(path: "Core"),
    .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
    .package(url: "https://github.com/krisk/fuse-swift", exact: "1.4.0"),
    .package(path: "Vendor/KeyboardShortcuts"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", exact: "1.1.0"),
    .package(url: "https://github.com/Clipy/Sauce", exact: "2.5.2"),
    .package(url: "https://github.com/sindresorhus/Settings.git", exact: "3.1.2"),
    .package(url: "https://github.com/apple/swift-log", exact: "1.15.1"),
    .package(url: "https://github.com/thii/SwiftHEXColors", exact: "1.4.1")
  ],
  targets: [
    .executableTarget(name: "Maccy", dependencies: [
      .product(name: "ShelfCore", package: "Core"),
      .product(name: "Defaults", package: "Defaults"),
      .product(name: "Fuse", package: "fuse-swift"),
      .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
      .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
      .product(name: "Sauce", package: "Sauce"),
      .product(name: "Settings", package: "Settings"),
      .product(name: "Logging", package: "swift-log"),
      .product(name: "SwiftHEXColors", package: "SwiftHEXColors")
    ], path: "Maccy", exclude: ["AppIcon.icon", "Assets.xcassets", "History.xcdatamodeld", "Info.plist", "Maccy.entitlements", "Sounds", "Storage.xcdatamodeld", "ar.lproj", "be.lproj", "bn.lproj", "bs.lproj", "ca.lproj", "ckb.lproj", "cs.lproj", "de.lproj", "el.lproj", "en.lproj", "eo.lproj", "es.lproj", "fa.lproj", "fi.lproj", "fr.lproj", "he.lproj", "hi.lproj", "hr.lproj", "hu.lproj", "id.lproj", "it.lproj", "ja.lproj", "km.lproj", "ko.lproj", "lt.lproj", "lv.lproj", "nb.lproj", "nl.lproj", "pl.lproj", "pt-BR.lproj", "pt.lproj", "ro.lproj", "ru.lproj", "sl.lproj", "sv.lproj", "ta.lproj", "th.lproj", "tr.lproj", "uk.lproj", "uz.lproj", "vi.lproj", "zh-Hans.lproj", "zh-Hant.lproj"],
      swiftSettings: [.defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances")])
  ]
)
