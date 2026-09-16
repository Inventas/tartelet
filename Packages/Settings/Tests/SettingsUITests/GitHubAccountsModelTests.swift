import GitHubDomain
@testable import SettingsUI
import XCTest

final class GitHubAccountsModelTests: XCTestCase {
    func testRemovingTheOpenAccountClosesItsModalAndPreservesOtherAccounts() {
        let organization = GitHubAccountProfile(login: "example-org")
        let personal = GitHubAccountProfile(login: "octocat", scope: .repo)
        let store = TestAccountStore(profiles: [organization, personal])
        let model = GitHubAccountsModel(accounts: store)
        model.edit(organization)

        model.removeAccount(organization, isSettingsEnabled: true)

        XCTAssertEqual(store.profiles, [personal])
        XCTAssertNil(model.editingProfile)
        XCTAssertNil(model.errorMessage)
    }

    func testFailedRemovalKeepsTheModalOpenAndReportsTheError() {
        let profile = GitHubAccountProfile(login: "example-org")
        let store = TestAccountStore(profiles: [profile])
        store.removalError = NSError(
            domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keychain is locked."])
        let model = GitHubAccountsModel(accounts: store)
        model.edit(profile)

        model.removeAccount(profile, isSettingsEnabled: true)

        XCTAssertEqual(store.profiles, [profile])
        XCTAssertEqual(model.editingProfile, profile)
        XCTAssertEqual(model.errorMessage, "Keychain is locked.")
    }

    func testStartingTheFleetWhileConfirmationIsOpenBlocksRemoval() {
        let profile = GitHubAccountProfile(login: "example-org")
        let store = TestAccountStore(profiles: [profile])
        let model = GitHubAccountsModel(accounts: store)
        model.edit(profile)

        model.removeAccount(profile, isSettingsEnabled: false)

        XCTAssertEqual(store.removalCount, 0)
        XCTAssertEqual(store.profiles, [profile])
        XCTAssertEqual(model.editingProfile, profile)
        XCTAssertNotNil(model.errorMessage)
    }

    func testStorageFailureBlocksRemoval() {
        let profile = GitHubAccountProfile(login: "example-org")
        let store = TestAccountStore(profiles: [profile])
        store.storageError = "Account settings could not be read."
        let model = GitHubAccountsModel(accounts: store)
        model.edit(profile)

        model.removeAccount(profile, isSettingsEnabled: true)

        XCTAssertEqual(store.removalCount, 0)
        XCTAssertEqual(model.editingProfile, profile)
        XCTAssertEqual(model.errorMessage, store.storageError)
    }

    func testOpeningAnAccountClearsThePreviousRemovalError() {
        let organization = GitHubAccountProfile(login: "example-org")
        let personal = GitHubAccountProfile(login: "octocat", scope: .repo)
        let store = TestAccountStore(profiles: [organization, personal])
        let model = GitHubAccountsModel(accounts: store)
        model.edit(organization)
        model.removeAccount(organization, isSettingsEnabled: false)

        model.edit(personal)

        XCTAssertEqual(model.editingProfile, personal)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(store.profiles, [organization, personal])
    }
}
