import GitHubDomain
import VirtualMachineDomain

public enum ConfigurationState {
    case ready
    case missingGitHubAccounts
    case invalidGitHubAccounts
    case missingVirtualMachine
    case missingSSHCredentials
    case missingGitHubAppId
    case missingGitHubPrivateKey
    case missingGitHubOrganizationName
    case missingGitHubOwnerName
    case missingGitHubRepositoryName

    public init(
        settingsStore: some SettingsStore,
        virtualMachineSSHCredentialsStore: VirtualMachineSSHCredentialsStore,
        accounts: GitHubAccountStore
    ) {
        if case .unknown = settingsStore.virtualMachine {
            self = .missingVirtualMachine
        } else if (virtualMachineSSHCredentialsStore.username ?? "").isEmpty {
            self = .missingSSHCredentials
        } else if (virtualMachineSSHCredentialsStore.password ?? "").isEmpty {
            self = .missingSSHCredentials
        } else if accounts.storageError != nil {
            self = .invalidGitHubAccounts
        } else if !accounts.profiles.contains(where: { $0.isEnabled }) {
            self = .missingGitHubAccounts
        } else if accounts.profiles.filter({ $0.isEnabled }).contains(where: { profile in
            profile.validationMessage != nil || (accounts.credentials(for: profile).appId ?? "").isEmpty
                || accounts.credentials(for: profile).privateKey == nil
        }) {
            self = .invalidGitHubAccounts
        } else {
            self = .ready
        }
    }
}

public extension ConfigurationState {
    var shortInstruction: String {
        switch self {
        case .missingGitHubAccounts:
            "Add and enable a GitHub account in Settings."
        case .invalidGitHubAccounts:
            "Check the GitHub accounts and credentials in Settings."
        case .ready:
            L10n.Settings.ConfigurationState.Ready.shortInstruction
        case .missingVirtualMachine:
            L10n.Settings.ConfigurationState.MissingVirtualMachine.shortInstruction
        case .missingSSHCredentials:
            L10n.Settings.ConfigurationState.MissingSshCredentials.shortInstruction
        case .missingGitHubAppId:
            L10n.Settings.ConfigurationState.MissingGithubAppId.shortInstruction
        case .missingGitHubPrivateKey:
            L10n.Settings.ConfigurationState.MissingGithubPrivateKey.shortInstruction
        case .missingGitHubOrganizationName:
            L10n.Settings.ConfigurationState.MissingGithubOrganizationName.shortInstruction
        case .missingGitHubOwnerName:
            L10n.Settings.ConfigurationState.MissingGithubOwnerName.shortInstruction
        case .missingGitHubRepositoryName:
            L10n.Settings.ConfigurationState.MissingGithubRepositoryName.shortInstruction
        }
    }
}
