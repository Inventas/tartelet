import GitHubDomain

/// Removes a runner left behind by a cancelled job, failed setup, or idle timeout.
public final class RegisteredRunnerVirtualMachine: VirtualMachine {
    public var name: String { machine.name }
    public var canStart: Bool { machine.canStart }
    private let machine: VirtualMachine
    private let client: GitHubClient
    private let scope: GitHubRunnerScope
    private var didDeleteMachine = false

    public init(machine: VirtualMachine, client: GitHubClient, scope: GitHubRunnerScope) {
        self.machine = machine
        self.client = client
        self.scope = scope
    }

    public func start() async throws { try await machine.start() }
    public func getIPAddress() async throws -> String { try await machine.getIPAddress() }

    public func clone(named newName: String) async throws -> VirtualMachine {
        let clone = try await machine.clone(named: newName)
        return RegisteredRunnerVirtualMachine(machine: clone, client: client, scope: scope)
    }

    public func delete() async throws {
        if !didDeleteMachine {
            try await machine.delete()
            didDeleteMachine = true
        }
        try await client.removeRunner(named: name, runnerScope: scope)
    }
}
