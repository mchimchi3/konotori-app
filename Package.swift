// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KonotoriApp",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        // Supabase Swift SDK — Auth, Realtime, PostgREST client
        .package(
            url: "https://github.com/supabase-community/supabase-swift.git",
            from: "2.0.0"
        ),
        // Kingfisher — async image downloading and caching
        .package(
            url: "https://github.com/onevcat/Kingfisher.git",
            from: "7.0.0"
        ),
        // KeychainAccess — simple Keychain wrapper for secure token storage
        .package(
            url: "https://github.com/kishikawakatsuki/KeychainAccess.git",
            from: "4.2.0"
        ),
    ],
    targets: [
        .target(
            name: "KonotoriApp",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Auth", package: "supabase-swift"),
                .product(name: "Realtime", package: "supabase-swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "KonotoriApp",
            resources: [
                .process("App/Info.plist")
            ]
        ),
    ]
)
