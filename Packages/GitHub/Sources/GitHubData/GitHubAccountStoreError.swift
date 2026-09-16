import Foundation

public enum GitHubAccountStoreError: LocalizedError {
    case invalidProfile(String)
    case invalidAppID
    case invalidPrivateKey
    case keychainWriteFailed
    case unreadableProfiles

    public var errorDescription: String? {
        switch self {
        case .invalidProfile(let message):
            message
        case .invalidAppID:
            "Enter the numeric GitHub App ID."
        case .invalidPrivateKey:
            "Select a valid RSA private key from your GitHub App."
        case .keychainWriteFailed:
            "Could not update Keychain. The account settings were not changed."
        case .unreadableProfiles:
            "The saved accounts could not be read. Restore your settings before making changes."
        }
    }
}
