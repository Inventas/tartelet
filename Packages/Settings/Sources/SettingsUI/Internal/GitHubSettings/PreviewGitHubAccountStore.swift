#if DEBUG
import Foundation
import GitHubDomain
import Observation

@Observable
final class PreviewGitHubAccountStore: GitHubAccountStore {
    var profiles: [GitHubAccountProfile]
    var storageError: String?
    private let store = PreviewGitHubCredentialsStore()

    init(profiles: [GitHubAccountProfile] = [
        GitHubAccountProfile(login: "example-org", privateKeyName: "runner.pem"),
        GitHubAccountProfile(login: "octocat", scope: .repo, isEnabled: false, privateKeyName: "personal.pem")
    ]) {
        self.profiles = profiles
    }

    func credentials(for profile: GitHubAccountProfile) -> GitHubCredentialsStore { store }
    func save(_ profile: GitHubAccountProfile, appID: String, privateKey: Data?) throws {
        profiles.removeAll { $0.id == profile.id }
        profiles.append(profile)
    }
    func remove(_ profile: GitHubAccountProfile) throws { profiles.removeAll { $0.id == profile.id } }
}
#endif
