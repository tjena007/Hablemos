// swift-tools-version: 5.9
// Vendored Swift wrapper from google-ai-edge/LiteRT-LM v0.19.1 (Apache-2.0), see LICENSE.
// The upstream repo needs Git LFS and is ~900 MB, so only its Swift sources are copied here.
import PackageDescription

let package = Package(
  name: "LiteRTLMKit",
  platforms: [.iOS(.v15)],
  products: [.library(name: "LiteRTLM", targets: ["LiteRTLM"])],
  targets: [
    .binaryTarget(
      name: "CLiteRTLM",
      url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.19.1/CLiteRTLM.xcframework.zip",
      checksum: "21cf294b3dfdd9c8166b0f7934ed392d5c69c8bfa57cd1a20e341a7d16874017"
    ),
    .target(name: "LiteRTLM", dependencies: ["CLiteRTLM"], path: "Sources/LiteRTLM"),
  ]
)
