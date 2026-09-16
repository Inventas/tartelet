import Foundation
import ShellData
import ShellDomain
import XCTest

final class ProcessShellTests: XCTestCase {
    @MainActor
    func testCancelledTaskCannotLaunchAProcess() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("tartelet-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: marker) }
        let task = Task {
            try await ProcessShell().runExecutable(atPath: "/usr/bin/touch", withArguments: [marker.path])
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    func testCancellationStopsAnAlreadyRunningProcess() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("tartelet-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: marker) }
        let task = Task {
            try await ProcessShell().runExecutable(
                atPath: "/bin/sh",
                withArguments: ["-c", "echo started > \"$1\"; exec sleep 30", "tartelet-test", marker.path]
            )
        }
        for _ in 0..<1_000 {
            if FileManager.default.fileExists(atPath: marker.path) { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        let start = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        }
    }

    func testSuccessfulProcessReturnsItsOutput() async throws {
        let output = try await ProcessShell().runExecutable(atPath: "/usr/bin/printf", withArguments: ["hello"])
        XCTAssertEqual(output, "hello")
    }
}
