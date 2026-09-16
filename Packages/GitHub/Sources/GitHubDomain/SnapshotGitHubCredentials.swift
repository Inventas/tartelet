import Foundation

public struct SnapshotGitHubCredentials: GitHubCredentials {
    public let organizationName: String?
    public let repositoryName: String?
    public let ownerName: String?
    public let appId: String?
    public let privateKey: Data?

    public init(profile: GitHubAccountProfile, repository: String? = nil, credentials: GitHubCredentials) {
        organizationName = profile.scope == .organization ? profile.login : nil
        ownerName = profile.login
        repositoryName = repository
        appId = credentials.appId
        privateKey = credentials.privateKey
    }
}
