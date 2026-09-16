import Foundation
import GitHubDomain

final class TestAccountStore: GitHubAccountStore {
    var profiles: [GitHubAccountProfile]
    var storageError: String?
    var removalError: Error?
    var removalCount = 0

    init(profiles: [GitHubAccountProfile]) {
        self.profiles = profiles
    }

    func credentials(for profile: GitHubAccountProfile) -> GitHubCredentialsStore {
        TestCredentials()
    }

    func save(_ profile: GitHubAccountProfile, appID: String, privateKey: Data?) throws {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    func remove(_ profile: GitHubAccountProfile) throws {
        removalCount += 1
        if let removalError {
            throw removalError
        }
        profiles.removeAll { $0.id == profile.id }
    }
}
