import Foundation

{{MARKER_START}}
struct FrameItManager {
    enum Error: Swift.Error, CustomStringConvertible {
        case downloadFailed(URL)
        case unzipFailed(URL, Int32)
        case copyFailed(URL, URL, Swift.Error)

        var description: String {
            switch self {
            case .downloadFailed(let url):
                return "Unable to download FrameIt assets from \(url.absoluteString)."
            case .unzipFailed(let url, let status):
                return "Failed to unzip \(url.lastPathComponent) (exit status \(status))."
            case .copyFailed(let source, let destination, let underlying):
                return "Failed to copy \(source.path) to \(destination.path): \(underlying)"
            }
        }
    }

    private let workspaceRoot: URL
    private let cacheDirectory: URL
    private let additionalArchives: [URL]
    private let verbose: Bool
    private let fileManager = FileManager.default

    init(
        cacheDirectory: URL?,
        workspaceRoot: URL,
        additionalArchives: [URL],
        verbose: Bool
    ) {
        self.workspaceRoot = workspaceRoot
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = workspaceRoot.appendingPathComponent("Tools/FrameItCache", isDirectory: true)
        }
        self.additionalArchives = additionalArchives
        self.verbose = verbose
    }

    var framesDirectory: URL {
        cacheDirectory.appendingPathComponent("frameit-frames-master", isDirectory: true)
    }

    func ensureAssets() throws {
        if fileManager.directoryExists(at: framesDirectory) {
            if verbose { Diagnostics.info("FrameIt assets already available at \(framesDirectory.path)") }
            return
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if try invokeExternalTool() {
            return
        }

        let primaryArchive = cacheDirectory.appendingPathComponent("frameit-master.zip")
        try download(from: URL(string: "https://github.com/fastlane/frameit-frames/archive/refs/heads/master.zip")!, to: primaryArchive)
        try unzipArchive(at: primaryArchive, destination: cacheDirectory)
        try? fileManager.removeItem(at: primaryArchive)

        for archive in additionalArchiveURLs() {
            do {
                try ingestAdditionalAsset(from: archive)
            } catch {
                Diagnostics.warn("Failed to ingest \(archive.absoluteString): \(error)")
            }
        }

        if verbose { Diagnostics.info("FrameIt assets ready at \(framesDirectory.path)") }
    }

    private func invokeExternalTool() throws -> Bool {
        guard let toolPath = which("framed-screenshots-tool") else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        var arguments = [
            "cache-frameit-frames",
            "--workspace", workspaceRoot.path
        ]
        arguments += ["--cache-dir", cacheDirectory.path]
        if verbose { arguments.append("--verbose") }
        process.arguments = arguments
        if verbose { Diagnostics.info("Delegating FrameIt download to \(toolPath) \(arguments.joined(separator: " "))") }

        let pipe = Pipe()
        process.standardOutput = verbose ? FileHandle.standardOutput : pipe
        process.standardError = verbose ? FileHandle.standardError : pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Diagnostics.warn("Failed to execute framed-screenshots-tool: \(error)")
            return false
        }
        if process.terminationStatus == 0, fileManager.directoryExists(at: framesDirectory) {
            return true
        }
        return false
    }

    private func download(from remote: URL, to destination: URL) throws {
        if verbose { Diagnostics.info("Downloading \(remote.absoluteString)…") }
        do {
            let data = try Data(contentsOf: remote)
            try data.write(to: destination, options: .atomic)
        } catch {
            throw Error.downloadFailed(remote)
        }
    }

    private func unzipArchive(at archive: URL, destination: URL) throws {
        if verbose { Diagnostics.info("Unzipping \(archive.lastPathComponent)…") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", archive.path, destination.path]
        let pipe = Pipe()
        process.standardOutput = verbose ? FileHandle.standardOutput : pipe
        process.standardError = verbose ? FileHandle.standardError : pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw Error.unzipFailed(archive, process.terminationStatus)
        }
    }

    private func ingestAdditionalAsset(from url: URL) throws {
        if verbose { Diagnostics.info("Ingesting additional FrameIt asset \(url.absoluteString)") }
        var tempFile: URL?
        defer {
            if let tempFile, tempFile.isFileURL {
                try? fileManager.removeItem(at: tempFile)
            }
        }

        let resolvedURL: URL
        if url.isFileURL {
            resolvedURL = url
        } else {
            let temp = cacheDirectory.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "tmp" : url.pathExtension))
            tempFile = temp
            try download(from: url, to: temp)
            resolvedURL = temp
        }

        if resolvedURL.pathExtension.lowercased() == "zip" {
            try unzipArchive(at: resolvedURL, destination: cacheDirectory)
        } else {
            let coloredDirectory = framesDirectory.appendingPathComponent("Colored", isDirectory: true)
            try fileManager.createDirectory(at: coloredDirectory, withIntermediateDirectories: true)
            let destination = coloredDirectory.appendingPathComponent(resolvedURL.lastPathComponent)
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: resolvedURL, to: destination)
            } catch {
                throw Error.copyFailed(resolvedURL, destination, error)
            }
        }
    }

    private func additionalArchiveURLs() -> [URL] {
        var ordered: OrderedSet<URL> = []
        additionalArchives.forEach { ordered.append($0) }

        if let env = ProcessInfo.processInfo.environment["FRAMED_SCREENSHOTS_FRAME_ARCHIVES"] {
            env.split(whereSeparator: { $0 == ":" || $0.isNewline })
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .compactMap(URL.init)
                .forEach { ordered.append($0) }
        }

        let manifest = workspaceRoot.appendingPathComponent("FrameItAdditionalArchives.json", isDirectory: false)
        if let data = try? Data(contentsOf: manifest) {
            if let strings = try? JSONDecoder().decode([String].self, from: data) {
                strings.compactMap(URL.init).forEach { ordered.append($0) }
            } else if let wrapper = try? JSONDecoder().decode(AdditionalArchiveManifest.self, from: data) {
                wrapper.archives.compactMap(URL.init).forEach { ordered.append($0) }
            }
        }

        return ordered.map { $0 }
    }

    private func which(_ executable: String) -> String? {
        let searchPaths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":") ?? []
        for component in searchPaths {
            let candidate = URL(fileURLWithPath: String(component), isDirectory: true).appendingPathComponent(executable)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }
        return nil
    }
}

private struct AdditionalArchiveManifest: Decodable {
    var archives: [String]
}

private struct OrderedSet<Element: Hashable>: ExpressibleByArrayLiteral, Sequence {
    private var storage: [Element] = []
    private var lookup: Set<Element> = []

    init() {}

    init(arrayLiteral elements: Element...) {
        elements.forEach { append($0) }
    }

    mutating func append(_ element: Element) {
        guard !lookup.contains(element) else { return }
        storage.append(element)
        lookup.insert(element)
    }

    func map<T>(_ transform: (Element) -> T) -> [T] {
        storage.map(transform)
    }

    func makeIterator() -> IndexingIterator<[Element]> {
        storage.makeIterator()
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }
}
{{MARKER_END}}
