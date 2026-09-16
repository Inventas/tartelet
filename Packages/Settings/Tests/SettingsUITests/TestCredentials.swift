import Foundation
import GitHubDomain

final class TestCredentials: GitHubCredentialsStore {
    var organizationName: String?
    var repositoryName: String?
    var ownerName: String?
    var appId: String? = "12345"
    var privateKey: Data?
    func setOrganizationName(_ organizationName: String?) { self.organizationName = organizationName }
    func setRepository(_ repositoryName: String?, withOwner ownerName: String?) {
        self.repositoryName = repositoryName
        self.ownerName = ownerName
    }
    func setAppID(_ appID: String?) { appId = appID }
    func setPrivateKey(_ privateKeyData: Data?) { privateKey = privateKeyData }
}
