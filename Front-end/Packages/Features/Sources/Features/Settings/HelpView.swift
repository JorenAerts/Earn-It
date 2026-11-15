import Account
import Localization
import StoreKit
import SwiftUI
import Telemetry
import UIKit

/// Settings › Help & feedback: FAQ, contact, rate, share, what's new.
struct HelpView: View {
    let auth: any AuthService
    @State private var content = HelpContent.load()
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    static let shareMessage = L10n.tr("I'm using Gloop: an alarm that keeps ringing until I've actually got up. Try it!")

    var body: some View {
        List {
            Section("Frequently asked") {
                ForEach(content.faq) { item in
                    DisclosureGroup {
                        Text(item.answer)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 4)
                            .onAppear {
                                Telemetry.shared.send(.action(.faqOpened(index: content.faq.firstIndex(of: item) ?? -1)))
                            }
                    } label: {
                        Text(item.question).font(.body.weight(.medium))
                    }
                }
            }

            Section {
                if let mail = supportMail {
                    Button { openURL(mail) } label: {
                        Label("Contact support", systemImage: "envelope.fill")
                    }
                }
                Button { requestReview(); Telemetry.shared.send(.action(.rateRequested)) } label: {
                    Label("Rate Gloop", systemImage: "star.fill")
                }
                if let url = auth.config.shareURL {
                    ShareLink(item: url, message: Text(Self.shareMessage)) {
                        Label("Share Gloop", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Feedback")
            } footer: {
                if supportMail != nil {
                    Text("Your app version and iPhone model are added to the email so we can help faster.")
                }
            }

            if !content.releases.isEmpty {
                Section("What's new") {
                    ForEach(content.releases) { release in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Version \(release.version)").font(.headline)
                            ForEach(release.items, id: \.self) { item in
                                Label(item, systemImage: "sparkle")
                                    .font(.subheadline)
                                    .labelStyle(BulletLabelStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Help & feedback")
        .onAppear { Telemetry.shared.send(.action(.helpOpened)) }
        .trackScreen("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var supportMail: URL? {
        guard let address = auth.config.supportEmail else { return nil }
        return HelpContent.supportMailURL(to: address, appVersion: SettingsView.version,
                                          systemVersion: UIDevice.current.systemVersion,
                                          model: Self.deviceModel)
    }

    /// "iPhone13,4" (the marketing name isn't available without a lookup table).
    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.foregroundStyle(.orange).font(.caption)
            configuration.title.foregroundStyle(.secondary)
        }
    }
}
