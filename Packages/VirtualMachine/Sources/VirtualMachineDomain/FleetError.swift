import Foundation

enum FleetError: LocalizedError {
    case missingVirtualMachine

    var errorDescription: String? { "Select a base virtual machine before starting the scheduler." }
}
