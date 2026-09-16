import GitHubDomain
import XCTest

final class QueuedJobTests: XCTestCase {
    func testAllRequestedLabelsMustMatchWithoutMatchingHostedJobs() {
        let profile = GitHubAccountProfile(login: "octocat")
        let job = GitHubQueuedJob(
            id: 1, profile: profile, repository: "app", labels: ["self-hosted", "macOS", "ARM64", "xcode"])
        XCTAssertTrue(job.matches(runnerLabels: "tartelet, Xcode", defaultLabels: true))
        XCTAssertFalse(job.matches(runnerLabels: "tartelet", defaultLabels: true))
        XCTAssertFalse(job.matches(runnerLabels: "xcode", defaultLabels: false))
        let hosted = GitHubQueuedJob(id: 2, profile: profile, repository: "app", labels: ["macos-latest"])
        XCTAssertFalse(hosted.matches(runnerLabels: "tartelet", defaultLabels: true))
        let empty = GitHubQueuedJob(id: 3, profile: profile, repository: "app", labels: [])
        XCTAssertFalse(empty.matches(runnerLabels: "tartelet", defaultLabels: true))
    }

    func testProfileRejectsURLsAndRepositoryPaths() {
        XCTAssertNotNil(GitHubAccountProfile(login: "https://github.com/org").validationMessage)
        XCTAssertNotNil(GitHubAccountProfile(login: "org", repositories: ["../other"]).validationMessage)
        XCTAssertNil(GitHubAccountProfile(login: "some-org", repositories: ["my.app", "site_2"]).validationMessage)
    }
}
