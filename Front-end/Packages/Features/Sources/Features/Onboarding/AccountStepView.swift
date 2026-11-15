import Account
import SwiftUI

/// Optional account: social providers (only those enabled on the server), email + password,
/// password reset, and "Continue without account". Reused later from Settings.
struct AccountStepView: View {
    let auth: any AuthService
    /// Secondary button title: "Continue without account" in onboarding, "Not now" in Settings.
    var skipTitle = "Continue without account"
    let onSkip: () -> Void

    enum Mode { case signUp, signIn }

    @State private var mode: Mode = .signUp
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var isError = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !busy
    }

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 20) {
                Text(mode == .signUp ? "Create your account" : "Welcome back")
                    .font(.largeTitle.bold())
                Text("Optional — keeps your progress safe and unlocks buddy features later.")
                    .foregroundStyle(.secondary)

                if !auth.availableProviders.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(auth.availableProviders) { provider in
                            Button {
                                run { try await auth.signIn(with: provider) }
                            } label: {
                                Label("Continue with \(provider.displayName)", systemImage: provider.symbolName)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(.primary)
                        }
                    }
                    if auth.config.emailPassword {
                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                            Text("or").font(.footnote).foregroundStyle(.secondary)
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        }
                    }
                }

                if auth.config.emailPassword {
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                        SecureField("Password (min. 6 characters)", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .focused($focused, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if canSubmit { submit() } }
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                    }

                    HStack {
                        Button(mode == .signUp ? "I already have an account" : "Create a new account") {
                            mode = mode == .signUp ? .signIn : .signUp
                            message = nil
                        }
                        Spacer()
                        if mode == .signIn {
                            Button("Forgot password?") {
                                run(success: "Check your inbox for a reset link.") {
                                    try await auth.resetPassword(email: email)
                                }
                            }
                            .disabled(!email.contains("@"))
                        }
                    }
                    .font(.subheadline)
                }

                if let message {
                    Label(message, systemImage: isError ? "exclamationmark.circle.fill" : "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(isError ? .red : .secondary)
                }
                if busy { ProgressView().frame(maxWidth: .infinity) }
            }
        } footer: {
            if auth.config.emailPassword {
                PrimaryButton(title: mode == .signUp ? "Create account" : "Sign in",
                              disabled: !canSubmit, action: submit)
            }
            LegalConsentLine(prefix: "By creating an account you accept the")
            Button(skipTitle, action: onSkip)
                .foregroundStyle(.secondary)
        }
    }

    private func submit() {
        focused = nil
        switch mode {
        case .signUp:
            run { try await auth.signUp(email: email, password: password) }
        case .signIn:
            run { try await auth.signIn(email: email, password: password) }
        }
    }

    /// Success moves on automatically (the onboarding view watches `auth.user`).
    private func run(success: String? = nil, _ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        message = nil
        Task {
            do {
                try await action()
                if let success {
                    message = success
                    isError = false
                }
            } catch AuthError.confirmEmail {
                message = AuthError.confirmEmail.errorDescription
                isError = false
                mode = .signIn
            } catch {
                message = error.localizedDescription
                isError = true
            }
            busy = false
        }
    }
}
