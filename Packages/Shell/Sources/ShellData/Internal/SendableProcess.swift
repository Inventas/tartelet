import Foundation

final class SendableProcess: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var isCancelled = false

    init(_ process: Process) {
        self.process = process
    }

    func run() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled else { throw CancellationError() }
        try process.run()
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        if process.isRunning {
            process.terminate()
        }
    }
}
