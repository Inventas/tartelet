import GitHubData
import GitHubDomain
import XCTest

final class RegistrationTests: XCTestCase {
    func testPersonalRegistrationAndCleanupStayInTheJobRepository() async throws {
        let credentials = TestCredentials()
        credentials.appId = "123"
        credentials.privateKey = try TestKeys.make()
        let profile = GitHubAccountProfile(login: "person", scope: .repo)
        let snapshot = SnapshotGitHubCredentials(profile: profile, repository: "second-repo", credentials: credentials)
        let networking = FixtureNetworking { request in
            let path = try XCTUnwrap(request.url?.path)
            let value: Any
            switch path {
            case "/repos/person/second-repo/installation":
                value = ["id": 7, "app_id": 123, "account": ["login": "person"]]
            case "/app/installations/7/access_tokens":
                value = ["token": "installation-token"]
            case "/repos/person/second-repo/actions/runners/registration-token":
                value = ["token": "registration-token"]
            case "/repos/person/second-repo/actions/runners":
                value = ["runners": [["id": 10, "name": "our-unique-runner"], ["id": 11, "name": "someone-else"]]]
            case "/repos/person/second-repo/actions/runners/10":
                XCTAssertEqual(request.httpMethod, "DELETE")
                return Data()
            default:
                throw NSError(domain: "Unexpected request: \(path)", code: 1)
            }
            return try JSONSerialization.data(withJSONObject: value)
        }
        let client = NetworkingGitHubClient(credentialsStore: snapshot, networkingService: networking)
        // Failed setup before registration must not need API access during cleanup.
        try await client.removeRunner(named: "our-unique-runner", runnerScope: .repo)
        XCTAssertTrue(networking.requests.isEmpty)
        let token = try await client.getAppAccessToken(runnerScope: .repo)
        _ = try await client.getRunnerRegistrationToken(with: token, runnerScope: .repo)
        try await client.removeRunner(named: "our-unique-runner", runnerScope: .repo)
        XCTAssertEqual(
            networking.requests.filter { $0.httpMethod == "DELETE" }.map { $0.url?.path },
            ["/repos/person/second-repo/actions/runners/10"])
        let count = networking.requests.count
        try await client.removeRunner(named: "our-unique-runner", runnerScope: .repo)
        XCTAssertEqual(networking.requests.count, count)
    }

    @MainActor
    func testFailureInOneOrganizationDoesNotBlockAnotherAccount() async throws {
        let suite = "tartelet.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var credentialStores: [UUID: TestCredentials] = [:]
        let store = KeychainGitHubAccountStore(defaults: defaults) { id in
            if let existing = credentialStores[id] {
                return existing
            }
            let credentials = TestCredentials()
            credentialStores[id] = credentials
            return credentials
        }
        let first = GitHubAccountProfile(login: "broken")
        let second = GitHubAccountProfile(login: "working")
        try store.save(first, appID: "123", privateKey: TestKeys.make())
        try store.save(second, appID: "456", privateKey: TestKeys.make())
        let networking = FixtureNetworking { request in
            let path = try XCTUnwrap(request.url?.path)
            let value: Any
            switch path {
            case "/orgs/broken/installation":
                throw NSError(domain: "App is not installed", code: 404)
            case "/orgs/working/installation":
                value = ["id": 7, "app_id": 456, "account": ["login": "working"]]
            case "/app/installations/7/access_tokens":
                value = ["token": "token"]
            case "/installation/repositories":
                value = [
                    "repositories": [["name": "app", "full_name": "working/app", "archived": false, "disabled": false]]
                ]
            case "/repos/working/app/actions/runs":
                value = ["workflow_runs": [["id": 50]]]
            case "/repos/working/app/actions/runs/50/jobs":
                value = ["jobs": [["id": 99, "status": "queued", "labels": ["tartelet"]]]]
            default:
                throw NSError(domain: "Unexpected request: \(path)", code: 1)
            }
            return try JSONSerialization.data(withJSONObject: value)
        }
        let queue = NetworkingGitHubJobQueue(
            accounts: store, networking: networking,
            runnerLabels: { "tartelet" }, defaultLabels: { true })
        let snapshot = try await queue.queuedJobs()
        XCTAssertEqual(snapshot.jobs.map(\.id), [99])
        XCTAssertEqual(snapshot.jobs.first?.profile.id, second.id)
        XCTAssertEqual(snapshot.errors.count, 1)
        XCTAssertTrue(snapshot.errors[0].contains("broken"))
    }
}
