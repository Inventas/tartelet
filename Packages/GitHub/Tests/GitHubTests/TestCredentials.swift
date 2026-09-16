import Foundation
import GitHubDomain
import Keychain

final class TestCredentials: GitHubCredentialsStore {
    var organizationName: String?
    var repositoryName: String?
    var ownerName: String?
    var appId: String?
    var privateKey: Data?
    var rejectWrites = false
    func setOrganizationName(_ organizationName: String?) { self.organizationName = organizationName }
    func setRepository(_ repositoryName: String?, withOwner ownerName: String?) {
        self.repositoryName = repositoryName
        self.ownerName = ownerName
    }
    func setAppID(_ appID: String?) { if !rejectWrites { appId = appID } }
    func setPrivateKey(_ privateKeyData: Data?) {
        if !rejectWrites { privateKey = privateKeyData.flatMap { RSAPrivateKey($0)?.data } }
    }
}
