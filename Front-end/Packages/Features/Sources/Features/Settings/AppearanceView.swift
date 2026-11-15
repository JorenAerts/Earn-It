import Coach
import SwiftUI
import Telemetry
import WidgetShared

/// Settings › Appearance: Light / Dark / Match iPhone, app icon, Gloop's colour.
struct AppearanceView: View {
    @State private var settings = AppearanceSettings.shared
    @State private var iconError: String?
    @State private var changing = false

    var body: some View {
        List {
            Section("Mode") {
                HStack(spacing: 12) {
                    ForEach(AppearancePreference.allCases) { option in
                        ModeTile(option: option, selected: settings.preference == option) {
                            withAnimation(.snappy) { settings.preference = option }
                            Telemetry.shared.send(.action(.appearanceChanged(mode: option.rawValue)))
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 14)], spacing: 16) {
                    ForEach(AppIconChoice.allCases) { choice in
                        IconTile(choice: choice, selected: settings.icon == choice) { setIcon(choice) }
                            .disabled(changing)
                    }
                }
                .padding(.vertical, 6)
                if let iconError {
                    Text(iconError).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("App icon")
            } footer: {
                Text("iOS confirms the change with a short message.")
            }

            Section {
                Toggle("Match \(CoachIdentity.name) to my icon", isOn: $settings.matchSlimeToIcon)
                if !settings.matchSlimeToIcon {
                    HStack(spacing: 10) {
                        ForEach(SlimeColor.allCases) { color in
                            Button {
                                settings.customSlimeColor = color
                            } label: {
                                SlimeView(look: SlimeLook.make(vitality: 0.9, state: CoachState(mood: .calm, context: .idle)),
                                          color: color, size: 48, animated: false)
                                    .padding(4)
                                    .background(settings.customSlimeColor == color ? Color.orange.opacity(0.18) : .clear,
                                                in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.title)
                            .accessibilityAddTraits(settings.customSlimeColor == color ? .isSelected : [])
                        }
                    }
                }
                HStack {
                    Spacer()
                    CoachAvatarView(state: CoachState(mood: .calm, context: .idle), size: 110)
                    Spacer()
                }
            } header: {
                Text(CoachIdentity.name)
            }
        }
        .navigationTitle("Appearance")
        .trackScreen("Settings.Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setIcon(_ choice: AppIconChoice) {
        guard choice != settings.icon else { return }
        changing = true
        Task {
            iconError = await settings.setIcon(choice)
            if iconError == nil { Telemetry.shared.send(.action(.iconChanged(icon: choice.rawValue))) }
            changing = false
        }
    }
}

/// A tiny phone mock in light / dark / split.
private struct ModeTile: View {
    let option: AppearancePreference
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    switch option {
                    case .light: mock(.white, .black.opacity(0.12))
                    case .dark: mock(Color(white: 0.12), .white.opacity(0.2))
                    case .system:
                        HStack(spacing: 0) {
                            mock(.white, .black.opacity(0.12))
                            mock(Color(white: 0.12), .white.opacity(0.2))
                        }
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.orange : Color.secondary.opacity(0.3),
                                                                         lineWidth: selected ? 3 : 1))
                Text(option.title).font(.caption.weight(.semibold))
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func mock(_ background: Color, _ bars: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Circle().fill(Color.orange).frame(width: 14, height: 14)
            RoundedRectangle(cornerRadius: 2).fill(bars).frame(height: 6)
            RoundedRectangle(cornerRadius: 2).fill(bars).frame(width: 30, height: 6)
            RoundedRectangle(cornerRadius: 2).fill(bars).frame(height: 6)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
    }
}

private struct IconTile: View {
    let choice: AppIconChoice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(choice.previewImageName)
                    .resizable().scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(.rect(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(selected ? Color.orange : Color.secondary.opacity(0.25), lineWidth: selected ? 3 : 1))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                Text(choice.title).font(.caption)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.title) icon")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Progress tab: how Gloop is doing (vitality) with an explanation.
struct SlimeHealthCard: View {
    @State private var coach = CoachModel.shared

    var body: some View {
        HStack(spacing: 16) {
            CoachAvatarView(state: CoachState(mood: .calm, context: .idle), size: 86)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(CoachIdentity.name)'s health").font(.headline)
                    Spacer()
                    Text("\(Int((coach.vitality * 100).rounded()))%").font(.headline.monospacedDigit())
                        .foregroundStyle(.orange)
                }
                ProgressView(value: coach.vitality).tint(.orange)
                Text(SlimeVitality.summary(coach.vitality)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
