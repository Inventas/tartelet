import GitHubDomain
import SwiftUI

struct GitHubAccountRow: View {
    let profile: GitHubAccountProfile

    var body: some View {
        HStack(spacing: 12) {
            GitHubAccountAvatar(profile: profile)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.login)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(profile.scope == .organization ? "Organization" : "Personal account")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Text(profile.isEnabled ? "Enabled" : "Disabled")
                .font(.callout)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    GitHubAccountRow(profile: GitHubAccountProfile(login: "inventas"))
        .frame(width: 560)
}
#endif
