import Foundation

public protocol GitHubCredentials {
    var organizationName: String? { get }
    var repositoryName: String? { get }
    var ownerName: String? { get }
    var appId: String? { get }
    var privateKey: Data? { get }
}
