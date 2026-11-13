import Account
import Foundation
import Testing

@Suite struct AuthConfigTests {
    @Test func bundledConfigLoads() {
        let config = AuthConfig.load()
        #expect(config.emailPassword)
        #expect(config.redirectURL.absoluteString == "earnit://auth-callback")
    }

    @Test func unknownProvidersAreIgnored() throws {
        let json = #"{"emailPassword":true,"providers":["google","myspace","apple"],"redirectURL":"earnit://auth-callback","termsURL":"https://e.com/t","privacyURL":"https://e.com/p"}"#
        let config = try JSONDecoder().decode(AuthConfig.self, from: Data(json.utf8))
        #expect(config.providers == [.google, .apple])
    }

    @Test func secretKeysAreNeverAccepted() {
        #expect(AuthServiceFactory.isUsableClientKey("sb_publishable_abc"))
        #expect(!AuthServiceFactory.isUsableClientKey("sb_secret_abc"))
        #expect(!AuthServiceFactory.isUsableClientKey(""))
    }
}

@Suite @MainActor struct FakeAuthTests {
    @Test func signInOutAndDelete() async throws {
        let auth = FakeAuthService()
        try await auth.signIn(email: "a@b.c", password: "pw")
        #expect(auth.user?.email == "a@b.c")
        await auth.updateProfile(ProfileUpdate(displayName: "Joren"))
        #expect(auth.profile?.displayName == "Joren")
        try await auth.deleteAccount()
        #expect(auth.user == nil && auth.profile == nil)
    }

    @Test func errorsSurface() async {
        let auth = FakeAuthService()
        auth.failNext = .confirmEmail
        await #expect(throws: AuthError.confirmEmail) { try await auth.signUp(email: "x@y.z", password: "pw") }
        #expect(auth.user == nil)
    }
}
