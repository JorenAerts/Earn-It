#if DEBUG
import Foundation
import Localization

/// Demo texts on the App Store screenshots that the app itself never shows (fake Lock Screen, sample
/// club). Kept here instead of the string catalog: DEBUG-only, screenshot languages from scenes.json.
@MainActor
enum StoreShotText {
    static func t(_ english: String) -> String {
        table[english]?[LanguageSettings.shared.current.code] ?? english
    }

    /// Friday 13 November 2026 in the app language ("vrijdag 13 november").
    static var lockScreenDate: String {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 13)) ?? .now
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(LanguageSettings.shared.current.locale))
    }

    private static let table: [String: [String: String]] = [
        "slide to stop": [
            "nl": "schuif om te stoppen", "de": "zum Stoppen schieben", "fr": "faire glisser pour arrêter",
            "es": "desliza para detener", "it": "scorri per fermare", "pt-BR": "deslize para parar",
            "pt-PT": "deslize para parar"],
        "Pick your mission": [
            "nl": "Kies je missie", "de": "Wähl deine Mission", "fr": "Choisis ta mission", "es": "Elige tu misión",
            "it": "Scegli la tua missione", "pt-BR": "Escolha sua missão", "pt-PT": "Escolha a sua missão"],
        "now": ["nl": "nu", "de": "jetzt", "fr": "maintenant", "es": "ahora", "it": "ora", "pt-BR": "agora", "pt-PT": "agora"],
        "Stop me with a mission, not a swipe.": [
            "nl": "Stop me met een missie, niet met een veeg.",
            "de": "Stopp mich mit einer Mission, nicht mit einem Wisch.",
            "fr": "Arrête-moi avec une mission, pas d’un glissement.",
            "es": "Párame con una misión, no deslizando.",
            "it": "Fermami con una missione, non con uno swipe.",
            "pt-BR": "Me pare com uma missão, não com um deslize.",
            "pt-PT": "Pare-me com uma missão, não com um deslize."],
        "Early birds": [
            "nl": "Vroege vogels", "de": "Frühaufsteher", "fr": "Lève-tôt", "es": "Madrugadores", "it": "Mattinieri",
            "pt-BR": "Madrugadores", "pt-PT": "Madrugadores"],
        "Up before 7, every weekday.": [
            "nl": "Voor 7 uur op, elke werkdag.", "de": "Vor 7 auf, jeden Werktag.",
            "fr": "Debout avant 7 h, chaque jour de semaine.", "es": "En pie antes de las 7, cada día laborable.",
            "it": "In piedi prima delle 7, ogni giorno feriale.", "pt-BR": "De pé antes das 7, todo dia útil.",
            "pt-PT": "De pé antes das 7, todos os dias úteis."],
        "Gym rats": [
            "nl": "Gymmaatjes", "de": "Gym-Crew", "fr": "Accros de la salle", "es": "Adictos al gym",
            "it": "Fissati della palestra", "pt-BR": "Ratos de academia", "pt-PT": "Viciados no ginásio"],
    ]
}
#endif
