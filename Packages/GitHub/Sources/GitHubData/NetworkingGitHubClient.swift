import Foundation
import GitHubDomain
import NetworkingDomain

private enum NetworkingGitHubClientError: LocalizedError {
    case organizationNameUnavailable
    case repositoryNameUnavailable
    case repositoryOwnerNameUnavailable
    case appIDUnavailable
    case privateKeyUnavailable
    case appIsNotInstalled
    case downloadNotFound(os:
        String, architecture: String)

    var errorDescription: String? {
        switch self {
        case .organizationNameUnavailable:
            return "The organization name is not available"
        case .repositoryNameUnavailable:
            return "The repository name is not available"
        case .repositoryOwnerNameUnavailable:
            return "The repository owner name is not available"
        case .appIDUnavailable:
            return "The app ID is not available"
        case .privateKeyUnavailable:
            return "The private key is not available"
        case .appIsNotInstalled:
            return "The GitHub app has not been installed. Please install it from the developer settings."
        case let .downloadNotFound(os, architecture):
            return "Could not find a download for \(os) (\(architecture))"
        }
    }
}

public final class NetworkingGitHubClient: GitHubClient {
    private let baseURL = URL(string: "https://api.github.com")!
    private let credentialsStore: GitHubCredentials
    private let networkingService: NetworkingService
    private var registrationMayExist = false

    public init(credentialsStore: GitHubCredentials, networkingService: NetworkingService) {
        self.credentialsStore = credentialsStore
        self.networkingService = networkingService
    }

    public func getAppAccessToken(runnerScope: GitHubRunnerScope) async throws -> GitHubAppAccessToken {
        let appInstallation = try await getAppInstallation(runnerScope: runnerScope)
        let installationID = String(appInstallation.id)
        let appID = String(appInstallation.appId)
        let url = baseURL.appending(path: "/app/installations/\(installationID)/access_tokens")
        guard let privateKey = credentialsStore.privateKey else {
            throw NetworkingGitHubClientError.privateKeyUnavailable
        }
        let jwtToken = try GitHubJWTTokenFactory.makeJWTToken(privateKey: privateKey, appID: appID)
        var request = URLRequest(url: url).addingBearerToken(jwtToken)
        request.httpMethod = "POST"
        return try await networkingService.load(
            IntermediateGitHubAppAccessToken.self,
            from: request
        ).map { parameters in
            GitHubAppAccessToken(parameters.value.token)
        }
    }

    public func removeRunner(named name: String, runnerScope: GitHubRunnerScope) async throws {
        guard registrationMayExist else {
            return
        }
        let token = try await getAppAccessToken(runnerScope: runnerScope)
        let registrationPath = try await runnerScope.runnerRegistrationPath(using: credentialsStore)
        let path = String(registrationPath.dropLast("/registration-token".count))
        let api = GitHubAPI(networking: networkingService)
        let runners = try await api.pages(GitHubRunnerPage.self, path: path, token: token, items: \.runners)
        for runner in runners where runner.name == name {
            var request = api.request(path: "\(path)/\(runner.id)", token: token)
            request.httpMethod = "DELETE"
            let response = await networkingService.data(from: request)
            if response.httpURLResponse?.statusCode != 404 { _ = try response.map(\.value) }
        }
        registrationMayExist = false
    }

    public func getRunnerDownloadURL(
        with appAccessToken: GitHubAppAccessToken,
        runnerScope: GitHubRunnerScope
    ) async throws -> URL {
        let url = try await baseURL.appending(path: runnerScope.runnerDownloadPath(using: credentialsStore))
        let request = URLRequest(url: url).addingBearerToken(appAccessToken.rawValue)
        let downloads = try await networkingService.load([GitHubRunnerDownload].self, from: request).map(\.value)
        let os = "osx"
        let architecture = "arm64"
        guard let download = downloads.first(where: { $0.os == os && $0.architecture == architecture }) else {
            throw NetworkingGitHubClientError.downloadNotFound(os: os, architecture: architecture)
        }
        return download.downloadURL
    }

    public func getRunnerRegistrationToken(
        with appAccessToken: GitHubAppAccessToken,
        runnerScope: GitHubRunnerScope
    ) async throws -> GitHubRunnerRegistrationToken {
        let url = try await baseURL.appending(path: runnerScope.runnerRegistrationPath(using: credentialsStore))
        var request = URLRequest(url: url).addingBearerToken(appAccessToken.rawValue)
        request.httpMethod = "POST"
        return try await networkingService.load(
            IntermediateGitHubRunnerRegistrationToken.self,
            from: request
        ).map { parameters in
            self.registrationMayExist = true
            return GitHubRunnerRegistrationToken(parameters.value.token)
        }
    }
}

private extension NetworkingGitHubClient {
    private func getAppInstallation(runnerScope: GitHubRunnerScope) async throws -> GitHubAppInstallation {
        let path: String
        switch runnerScope {
        case .organization:
            guard let login = credentialsStore.organizationName else {
                throw NetworkingGitHubClientError.organizationNameUnavailable
            }
            path = "/orgs/\(login)/installation"
        case .repo:
            guard let login = credentialsStore.ownerName else {
                throw NetworkingGitHubClientError.repositoryOwnerNameUnavailable
            }
            if let repository = credentialsStore.repositoryName, !repository.isEmpty {
                path = "/repos/\(login)/\(repository)/installation"
            } else {
                path = "/users/\(login)/installation"
            }
        }
        let token = try await getAppJWTToken()
        let request = URLRequest(url: baseURL.appending(path: path)).addingBearerToken(token)
        return try await networkingService.load(GitHubAppInstallation.self, from: request).map(\.value)
    }

    private func getAppJWTToken() async throws -> String {
        guard let privateKey = credentialsStore.privateKey else {
            throw NetworkingGitHubClientError.privateKeyUnavailable
        }
        guard let appID = credentialsStore.appId else {
            throw NetworkingGitHubClientError.appIDUnavailable
        }
        return try GitHubJWTTokenFactory.makeJWTToken(privateKey: privateKey, appID: appID)
    }
}

private extension URLRequest {
    func addingBearerToken(_ token: String) -> URLRequest {
        var mutableRequest = self
        mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutableRequest
    }
}

private extension GitHubRunnerScope {
    func runnerRegistrationPath(using credentialsStore: GitHubCredentials) async throws -> String {
        switch self {
        case .organization:
            guard let organizationName = credentialsStore.organizationName else {
                throw NetworkingGitHubClientError.organizationNameUnavailable
            }
            return "/orgs/\(organizationName)/actions/runners/registration-token"
        case .repo:
            guard let repositoryName = credentialsStore.repositoryName else {
                throw NetworkingGitHubClientError.repositoryNameUnavailable
            }
            guard let ownerName = credentialsStore.ownerName else {
                throw NetworkingGitHubClientError.repositoryOwnerNameUnavailable
            }

            return "/repos/\(ownerName)/\(repositoryName)/actions/runners/registration-token"
        }
    }

    func runnerDownloadPath(using credentialsStore: GitHubCredentials) async throws -> String {
        switch self {
        case .organization:
            guard let organizationName = credentialsStore.organizationName else {
                throw NetworkingGitHubClientError.organizationNameUnavailable
            }
            return "/orgs/\(organizationName)/actions/runners/downloads"
        case .repo:
            guard let repositoryName = credentialsStore.repositoryName else {
                throw NetworkingGitHubClientError.repositoryNameUnavailable
            }
            guard let ownerName = credentialsStore.ownerName else {
                throw NetworkingGitHubClientError.repositoryOwnerNameUnavailable
            }
            return "/repos/\(ownerName)/\(repositoryName)/actions/runners/downloads"
        }
    }

    func runnerLogin(using credentialsStore: GitHubCredentials) async -> String? {
        switch self {
        case .organization:
            return credentialsStore.organizationName
        case .repo:
            return credentialsStore.ownerName
        }
    }
}
