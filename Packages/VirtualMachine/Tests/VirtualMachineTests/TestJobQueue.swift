import GitHubDomain

@MainActor
final class TestJobQueue: GitHubJobQueue {
    var jobs: [GitHubQueuedJob] = []
    func queuedJobs() async throws -> GitHubQueueSnapshot { GitHubQueueSnapshot(jobs: jobs) }
}
