import Foundation

public protocol GitHubAccountStore: AnyObject {
    var profiles: [GitHubAccountProfile] { get }
    var storageError: String? { get }
    func credentials(for profile: GitHubAccountProfile) -> GitHubCredentialsStore
    func save(_ profile: GitHubAccountProfile, appID: String, privateKey: Data?) throws
    func remove(_ profile: GitHubAccountProfile) throws
}
