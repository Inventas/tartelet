import Foundation

@MainActor
public protocol GitHubJobQueue {
    func queuedJobs() async throws -> GitHubQueueSnapshot
}
