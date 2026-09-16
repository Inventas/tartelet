import GitHubData
import GitHubDomain
import XCTest

final class QueueDiscoveryTests: XCTestCase {
    @MainActor
    func testPersonalRepositoriesRunningWorkflowsPaginationAndTokenReuse() async throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = TestCredentials()
        let store = KeychainGitHubAccountStore(defaults: defaults) { _ in credentials }
        let profile = GitHubAccountProfile(login: "person", scope: .repo)
        try store.save(profile, appID: "123", privateKey: TestKeys.make())
        let networking = FixtureNetworking(response: response)
        let queue = NetworkingGitHubJobQueue(
            accounts: store, networking: networking,
            runnerLabels: { "tartelet" }, defaultLabels: { true })
        let first = try await queue.queuedJobs()
        let second = try await queue.queuedJobs()
        XCTAssertTrue(first.errors.isEmpty, first.errors.joined())
        XCTAssertEqual(first.jobs.map(\.id), [101])
        XCTAssertEqual(second.jobs.first?.repository, "app")
        XCTAssertEqual(networking.requests.filter { $0.url?.path == "/app/installations/7/access_tokens" }.count, 1)
    }

    private func response(to request: URLRequest) throws -> Data {
    let url = try XCTUnwrap(request.url)
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let page = query.first { $0.name == "page" }?.value
    let status = query.first { $0.name == "status" }?.value
    let value: Any
    switch url.path {
    case "/users/person/installation":
        value = ["id": 7, "app_id": 123, "account": ["login": "person"]]
    case "/app/installations/7/access_tokens":
        value = ["token": "test-installation-token"]
    case "/installation/repositories":
        value = [
            "repositories": ["app", "website"].map { name in
                ["name": name, "full_name": "person/\(name)", "archived": false, "disabled": false] as [String: Any]
            }
        ]
    case "/repos/person/app/actions/runs":
        value = ["workflow_runs": status == "in_progress" ? [["id": 50]] : []]
    case "/repos/person/website/actions/runs":
        value = ["workflow_runs": []]
    case "/repos/person/app/actions/runs/50/jobs":
        XCTAssertEqual(query.first { $0.name == "filter" }?.value, "latest")
        if page == "1" {
            value = [
                "jobs": (1...100).map { id in
                    ["id": id, "status": "completed", "labels": ["tartelet"]] as [String: Any]
                }
            ]
        } else {
            value = [
                "jobs": [
                    ["id": 101, "status": "queued", "labels": ["self-hosted", "tartelet"]],
                    ["id": 102, "status": "queued", "labels": ["ubuntu-latest"]]
                ]
            ]
        }
    default:
        throw NSError(domain: "Unexpected request: \(url)", code: 1)
    }
    return try JSONSerialization.data(withJSONObject: value)
    }
}
