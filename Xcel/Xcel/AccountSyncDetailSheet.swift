import SwiftUI

// Tapping the "Signed in" row opens this instead of showing an inline text
// link for sign-out - a plain Text button next to a disabled row read as a
// caption, not something tappable.
struct AccountSyncDetailSheet: View {
    let accent: Color
    let displayName: String
    let avatarData: Data?
    let onSignOut: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(spacing: 24) {
                header

                AvatarView(data: avatarData, accent: accent, size: 88)

                VStack(spacing: 4) {
                    Text(displayName.isEmpty ? "Synced" : displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text("Signed in with Apple")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.45))
                }

                Text("Your series, games, and settings back up automatically. Signing out only stops syncing on this device - your local history stays put.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                Spacer()

                Button {
                    onSignOut()
                    dismiss()
                } label: {
                    Text("Sign out")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.eliminationRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.eliminationRed.opacity(0.4), lineWidth: 1))
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ACCOUNT")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Synced")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
