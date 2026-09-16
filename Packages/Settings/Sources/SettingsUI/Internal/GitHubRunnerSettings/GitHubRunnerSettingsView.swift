import Observation
import SettingsDomain
import SwiftUI

struct GitHubRunnerSettingsView<SettingsStoreType: SettingsStore & Observable>: View {
    @Bindable var settingsStore: SettingsStoreType
    let isSettingsEnabled: Bool

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settingsStore.gitHubRunnerDisableDefaultLabels) {
                    Text(L10n.Settings.GithubRunner.disableDefaultLabels)
                }
                .disabled(!isSettingsEnabled)

                TextField(
                    L10n.Settings.GithubRunner.labels,
                    text: $settingsStore.gitHubRunnerLabels,
                    prompt: Text(L10n.Settings.GithubRunner.Labels.prompt)
                )
                .disabled(!isSettingsEnabled)
            } footer: {
                Text("""
                These labels apply to all accounts. Only queued jobs whose labels match this runner can start a VM. \
                Runner names are generated automatically.
                """)
            }
            Section {
                Toggle(isOn: $settingsStore.gitHubRunnerDisableUpdates) {
                    Text(L10n.Settings.GithubRunner.disableUpdates)
                    Text(L10n.Settings.GithubRunner.DisableUpdates.subtitle)
                }
                .disabled(!isSettingsEnabled)
            }
        }
        .formStyle(.grouped)
    }

}
