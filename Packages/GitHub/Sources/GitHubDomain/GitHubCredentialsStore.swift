import Foundation

public protocol GitHubCredentialsStore: AnyObject, GitHubCredentials {
    func setOrganizationName(_ organizationName: String?)
    func setRepository(_ repositoryName: String?, withOwner ownerName: String?)
    func setAppID(_ appID: String?)
    func setPrivateKey(_ privateKeyData: Data?)
}
