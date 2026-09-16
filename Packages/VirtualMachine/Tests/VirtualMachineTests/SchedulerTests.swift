import GitHubDomain
import VirtualMachineDomain
import XCTest

final class SchedulerTests: XCTestCase {
    func testSharesSlotsFairlyAndLetsOneAccountUseBoth() {
        let organization = GitHubAccountProfile(login: "org")
        let personal = GitHubAccountProfile(login: "person", scope: .repo)
        let jobs = [
            GitHubQueuedJob(id: 1, profile: organization, repository: "app", labels: ["tartelet"]),
            GitHubQueuedJob(id: 2, profile: organization, repository: "app", labels: ["tartelet"]),
            GitHubQueuedJob(id: 3, profile: personal, repository: "site", labels: ["tartelet"])
        ]
        var scheduler = GitHubJobScheduler()
        XCTAssertEqual(scheduler.select(from: jobs, excluding: [], limit: 2).map(\.id), [1, 3])
        XCTAssertEqual(scheduler.select(from: jobs, excluding: [1, 3], limit: 1).map(\.id), [2])
        XCTAssertEqual(scheduler.select(from: Array(jobs.prefix(2)), excluding: [], limit: 2).map(\.id), [1, 2])
        XCTAssertTrue(scheduler.select(from: jobs, excluding: [], limit: 0).isEmpty)
    }

    @MainActor
    func testFleetCapsAtTwoDoesNotDuplicateJobsAndWaitsForCleanup() async throws {
        let queue = TestJobQueue()
        let profile = GitHubAccountProfile(login: "org")
        queue.jobs = (1...3).map { id in
            GitHubQueuedJob(id: Int64(id), profile: profile, repository: "app", labels: ["tartelet"])
        }
        let state = TestMachineState()
        state.failFirstDelete = true
        let fleet = VirtualMachineFleet(logger: TestLogger(), queue: queue, pollInterval: 5_000_000) { _ in
            TestMachine(state: state)
        }
        fleet.start(numberOfMachines: 20)
        try await eventually { state.starts.count == 2 }
        try await Task.sleep(nanoseconds: 25_000_000)
        XCTAssertEqual(state.starts.count, 2)
        XCTAssertEqual(Set(state.starts).count, 2)
        XCTAssertEqual(fleet.activeMachineCount, 2)
        fleet.stopImmediately()
        XCTAssertTrue(fleet.isStarted)
        try await eventually { !fleet.isStarted }
        XCTAssertEqual(state.deleted.count, 2)
        XCTAssertEqual(state.deleteAttempts, 3)
        XCTAssertEqual(fleet.activeMachineCount, 0)
        XCTAssertFalse(fleet.isStopping)
    }

    @MainActor
    func testGracefulStopFinishesCurrentJobWithoutStartingAnother() async throws {
        let queue = TestJobQueue()
        let profile = GitHubAccountProfile(login: "person", scope: .repo)
        queue.jobs = (1...2).map { id in
            GitHubQueuedJob(id: Int64(id), profile: profile, repository: "app", labels: ["tartelet"])
        }
        let state = TestMachineState()
        let fleet = VirtualMachineFleet(logger: TestLogger(), queue: queue, pollInterval: 5_000_000) { _ in
            TestMachine(state: state)
        }
        fleet.start(numberOfMachines: 1)
        try await eventually { state.starts.count == 1 }
        fleet.stop()
        XCTAssertTrue(fleet.isStopping)
        state.finished.formUnion(state.starts)
        try await eventually { !fleet.isStarted }
        XCTAssertEqual(state.starts.count, 1)
        XCTAssertEqual(state.deleted, state.starts)
    }

    @MainActor
    func testFailedStartStillDeletesCloneAndStopWithNoJobsIsImmediate() async throws {
        let queue = TestJobQueue()
        let state = TestMachineState()
        state.failStart = true
        let fleet = VirtualMachineFleet(logger: TestLogger(), queue: queue, pollInterval: 50_000_000) { _ in
            TestMachine(state: state)
        }
        fleet.start(numberOfMachines: 2)
        fleet.stop()
        XCTAssertFalse(fleet.isStarted)
        queue.jobs = [
            GitHubQueuedJob(id: 1, profile: GitHubAccountProfile(login: "org"), repository: "app", labels: ["tartelet"])
        ]
        fleet.start(numberOfMachines: 1)
        try await eventually { state.deleted.count == 1 }
        fleet.stop()
        XCTAssertEqual(state.deleted, state.starts)
        try await eventually { !fleet.isStarted }
    }

    @MainActor
    private func eventually(_ predicate: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if predicate() {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("The asynchronous operation did not complete")
    }
}
