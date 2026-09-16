import Foundation

public struct GitHubQueuedJob: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let profile: GitHubAccountProfile
    public let repository: String
    public let labels: [String]

    public init(id: Int64, profile: GitHubAccountProfile, repository: String, labels: [String]) {
        self.id = id
        self.profile = profile
        self.repository = repository
        self.labels = labels
    }

    public func matches(runnerLabels: String, defaultLabels: Bool) -> Bool {
        var available = Set(
            runnerLabels.split(separator: ",").map { label in
                label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }.filter { !$0.isEmpty })
        if defaultLabels {
            available.formUnion(["self-hosted", "macos", "arm64"])
        }
        return !labels.isEmpty && Set(labels.map { $0.lowercased() }).isSubset(of: available)
    }
}
