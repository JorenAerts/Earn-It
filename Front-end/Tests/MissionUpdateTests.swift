import Core
import Foundation
import Missions
import Testing

@Suite struct ObjectMatchPolicyTests {
    @Test func thresholdFollowsTheItemsOwnSpreadWithinBounds() {
        #expect(ObjectMatchPolicy.threshold(pairwiseDistances: []) == ObjectMatchPolicy.minimumThreshold)
        #expect(ObjectMatchPolicy.threshold(pairwiseDistances: [0.1, 0.2]) == ObjectMatchPolicy.minimumThreshold)
        let mid = ObjectMatchPolicy.threshold(pairwiseDistances: [0.3, 0.5])
        #expect(abs(mid - 0.5 * ObjectMatchPolicy.thresholdMargin) < 0.0001)
        #expect(ObjectMatchPolicy.threshold(pairwiseDistances: [2]) == ObjectMatchPolicy.maximumThreshold)
    }

    @Test func closenessMeter() {
        #expect(ObjectMatchPolicy.closeness(distance: 0.2, threshold: 0.5) == 1)
        #expect(ObjectMatchPolicy.closeness(distance: 1.0, threshold: 0.5) == 0)
        let half = ObjectMatchPolicy.closeness(distance: 0.75, threshold: 0.5)
        #expect(half > 0.49 && half < 0.51)
    }

    @Test func needsConsecutiveMatches() {
        var tracker = ObjectMatchTracker()
        for _ in 0..<(ObjectMatchPolicy.requiredConsecutive - 1) { tracker.record(distance: 0.2, threshold: 0.5) }
        #expect(!tracker.isComplete)
        tracker.record(distance: 0.9, threshold: 0.5)   // a different object breaks the streak
        #expect(tracker.streak == 0)
        tracker.record(distance: nil, threshold: 0.5)   // nothing in view
        #expect(tracker.lastCloseness == 0)
        for _ in 0..<ObjectMatchPolicy.requiredConsecutive { tracker.record(distance: 0.2, threshold: 0.5) }
        #expect(tracker.isComplete)
    }

    @Test func setupShotsMustChangeAngle() {
        #expect(!ObjectMatchPolicy.isDistinctAngle(distanceToPrevious: 0.01))
        #expect(ObjectMatchPolicy.isDistinctAngle(distanceToPrevious: 0.2))
    }
}

@Suite struct MissionRunTests {
    private let item = MissionConfig(kind: .object, payload: "ref", label: "Toothbrush")

    @Test func successAdvancesAndFinishes() {
        var run = MissionRun(steps: [MissionConfig(kind: .math), MissionConfig(kind: .shake)])
        #expect(run.apply(.success) == .nextStep && run.current?.kind == .shake)
        #expect(run.apply(.success) == .finished && run.isFinished)
    }

    @Test func needsBackupNeverCountsAsSuccess() {
        var run = MissionRun(steps: [item])
        #expect(run.apply(.needsBackup) == .backupStarted)
        #expect(!run.isFinished)
        #expect(run.current?.kind == .math && run.current?.difficulty == .hard && run.current?.target == 5)
        #expect(run.backupDelay == nil, "no second backup for the same step")
        #expect(run.apply(.success) == .finished)
    }

    @Test func backupOfferOnlyForMissionsThatNeedIt() {
        #expect(MissionRun(steps: [item]).backupDelay == 120)
        #expect(MissionRun(steps: [MissionConfig(kind: .math)]).backupDelay == nil)
    }
}

@Suite struct MissionMetadataTests {
    @Test func everyKindHasPickerInfo() {
        for kind in MissionKind.allCases {
            #expect(!kind.symbol.isEmpty && !kind.tagline.isEmpty && !kind.estimatedDuration.isEmpty, "\(kind)")
            #expect(!MissionConfig(kind: kind).instruction.isEmpty)
        }
    }

    @Test func objectMissionNeedsAScanAndUsesItsName() {
        var config = MissionConfig(kind: .object)
        #expect(!config.isReady && config.kind.needsCamera && config.kind.needsSetup)
        config.payload = "ref"
        config.label = "Toothbrush"
        #expect(config.isReady)
        #expect(config.summary == "Toothbrush")
        #expect(config.instruction.contains("toothbrush"))
        #expect(AlarmPlan(missions: [config]).alarmTitle == "Earn It - Scan Toothbrush")
    }

    @Test func oldMissionJSONWithoutLabelDecodes() throws {
        let json = #"{"id":"D4B30B83-E6F4-4241-ADA8-6C619FEA3C91","kind":"qr","difficulty":"easy","target":1,"payload":"x"}"#
        let config = try JSONDecoder().decode(MissionConfig.self, from: Data(json.utf8))
        #expect(config.label == nil && config.isReady)
    }

    @Test func pruneKeepsUsedAndRecentScans() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        for id in ["used", "old", "fresh"] {
            try FileManager.default.createDirectory(at: root.appending(path: id), withIntermediateDirectories: true)
        }
        let store = ObjectReferenceStore(root: root)
        store.prune(keeping: ["used"], olderThan: 3_600, now: Date().addingTimeInterval(10))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "fresh").path()), "kept: too recent")
        store.prune(keeping: ["used"], olderThan: 3_600, now: Date().addingTimeInterval(7_200))
        let left = try FileManager.default.contentsOfDirectory(atPath: root.path())
        #expect(left == ["used"])
    }
}
