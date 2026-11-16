import Foundation
import Observation
import os
import TelemetryDeck

private let log = Logger(subsystem: "be.gloop.app", category: "telemetry")

/// Where signals go.
@MainActor
public protocol TelemetrySink: AnyObject {
    func start(appID: String, namespace: String?, userID: String, testMode: Bool)
    func stop()
    func send(name: String, parameters: [String: String])
}

/// TelemetryDeck (live).
@MainActor
public final class TelemetryDeckSink: TelemetrySink {
    public init() {}

    public func start(appID: String, namespace: String?, userID: String, testMode: Bool) {
        let config = TelemetryDeck.Config(appID: appID, namespace: namespace)
        config.defaultUser = userID
        config.testMode = testMode
        TelemetryDeck.initialize(config: config)
    }

    public func stop() { TelemetryDeck.terminate() }

    public func send(name: String, parameters: [String: String]) {
        TelemetryDeck.signal(name, parameters: parameters)
    }
}

/// Drops everything (no App ID configured).
@MainActor
public final class NoopSink: TelemetrySink {
    public init() {}
    public func start(appID: String, namespace: String?, userID: String, testMode: Bool) {}
    public func stop() {}
    public func send(name: String, parameters: [String: String]) {}
}

/// Keeps signals in memory (tests).
@MainActor
public final class RecordingSink: TelemetrySink {
    public private(set) var signals: [(name: String, parameters: [String: String])] = []
    public private(set) var started = false
    public init() {}
    public func start(appID: String, namespace: String?, userID: String, testMode: Bool) { started = true }
    public func stop() { started = false }
    public func send(name: String, parameters: [String: String]) { signals.append((name, parameters)) }
    public var names: [String] { signals.map(\.name) }
}

/// Anonymous usage statistics. On by default; users can switch it off in Settings › Privacy.
/// Each signal carries a few common, non-personal parameters (app version, days since install, tier).
@MainActor
@Observable
public final class Telemetry {
    public static let shared = Telemetry()

    public private(set) var isEnabled: Bool
    public private(set) var isConfigured = false
    /// Screen the user is on (for "where do people leave the app").
    public private(set) var currentScreen = "Launch"

    /// Extra common parameters supplied by the app (tier, onboarding done). Must stay non-personal.
    @ObservationIgnored public var commonParameters: @MainActor () -> [String: String] = { [:] }

    @ObservationIgnored private var sink: any TelemetrySink = NoopSink()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var screenSince: Date
    @ObservationIgnored private var sessionStart: Date
    @ObservationIgnored private var appID = ""
    @ObservationIgnored private var namespace: String?

    static let enabledKey = "gloop.telemetry.enabled"
    static let idKey = "gloop.telemetry.id"
    static let installKey = "gloop.telemetry.installDate"

    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        screenSince = now()
        sessionStart = now()
        if defaults.object(forKey: Self.installKey) == nil { defaults.set(now(), forKey: Self.installKey) }
    }

    /// Starts sending. An empty App ID (no `Shared/Config/Telemetry.json` value) keeps telemetry off.
    public func configure(appID: String?, namespace: String? = nil, sink: (any TelemetrySink)? = nil, testMode: Bool) {
        let id = (appID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.appID = id
        let ns = (namespace ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.namespace = ns.isEmpty ? nil : ns
        guard !id.isEmpty else {
            self.sink = NoopSink()
            isConfigured = false
            log.notice("telemetry off: no App ID")
            return
        }
        self.sink = sink ?? TelemetryDeckSink()
        isConfigured = true
        if isEnabled { self.sink.start(appID: id, namespace: self.namespace, userID: installationID, testMode: testMode) }
    }

    /// `Telemetry.json` in the bundle: `{"appID": "…", "namespace": "…"}`.
    public static func bundledConfig(_ bundle: Bundle = .main) -> (appID: String?, namespace: String?) {
        struct File: Decodable { let appID: String?; let namespace: String? }
        guard let url = bundle.url(forResource: "Telemetry", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return (nil, nil) }
        return (file.appID, file.namespace)
    }

    // MARK: Opt-out

    /// Off: nothing is sent anymore and the installation ID is forgotten (a new one is made if
    /// the user turns stats back on, so old and new data can't be linked).
    public func setEnabled(_ on: Bool, testMode: Bool = false) {
        guard on != isEnabled else { return }
        isEnabled = on
        defaults.set(on, forKey: Self.enabledKey)
        if on {
            if isConfigured { sink.start(appID: appID, namespace: namespace, userID: installationID, testMode: testMode) }
        } else {
            sink.stop()
            defaults.removeObject(forKey: Self.idKey)
        }
    }

    /// Random, per-install, never linked to an account.
    public var installationID: String {
        if let id = defaults.string(forKey: Self.idKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.idKey)
        return id
    }

    public var daysSinceInstall: Int {
        guard let install = defaults.object(forKey: Self.installKey) as? Date else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: install, to: now()).day ?? 0)
    }

    // MARK: Sending

    public func send(_ event: TelemetryEvent) {
        guard isEnabled, isConfigured else { return }
        var parameters = commonParameters()
        parameters["daysSinceInstall"] = TelemetryBuckets.days(daysSinceInstall)
        parameters.merge(event.parameters) { _, new in new }
        sink.send(name: event.name, parameters: Self.sanitized(parameters))
    }

    /// Last line of defence: short values only, nothing that looks like an email or an ID.
    static func sanitized(_ parameters: [String: String]) -> [String: String] {
        parameters.compactMapValues { value in
            if value.contains("@") || UUID(uuidString: value) != nil { return nil }
            return String(value.prefix(64))
        }
    }

    // MARK: Screens & sessions

    public func screen(_ name: String) {
        guard name != currentScreen else { return }
        currentScreen = name
        screenSince = now()
        send(.screenViewed(screen: name))
    }

    public func sessionStarted(source: LaunchSource? = nil) {
        sessionStart = now()
        screenSince = now()
        if let source { send(.appLaunched(source: source)) } else { send(.appForegrounded) }
    }

    /// App left the foreground: where the user was and how long they stayed.
    public func sessionEnded() {
        let t = now()
        send(.appBackgrounded(screen: currentScreen,
                              secondsOnScreen: Int(t.timeIntervalSince(screenSince)),
                              sessionSeconds: Int(t.timeIntervalSince(sessionStart))))
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Marks the screen the user is looking at (Screen.viewed + last screen before leaving).
    public func trackScreen(_ name: String) -> some View {
        onAppear { Telemetry.shared.screen(name) }
    }
}
#endif
