import Foundation

public struct GitHubAccountProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var login: String
    public var scope: GitHubRunnerScope
    public var repositories: [String]
    public var isEnabled: Bool
    public var privateKeyName: String
    public var runnerGroup: String

    public init(
        id: UUID = UUID(),
        login: String = "",
        scope: GitHubRunnerScope = .organization,
        repositories: [String] = [],
        isEnabled: Bool = true,
        privateKeyName: String = "",
        runnerGroup: String = ""
    ) {
        self.id = id
        self.login = login
        self.scope = scope
        self.repositories = repositories
        self.isEnabled = isEnabled
        self.privateKeyName = privateKeyName
        self.runnerGroup = runnerGroup
    }

    public var validationMessage: String? {
        if login.range(of: "^[A-Za-z0-9][A-Za-z0-9-]*$", options: .regularExpression) == nil {
            return "Enter a GitHub account name, without a URL."
        }
        if repositories.contains(where: { repository in
            repository == "." || repository == ".."
                || repository.range(of: "^[A-Za-z0-9_.-]+$", options: .regularExpression) == nil
        }) {
            return "Use repository names only, without the owner or a URL."
        }
        return nil
    }
}
