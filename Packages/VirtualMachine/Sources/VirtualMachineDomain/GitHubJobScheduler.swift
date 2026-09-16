import Foundation
import GitHubDomain

/// Round-robin between accounts; one account can use all slots when the others have no jobs.
public struct GitHubJobScheduler {
    private var lastProfileID: UUID?

    public init() {}

    public mutating func select(from jobs: [GitHubQueuedJob], excluding active: Set<Int64>, limit: Int)
    -> [GitHubQueuedJob] {
        var pending = jobs.filter { !active.contains($0.id) }.sorted { $0.id < $1.id }
        var selected: [GitHubQueuedJob] = []
        while !pending.isEmpty && selected.count < limit {
            var profiles: [UUID] = []
            for job in pending where !profiles.contains(job.profile.id) { profiles.append(job.profile.id) }
            let next: UUID
            if let lastProfileID, let index = profiles.firstIndex(of: lastProfileID) {
                next = profiles[(index + 1) % profiles.count]
            } else {
                next = profiles[0]
            }
            guard let job = pending.first(where: { $0.profile.id == next }) else { break }
            selected.append(job)
            pending.removeAll { $0.id == job.id }
            lastProfileID = next
        }
        return selected
    }
}
