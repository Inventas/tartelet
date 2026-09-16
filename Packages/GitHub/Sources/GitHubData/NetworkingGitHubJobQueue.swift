import Foundation
import GitHubDomain
import NetworkingDomain

@MainActor
public final class NetworkingGitHubJobQueue: GitHubJobQueue {
    private let accounts: GitHubAccountStore
    private let networking: NetworkingService
    private let runnerLabels: () -> String
    private let defaultLabels: () -> Bool
    private var tokens: [UUID: CachedGitHubToken] = [:]
    private var rateLimits: [UUID: GitHubRateLimitError] = [:]

    public init(
        accounts: GitHubAccountStore,
        networking: NetworkingService,
        runnerLabels: @escaping () -> String,
        defaultLabels: @escaping () -> Bool
    ) {
        self.accounts = accounts
        self.networking = networking
        self.runnerLabels = runnerLabels
        self.defaultLabels = defaultLabels
    }

    public func queuedJobs() async throws -> GitHubQueueSnapshot {
        if let error = accounts.storageError {
            return GitHubQueueSnapshot(jobs: [], errors: [error])
        }
        guard accounts.profiles.contains(where: { $0.isEnabled }) else {
            return GitHubQueueSnapshot(jobs: [], errors: ["Add and enable a GitHub account in Settings."])
        }
        var jobs: [GitHubQueuedJob] = []
        var errors: [String] = []
        var seen: Set<Int64> = []
        for profile in accounts.profiles where profile.isEnabled {
            try Task.checkCancellation()
            if let limit = rateLimits[profile.id], limit.retryDate > Date() {
                errors.append("\(profile.login): \(limit.localizedDescription)")
                continue
            }
            do {
                let token = try await accessToken(for: profile)
                let repositories = try await repositories(for: profile, token: token)
                for repository in repositories {
                    do {
                        let candidates = try await queuedJobs(profile: profile, repository: repository, token: token)
                        jobs.append(contentsOf: candidates.filter { job in
                            job.matches(runnerLabels: runnerLabels(), defaultLabels: defaultLabels())
                                && seen.insert(job.id).inserted
                        })
                    } catch {
                        try Task.checkCancellation()
                        if error is GitHubRateLimitError { throw error }
                        errors.append("\(profile.login)/\(repository): \(error.localizedDescription)")
                    }
                }
            } catch {
                try Task.checkCancellation()
                if let limit = error as? GitHubRateLimitError { rateLimits[profile.id] = limit }
                tokens.removeValue(forKey: profile.id)
                errors.append("\(profile.login): \(error.localizedDescription)")
            }
        }
        return GitHubQueueSnapshot(jobs: jobs, errors: errors)
    }

    private func accessToken(for profile: GitHubAccountProfile) async throws -> GitHubAppAccessToken {
        let credentials = SnapshotGitHubCredentials(
            profile: profile, repository: profile.repositories.first,
            credentials: accounts.credentials(for: profile))
        if let cached = tokens[profile.id], cached.isValid(for: credentials) {
            return cached.token
        }
        let client = NetworkingGitHubClient(credentialsStore: credentials, networkingService: networking)
        let token = try await client.getAppAccessToken(runnerScope: profile.scope)
        tokens[profile.id] = CachedGitHubToken(token: token, credentials: credentials)
        return token
    }

    private func repositories(for profile: GitHubAccountProfile, token: GitHubAppAccessToken) async throws -> [String] {
        let repositories = try await GitHubAPI(networking: networking).pages(
            GitHubRepositoryPage.self, path: "/installation/repositories", token: token, items: \.repositories
        )
        let available = repositories.filter { repository in
            !repository.archived && !repository.disabled
                && repository.full_name.lowercased() == "\(profile.login)/\(repository.name)".lowercased()
        }.map(\.name)
        guard !profile.repositories.isEmpty else {
            return available
        }
        let names = Set(available.map { $0.lowercased() })
        let missing = profile.repositories.filter { !names.contains($0.lowercased()) }
        guard missing.isEmpty else {
            throw GitHubAccountStoreError.invalidProfile(
                "The GitHub App cannot access these active repositories: \(missing.joined(separator: ", "))."
            )
        }
        return available.filter { name in profile.repositories.contains { $0.lowercased() == name.lowercased() } }
    }

    private func queuedJobs(
        profile: GitHubAccountProfile, repository: String, token: GitHubAppAccessToken
    ) async throws -> [GitHubQueuedJob] {
        let api = GitHubAPI(networking: networking)
        let path = "/repos/\(profile.login)/\(repository)/actions/runs"
        var runs: Set<Int64> = []
        // Running workflows can contain queued downstream or matrix jobs.
        for status in ["queued", "in_progress"] {
            let page = try await api.pages(
                GitHubWorkflowRunPage.self, path: path, token: token,
                query: [URLQueryItem(name: "status", value: status)], items: \.workflow_runs)
            runs.formUnion(page.map(\.id))
        }
        var result: [GitHubQueuedJob] = []
        for run in runs.sorted() {
            let jobs = try await api.pages(
                GitHubWorkflowJobPage.self, path: "\(path)/\(run)/jobs", token: token,
                query: [URLQueryItem(name: "filter", value: "latest")], items: \.jobs)
            result.append(
                contentsOf: jobs.filter { $0.status == "queued" }.map { job in
                    GitHubQueuedJob(id: job.id, profile: profile, repository: repository, labels: job.labels)
                })
        }
        return result
    }
}
