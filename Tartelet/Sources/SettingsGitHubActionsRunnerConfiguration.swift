import GitHubDomain
import SettingsDomain
import VirtualMachineDomain

struct SettingsGitHubActionsRunnerConfiguration<
    SettingsStoreType: SettingsStore
>: GitHubActionsRunnerConfiguration {
    let settingsStore: SettingsStoreType
    let profile: GitHubAccountProfile
    var runnerDisableDefaultLabels: Bool {
        settingsStore.gitHubRunnerDisableDefaultLabels
    }
    var runnerDisableUpdates: Bool {
        settingsStore.gitHubRunnerDisableUpdates
    }
    var runnerScope: GitHubRunnerScope {
        profile.scope
    }
    var runnerLabels: String {
        settingsStore.gitHubRunnerLabels
    }
    var runnerGroup: String {
        profile.scope == .organization ? profile.runnerGroup : ""
    }
    var runnerName: String {
        ""
    }
}
