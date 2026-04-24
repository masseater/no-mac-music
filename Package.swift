// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NoMacMusic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NoMacMusic", targets: ["NoMacMusic"])
    ],
    targets: [
        .executableTarget(
            name: "NoMacMusic",
            path: "Sources/NoMacMusic",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
