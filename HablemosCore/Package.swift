// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "HablemosCore", platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "HablemosCore", targets: ["HablemosCore"])],
  targets: [.target(name: "HablemosCore"), .testTarget(name: "HablemosCoreTests", dependencies: ["HablemosCore"])])
