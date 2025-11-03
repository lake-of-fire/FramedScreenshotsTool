import AppStoreConnect_Swift_SDK
import CryptoKit
import Foundation
#if canImport(Security)
import Security
#endif

{{MARKER_START}}
struct AppStoreConnectUploader {
    struct Configuration {
        let keyIdentifier: String
        let issuerIdentifier: String
        let privateKey: String
        let appId: String
        let platform: Platform
        let version: String?

        enum Platform: String {
            case ios
            case macos
            case appletvos

            var sdkPlatform: APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters.FilterPlatform {
                switch self {
                case .ios: return .ios
                case .macos: return .macOs
                case .appletvos: return .tvOs
                }
            }
        }

        static func load(workspaceRoot: URL?) -> Configuration? {
            if let env = loadFromEnvironment() {
                return env
            }
            if let root = workspaceRoot, let stored = KeychainStorage.load(from: root) {
                return stored
            }
            return nil
        }

        private static func loadFromEnvironment() -> Configuration? {
            let env = ProcessInfo.processInfo.environment
            guard let keyId = env["ASC_KEY_ID"],
                  let issuer = env["ASC_ISSUER_ID"],
                  let privateKey = env["ASC_PRIVATE_KEY"],
                  let appId = env["ASC_APP_ID"] else {
                return nil
            }
            let platform = Platform(rawValue: env["ASC_PLATFORM"]?.lowercased() ?? "ios") ?? .ios
            let version = env["ASC_APP_VERSION"]
            return Configuration(
                keyIdentifier: keyId,
                issuerIdentifier: issuer,
                privateKey: privateKey,
                appId: appId,
                platform: platform,
                version: version
            )
        }
    }

    private enum UploadError: Swift.Error, CustomStringConvertible {
        case unavailableCredentials
        case noActiveVersion
        case uploadOperationsMissing
        case invalidUploadOperation
        case httpFailure(code: Int)

        var description: String {
            switch self {
            case .unavailableCredentials:
                return "App Store Connect credentials not configured."
            case .noActiveVersion:
                return "No eligible App Store version to receive screenshots."
            case .uploadOperationsMissing:
                return "Upload operations missing from App Store Connect response."
            case .invalidUploadOperation:
                return "Encountered an invalid upload operation."
            case .httpFailure(let code):
                return "Upload request failed with status code \(code)."
            }
        }
    }

    private let configuration: Configuration?
    private let provider: APIProvider?
    private let session: URLSession
    private let verbose: Bool

    init(workspaceRoot: URL?, verbose: Bool) {
        self.configuration = Configuration.load(workspaceRoot: workspaceRoot)
        if let configuration {
            let apiConfiguration = APIConfiguration(
                issuerID: configuration.issuerIdentifier,
                privateKeyID: configuration.keyIdentifier,
                privateKey: configuration.privateKey
            )
            self.provider = APIProvider(configuration: apiConfiguration)
        } else {
            self.provider = nil
        }
        self.verbose = verbose
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    func uploadIfPossible(
        locale: LocalizationMatrix.LocaleContext,
        platformVariant: String,
        assets: [URL]
    ) async {
        guard let configuration, let provider else {
            Diagnostics.warn("App Store Connect credentials not configured. Skipping upload for locale \(locale.identifier).")
            return
        }

        guard !assets.isEmpty else {
            if verbose {
                Diagnostics.info("No screenshots produced for locale \(locale.identifier); skipping App Store Connect upload.")
            }
            return
        }

        do {
            if verbose {
                Diagnostics.info("Preparing App Store Connect upload for locale \(locale.identifier) (\(assets.count) asset(s)).")
            }

            guard let version = try await resolveTargetVersion(provider: provider, configuration: configuration) else {
                throw UploadError.noActiveVersion
            }

            let normalizedLocale = normalizedLocaleIdentifier(from: locale.identifier)
            let localization = try await ensureLocalization(
                provider: provider,
                versionId: version.id,
                localeIdentifier: normalizedLocale
            )

            let displayType = determineDisplayType(platformVariant: platformVariant, assets: assets)
            let screenshotSet = try await ensureScreenshotSet(
                provider: provider,
                localizationId: localization.id,
                displayType: displayType
            )

            try await replaceScreenshots(
                provider: provider,
                screenshotSetId: screenshotSet.id,
                assets: assets,
                localeIdentifier: normalizedLocale
            )

            if verbose {
                Diagnostics.info("Uploaded \(assets.count) screenshot(s) for locale \(normalizedLocale) (\(displayType.rawValue)).")
            }
        } catch {
            Diagnostics.warn("Failed to upload screenshots for locale \(locale.identifier): \(error)")
        }
    }
}

private extension AppStoreConnectUploader {
    func resolveTargetVersion(
        provider: APIProvider,
        configuration: Configuration
    ) async throws -> AppStoreVersion? {
        let parameters = APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters(
            filterAppStoreState: [.prepareForSubmission, .developerRejected, .metadataRejected, .developerRemovedFromSale, .rejected, .readyForReview],
            filterPlatform: [configuration.platform.sdkPlatform],
            filterVersionString: configuration.version.map { [$0] },
            limit: 10
        )

        let response = try await provider.request(
            APIEndpoint
                .v1
                .apps
                .id(configuration.appId)
                .appStoreVersions
                .get(parameters: parameters)
        )

        if let version = response.data.first(where: { version in
            guard let state = version.attributes?.appStoreState else {
                return false
            }
            return allowedStates.contains(state)
        }) {
            return version
        }

        if verbose {
            Diagnostics.warn("No App Store version found that is eligible for screenshot upload (platform: \(configuration.platform.rawValue)).")
        }
        return nil
    }

    func ensureLocalization(
        provider: APIProvider,
        versionId: String,
        localeIdentifier: String
    ) async throws -> AppStoreVersionLocalization {
        let response = try await provider.request(
            APIEndpoint
                .v1
                .appStoreVersions
                .id(versionId)
                .appStoreVersionLocalizations
                .get(limit: 200)
        )

        if let existing = response.data.first(where: { $0.attributes?.locale?.lowercased() == localeIdentifier.lowercased() }) {
            return existing
        }

        if verbose {
            Diagnostics.info("Creating App Store Version localization for \(localeIdentifier).")
        }

        let request = AppStoreVersionLocalizationCreateRequest(
            data: .init(
                type: .appStoreVersionLocalizations,
                attributes: .init(locale: localeIdentifier),
                relationships: .init(
                    appStoreVersion: .init(
                        data: .init(
                            type: .appStoreVersions,
                            id: versionId
                        )
                    )
                )
            )
        )

        let localization = try await provider.request(
            APIEndpoint
                .v1
                .appStoreVersionLocalizations
                .post(request)
        )
        return localization.data
    }

    func ensureScreenshotSet(
        provider: APIProvider,
        localizationId: String,
        displayType: ScreenshotDisplayType
    ) async throws -> AppScreenshotSet {
        let filterType = APIEndpoint
            .v1
            .appStoreVersionLocalizations
            .id(localizationId)
            .appScreenshotSets

        let parameters = APIEndpoint.V1.AppStoreVersionLocalizations.WithID.AppScreenshotSets.GetParameters(
            filterScreenshotDisplayType: [displayTypeFilter(from: displayType)],
            limit: 10,
            limitAppScreenshots: 50
        )

        let response = try await provider.request(
            filterType.get(parameters: parameters)
        )

        if let existing = response.data.first {
            return existing
        }

        if verbose {
            Diagnostics.info("Creating screenshot set of type \(displayType.rawValue) for localization \(localizationId).")
        }

        let request = AppScreenshotSetCreateRequest(
            data: .init(
                type: .appScreenshotSets,
                attributes: .init(screenshotDisplayType: displayType),
                relationships: .init(
                    appStoreVersionLocalization: .init(
                        data: .init(type: .appStoreVersionLocalizations, id: localizationId)
                    )
                )
            )
        )

        let created = try await provider.request(
            APIEndpoint
                .v1
                .appScreenshotSets
                .post(request)
        )

        return created.data
    }

    func replaceScreenshots(
        provider: APIProvider,
        screenshotSetId: String,
        assets: [URL],
        localeIdentifier: String
    ) async throws {
        try await purgeExistingScreenshots(provider: provider, screenshotSetId: screenshotSetId)

        for assetURL in assets {
            do {
                let data = try Data(contentsOf: assetURL)
                let fileName = assetURL.lastPathComponent
                let checksum = sha256Hex(for: data)

                let createRequest = AppScreenshotCreateRequest(
                    data: .init(
                        type: .appScreenshots,
                        attributes: .init(
                            fileSize: data.count,
                            fileName: fileName
                        ),
                        relationships: .init(
                            appScreenshotSet: .init(
                                data: .init(
                                    type: .appScreenshotSets,
                                    id: screenshotSetId
                                )
                            )
                        )
                    )
                )

                let response = try await provider.request(
                    APIEndpoint
                        .v1
                        .appScreenshots
                        .post(createRequest)
                )

                guard let operations = response.data.attributes?.uploadOperations, !operations.isEmpty else {
                    throw UploadError.uploadOperationsMissing
                }

                try await performUpload(operations: operations, data: data)

                let updateRequest = AppScreenshotUpdateRequest(
                    data: .init(
                        type: .appScreenshots,
                        id: response.data.id,
                        attributes: .init(
                            sourceFileChecksum: checksum,
                            isUploaded: true
                        )
                    )
                )

                _ = try await provider.request(
                    APIEndpoint
                        .v1
                        .appScreenshots
                        .id(response.data.id)
                        .patch(updateRequest)
                )

                if verbose {
                    Diagnostics.info("Uploaded \(fileName) for \(localeIdentifier).")
                }
            } catch {
                Diagnostics.warn("Failed to upload screenshot \(assetURL.lastPathComponent): \(error)")
            }
        }
    }

    func purgeExistingScreenshots(
        provider: APIProvider,
        screenshotSetId: String
    ) async throws {
        let parameters = APIEndpoint.V1.AppScreenshotSets.WithID.AppScreenshots.GetParameters(
            limit: 60
        )

        let response = try await provider.request(
            APIEndpoint
                .v1
                .appScreenshotSets
                .id(screenshotSetId)
                .appScreenshots
                .get(parameters: parameters)
        )

        if response.data.isEmpty {
            return
        }

        for screenshot in response.data {
            try await provider.request(
                APIEndpoint
                    .v1
                    .appScreenshots
                    .id(screenshot.id)
                    .delete
            )
        }
    }

    func performUpload(operations: [UploadOperation], data: Data) async throws {
        for operation in operations {
            guard
                let method = operation.method,
                let urlString = operation.url,
                let url = URL(string: urlString)
            else {
                throw UploadError.invalidUploadOperation
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            operation.requestHeaders?.forEach { header in
                if let name = header.name, let value = header.value {
                    request.setValue(value, forHTTPHeaderField: name)
                }
            }

            let chunk: Data
            if let offset = operation.offset, let length = operation.length {
                let lower = Int(offset)
                let upper = Int(offset + length)
                guard lower >= 0, upper <= data.count else {
                    throw UploadError.invalidUploadOperation
                }
                chunk = data.subdata(in: lower..<upper)
            } else {
                chunk = data
            }

            let (_, response) = try await session.upload(for: request, from: chunk)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw UploadError.httpFailure(code: statusCode)
            }
        }
    }

    func normalizedLocaleIdentifier(from identifier: String) -> String {
        let sanitized = identifier.replacingOccurrences(of: "_", with: "-")
        let locale = Locale(identifier: sanitized)
        let language: String
        let region: String
        if #available(macOS 13.0, *) {
            language = locale.language.languageCode?.identifier.lowercased() ?? sanitized.lowercased()
            region = locale.region?.identifier.uppercased() ?? "US"
        } else {
            language = locale.languageCode?.lowercased() ?? sanitized.lowercased()
            region = locale.regionCode?.uppercased() ?? "US"
        }
        if sanitized.contains("-") {
            return sanitized
        }
        return "\(language)-\(region)"
    }

    func determineDisplayType(
        platformVariant: String,
        assets: [URL]
    ) -> ScreenshotDisplayType {
        let candidateNames = ([platformVariant] + assets.map { $0.lastPathComponent })
            .map { $0.lowercased() }

        if candidateNames.contains(where: { $0.contains("mac") }) {
            return .appDesktop
        }
        if candidateNames.contains(where: { $0.contains("ipad") }) {
            return .appIpadPro3gen129
        }
        if candidateNames.contains(where: { $0.contains("tv") }) {
            return .appAppleTv
        }
        return .appIphone67
    }

    func displayTypeFilter(from displayType: ScreenshotDisplayType) -> APIEndpoint.V1.AppStoreVersionLocalizations.WithID.AppScreenshotSets.GetParameters.FilterScreenshotDisplayType {
        switch displayType {
        case .appIphone67: return .appIphone67
        case .appIphone61: return .appIphone61
        case .appIphone65: return .appIphone65
        case .appIphone58: return .appIphone58
        case .appIphone55: return .appIphone55
        case .appIphone47: return .appIphone47
        case .appIphone40: return .appIphone40
        case .appIphone35: return .appIphone35
        case .appIpadPro3gen129: return .appIpadPro3gen129
        case .appIpadPro3gen11: return .appIpadPro3gen11
        case .appIpadPro129: return .appIpadPro129
        case .appIpad105: return .appIpad105
        case .appIpad97: return .appIpad97
        case .appDesktop: return .appDesktop
        case .appWatchUltra: return .appWatchUltra
        case .appWatchSeries7: return .appWatchSeries7
        case .appWatchSeries4: return .appWatchSeries4
        case .appWatchSeries3: return .appWatchSeries3
        case .appAppleTv: return .appAppleTv
        case .imessageAppIphone67: return .appIphone67
        case .imessageAppIphone61: return .appIphone61
        case .imessageAppIphone65: return .appIphone65
        case .imessageAppIphone58: return .appIphone58
        case .imessageAppIphone55: return .appIphone55
        case .imessageAppIphone47: return .appIphone47
        case .imessageAppIphone40: return .appIphone40
        case .imessageAppIpadPro3gen129: return .appIpadPro3gen129
        case .imessageAppIpadPro3gen11: return .appIpadPro3gen11
        case .imessageAppIpadPro129: return .appIpadPro129
        case .imessageAppIpad105: return .appIpad105
        case .imessageAppIpad97: return .appIpad97
        }
    }

    func sha256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    var allowedStates: Set<AppStoreVersionState> {
        [.prepareForSubmission, .developerRejected, .metadataRejected, .developerRemovedFromSale, .rejected, .readyForReview]
    }
}

private enum KeychainStorage {
    private static let service = "com.manabi.FramedScreenshotsTool.AppStoreConnect"

    struct Stored: Codable {
        var keyIdentifier: String
        var issuerIdentifier: String
        var privateKey: String
        var appId: String
        var platform: String
        var version: String?
    }

    static func load(from workspaceRoot: URL) -> AppStoreConnectUploader.Configuration? {
#if canImport(Security)
        let account = workspaceRoot.standardizedFileURL.path
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true as CFBoolean
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        let decoder = JSONDecoder()
        guard let stored = try? decoder.decode(Stored.self, from: data),
              let platform = AppStoreConnectUploader.Configuration.Platform(rawValue: stored.platform.lowercased())
        else {
            return nil
        }
        return AppStoreConnectUploader.Configuration(
            keyIdentifier: stored.keyIdentifier,
            issuerIdentifier: stored.issuerIdentifier,
            privateKey: stored.privateKey,
            appId: stored.appId,
            platform: platform,
            version: stored.version
        )
#else
        return nil
#endif
    }
}
{{MARKER_END}}
