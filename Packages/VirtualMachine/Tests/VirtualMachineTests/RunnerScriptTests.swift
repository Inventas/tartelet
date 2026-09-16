import Foundation
import VirtualMachineDomain
import XCTest

final class RunnerScriptTests: XCTestCase {
    func testScriptHasValidShellSyntaxAndQuotesValuesLiterally() throws {
        let script = RunnerStartupScript.make(
            runnerURL: try XCTUnwrap(URL(string: "https://github.com/example")),
            downloadURL: try XCTUnwrap(URL(string: "https://example.com/runner.tar.gz")),
            token: "dummy'$(echo bad)", name: "runner's-name", configuration: TestRunnerConfiguration()
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tartelet-test-\(UUID()).sh")
        defer { try? FileManager.default.removeItem(at: url) }
        try script.write(to: url, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-n", url.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(script.contains("--ephemeral"))
        XCTAssertTrue(script.contains("sleep 300"))
        XCTAssertTrue(script.contains("ACTIONS_RUNNER_HOOK_JOB_STARTED="))
        XCTAssertTrue(script.contains("ACTIONS_RUNNER_HOOK_JOB_COMPLETED="))
        XCTAssertTrue(script.contains(RunnerStartupScript.quote("dummy'$(echo bad)")))
        XCTAssertFalse(script.contains("--replace"))
        // Execute only the quoting expression; the generated VM startup script is never run on the host.
        let pipe = Pipe()
        let shell = Process()
        let value = "literal ' \" $HOME $(echo unsafe) `echo unsafe`"
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-c", "printf %s " + RunnerStartupScript.quote(value)]
        shell.standardOutput = pipe
        try shell.run()
        let result = pipe.fileHandleForReading.readDataToEndOfFile()
        shell.waitUntilExit()
        XCTAssertEqual(String(data: result, encoding: .utf8), value)
    }
}
