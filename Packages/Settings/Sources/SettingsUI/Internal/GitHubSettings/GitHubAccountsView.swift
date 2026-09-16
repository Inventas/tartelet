import GitHubDomain
import SwiftUI

struct GitHubAccountsView: View {
    let accounts: GitHubAccountStore
    let isSettingsEnabled: Bool
    let schedulerStatus: String
    let schedulerError: String?
    @State private var model: GitHubAccountsModel

    init(
        accounts: GitHubAccountStore, isSettingsEnabled: Bool,
        schedulerStatus: String, schedulerError: String?
    ) {
        self.accounts = accounts
        self.isSettingsEnabled = isSettingsEnabled
        self.schedulerStatus = schedulerStatus
        self.schedulerError = schedulerError
        _model = State(initialValue: GitHubAccountsModel(accounts: accounts))
    }

    var body: some View {
        overview
        .safeAreaInset(edge: .bottom, spacing: 0) {
            notices
        }
        .sheet(item: $model.editingProfile) { profile in
            GitHubAccountEditor(
                profile: profile, accounts: accounts, isSettingsEnabled: canEdit,
                removalError: model.errorMessage
            ) {
                model.removeAccount(profile, isSettingsEnabled: isSettingsEnabled)
            }
        }
    }

    private var canEdit: Bool { isSettingsEnabled && accounts.storageError == nil }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                accountList
                HStack {
                    Spacer()
                    Button("Add Account…") { model.edit(GitHubAccountProfile()) }
                        .disabled(!canEdit)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Both VM slots are shared between enabled accounts with matching queued jobs.")
                    Text(schedulerStatus)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var accountList: some View {
        VStack(spacing: 0) {
            if accounts.profiles.isEmpty {
                ContentUnavailableView(
                    "No GitHub Accounts", systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add an organization or a personal account to share the VM slots.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(accounts.profiles) { profile in
                    Button {
                        model.edit(profile)
                    } label: {
                        GitHubAccountRow(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Open account settings")
                    if profile.id != accounts.profiles.last?.id {
                        Divider().padding(.leading, 64).padding(.trailing, 16)
                    }
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var notices: some View {
        if !isSettingsEnabled || model.errorMessage != nil || accounts.storageError != nil || schedulerError != nil {
            VStack(alignment: .leading, spacing: 8) {
                if !isSettingsEnabled {
                    Label("Stop the virtual machines before changing accounts.", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }
                if let message = model.errorMessage ?? accounts.storageError ?? schedulerError {
                    ScrollView {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 90)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.bar)
        }
    }
}

#if DEBUG
#Preview("Accounts") {
    GitHubAccountsView(
        accounts: PreviewGitHubAccountStore(), isSettingsEnabled: true,
        schedulerStatus: "Waiting for matching jobs", schedulerError: nil
    )
    .frame(width: 700, height: 560)
}

#Preview("Empty") {
    GitHubAccountsView(
        accounts: PreviewGitHubAccountStore(profiles: []), isSettingsEnabled: true,
        schedulerStatus: "Stopped", schedulerError: nil
    )
    .frame(width: 700, height: 560)
}

#Preview("Running with an error") {
    GitHubAccountsView(
        accounts: PreviewGitHubAccountStore(), isSettingsEnabled: false,
        schedulerStatus: "1 of 2 VM slots in use",
        schedulerError: "example-org: GitHub could not verify the credentials."
    )
    .frame(width: 700, height: 560)
}
#endif
