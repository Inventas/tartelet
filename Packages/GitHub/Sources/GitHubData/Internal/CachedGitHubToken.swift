import Foundation
import GitHubDomain

struct CachedGitHubToken {
    let token: GitHubAppAccessToken
    let credentials: SnapshotGitHubCredentials
    private let createdAt = Date()

    func isValid(for current: SnapshotGitHubCredentials) -> Bool {
        Date().timeIntervalSince(createdAt) < 45 * 60 && credentials.appId == current.appId
            && credentials.privateKey == current.privateKey && credentials.ownerName == current.ownerName
            && credentials.organizationName == current.organizationName
    }
}
