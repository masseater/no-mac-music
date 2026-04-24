import Foundation

enum AppMetadata {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "NoMacMusic"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.masseater.NoMacMusic"
    }
}
