import AlarmEngine
import Core
import MusicKit
import Purchases
import Permissions
import SwiftUI
import UniformTypeIdentifiers

/// Alarm editor › Sound: built-in sounds by category, the user's own sounds (import / record),
/// and an Apple Music song. Tap = select + preview.
struct SoundPickerView: View {
    @Binding var selection: SoundChoice
    let gate: FeatureGate
    @State private var preview = SoundPreview()
    @State private var mySounds = MySounds.shared
    @State private var importing = false
    @State private var importedURL: ImportedFile?
    @State private var recording = false
    @State private var showPaywall = false
    @State private var renaming: CustomSound?
    @State private var newName = ""
    @State private var importError: String?

    struct ImportedFile: Identifiable {
        let url: URL
        let name: String
        var id: URL { url }
    }

    var body: some View {
        List {
            ForEach(AlarmSound.Category.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(AlarmSound.allCases.filter { $0.category == category }) { sound in
                        row(.builtIn(sound), title: sound.displayName, subtitle: sound.credit, locked: gate.isLocked(sound))
                    }
                }
            }

            Section {
                ForEach(mySounds.sounds) { sound in
                    row(sound.choice, title: sound.name,
                        subtitle: "\(sound.source == .recorded ? "Recording" : "Imported") · \(Int(sound.duration.rounded())) s",
                        locked: gate.isLocked(sound.choice))
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                if selection == sound.choice { selection = .classic }
                                mySounds.delete(sound.id)
                            }
                            Button("Rename") {
                                newName = sound.name
                                renaming = sound
                            }
                            .tint(.orange)
                        }
                }
                ownSoundButton("Import a file", symbol: "square.and.arrow.down") { importing = true }
                ownSoundButton("Record your own", symbol: "mic.fill") {
                    Task { if await PermissionCenter.shared.ensure(.microphone) { recording = true } }
                }
                if let importError {
                    Text(importError).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("My sounds")
            } footer: {
                Text("Your own sounds stay on this iPhone. Only use audio you have the rights to. Up to \(CustomSoundLibrary.maxSounds) sounds.")
            }

            Section {
                if case .appleMusic(let pick) = selection {
                    HStack {
                        Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                        VStack(alignment: .leading) {
                            Text(pick.title).font(.body.weight(.semibold))
                            Text("\(pick.artist) · starts at \(Int(pick.startOffset)) s").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if gate.isLocked(SoundChoice.appleMusic(AppleMusicPick(songID: "", title: "", artist: ""))) {
                    Button { showPaywall = true } label: { HStack { Label("Choose a song", systemImage: "music.note"); Spacer(); ProBadge() } }
                } else {
                    NavigationLink {
                        AppleMusicSearchView(selection: $selection)
                    } label: {
                        Label(selection.isAppleMusic ? "Choose another song" : "Choose a song", systemImage: "music.note")
                    }
                }
            } header: {
                Text("Apple Music")
            } footer: {
                Text("Plays in the app while you do your mission (Apple Music subscription needed). The alarm itself rings with a tone you pick.")
            }
        }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
        .paywallSheet(isPresented: $showPaywall)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            importError = nil
            switch result {
            case .success(let url): importFile(url)
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .sheet(item: $importedURL) { file in
            NavigationStack {
                TrimSoundView(source: file.url, suggestedName: file.name, kind: .imported) { sound in
                    selection = sound.choice
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { importedURL = nil } } }
            }
        }
        .sheet(isPresented: $recording) {
            RecordSoundView { sound in selection = sound.choice }
        }
        .alert("Rename sound", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let sound = renaming {
                    mySounds.rename(sound.id, to: newName)
                    if selection == sound.choice || { if case .custom(let id, _) = selection { return id == sound.id } else { return false } }() {
                        selection = .custom(id: sound.id, name: newName)
                    }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func row(_ choice: SoundChoice, title: String, subtitle: String?, locked: Bool) -> some View {
        Button {
            preview.toggle(choice)
            if locked { showPaywall = true } else { selection = choice }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preview.playing == choice ? "speaker.wave.2.fill" : "play.circle")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(Color.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.secondary) }
                }
                Spacer()
                if locked { ProBadge() }
                if selection == choice {
                    Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                }
            }
        }
        .accessibilityAddTraits(selection == choice ? .isSelected : [])
    }

    private func ownSoundButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            if !gate.isPro { showPaywall = true }
            else if mySounds.isFull { importError = "You have \(CustomSoundLibrary.maxSounds) sounds. Delete one first." }
            else { action() }
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                if !gate.isPro { ProBadge() }
            }
        }
    }

    /// Copy the picked file out of its security scope, then open the trim screen.
    private func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let copy = FileManager.default.temporaryDirectory.appending(path: "import-\(UUID().uuidString).\(url.pathExtension)")
        do {
            try FileManager.default.copyItem(at: url, to: copy)
            importedURL = ImportedFile(url: copy, name: url.deletingPathExtension().lastPathComponent)
        } catch {
            importError = "Couldn't open the file: \(error.localizedDescription)"
        }
    }
}

extension SoundChoice {
    var isAppleMusic: Bool {
        if case .appleMusic = self { return true }
        return false
    }
}

/// Plays a few seconds of a sound in the picker. Tapping the playing one stops it.
@MainActor
@Observable
final class SoundPreview {
    private(set) var playing: SoundChoice?
    @ObservationIgnored private let player = AlarmSoundPlayer()
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    func toggle(_ sound: SoundChoice) {
        if playing == sound {
            stop()
            return
        }
        playing = sound
        player.start(sound)
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        player.stop()
        playing = nil
    }
}

// MARK: - Apple Music

/// Search the Apple Music catalog and pick a song, start point and the tone for the system alarm.
struct AppleMusicSearchView: View {
    @Binding var selection: SoundChoice
    @State private var status = MusicAuthorization.currentStatus
    @State private var term = ""
    @State private var songs: MusicItemCollection<Song> = []
    @State private var error: String?
    @State private var searching = false

    var body: some View {
        List {
            switch status {
            case .authorized:
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(songs) { song in
                    NavigationLink {
                        AppleMusicSongView(song: song, selection: $selection)
                    } label: {
                        HStack(spacing: 12) {
                            if let artwork = song.artwork { ArtworkImage(artwork, width: 48) .clipShape(.rect(cornerRadius: 6)) }
                            VStack(alignment: .leading) {
                                Text(song.title).lineLimit(1)
                                Text(song.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                if songs.isEmpty && !searching && error == nil {
                    Text("Search for a song to wake up to.").foregroundStyle(.secondary)
                }
            case .denied, .restricted:
                PermissionBanner(kind: .appleMusic, message: "Apple Music access is off for Gloop, so songs can't be searched or played.")
            default:
                Button("Allow Apple Music") {
                    Task {
                        await PermissionCenter.shared.request(.appleMusic)
                        status = MusicAuthorization.currentStatus
                    }
                }
            }
        }
        .navigationTitle("Apple Music")
        .searchable(text: $term, prompt: "Songs or artists")
        .onSubmit(of: .search) { Task { await search() } }
        .overlay { if searching { ProgressView() } }
        .task {
            if status == .notDetermined { await PermissionCenter.shared.request(.appleMusic) }
            status = MusicAuthorization.currentStatus
        }
    }

    private func search() async {
        guard !term.isEmpty else { return }
        searching = true
        defer { searching = false }
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 25
            songs = try await request.response().songs
            error = nil
        } catch {
            self.error = "Apple Music isn't available right now. (It needs the paid Apple Developer Program with the MusicKit service.)"
        }
    }
}

private struct AppleMusicSongView: View {
    let song: Song
    @Binding var selection: SoundChoice
    @State private var start: Double = 0
    @State private var fallback: AlarmSound = .classic
    @State private var previewing = false
    @Environment(\.dismiss) private var dismiss

    private var maxStart: Double { max(0, (song.duration ?? 60) - 30) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    if let artwork = song.artwork { ArtworkImage(artwork, width: 72).clipShape(.rect(cornerRadius: 10)) }
                    VStack(alignment: .leading) {
                        Text(song.title).font(.headline)
                        Text(song.artistName).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Slider(value: $start, in: 0...max(1, maxStart), step: 1) { Text("Start") }
                Text("Starts at \(Int(start) / 60):\(String(format: "%02d", Int(start) % 60))").font(.subheadline.monospacedDigit())
                Button(previewing ? "Stop preview" : "Preview from here") { Task { await togglePreview() } }
            } header: {
                Text("Start the song at")
            }
            Section {
                Picker("Alarm tone", selection: $fallback) {
                    ForEach(AlarmSound.allCases) { Text($0.displayName).tag($0) }
                }
            } footer: {
                Text("iOS can't ring an alarm with an Apple Music song, so the alarm rings with this tone. The song starts as soon as you open your mission.")
            }
        }
        .navigationTitle("Song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Use this song") {
                    stopPreview()
                    selection = .appleMusic(AppleMusicPick(songID: song.id.rawValue, title: song.title, artist: song.artistName,
                                                           startOffset: start, artworkURL: song.artwork?.url(width: 300, height: 300),
                                                           fallback: fallback))
                    dismiss()
                }
            }
        }
        .onDisappear { stopPreview() }
    }

    private func togglePreview() async {
        if previewing { stopPreview(); return }
        let player = ApplicationMusicPlayer.shared
        player.queue = [song]
        do {
            try await player.prepareToPlay()
            player.playbackTime = start
            try await player.play()
            previewing = true
        } catch {
            previewing = false
        }
    }

    private func stopPreview() {
        if previewing { ApplicationMusicPlayer.shared.stop() }
        previewing = false
    }
}
