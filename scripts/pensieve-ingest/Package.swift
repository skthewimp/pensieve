// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "pensieve-ingest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "pensieve-ingest", targets: ["PensieveIngest"]),
        .library(name: "PensieveIngestCore", targets: ["PensieveIngestCore"]),
    ],
    targets: [
        .executableTarget(name: "PensieveIngest", dependencies: ["PensieveIngestCore"]),
        .target(name: "PensieveIngestCore"),
        .testTarget(
            name: "PensieveIngestCoreTests",
            dependencies: ["PensieveIngestCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
