import Foundation
import GitHubDomain
import Observation

@Observable
final class GitHubAccountsModel {
    let accounts: GitHubAccountStore
    var editingProfile: GitHubAccountProfile?
    var errorMessage: String?

    init(accounts: GitHubAccountStore) {
        self.accounts = accounts
    }

    func edit(_ profile: GitHubAccountProfile) {
        errorMessage = nil
        editingProfile = profile
    }

    func removeAccount(_ profile: GitHubAccountProfile, isSettingsEnabled: Bool) {
        guard isSettingsEnabled, accounts.storageError == nil else {
            errorMessage = accounts.storageError ?? "Stop the virtual machines before changing accounts."
            return
        }
        do {
            try accounts.remove(profile)
            if editingProfile?.id == profile.id {
                editingProfile = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
