public struct GitHubQueueSnapshot: Sendable {
    public let jobs: [GitHubQueuedJob]
    public let errors: [String]

    public init(jobs: [GitHubQueuedJob], errors: [String] = []) {
        self.jobs = jobs
        self.errors = errors
    }
}
