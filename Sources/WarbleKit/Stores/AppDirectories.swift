import Foundation

public enum AppDirectories {
    public static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Warble", isDirectory: true)
    }

    public static func applicationSupportFile(named name: String) -> URL {
        applicationSupport.appendingPathComponent(name)
    }
}
