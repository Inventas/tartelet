import Foundation
import GitHubDomain
import Keychain
import Observation

@Observable
public final class KeychainGitHubAccountStore: GitHubAccountStore {
    public private(set) var profiles: [GitHubAccountProfile] = []
    public private(set) var storageError: String?
    private let defaults: UserDefaults
    private let makeCredentials: (UUID) -> GitHubCredentialsStore
    private let profilesKey = "githubAccountProfiles.v1"

    public init(defaults: UserDefaults = .standard, makeCredentials: @escaping (UUID) -> GitHubCredentialsStore) {
        self.defaults = defaults
        self.makeCredentials = makeCredentials
        if let data = defaults.data(forKey: profilesKey) {
            do {
                profiles = try JSONDecoder().decode([GitHubAccountProfile].self, from: data)
            } catch {
                storageError = GitHubAccountStoreError.unreadableProfiles.localizedDescription
            }
        }
    }

    public func credentials(for profile: GitHubAccountProfile) -> GitHubCredentialsStore {
        makeCredentials(profile.id)
    }

    public func save(_ profile: GitHubAccountProfile, appID: String, privateKey: Data?) throws {
        guard storageError == nil else { throw GitHubAccountStoreError.unreadableProfiles }
        if let message = profile.validationMessage { throw GitHubAccountStoreError.invalidProfile(message) }
        guard !appID.isEmpty, appID.allSatisfy(\.isNumber) else { throw GitHubAccountStoreError.invalidAppID }
        let store = credentials(for: profile)
        let keyData = privateKey ?? store.privateKey
        guard let keyData, let key = RSAPrivateKey(keyData) else {
            throw GitHubAccountStoreError.invalidPrivateKey
        }
        // Check every credential write before publishing a profile. Keep the previous values on failure.
        let previous = SnapshotGitHubCredentials(profile: profile, credentials: store)
        store.setAppID(appID)
        if privateKey != nil { store.setPrivateKey(keyData) }
        guard store.appId == appID, store.privateKey == key.data else {
            store.setAppID(previous.appId)
            store.setPrivateKey(previous.privateKey)
            throw GitHubAccountStoreError.keychainWriteFailed
        }
        var updated = profiles
        if let index = updated.firstIndex(where: { $0.id == profile.id }) {
            updated[index] = profile
        } else {
            updated.append(profile)
        }
        try persist(updated)
    }

    public func remove(_ profile: GitHubAccountProfile) throws {
        guard storageError == nil else { throw GitHubAccountStoreError.unreadableProfiles }
        let store = credentials(for: profile)
        let previous = SnapshotGitHubCredentials(profile: profile, credentials: store)
        store.setAppID(nil)
        store.setPrivateKey(nil)
        guard store.appId == nil, store.privateKey == nil else {
            store.setAppID(previous.appId)
            store.setPrivateKey(previous.privateKey)
            throw GitHubAccountStoreError.keychainWriteFailed
        }
        try persist(profiles.filter { $0.id != profile.id })
    }

    public func migrateLegacyAccount(
        credentials: GitHubCredentials,
        scope: GitHubRunnerScope,
        privateKeyName: String?,
        runnerGroup: String = ""
    ) {
        guard defaults.object(forKey: profilesKey) == nil else {
            return
        }
        let login = scope == .organization ? credentials.organizationName : credentials.ownerName
        guard let login, !login.isEmpty, let appID = credentials.appId, credentials.privateKey != nil else {
            return
        }
        let repositories = scope == .repo ? [credentials.repositoryName].compactMap { $0 }.filter { !$0.isEmpty } : []
        let profile = GitHubAccountProfile(
            login: login, scope: scope, repositories: repositories, privateKeyName: privateKeyName ?? "",
            runnerGroup: runnerGroup
        )
        do {
            try save(profile, appID: appID, privateKey: credentials.privateKey)
        } catch {
            storageError = "Could not import the previous account: \(error.localizedDescription)"
        }
    }

    private func persist(_ profiles: [GitHubAccountProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        defaults.set(data, forKey: profilesKey)
        self.profiles = profiles
    }
}
