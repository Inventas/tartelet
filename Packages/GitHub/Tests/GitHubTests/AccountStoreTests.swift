import GitHubData
import GitHubDomain
import Keychain
import XCTest

final class AccountStoreTests: XCTestCase {
    func testProfilesKeepIndependentCredentialsAndPersistEditsWithoutAReplacementKey() throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var credentials: [UUID: TestCredentials] = [:]
        let makeStore: (UUID) -> GitHubCredentialsStore = { id in
            if let existing = credentials[id] {
                return existing
            }
            let store = TestCredentials()
            credentials[id] = store
            return store
        }
        let store = KeychainGitHubAccountStore(defaults: defaults, makeCredentials: makeStore)
        var organization = GitHubAccountProfile(login: "organization")
        let personal = GitHubAccountProfile(login: "person", scope: .repo, repositories: ["app", "website"])
        let firstKey = try TestKeys.make()
        let secondKey = try TestKeys.make()
        try store.save(organization, appID: "100", privateKey: firstKey)
        try store.save(personal, appID: "200", privateKey: secondKey)
        organization.isEnabled = false
        try store.save(organization, appID: "100", privateKey: nil)
        XCTAssertEqual(store.credentials(for: organization).privateKey, firstKey)
        XCTAssertEqual(store.credentials(for: personal).privateKey, secondKey)
        let restored = KeychainGitHubAccountStore(defaults: defaults, makeCredentials: makeStore)
        XCTAssertEqual(restored.profiles, [organization, personal])
        try restored.remove(organization)
        XCTAssertNil(restored.credentials(for: organization).privateKey)
        XCTAssertEqual(restored.credentials(for: personal).privateKey, secondKey)
        XCTAssertEqual(restored.profiles, [personal])
    }

    func testLegacyMigrationRunsOnceAndDoesNotDeleteLegacyCredentials() throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = TestCredentials()
        legacy.ownerName = "octocat"
        legacy.repositoryName = "app"
        legacy.appId = "123"
        legacy.privateKey = try TestKeys.make()
        let target = TestCredentials()
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in target }
        store.migrateLegacyAccount(credentials: legacy, scope: .repo, privateKeyName: "old.pem")
        store.migrateLegacyAccount(credentials: legacy, scope: .repo, privateKeyName: "old.pem")
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.repositories, ["app"])
        XCTAssertEqual(target.privateKey, legacy.privateKey)
        try store.remove(try XCTUnwrap(store.profiles.first))
        store.migrateLegacyAccount(credentials: legacy, scope: .repo, privateKeyName: "old.pem")
        XCTAssertTrue(store.profiles.isEmpty)
        XCTAssertNotNil(legacy.privateKey)
    }

    func testInvalidKeyAndFailedKeychainWriteDoNotPublishProfiles() throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = TestCredentials()
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in credentials }
        let profile = GitHubAccountProfile(login: "octocat")
        XCTAssertThrowsError(try store.save(profile, appID: "123", privateKey: Data("invalid".utf8)))
        credentials.rejectWrites = true
        XCTAssertThrowsError(try store.save(profile, appID: "123", privateKey: TestKeys.make()))
        XCTAssertTrue(store.profiles.isEmpty)
        XCTAssertNil(defaults.object(forKey: "githubAccountProfiles.v1"))
    }

    func testCorruptProfilesCannotBeOverwritten() throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: "githubAccountProfiles.v1")
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in TestCredentials() }
        XCTAssertNotNil(store.storageError)
        XCTAssertThrowsError(
            try store.save(GitHubAccountProfile(login: "octocat"), appID: "1", privateKey: TestKeys.make()))
        XCTAssertEqual(defaults.data(forKey: "githubAccountProfiles.v1"), corrupt)
    }

    func testAcceptsGitHubPEMAndKeychainDER() throws {
        let data = try TestKeys.make()
        let pem = "-----BEGIN RSA PRIVATE KEY-----\n\(data.base64EncodedString())\n-----END RSA PRIVATE KEY-----"
        XCTAssertEqual(RSAPrivateKey(Data(pem.utf8))?.data, data)
        XCTAssertEqual(RSAPrivateKey(data)?.data, data)
    }
    func testFailedCredentialRemovalKeepsTheAccount() throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = TestCredentials()
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in credentials }
        let profile = GitHubAccountProfile(login: "org")
        let key = try TestKeys.make()
        try store.save(profile, appID: "123", privateKey: key)
        credentials.rejectWrites = true
        XCTAssertThrowsError(try store.remove(profile))
        XCTAssertEqual(store.profiles, [profile])
        XCTAssertEqual(credentials.privateKey, key)
    }

}
