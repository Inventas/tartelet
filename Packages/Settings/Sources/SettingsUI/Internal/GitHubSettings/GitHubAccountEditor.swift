import GitHubDomain
import SwiftUI
import UniformTypeIdentifiers

struct GitHubAccountEditor: View {
    let accounts: GitHubAccountStore
    let isSettingsEnabled: Bool
    let removalError: String?
    let onRemove: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var profile: GitHubAccountProfile
    @State private var appID: String
    @State private var repositoryNames: String
    @State private var privateKey: Data?
    @State private var isChoosingKey = false
    @State private var isConfirmingRemoval = false
    @State private var errorMessage: String?

    init(
        profile: GitHubAccountProfile, accounts: GitHubAccountStore, isSettingsEnabled: Bool = true,
        removalError: String? = nil, onRemove: (() -> Void)? = nil
    ) {
        self.accounts = accounts
        self.isSettingsEnabled = isSettingsEnabled
        self.removalError = removalError
        self.onRemove = onRemove
        _profile = State(initialValue: profile)
        _appID = State(initialValue: accounts.credentials(for: profile).appId ?? "")
        _repositoryNames = State(initialValue: profile.repositories.joined(separator: ", "))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isExistingAccount ? "Account Settings" : "Add Account")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)
            Form {
                Section("Account") {
                    Picker("Account type", selection: $profile.scope) {
                        Text("Organization").tag(GitHubRunnerScope.organization)
                        Text("Personal account").tag(GitHubRunnerScope.repo)
                    }
                    TextField("Account name", text: $profile.login, prompt: Text("octocat"))
                    TextField(
                        "Repositories", text: $repositoryNames, prompt: Text("All repositories available to the app"))
                    Text(
                        """
                        Optional: enter repository names separated by commas. \
                        Personal accounts use a separate runner registration for each repository.
                        """
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Toggle("Enabled", isOn: $profile.isEnabled)
                    if profile.scope == .organization {
                        TextField("Runner group", text: $profile.runnerGroup, prompt: Text("Default"))
                    }
                }
                Section("GitHub App") {
                    TextField("App ID", text: $appID)
                    LabeledContent("Private key") {
                        Text(profile.privateKeyName.isEmpty ? "No key selected" : profile.privateKeyName)
                            .lineLimit(1).truncationMode(.middle)
                        Button("Choose file…") { isChoosingKey = true }
                    }
                    Text(permissions)
                        .font(.caption).foregroundStyle(.secondary)
                    Link("GitHub App settings", destination: appSettingsURL)
                }
                if let errorMessage = errorMessage ?? removalError {
                    Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            .formStyle(.grouped)
            .disabled(!isSettingsEnabled)
            HStack {
                if isExistingAccount && onRemove != nil {
                    Button("Remove Account…", role: .destructive) { isConfirmingRemoval = true }
                        .disabled(!isSettingsEnabled)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(!isSettingsEnabled)
            }
            .padding()
        }
        .frame(width: 590, height: 590)
        .alert("Remove \(savedAccountName)?", isPresented: $isConfirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                errorMessage = nil
                onRemove?()
            }
        } message: {
            Text("Its saved credentials will be removed. Its base VM and cache files will remain.")
        }
        .fileImporter(isPresented: $isChoosingKey, allowedContentTypes: [.item]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                privateKey = try Data(contentsOf: url)
                profile.privateKeyName = url.lastPathComponent
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var isExistingAccount: Bool { accounts.profiles.contains { $0.id == profile.id } }

    private var savedAccountName: String {
        accounts.profiles.first { $0.id == profile.id }?.login ?? profile.login
    }

    private var permissions: String {
        let runnerPermission =
            profile.scope == .organization
            ? "Organization: Self-hosted runners (read and write)."
            : "Repository: Administration (read and write)."
        return "Install the app on this account and grant access to the repositories to monitor. "
            + "Required permissions: Repository Actions (read), Metadata (read). " + runnerPermission
    }

    private var appSettingsURL: URL {
        if profile.scope == .organization && profile.validationMessage == nil {
            return URL(string: "https://github.com/organizations/\(profile.login)/settings/apps")!
        }
        return URL(string: "https://github.com/settings/apps")!
    }

    private func save() {
        profile.login = profile.login.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.runnerGroup = profile.runnerGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.repositories = repositoryNames.split(separator: ",").map { name in
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        do {
            try accounts.save(
                profile, appID: appID.trimmingCharacters(in: .whitespacesAndNewlines), privateKey: privateKey)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    GitHubAccountEditor(
        profile: GitHubAccountProfile(login: "octocat", scope: .repo), accounts: PreviewGitHubAccountStore())
}
#endif
