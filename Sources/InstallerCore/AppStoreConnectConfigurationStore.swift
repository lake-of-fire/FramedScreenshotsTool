import Foundation
#if canImport(Security)
import Security
#endif

public enum AppStoreConnectConfigurationStore {
    public struct Credentials: Codable, Equatable, Sendable {
        public var keyIdentifier: String
        public var issuerIdentifier: String
        public var privateKey: String
        public var appId: String
        public var platform: String
        public var version: String?

        public init(
            keyIdentifier: String,
            issuerIdentifier: String,
            privateKey: String,
            appId: String,
            platform: String,
            version: String?
        ) {
            self.keyIdentifier = keyIdentifier
            self.issuerIdentifier = issuerIdentifier
            self.privateKey = privateKey
            self.appId = appId
            self.platform = platform
            self.version = version
        }
    }

    public enum StoreError: Swift.Error, CustomStringConvertible {
        case keychain(OSStatus)

        public var description: String {
            switch self {
            case .keychain(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
                return "Keychain operation failed: \(message) (\(status))"
            }
        }
    }

    private static let service = "com.manabi.FramedScreenshotsTool.AppStoreConnect"

    public static func loadCredentials(workspaceRoot: URL) -> Credentials? {
#if canImport(Security)
        let account = accountIdentifier(for: workspaceRoot)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true as CFBoolean
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(Credentials.self, from: data)
#else
        return nil
#endif
    }

    public static func saveCredentials(_ credentials: Credentials, workspaceRoot: URL) throws {
#if canImport(Security)
        let account = accountIdentifier(for: workspaceRoot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(credentials)

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychain(status)
        }
#else
        throw StoreError.keychain(errSecUnimplemented)
#endif
    }

    public static func deleteCredentials(workspaceRoot: URL) throws {
#if canImport(Security)
        let account = accountIdentifier(for: workspaceRoot)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.keychain(status)
        }
#else
        throw StoreError.keychain(errSecUnimplemented)
#endif
    }

    private static func accountIdentifier(for workspaceRoot: URL) -> String {
        workspaceRoot.standardizedFileURL.path
    }
}
