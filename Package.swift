// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "LibDCSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "LibDCSwift",
            targets: ["LibDCSwift"]
        ),
        .library(
            name: "LibDCBridge",
            type: .dynamic,
            targets: ["LibDCBridge"]
        )
    ],
    targets: [
        .target(
            name: "Clibdivecomputer",
            path: "libdivecomputer",
            exclude: [
                "doc",
                "m4",
                "src/serial_win32.c"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/libdivecomputer"),
                .headerSearchPath("src"),
                .define("HAVE_PTHREAD_H")
            ]
        ),
        .target(
            name: "LibDCBridge",
            dependencies: ["Clibdivecomputer"],
            path: "Sources/LibDCBridge",
            sources: [
                "src/configuredc.c",
                "src/BLEBridge.m"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../../libdivecomputer/include"),
                .headerSearchPath("../../libdivecomputer/src"),
                .define("OBJC_OLD_DISPATCH_PROTOTYPES", to: "1")
            ],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("Foundation")
            ]
        ),
        .target(
            name: "LibDCSwift",
            dependencies: ["LibDCBridge", "Clibdivecomputer"],
            path: "Sources/LibDCSwift",
            sources: [
                "Models/DeviceConfiguration.swift",
                "Models/DiveData.swift",
                "Models/SampleData.swift",
                "Parser/GenericParser.swift"
            ],
            cSettings: [
                .headerSearchPath("../LibDCBridge/include"),
                .headerSearchPath("../Clibdivecomputer/include")
            ],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("Foundation")
            ]
        )
    ]
) 
