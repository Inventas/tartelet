@testable import VirtualMachineData
import XCTest

final class CloneCleanupTests: XCTestCase {
    func testCancelledCloneRemovesOnlyTheNewImage() async throws {
        let shell = CancelledCloneShell()
        let tart = Tart(homeProvider: TestTartHome(), shell: shell, executablePath: "/test/tart")
        let base = TartVirtualMachine(tart: tart, vmName: "base")
        do {
            _ = try await base.clone(named: "new-clone")
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(shell.commands.last, ["delete", "new-clone"])
            XCTAssertFalse(shell.commands.contains(["delete", "base"]))
        }
    }

    func testCancelledCloneDoesNotDeleteAnImageThatWasNeverCreated() async throws {
        let shell = CancelledCloneShell()
        shell.remainingVMs = "base\n"
        let tart = Tart(homeProvider: TestTartHome(), shell: shell, executablePath: "/test/tart")
        let base = TartVirtualMachine(tart: tart, vmName: "base")
        do {
            _ = try await base.clone(named: "new-clone")
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertFalse(shell.commands.contains { $0.first == "delete" })
        }
    }
}
