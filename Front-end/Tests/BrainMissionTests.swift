import Core
import Foundation
import Localization
@testable import Missions
import Testing

private struct SeededRNG: RandomNumberGenerator, Sendable {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private let front = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
private let shipped = (Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String] ?? []).filter { $0 != "en" }

@Suite struct MissionCategoryTests {
    @Test func everyMissionHasAFolderAndOnboardingKindsExist() {
        let inFolders = MissionCategory.allCases.flatMap(\.kinds)
        #expect(Set(inFolders) == Set(MissionKind.allCases) && inFolders.count == MissionKind.allCases.count)
        #expect(MissionKind.quiz.category == .brain && MissionKind.shake.category == .body && MissionKind.object.category == .outOfBed)
        #expect(Set(MissionKind.onboardingKinds).isSubset(of: Set(MissionKind.allCases)))
    }

    @Test func quizTopicIsStoredInPayload() {
        var config = MissionConfig(kind: .quiz)
        #expect(config.quizTopic == .general && config.isReady)
        config.quizTopic = .food
        #expect(config.payload == "food" && config.quizTopic == .food)
        let decoded = try? JSONDecoder().decode(MissionConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded?.quizTopic == .food)
    }
}

@Suite struct QuizSessionTests {
    private let questions = (1...5).map { QuizQuestion(question: "Q\($0)", answer: "A\($0)", wrong: ["x", "y", "z"]) }

    @Test func completesAfterTargetCorrectAnswersAndWrongOnesMoveOn() {
        var session = QuizSession(questions: questions, target: 2, rng: SeededRNG(state: 1))
        var seen = Set<String>()
        let first = session.round!
        seen.insert(first.question.question)
        #expect(first.options.count == 4 && first.options.contains(first.question.answer))
        let wrong = session.answer((first.correctIndex + 1) % 4)
        #expect(!wrong)
        #expect(session.correct == 0 && !session.isComplete)
        #expect(session.round!.question != first.question)
        let right1 = session.answer(session.round!.correctIndex)
        let right2 = session.answer(session.round!.correctIndex)
        #expect(right1 && right2 && session.isComplete)
    }

    @Test func targetNeverExceedsTheQuestions() {
        #expect(QuizSession(questions: questions, target: 50, rng: SeededRNG(state: 2)).target == 5)
        #expect(QuizSession(questions: [], target: 3, rng: SeededRNG(state: 2)).round == nil)
    }
}

@Suite struct MemoryGameTests {
    @Test func pairsMatchAndMismatchesClose() {
        var rng = SeededRNG(state: 7)
        var game = MemoryGame(pairs: 3, rng: &rng)
        #expect(game.cards.count == 6)
        let faces = game.cards.map(\.face)
        let a = 0
        let partner = faces.indices.first { $0 != a && faces[$0] == faces[a] }!
        let other = faces.indices.first { faces[$0] != faces[a] }!
        let r1 = game.flip(a), r2 = game.flip(other)
        #expect(r1 == .first && r2 == .mismatch && game.needsClose)
        let blocked = game.flip(partner)
        #expect(blocked == .ignored)
        game.closeMismatch()
        #expect(!game.cards[a].isUp)
        let r3 = game.flip(a), r4 = game.flip(partner)
        #expect(r3 == .first && r4 == .match)
        let again = game.flip(a)
        #expect(game.cards[a].isMatched && again == .ignored)
        // Solve the rest.
        while !game.isComplete {
            let open = game.cards.indices.filter { !game.cards[$0].isMatched }
            let i = open[0], j = open.first { $0 != i && game.cards[$0].face == game.cards[i].face }!
            _ = game.flip(i); _ = game.flip(j)
        }
        #expect(game.isComplete && game.moves == 4)  // 3 pairs + 1 mismatch
    }

    @Test func boardSizeFollowsDifficulty() {
        #expect(MissionConfig(kind: .memory, difficulty: .easy).memoryPairs == 6)
        #expect(MissionConfig(kind: .memory, difficulty: .hard).memoryPairs == 10)
        #expect(MemoryGame.faces.count >= 10)
    }
}

@Suite struct TypingCheckTests {
    @Test func forgivesCasePunctuationAndSpaces() {
        #expect(TypingCheck.matches("she SELLS  seashells, by the seashore!", "She sells seashells by the seashore"))
        #expect(TypingCheck.matches("Betty Botter's butter", "Betty Botter’s butter"))
        #expect(!TypingCheck.matches("she sells sea shells", "She sells seashells"))
        #expect(TypingCheck.matches("Fischers Fritz fischt", "Fischers Fritz fischt"))
        #expect(!TypingCheck.matches("cafe", "café"))  // letters, accents included, must match
        #expect(TypingCheck.correctPrefix("she sel", "She sells") == 7)
    }
}

@Suite struct BrainContentTests {
    private func json(_ path: String) -> Any? {
        (try? Data(contentsOf: front.appending(path: path))).flatMap { try? JSONSerialization.jsonObject(with: $0) }
    }

    private func checkQuiz(_ table: [String: [[String: Any]]], _ name: String) {
        #expect(Set(table.keys) == Set(QuizTopic.allCases.map(\.rawValue)), "\(name): topics")
        for (topic, list) in table {
            #expect(list.count == 20, "\(name) \(topic): \(list.count) questions")
            for q in list {
                let answer = q["answer"] as? String ?? "", wrong = q["wrong"] as? [String] ?? []
                #expect(!(q["question"] as? String ?? "").isEmpty && !answer.isEmpty, "\(name) \(topic): empty")
                #expect(wrong.count == 3 && !wrong.contains(answer) && Set(wrong).count == 3, "\(name) \(topic): \(q["question"] ?? "")")
            }
        }
    }

    @Test func quizHas20QuestionsPerTopicInEveryLanguage() throws {
        checkQuiz(try #require(json("Config/Quiz.json") as? [String: [[String: Any]]]), "en")
        for code in shipped {
            let table = try #require(L10n.contentCodes(for: code).lazy
                .compactMap { json("Config/Translations/Quiz.\($0).json") as? [String: [[String: Any]]] }.first,
                "Config/Translations/Quiz.\(code).json missing")
            checkQuiz(table, code)
        }
    }

    @Test func tongueTwistersForEveryDifficultyAndLanguage() throws {
        for code in ["en"] + shipped {
            let file = code == "en" ? "Config/TongueTwisters.json"
                : L10n.contentCodes(for: code).map { "Config/Translations/TongueTwisters.\($0).json" }
                    .first { FileManager.default.fileExists(atPath: front.appending(path: $0).path) } ?? code
            let table = try #require(json(file) as? [String: [String]], "\(file) missing")
            for level in MissionDifficulty.allCases {
                #expect((table[level.rawValue]?.count ?? 0) >= 5, "\(file): \(level.rawValue)")
            }
        }
    }
}
