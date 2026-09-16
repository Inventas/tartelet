import FileSystemData
import GitHubData
import GitHubDomain
import Keychain
import LoggingData
import LoggingDomain
import NetworkingData
import Observation
import SettingsData
import SettingsDomain
import ShellData
import SSHData
import VirtualMachineData
import VirtualMachineDomain

@MainActor
enum Composers {
    static let settingsStore = AppStorageSettingsStore()

    static var configurationState: ConfigurationState {
        ConfigurationState(settingsStore: settingsStore,
                           virtualMachineSSHCredentialsStore: virtualMachineSSHCredentialsStore, accounts: accounts)
    }

    static let accounts: KeychainGitHubAccountStore = {
        let store = KeychainGitHubAccountStore { id in
            KeychainGitHubCredentialsStore(
                keychain: keychain(logger: logger(subsystem: "GitHubAccounts")),
                serviceName: "Tartelet GitHub Account \(id.uuidString)",
                privateKeyTag: "github.accounts.\(id.uuidString).privateKey"
            )
        }
        store.migrateLegacyAccount(
            credentials: gitHubCredentialsStore, scope: settingsStore.githubRunnerScope,
            privateKeyName: settingsStore.gitHubPrivateKeyName, runnerGroup: settingsStore.gitHubRunnerGroup
        )
        return store
    }()

    static let networking = URLSessionNetworkingService(logger: logger(subsystem: "GitHub"))

    static let fleet = VirtualMachineFleet(
        logger: logger(subsystem: "VirtualMachineFleet"),
        queue: NetworkingGitHubJobQueue(
            accounts: accounts, networking: networking,
            runnerLabels: { settingsStore.gitHubRunnerLabels },
            defaultLabels: { !settingsStore.gitHubRunnerDisableDefaultLabels }
        ),
        makeVirtualMachine: makeVirtualMachine
    )

    private static func makeVirtualMachine(for job: GitHubQueuedJob) throws -> VirtualMachineDomain.VirtualMachine {
        let credentials = SnapshotGitHubCredentials(
            profile: job.profile, repository: job.repository, credentials: accounts.credentials(for: job.profile)
        )
        let client = NetworkingGitHubClient(credentialsStore: credentials, networkingService: networking)
        let machine = SSHConnectingVirtualMachine(
            logger: logger(subsystem: "SSHConnectingVirtualMachine"),
            virtualMachine: SettingsVirtualMachine(
                tart: Tart(homeProvider: SettingsTartHomeProvider(settingsStore: settingsStore),
                           shell: ProcessShell(), cacheNamespace: job.profile.id.uuidString),
                settingsStore: settingsStore
            ),
            sshClient: VirtualMachineSSHClient(
                logger: logger(subsystem: "VirtualMachineSSHClient"),
                client: CitadelSSHClient(logger: logger(subsystem: "CitadelSSHClient")),
                ipAddressReader: RetryingVirtualMachineIPAddressReader(),
                credentialsStore: virtualMachineSSHCredentialsStore,
                connectionHandler: CompositeVirtualMachineSSHConnectionHandler([
                    PostBootScriptSSHConnectionHandler(),
                    GitHubActionsRunnerSSHConnectionHandler(
                        logger: logger(subsystem: "GitHubActionsRunner"), client: client,
                        credentialsStore: credentials,
                        configuration: SettingsGitHubActionsRunnerConfiguration(
                            settingsStore: settingsStore, profile: job.profile
                        )
                    )
                ])
            )
        )
        return RegisteredRunnerVirtualMachine(machine: machine, client: client, scope: job.profile.scope)
    }

    static let editor = VirtualMachineEditor(
        logger: logger(subsystem: "VirtualMachineEditor"),
        virtualMachine: SettingsVirtualMachine(
            tart: Tart(
                homeProvider: SettingsTartHomeProvider(
                    settingsStore: settingsStore
                ),
                shell: ProcessShell()
            ),
            settingsStore: settingsStore
        )
    )

    static let gitHubCredentialsStore = KeychainGitHubCredentialsStore(
        keychain: keychain(
            logger: logger(subsystem: "GitHubCredentialsStore")
        ),
        serviceName: "Tartelet GitHub Account"
    )

    static let virtualMachineSSHCredentialsStore = KeychainVirtualMachineSSHCredentialsStore(
        keychain: keychain(
            logger: logger(subsystem: "KeychainVirtualMachineSSHCredentialsStore")
        ),
        serviceName: "Tartelet Virtual Machine SSH Credentials"
    )

    static func logger(subsystem: String) -> Logger {
        FileLogger(
            fileSystem: DiskFileSystem(),
            dateProvider: FoundationDateProvider(),
            subsystem: subsystem,
            daysOfRetention: 7
        )
    }
}

private extension Composers {
    private static func keychain(logger: Logger) -> Keychain {
        Keychain(logger: logger)
    }
}
