import Foundation

@MainActor
final class TestMachineState {
    var starts: [String] = []
    var deleted: [String] = []
    var finished: Set<String> = []
    var deleteAttempts = 0
    var failFirstDelete = false
    var failStart = false

    func run(_ name: String) async throws {
        starts.append(name)
        if failStart { throw NSError(domain: "start failed", code: 1) }
        while !finished.contains(name) { try await Task.sleep(nanoseconds: 1_000_000) }
    }

    func delete(_ name: String) throws {
        deleteAttempts += 1
        if failFirstDelete && deleteAttempts == 1 { throw NSError(domain: "delete failed", code: 1) }
        deleted.append(name)
    }
}
