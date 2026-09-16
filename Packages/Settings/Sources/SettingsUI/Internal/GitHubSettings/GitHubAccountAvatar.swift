import GitHubDomain
import SwiftUI

struct GitHubAccountAvatar: View {
    let profile: GitHubAccountProfile

    var body: some View {
        Text(String(profile.login.prefix(2)).uppercased())
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(.gray.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    GitHubAccountAvatar(profile: GitHubAccountProfile(login: "inventas"))
        .padding()
}
#endif
