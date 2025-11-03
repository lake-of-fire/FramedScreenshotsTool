import Foundation

public struct FrameItAssetPreparer {
    public enum Error: Swift.Error, CustomStringConvertible {
        case downloadFailed(URL)
        case unzipFailed(URL, Int32)

        public var description: String {
            switch self {
            case .downloadFailed(let url):
                return "Unable to download FrameIt archive at \(url.absoluteString)."
            case .unzipFailed(let url, let status):
                return "Failed to unzip archive \(url.lastPathComponent) (exit status \(status))."
            }
        }
    }

    private let fileManager: FileManager
    private let verbose: Bool
    private let session: URLSession
    private let primaryArchiveURL: URL

    public init(
        fileManager: FileManager = .default,
        verbose: Bool = false,
        session: URLSession = .shared,
        primaryArchiveURL: URL = URL(string: "https://github.com/fastlane/frameit-frames/archive/refs/heads/master.zip")!
    ) {
        self.fileManager = fileManager
        self.verbose = verbose
        self.session = session
        self.primaryArchiveURL = primaryArchiveURL
    }

    @discardableResult
    public func prepareAssets(
        workspaceRoot: URL,
        cacheOverride: URL? = nil,
        force: Bool = false,
        additionalArchives: [URL] = []
    ) throws -> URL {
        let cacheDirectory = cacheOverride ?? workspaceRoot
            .appendingPathComponent("Tools/FrameItCache", isDirectory: true)
        let framesDirectory = cacheDirectory
            .appendingPathComponent("frameit-frames-master", isDirectory: true)

        if !force, directoryExists(framesDirectory) {
            if verbose {
                print("FrameIt assets already cached at \(framesDirectory.path)")
            }
            return framesDirectory
        }

        if force, directoryExists(cacheDirectory) {
            try? fileManager.removeItem(at: cacheDirectory)
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let primaryArchive = cacheDirectory.appendingPathComponent("frameit-master.zip")
        try download(from: primaryArchiveURL, to: primaryArchive)
        try unzip(archive: primaryArchive, destination: cacheDirectory)
        try fileManager.removeItem(at: primaryArchive)

        for archiveURL in additionalArchives {
            do {
                try ingestAdditionalAsset(
                    from: archiveURL,
                    cacheDirectory: cacheDirectory,
                    framesDirectory: framesDirectory
                )
            } catch {
                if verbose {
                    print("⚠️  Failed to ingest additional archive \(archiveURL.absoluteString): \(error)")
                }
            }
        }

        if verbose {
            print("FrameIt assets available at \(framesDirectory.path)")
        }
        return framesDirectory
    }

    private func download(from remote: URL, to destination: URL) throws {
        if verbose {
            print("Downloading \(remote.absoluteString)...")
        }
        if remote.isFileURL {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: remote, to: destination)
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var outputURL: URL?
        var encounteredError: Swift.Error?

        let task = session.downloadTask(with: remote) { url, _, error in
            outputURL = url
            encounteredError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = encounteredError {
            if verbose {
                print("⚠️  Download error: \(error)")
            }
            throw Error.downloadFailed(remote)
        }

        guard let tempURL = outputURL else {
            throw Error.downloadFailed(remote)
        }

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
        } catch {
            throw Error.downloadFailed(remote)
        }
    }

    private func unzip(archive: URL, destination: URL) throws {
        if verbose {
            print("Unzipping \(archive.lastPathComponent)...")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", archive.path, destination.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw Error.unzipFailed(archive, process.terminationStatus)
        }
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }

    private func ingestAdditionalAsset(
        from source: URL,
        cacheDirectory: URL,
        framesDirectory: URL
    ) throws {
        var cleanupURL: URL?
        let resolvedURL: URL

        if source.isFileURL {
            resolvedURL = source
        } else {
            let temporary = cacheDirectory.appendingPathComponent("frameit-extra-\(UUID().uuidString)")
            try download(from: source, to: temporary)
            cleanupURL = temporary
            resolvedURL = temporary
        }

        defer {
            if let cleanupURL {
                try? fileManager.removeItem(at: cleanupURL)
            }
        }

        if resolvedURL.pathExtension.lowercased() == "zip" {
            try unzip(archive: resolvedURL, destination: cacheDirectory)
        } else {
            let coloredDirectory = framesDirectory.appendingPathComponent("Colored", isDirectory: true)
            try fileManager.createDirectory(at: coloredDirectory, withIntermediateDirectories: true)
            let destination = coloredDirectory.appendingPathComponent(resolvedURL.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: resolvedURL, to: destination)
        }
    }
}
