import GitHubDomain
import LoggingDomain
import Observation
import SettingsDomain
import SwiftUI
import VirtualMachineDomain

struct SettingsView<SettingsStoreType: SettingsStore & Observable>: View {
    let settingsStore: SettingsStoreType
    let accounts: GitHubAccountStore
    let virtualMachineSSHCredentialsStore: VirtualMachineSSHCredentialsStore
    let virtualMachinesSourceNameRepository: VirtualMachineSourceNameRepository
    let logExporter: LogExporter
    let isSettingsEnabled: Bool
    let schedulerStatus: String
    let schedulerError: String?

    var body: some View {
        TabView {
            GeneralSettingsView(
                settingsStore: settingsStore,
                logExporter: logExporter
            )
            .tabItem {
                Label(L10n.Settings.general, systemImage: "gear")
            }
            VirtualMachineSettingsView(
                settingsStore: settingsStore,
                credentialsStore: virtualMachineSSHCredentialsStore,
                virtualMachinesSourceNameRepository: virtualMachinesSourceNameRepository,
                isSettingsEnabled: isSettingsEnabled
            )
            .tabItem {
                Label(L10n.Settings.virtualMachine, systemImage: "desktopcomputer")
            }
            GitHubAccountsView(
                accounts: accounts,
                isSettingsEnabled: isSettingsEnabled,
                schedulerStatus: schedulerStatus,
                schedulerError: schedulerError
            )
            .tabItem {
                Label {
                    Text(L10n.Settings.github)
                } icon: {
                    Image(nsImage: Asset.github.image)
                }
            }
            GitHubRunnerSettingsView(
                settingsStore: settingsStore,
                isSettingsEnabled: isSettingsEnabled
            )
            .tabItem {
                Label {
                    Text(L10n.Settings.githubRunner)
                } icon: {
                    Image(nsImage: Asset.githubActions.image)
                }
            }
            DocumentationSettingsView()
                .tabItem {
                    Label(L10n.Settings.documentation, systemImage: "text.book.closed")
                }
        }
        .frame(minWidth: 560, maxWidth: 760, minHeight: 420, maxHeight: 650)
    }
}
