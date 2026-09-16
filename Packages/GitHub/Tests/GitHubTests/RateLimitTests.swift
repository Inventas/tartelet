import GitHubData
import GitHubDomain
import XCTest

final class RateLimitTests: XCTestCase {
    @MainActor
    func testRateLimitedAccountIsNotPolledAgainBeforeRetryAfter() async throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = TestCredentials()
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in credentials }
        try store.save(GitHubAccountProfile(login: "org"), appID: "123", privateKey: TestKeys.make())
        let networking = FixtureNetworking { request in
            let value: Any
            switch request.url?.path {
            case "/orgs/org/installation":
                value = ["id": 7, "app_id": 123, "account": ["login": "org"]]
            case "/app/installations/7/access_tokens":
                value = ["token": "token"]
            default:
                value = ["message": "rate limit"]
            }
            return try JSONSerialization.data(withJSONObject: value)
        }
        networking.metadata = { request in
            guard request.url?.path == "/installation/repositories", let url = request.url else {
                return nil
            }
            return HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "3600"])
        }
        let queue = NetworkingGitHubJobQueue(accounts: store, networking: networking,
                                             runnerLabels: { "tartelet" }, defaultLabels: { true })
        let first = try await queue.queuedJobs()
        let count = networking.requests.count
        let second = try await queue.queuedJobs()
        XCTAssertTrue(first.jobs.isEmpty)
        XCTAssertTrue(first.errors.first?.contains("rate limit") == true)
        XCTAssertEqual(first.errors, second.errors)
        XCTAssertEqual(networking.requests.count, count)
    }
}
