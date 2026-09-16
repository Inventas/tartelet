import Foundation
import GitHubDomain
import LoggingDomain
import Observation

@MainActor
@Observable
public final class VirtualMachineFleet {
    public private(set) var isStarted = false
    public private(set) var isStopping = false
    public private(set) var activeMachineCount = 0
    public private(set) var statusMessage = "Stopped"
    public private(set) var lastError: String?

    private let logger: Logger
    private let queue: GitHubJobQueue
    private let makeVirtualMachine: (GitHubQueuedJob) throws -> VirtualMachine
    private let pollInterval: UInt64
    private var pollingTask: Task<Void, Never>?
    private var activeTasks: [Int64: Task<Void, Never>] = [:]
    private var scheduler = GitHubJobScheduler()
    private var cleanupErrors: [String: String] = [:]
    private var capacity = 2

    public init(
        logger: Logger,
        queue: GitHubJobQueue,
        pollInterval: UInt64 = 30_000_000_000,
        makeVirtualMachine: @escaping (GitHubQueuedJob) throws -> VirtualMachine
    ) {
        self.logger = logger
        self.queue = queue
        self.pollInterval = pollInterval
        self.makeVirtualMachine = makeVirtualMachine
    }

    public func start(numberOfMachines: Int) {
        guard !isStarted else {
            return
        }
        capacity = min(2, max(1, numberOfMachines))
        isStarted = true
        isStopping = false
        lastError = nil
        statusMessage = "Checking queued jobs…"
        pollingTask = Task {
            while !Task.isCancelled && !isStopping {
                await poll()
                do { try await Task.sleep(nanoseconds: pollInterval) } catch { break }
            }
        }
    }

    public func stop() {
        guard isStarted else {
            return
        }
        isStopping = true
        pollingTask?.cancel()
        pollingTask = nil
        statusMessage = "Waiting for active jobs and cleanup…"
        finishStoppingIfPossible()
    }

    public func stopImmediately() {
        stop()
        for task in activeTasks.values { task.cancel() }
    }

    private func poll() async {
        do {
            let snapshot = try await queue.queuedJobs()
            guard !Task.isCancelled && !isStopping else {
                return
            }
            let errors = Array(cleanupErrors.values) + snapshot.errors
            lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")
            let jobs = scheduler.select(from: snapshot.jobs, excluding: Set(activeTasks.keys),
                                        limit: capacity - activeTasks.count)
            for job in jobs { launch(job) }
            statusMessage = activeTasks.isEmpty
                ? "Waiting for matching jobs" : "\(activeTasks.count) of \(capacity) VM slots in use"
        } catch {
            guard !Task.isCancelled else {
                return
            }
            lastError = error.localizedDescription
            logger.error(error.localizedDescription)
        }
    }

    private func launch(_ job: GitHubQueuedJob) {
        activeTasks[job.id] = Task {
            var machine: VirtualMachine?
            do {
                let base = try makeVirtualMachine(job)
                guard base.canStart else { throw FleetError.missingVirtualMachine }
                let name = "tartelet-\(job.profile.id.uuidString)-\(UUID().uuidString)"
                machine = try await base.clone(named: name)
                try Task.checkCancellation()
                try await machine?.start()
            } catch {
                if !(error is CancellationError) {
                    lastError = "\(job.profile.login): \(error.localizedDescription)"
                    logger.error(lastError ?? error.localizedDescription)
                }
            }
            if let machine {
                // An unstructured task completes cleanup even if the job task was cancelled.
                // The slot stays occupied until both VM and runner registration are removed.
                await Task { await self.cleanUp(machine) }.value
            }
            activeTasks.removeValue(forKey: job.id)
            activeMachineCount = activeTasks.count
            finishStoppingIfPossible()
        }
        activeMachineCount = activeTasks.count
    }

    private func cleanUp(_ machine: VirtualMachine) async {
        defer { cleanupErrors.removeValue(forKey: machine.name) }
        while true {
            do {
                try await machine.delete()
                return
            } catch {
                lastError = "Cleanup failed for \(machine.name). Retrying: \(error.localizedDescription)"
                cleanupErrors[machine.name] = lastError
                logger.error(lastError ?? error.localizedDescription)
                try? await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }

    private func finishStoppingIfPossible() {
        if isStopping && activeTasks.isEmpty {
            isStarted = false
            isStopping = false
            statusMessage = "Stopped"
        }
    }
}
