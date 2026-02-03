import SwiftUI

/// A reusable view for displaying Google Sign-In status and controls
struct GoogleSignInView: View {
    @ObservedObject var authService = GoogleAuthService.shared
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 12) {
            if authService.isSignedIn, let user = authService.currentUser {
                signedInView(user: user)
            } else {
                signedOutView
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authService.error ?? "An unknown error occurred")
        }
        .onChange(of: authService.error) { _, newValue in
            showingError = newValue != nil
        }
    }

    // MARK: - Signed In View

    private func signedInView(user: GoogleUser) -> some View {
        HStack(spacing: 12) {
            // User avatar placeholder
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)

                Text(user.name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Sign Out") {
                authService.signOut()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Signed Out View

    private var signedOutView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cloud")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Sign in to save transcripts to Google Drive")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GoogleSignInButton {
                Task {
                    do {
                        try await authService.signIn()
                    } catch {
                        await MainActor.run {
                            authService.error = error.localizedDescription
                        }
                    }
                }
            }
            .disabled(authService.isLoading)

            if authService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
}

/// A styled button that looks like the official Google Sign-In button
struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Google "G" logo approximation
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)

                    Text("G")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                }

                Text("Sign in with Google")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .foregroundColor(.primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// Compact version of GoogleSignInView for use in settings rows
struct GoogleSignInCompactView: View {
    @ObservedObject var authService = GoogleAuthService.shared

    var body: some View {
        if authService.isSignedIn, let user = authService.currentUser {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.subheadline)

                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        } else {
            HStack {
                Text("Not signed in")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Sign In") {
                    Task {
                        try? await authService.signIn()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

#Preview("Signed Out") {
    GoogleSignInView()
        .padding()
}

#Preview("Button") {
    GoogleSignInButton {
        print("Sign in tapped")
    }
    .padding()
}
