import VirtualMachineDomain

final class TestMachine: VirtualMachine {
    let name: String
    let canStart = true
    let state: TestMachineState
    init(name: String = "base", state: TestMachineState) {
        self.name = name
        self.state = state
    }
    func start() async throws { try await state.run(name) }
    func clone(named newName: String) async throws -> VirtualMachine { TestMachine(name: newName, state: state) }
    func delete() async throws { try await state.delete(name) }
    func getIPAddress() async throws -> String { "127.0.0.1" }
}
