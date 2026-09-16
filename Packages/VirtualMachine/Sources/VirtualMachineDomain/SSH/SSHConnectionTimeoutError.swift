import Foundation

enum SSHConnectionTimeoutError: LocalizedError {
    case timedOut

    var errorDescription: String? { "The VM did not complete runner setup within five minutes." }
}
