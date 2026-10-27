import Foundation

/// Global flags precede the command, so text arguments are never interpreted as flags.
public struct DataCLIInvocation {
    public let cli: DataCLI
    public let arguments: [String]

    public init(arguments input: [String]) throws {
        var args = input
        var directory: URL?
        var json = false
        while let flag = args.first, flag.hasPrefix("--") {
            args.removeFirst()
            switch flag {
            case "--json" where !json: json = true
            case "--data-dir" where directory == nil:
                guard let path = args.first, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !path.hasPrefix("--") else {
                    throw DataCLI.Failure(message: "--data-dir requires a directory path.")
                }
                args.removeFirst()
                directory = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
            default: throw DataCLI.Failure(message: "Unknown or repeated global option: \(flag)")
            }
        }
        guard let command = args.first, ["dictionary", "history", "settings", "status"].contains(command) else {
            throw DataCLI.Failure(message: "Data options support only dictionary, history, settings and status. Place global flags before the command.")
        }
        if let directory {
            // Never allow an isolation override to bypass the live app's lock.
            let resolved = directory.resolvingSymlinksInPath()
            let live = AppDirectories.applicationSupport.resolvingSymlinksInPath()
            cli = DataCLI(dataDirectory: directory, configFile: directory.appendingPathComponent("config.json"),
                          lockFile: resolved == live ? DaemonLock.defaultLockURL : directory.appendingPathComponent("daemon.lock"))
        } else { cli = DataCLI() }
        arguments = args
    }
}
