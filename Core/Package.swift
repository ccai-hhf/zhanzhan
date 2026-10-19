// swift-tools-version: 6.0
import PackageDescription
let package = Package(
  name: "ShelfCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "ShelfCore", targets: ["ShelfCore"])],
  targets: [.target(name: "ShelfCore"), .executableTarget(name: "ShelfCoreChecks", dependencies: ["ShelfCore"], path: "Tests/ShelfCoreTests")]
)
