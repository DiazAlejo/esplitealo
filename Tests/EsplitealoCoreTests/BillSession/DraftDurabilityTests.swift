import XCTest
@testable import EsplitealoCore

/// What happens to the draft file when the world is unkind: a write cut short, a file damaged on disk, a file from an
/// older app, a bill that references things that are no longer there. Whatever is on disk, loading either returns the
/// bill or throws (the app then deletes the file and starts clean); it never crashes and never leaves the folder
/// unusable for the next save.
final class DraftDurabilityTests: XCTestCase {
    private var directory: URL!
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/BillSessions", isDirectory: true)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("esplitealo-durability-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // A test may leave the folder read-only.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: FileBillDraftStore { FileBillDraftStore(directory: directory) }
    private var draftFile: URL { directory.appendingPathComponent(FileBillDraftStore.fileName) }

    private func validData(_ session: BillSession = .sampleReadyToShare()) throws -> Data {
        try BillSessionCoding.encoder().encode(session)
    }

    private func filesInDirectory() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    // MARK: A damaged file

    /// The user can always carry on: whatever is in `draft.json`, `load()` fails cleanly, and after the app deletes the
    /// file (what `BillStore.loadSavedDraft` does) the next bill saves and loads like any other.
    private func assertDamagedFileFailsCleanlyAndTheFolderStaysUsable(_ bytes: Data, _ description: String, file: StaticString = #filePath, line: UInt = #line) throws {
        try bytes.write(to: draftFile)
        XCTAssertThrowsError(try store.load(), description, file: file, line: line)

        try store.delete()
        XCTAssertNil(try store.load(), "\(description): deleted", file: file, line: line)

        let next = BillSession.sampleTwoPeopleOneItem()
        try store.save(next)
        XCTAssertEqual(try store.load(), next, "\(description): the next bill saves", file: file, line: line)
    }

    func testATruncatedFileFailsCleanlyAtEveryLengthAndTheFolderStaysUsable() throws {
        let data = try validData()
        // Every cut of the JSON, in steps, as a power cut during a non-atomic write would have left it.
        for length in stride(from: 0, to: data.count, by: max(1, data.count / 40)) {
            try assertDamagedFileFailsCleanlyAndTheFolderStaysUsable(data.prefix(length), "truncated at \(length) of \(data.count) bytes")
        }
    }

    func testEmptyGarbageAndWrongShapeFilesFailCleanly() throws {
        let cases: [(String, Data)] = [
            ("empty file", Data()),
            ("only whitespace", Data("   \n".utf8)),
            ("random bytes", Data((0 ..< 512).map { UInt8(($0 * 37 + 11) % 256) })),
            ("null", Data("null".utf8)),
            ("an empty object", Data("{}".utf8)),
            ("an array", Data("[1,2,3]".utf8)),
            ("a version and nothing else", Data(#"{"schemaVersion":2}"#.utf8)),
            ("text where the draft should be", Data(#"{"schemaVersion":2,"draft":"oops"}"#.utf8)),
        ]
        for (description, bytes) in cases {
            try assertDamagedFileFailsCleanlyAndTheFolderStaysUsable(bytes, description)
        }
    }

    func testAFlippedByteEitherFailsOrLoadsABillAndNeverCrashes() throws {
        let data = try validData()
        for index in stride(from: 0, to: data.count, by: max(1, data.count / 60)) {
            var damaged = data
            damaged[index] ^= 0xFF
            try damaged.write(to: draftFile)
            // A bit flip inside a name or an amount is still valid JSON; the bill then simply has different text.
            _ = try? store.load()
        }
        try store.delete()
        try store.save(.sampleReadyToShare())
        XCTAssertEqual(try store.load(), .sampleReadyToShare())
    }

    func testADirectoryWhereTheDraftFileShouldBeFailsCleanly() throws {
        try FileManager.default.createDirectory(at: draftFile, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.load())
        try store.delete()
        XCTAssertNil(try store.load())
        try store.save(.sampleReadyToShare())
        XCTAssertEqual(try store.load(), .sampleReadyToShare())
    }

    // MARK: An interrupted write

    func testALeftoverTemporaryFileFromACutShortWriteChangesNothing() throws {
        let session = BillSession.sampleReadyToShare()
        try store.save(session)
        // `Data.write(options: .atomic)` writes a sibling temporary file and renames it; a crash before the rename
        // leaves the temporary file behind and the previous draft untouched.
        let leftover = directory.appendingPathComponent("draft.json.sb-1a2b3c4d-XYZ123")
        try Data(try validData().prefix(100)).write(to: leftover)

        XCTAssertEqual(try store.load(), session, "the saved bill is the one that was complete")
        let newer = BillSession.sampleTwoPeopleOneItem()
        try store.save(newer)
        XCTAssertEqual(try store.load(), newer, "and saving still works beside the leftover")
    }

    func testAFailedWriteLeavesThePreviousDraftIntactAndNoTemporaryFile() throws {
        let session = BillSession.sampleReadyToShare()
        try store.save(session)
        let before = try filesInDirectory()

        // A folder that cannot be written to makes the replacement fail, as a full disk or a revoked file would.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        try XCTSkipIf(FileManager.default.isWritableFile(atPath: directory.path), "this account can write to a read-only folder")
        XCTAssertThrowsError(try store.save(.sampleTwoPeopleOneItem()))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)

        XCTAssertEqual(try store.load(), session, "the previous bill is still there, whole")
        XCTAssertEqual(try filesInDirectory(), before, "no half-written file stays behind")
    }

    func testTheFolderBeingDeletedUnderTheStoreIsRecreatedOnTheNextSave() throws {
        try store.save(.sampleReadyToShare())
        try FileManager.default.removeItem(at: directory)
        XCTAssertNil(try store.load())
        let next = BillSession.sampleTwoPeopleOneItem()
        try store.save(next)
        XCTAssertEqual(try store.load(), next)
    }

    func testSavingManyTimesInARowAlwaysLeavesOneCompleteFile() throws {
        var session = BillSession.sampleTwoPeopleOneItem()
        for round in 0 ..< 50 {
            session.merchantName = "Round \(round)"
            try store.save(session)
            XCTAssertEqual(try filesInDirectory(), [FileBillDraftStore.fileName])
        }
        XCTAssertEqual(try store.load()?.merchantName, "Round 49")
    }

    // MARK: Older drafts

    func testAVersion1DraftOnDiskResumesAndIsRewrittenAsTheCurrentVersionWithTheSameBill() throws {
        try Data(contentsOf: fixturesURL.appendingPathComponent("v1-in-progress.json")).write(to: draftFile)
        let resumed = try XCTUnwrap(store.load())

        try store.save(resumed)
        let rewritten = try JSONSerialization.jsonObject(with: Data(contentsOf: draftFile)) as? [String: Any]
        XCTAssertEqual(rewritten?["schemaVersion"] as? Int, BillSession.currentSchemaVersion)
        XCTAssertEqual(try store.load(), resumed, "migrating changes the file, not the bill")
    }

    func testEveryCommittedOlderFixtureLoadsAndRoundTrips() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: fixturesURL.path).filter { $0.hasSuffix(".json") }.sorted()
        XCTAssertGreaterThanOrEqual(names.count, 3)
        for name in names {
            try Data(contentsOf: fixturesURL.appendingPathComponent(name)).write(to: draftFile)
            let loaded = try XCTUnwrap(store.load(), name)
            try store.save(loaded)
            XCTAssertEqual(try store.load(), loaded, name)
            // Whatever the old file held, the screens can price it.
            _ = loaded.personBreakdowns
            _ = loaded.unassignedUnits
            _ = loaded.canShare
        }
    }

    func testAnUnknownExtraKeyFromANewerPatchIsIgnored() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: validData()) as? [String: Any])
        object["somethingAddedLater"] = ["a": 1]
        try JSONSerialization.data(withJSONObject: object).write(to: draftFile)
        XCTAssertEqual(try store.load(), .sampleReadyToShare())
    }

    // MARK: A bill that points at things that are gone

    /// A decoded bill is never repaired or pruned (a restored bill equals the saved one), so a damaged file can hold
    /// assignments for items or people that do not exist. The screens read these through the calculator: it must
    /// price them without trapping.
    func testAssignmentsToMissingItemsPeopleAndUnitsDoNotCrashTheScreens() throws {
        var session = BillSession.sampleReadyToShare()
        let ghost = UUID()
        let item = try XCTUnwrap(session.draft.items.first)
        let person = try XCTUnwrap(session.participants.first)
        session.assignments += [
            ItemAssignment(itemID: ghost, unitIndex: 0, participantIDs: [person.id]),
            ItemAssignment(itemID: item.id, unitIndex: 7, participantIDs: [person.id]),
            ItemAssignment(itemID: item.id, unitIndex: -1, participantIDs: [person.id]),
            ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: [ghost]),
            ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: []),
            ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: [person.id, person.id]),
        ]
        try store.save(session)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded, session)

        touchEverythingAScreenReads(in: loaded)
    }

    func testDuplicatePeopleAndOrderIndexesDoNotCrashTheScreens() throws {
        var session = BillSession.sampleReadyToShare()
        let first = try XCTUnwrap(session.participants.first)
        session.participants.append(first)
        session.participants.append(Participant(name: "Twin", orderIndex: first.orderIndex))
        try store.save(session)

        touchEverythingAScreenReads(in: try XCTUnwrap(store.load()))
    }

    func testAnEmptyTableWithAssignmentsAndAnItemlessBillDoNotCrashTheScreens() throws {
        var session = BillSession.sampleReadyToShare()
        session.participants = []
        try store.save(session)
        touchEverythingAScreenReads(in: try XCTUnwrap(store.load()))

        var itemless = BillSession.sampleReadyToShare()
        itemless.draft.items = []
        try store.save(itemless)
        touchEverythingAScreenReads(in: try XCTUnwrap(store.load()))
    }

    func testNegativeAndZeroAmountsAndTipsDoNotCrashTheScreens() throws {
        var session = BillSession.sampleReadyToShare()
        session.draft.items[0].lineTotal = DraftAmount(minorUnits: -500)
        session.draft.items[1].lineTotal = DraftAmount(minorUnits: 0)
        session.draft.tax = DraftAmount(minorUnits: -1)
        session.serviceChargeCents = -300
        session.tip = .percentage(percent: -20, basis: .postTaxTotal)
        try store.save(session)
        touchEverythingAScreenReads(in: try XCTUnwrap(store.load()))

        session.tip = .custom(cents: -1000)
        touchEverythingAScreenReads(in: session)
    }

    private func touchEverythingAScreenReads(in session: BillSession, file: StaticString = #filePath, line: UInt = #line) {
        _ = session.phase
        _ = session.shareBlockReason
        _ = session.unassignedUnits
        _ = session.splitResult
        _ = session.personBreakdowns
        _ = session.confirmedBillTotalCents
        _ = session.netItemsSubtotalCents
        for participant in session.participants { _ = session.preTaxSubtotalCents(for: participant.id) }
        if session.canShare {
            XCTAssertFalse(ShareSummaryBuilder.build(for: session, language: .es).isEmpty, file: file, line: line)
        }
        var rest = session
        rest.splitRestEvenly()
        _ = rest.canShare
    }
}
