import Foundation
import ShellDomain

final class CancelledCloneShell: Shell {
    var commands: [[String]] = []
    var remainingVMs = "base\nnew-clone\n"

    func runExecutable(
        atPath executablePath: String, withArguments arguments: [String], environment: [String: String]
    ) async throws -> String {
        commands.append(arguments)
        switch arguments.first {
        case "clone":
            throw CancellationError()
        case "list":
            return remainingVMs
        default:
            return ""
        }
    }
}
