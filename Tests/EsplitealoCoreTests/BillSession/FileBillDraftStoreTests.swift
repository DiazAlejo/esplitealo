import XCTest
@testable import EsplitealoCore

final class FileBillDraftStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("esplitealo-draft-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> FileBillDraftStore {
        FileBillDraftStore(directory: directory)
    }

    private func filesInDirectory() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    func testLoadReturnsNilWhenThereIsNoDraft() throws {
        XCTAssertNil(try makeStore().load())
    }

    func testLoadReturnsNilWhenTheDirectoryDoesNotExistYet() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertNil(try makeStore().load())
    }

    func testSaveThenLoadReturnsTheSameBill() throws {
        let store = makeStore()
        let session = BillSession.sampleReadyToShare()
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
    }

    func testSaveCreatesMissingDirectories() throws {
        let nested = directory.appendingPathComponent("a/b/Draft", isDirectory: true)
        let store = FileBillDraftStore(directory: nested)
        try store.save(BillSession.sampleAssigned())
        XCTAssertNotNil(try store.load())
    }

    func testSaveReplacesThePreviousDraft() throws {
        let store = makeStore()
        try store.save(BillSession.sampleReadyToShare())
        var updated = BillSession.sampleAssigned()
        updated.merchantName = "Otro sitio"
        try store.save(updated)
        XCTAssertEqual(try store.load(), updated)
    }

    func testDraftIsOneJsonFileAndNoTemporaryFilesAreLeftBehind() throws {
        let store = makeStore()
        try store.save(BillSession.sampleReadyToShare())
        try store.save(BillSession.sampleAssigned())
        XCTAssertEqual(try filesInDirectory(), [FileBillDraftStore.fileName])
        XCTAssertEqual(FileBillDraftStore.fileName, "draft.json")
    }

    func testFileHoldsTheVersionedJSON() throws {
        try makeStore().save(BillSession.sampleReadyToShare())
        let data = try Data(contentsOf: directory.appendingPathComponent(FileBillDraftStore.fileName))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, BillSession.currentSchemaVersion)
    }

    func testDraftSurvivesANewStoreInstance() throws {
        let session = BillSession.sampleReadyToShare()
        try makeStore().save(session)
        XCTAssertEqual(try makeStore().load(), session)
    }

    func testDeleteRemovesTheDraft() throws {
        let store = makeStore()
        try store.save(BillSession.sampleReadyToShare())
        try store.delete()
        XCTAssertNil(try store.load())
        XCTAssertEqual(try filesInDirectory(), [])
    }

    func testDeleteWithoutADraftDoesNothing() throws {
        XCTAssertNoThrow(try makeStore().delete())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertNoThrow(try makeStore().delete())
    }

    func testLoadThrowsForACorruptFileAndLeavesItInPlace() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(FileBillDraftStore.fileName)
        try Data("{ not json".utf8).write(to: file)
        XCTAssertThrowsError(try makeStore().load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testLoadThrowsForADraftFromANewerApp() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let future = BillSession.currentSchemaVersion + 1
        let json = #"{"schemaVersion": \#(future)}"#
        try Data(json.utf8).write(to: directory.appendingPathComponent(FileBillDraftStore.fileName))
        XCTAssertThrowsError(try makeStore().load()) { error in
            XCTAssertEqual(error as? BillSessionDecodingError, .unsupportedSchemaVersion(found: future))
        }
    }

    func testStoreWorksThroughTheProtocol() throws {
        let store: any BillDraftStore = makeStore()
        try store.save(BillSession.sampleTwoPeopleOneItem())
        XCTAssertNotNil(try store.load())
        try store.delete()
        XCTAssertNil(try store.load())
    }
}
