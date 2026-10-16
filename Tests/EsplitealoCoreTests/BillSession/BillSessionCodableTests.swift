import XCTest
@testable import EsplitealoCore

final class BillSessionCodableTests: XCTestCase {
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/BillSessions", isDirectory: true)

    private func fixtureData(_ name: String) throws -> Data {
        try Data(contentsOf: fixturesURL.appendingPathComponent("\(name).json"))
    }

    private func roundTrip(_ session: BillSession) throws -> BillSession {
        let data = try BillSessionCoding.encoder().encode(session)
        return try BillSessionCoding.decoder().decode(BillSession.self, from: data)
    }

    // MARK: - Round trips

    func testReadyToShareSampleRoundTripsExactly() throws {
        let session = BillSession.sampleReadyToShare()
        XCTAssertEqual(try roundTrip(session), session)
    }

    func testServiceChargeSampleRoundTripsExactly() throws {
        let session = BillSession.sampleWithServiceChargeAssigned()
        XCTAssertEqual(try roundTrip(session), session)
    }

    func testMismatchSampleRoundTripsExactly() throws {
        let session = BillSession.sampleMismatch()
        XCTAssertEqual(try roundTrip(session), session)
    }

    func testRoundTripKeepsDerivedMoney() throws {
        let session = BillSession.sampleReadyToShare()
        let restored = try roundTrip(session)
        XCTAssertEqual(restored.phase, .ready)
        XCTAssertEqual(restored.confirmedBillTotalCents, session.confirmedBillTotalCents)
        XCTAssertEqual(restored.personBreakdowns, session.personBreakdowns)
    }

    func testDateSurvivesRoundTripToTheSecond() throws {
        var session = BillSession(draft: ReceiptDraft())
        session.date = Date(timeIntervalSince1970: 1_791_909_900)
        XCTAssertEqual(try roundTrip(session).date, session.date)
    }

    func testRoundTripKeepsEveryDraftFieldTheScannerCanProduce() throws {
        let rect = PixelRect(x: 1.5, y: 2.5, width: 3.5, height: 4.5)
        let draft = ReceiptDraft(
            items: [
                DraftItem(
                    name: "Café",
                    quantity: 3,
                    lineTotal: DraftAmount(minorUnits: 900, sourceRect: rect, needsAttention: true),
                    unitPrice: DraftAmount(minorUnits: 300),
                    notes: ["extra caliente"],
                    flags: [.zeroPrice, .formatGuessed],
                    sourceRect: rect
                ),
            ],
            subtotal: DraftAmount(minorUnits: 900),
            tax: DraftAmount(minorUnits: 90),
            tip: DraftAmount(minorUnits: 100),
            total: DraftAmount(minorUnits: 1090),
            adjustments: [DraftAdjustment(label: "Promo", amount: DraftAmount(minorUnits: -50))],
            numberFormat: NumberFormat(decimalSeparator: ",", groupSeparator: ".", fractionDigits: 2, isGuessed: true),
            warnings: [
                ReceiptWarning(
                    issue: .unparsedPriceRow("5,00 ??"),
                    rowLabel: "Café",
                    sourceRect: rect,
                    itemID: UUID(uuidString: "30000000-0000-0000-0000-000000000001"),
                    isDismissed: true
                ),
                ReceiptWarning(issue: .numberFormatGuessed(.usdCents)),
            ],
            issues: [
                .itemsDoNotMatchSubtotal(itemsSum: 1, printed: 2),
                .totalsDoNotAddUp(expected: 3, printed: 4),
                .numberFormatGuessed(.usdCents),
                .noTotalFound,
                .noItemsFound,
                .unparsedPriceRow("5,00 ??"),
            ],
            reconciles: true
        )
        var session = BillSession(draft: draft, merchantName: "Café Central", serviceChargeCents: 12)
        session.date = Date(timeIntervalSince1970: 1_791_909_900)
        _ = session.addParticipant(name: "Ana")
        session.tip = .custom(cents: 250)
        XCTAssertEqual(try roundTrip(session), session)
    }

    func testEncodedJSONCarriesTheSchemaVersion() throws {
        let data = try BillSessionCoding.encoder().encode(BillSession.sampleReadyToShare())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, BillSession.currentSchemaVersion)
        XCTAssertEqual(BillSession.currentSchemaVersion, 2)
    }

    func testEncodedJSONIsDeterministic() throws {
        let session = BillSession.sampleReadyToShare()
        let first = try BillSessionCoding.encoder().encode(session)
        let second = try BillSessionCoding.encoder().encode(session)
        XCTAssertEqual(first, second)
    }

    // MARK: - Committed fixtures (the on-disk format is a contract)

    func testDecodesVersion1InProgressFixture() throws {
        let session = try BillSessionCoding.decoder().decode(
            BillSession.self,
            from: fixtureData("v1-in-progress")
        )
        XCTAssertEqual(session.merchantName, "Fonda Doña Lola")
        XCTAssertEqual(session.date, Date(timeIntervalSince1970: 1_791_909_900))
        XCTAssertEqual(session.serviceChargeCents, 0)
        XCTAssertTrue(session.mismatchAcknowledged)
        XCTAssertEqual(session.tip, .percentage(percent: 18, basis: .postTaxTotal))

        XCTAssertEqual(session.participants.map(\.name), ["Alex", "Sam"])
        XCTAssertEqual(session.participants.map(\.orderIndex), [0, 1])
        XCTAssertEqual(session.participants[0].id, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))

        XCTAssertEqual(session.assignments.count, 2)
        XCTAssertEqual(session.assignments[1].unitIndex, 1)
        XCTAssertEqual(session.assignments[1].participantIDs.count, 2)

        let draft = session.draft
        XCTAssertEqual(draft.items.map(\.name), ["Mofongo", "Tostones"])
        XCTAssertEqual(draft.items.map(\.quantity), [1, 2])
        XCTAssertEqual(draft.items[0].lineTotal.minorUnits, 1450)
        XCTAssertEqual(draft.items[0].lineTotal.sourceRect, PixelRect(x: 120.5, y: 88, width: 64, height: 18))
        XCTAssertNil(draft.items[0].unitPrice)
        XCTAssertTrue(draft.items[1].lineTotal.needsAttention)
        XCTAssertEqual(draft.items[1].unitPrice?.minorUnits, 450)
        XCTAssertEqual(draft.items[1].notes, ["sin sal"])
        XCTAssertEqual(draft.items[1].flags, [.needsReview])
        XCTAssertEqual(draft.subtotal?.minorUnits, 2350)
        XCTAssertEqual(draft.tax?.minorUnits, 270)
        XCTAssertNil(draft.tip)
        XCTAssertEqual(draft.total?.minorUnits, 2300)
        XCTAssertEqual(draft.adjustments.map(\.label), ["Descuento"])
        XCTAssertEqual(draft.adjustments.first?.amount.minorUnits, -320)
        XCTAssertEqual(draft.numberFormat, .usdCents)
        XCTAssertEqual(draft.issues, [
            .totalsDoNotAddUp(expected: 2620, printed: 2300),
            .unparsedPriceRow("Gracias por su visita 5"),
            .noTotalFound,
        ])
        XCTAssertFalse(draft.reconciles)
    }

    func testDecodesVersion1MinimalFixture() throws {
        let session = try BillSessionCoding.decoder().decode(
            BillSession.self,
            from: fixtureData("v1-minimal")
        )
        XCTAssertEqual(session.merchantName, "")
        XCTAssertNil(session.date)
        XCTAssertEqual(session.tip, .custom(cents: 500))
        XCTAssertTrue(session.participants.isEmpty)
        XCTAssertTrue(session.draft.items.isEmpty)
        XCTAssertEqual(session.draft.numberFormat.decimalSeparator, ",")
        XCTAssertTrue(session.draft.numberFormat.isGuessed)
    }

    func testFixturesSurviveReEncoding() throws {
        for name in ["v1-in-progress", "v1-minimal", "v2-with-warnings"] {
            let decoded = try BillSessionCoding.decoder().decode(BillSession.self, from: fixtureData(name))
            XCTAssertEqual(try roundTrip(decoded), decoded, name)
        }
    }

    // MARK: - Version 2: parser warnings

    func testDecodesVersion2WithWarningsFixture() throws {
        let session = try BillSessionCoding.decoder().decode(BillSession.self, from: fixtureData("v2-with-warnings"))
        let warnings = session.draft.warnings
        XCTAssertEqual(warnings.count, 3)
        XCTAssertEqual(warnings[0].id, UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(warnings[0].issue, .unparsedPriceRow("3,5"))
        XCTAssertEqual(warnings[0].rowLabel, "Soda")
        XCTAssertEqual(warnings[0].sourceRect, PixelRect(x: 12, y: 66, width: 288, height: 18))
        XCTAssertNil(warnings[0].itemID)
        XCTAssertFalse(warnings[0].isDismissed)
        XCTAssertEqual(warnings[1].itemID, UUID(uuidString: "10000000-0000-0000-0000-000000000002"))
        XCTAssertTrue(warnings[1].isDismissed)
        XCTAssertEqual(warnings[2].issue, .numberFormatGuessed(NumberFormat(decimalSeparator: ".", groupSeparator: ",", fractionDigits: 0, isGuessed: true)))
        XCTAssertEqual(session.draft.activeWarnings.map(\.id), [warnings[0].id, warnings[2].id])
        XCTAssertEqual(session.draft.items.map(\.name), ["Mofongo", "Tostones"], "the rest of the bill reads as before")
    }

    func testVersion1FilesMigrateWithNoWarnings() throws {
        for name in ["v1-in-progress", "v1-minimal"] {
            let old = try BillSessionCoding.decoder().decode(BillSession.self, from: fixtureData(name))
            XCTAssertTrue(old.draft.warnings.isEmpty, name)
            XCTAssertTrue(old.draft.activeWarnings.isEmpty, name)
        }
    }

    func testAVersion1BillIsWrittenBackAsVersion2() throws {
        let old = try BillSessionCoding.decoder().decode(BillSession.self, from: fixtureData("v1-in-progress"))
        let data = try BillSessionCoding.encoder().encode(old)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        let migrated = try BillSessionCoding.decoder().decode(BillSession.self, from: data)
        XCTAssertEqual(migrated, old, "migrating changes nothing but the version")
    }

    func testADraftWithoutAWarningsKeyDecodesAsNoWarnings() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData("v2-with-warnings")) as? [String: Any]
        )
        var draft = try XCTUnwrap(object["draft"] as? [String: Any])
        draft.removeValue(forKey: "warnings")
        object["draft"] = draft
        let data = try JSONSerialization.data(withJSONObject: object)
        let session = try BillSessionCoding.decoder().decode(BillSession.self, from: data)
        XCTAssertTrue(session.draft.warnings.isEmpty)
    }

    func testAVersion1FileOnDiskLoadsThroughTheDraftStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("esplitealo-migration-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try fixtureData("v1-in-progress").write(to: directory.appendingPathComponent(FileBillDraftStore.fileName))
        let session = try XCTUnwrap(try FileBillDraftStore(directory: directory).load())
        XCTAssertEqual(session.merchantName, "Fonda Doña Lola")
        XCTAssertTrue(session.draft.warnings.isEmpty)
    }

    // MARK: - Versioning

    func testRejectsFilesFromANewerSchemaVersion() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData("v1-minimal")) as? [String: Any]
        )
        object["schemaVersion"] = BillSession.currentSchemaVersion + 1
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BillSessionCoding.decoder().decode(BillSession.self, from: data)) { error in
            XCTAssertEqual(
                error as? BillSessionDecodingError,
                .unsupportedSchemaVersion(found: BillSession.currentSchemaVersion + 1)
            )
        }
    }

    func testRejectsFilesWithoutASchemaVersion() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData("v1-minimal")) as? [String: Any]
        )
        object.removeValue(forKey: "schemaVersion")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BillSessionCoding.decoder().decode(BillSession.self, from: data))
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try BillSessionCoding.decoder().decode(BillSession.self, from: Data("nope".utf8)))
    }
}
