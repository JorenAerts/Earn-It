#if DEBUG
import Account
import SwiftUI

/// Temporary test UI for login until the onboarding account step (phase 4) exists.
struct AccountDebugSection: View {
    let auth: any AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        Section {
            if !auth.isAvailable {
                Text("Supabase isn't configured in this build.").foregroundStyle(.secondary)
            } else if let user = auth.user {
                LabeledContent("Signed in", value: user.email ?? "no email")
                LabeledContent("User ID", value: String(user.id.uuidString.prefix(8)))
                Button("Sign out") { run { await auth.signOut() } }
                Button("Delete account", role: .destructive) { run { try await auth.deleteAccount() } }
            } else {
                ForEach(auth.availableProviders) { provider in
                    Button {
                        run { try await auth.signIn(with: provider) }
                    } label: {
                        Label("Continue with \(provider.displayName)", systemImage: provider.symbolName)
                    }
                }
                if auth.config.emailPassword {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password (min. 6)", text: $password)
                        .textContentType(.password)
                    HStack {
                        Button("Sign in") { run { try await auth.signIn(email: email, password: password) } }
                        Spacer()
                        Button("Create account") { run { try await auth.signUp(email: email, password: password) } }
                    }
                    .buttonStyle(.borderless)
                    .disabled(email.isEmpty || password.count < 6)
                }
            }
            if busy { ProgressView() }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Account (test)")
        } footer: {
            Text("Temporary — the real login comes with onboarding. Only providers enabled in Supabase are shown.")
        }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        message = nil
        Task {
            do {
                try await action()
                message = "Done."
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }
}
#endif
