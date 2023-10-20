// swift-tools-version:4.8
import PackageDescription

let package = Package(name: "UpdateMahjongFaceIndex")

package.products = [
    .executable(name: "UpdateMahjongFaceIndex", targets: ["UpdateMahjongFaceIndex"])
]
package.dependencies = [
    .package(url: "https://github.com/JohnSundell/Files.git", .upToNextMajor(from: "4.0.0"))
]
package.targets = [
    .target(
        name: "UpdateMahjongFaceIndex",
        dependencies: [.product(name: "Files", package: "Files")],
        path: "Sources"
    )
]
