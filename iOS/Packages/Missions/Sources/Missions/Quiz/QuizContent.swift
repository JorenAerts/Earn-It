import Core
import Foundation
import Localization

/// One multiple-choice question: `answer` is right, `wrong` are the distractors.
public struct QuizQuestion: Codable, Hashable, Sendable {
    public let question: String
    public let answer: String
    public let wrong: [String]

    public init(question: String, answer: String, wrong: [String]) {
        self.question = question
        self.answer = answer
        self.wrong = wrong
    }
}

/// `Shared/Config/Quiz.json`: `{ "<topic>": [ {question, answer, wrong: [3]} ×20 ] }`, translated in
/// `Translations/Quiz.<code>.json` (same shape; a topic missing there stays English).
public enum QuizBank {
    public static func load(from bundle: Bundle = .main, language: String = L10n.languageCode) -> [QuizTopic: [QuizQuestion]] {
        func decode(_ url: URL?) -> [String: [QuizQuestion]] {
            guard let url, let data = try? Data(contentsOf: url),
                  let table = try? JSONDecoder().decode([String: [QuizQuestion]].self, from: data) else { return [:] }
            return table
        }
        var table = decode(bundle.url(forResource: "Quiz", withExtension: "json"))
        let local = decode(L10n.translatedResource("Quiz", ext: "json", subdirectories: ["Translations", nil],
                                                   code: language, in: bundle))
        for (topic, questions) in local where !questions.isEmpty { table[topic] = questions }
        var result: [QuizTopic: [QuizQuestion]] = [:]
        for (key, questions) in table { if let topic = QuizTopic(rawValue: key) { result[topic] = questions } }
        return result
    }

    public static func questions(for topic: QuizTopic, bundle: Bundle = .main) -> [QuizQuestion] {
        load(from: bundle)[topic] ?? []
    }
}
