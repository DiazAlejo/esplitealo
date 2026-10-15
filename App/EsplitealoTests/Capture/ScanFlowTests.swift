import CoreGraphics
import EsplitealoCapture
import EsplitealoCore
import EsplitealoScanning
import Foundation
import Synchronization
import Testing
@testable import Esplitealo

/// The capture flow without a camera: permission states, what the system camera and photo picker hand back, the
/// processing timeline, and where a good or bad scan sends the user.
@MainActor
struct ScanFlowTests {
    let clock = ManualClock()
    let drafts = RecordingDraftStore()
    let router = AppRouter()
    let store: BillStore
    let scanned = SampleBill.scannedDraft()

    init() {
        store = BillStore(draftStore: drafts)
    }

    /// A scanner the test controls: it returns `result` once `release()` has been called (at once if `gated` is false).
    final class FakeScanner: Sendable {
        private let state = Mutex(State())
        private struct State {
            var calls = 0
            var waiters: [CheckedContinuation<Void, Never>] = []
            var open = true
        }

        let result: Result<ReceiptDraft, any Error>

        init(_ result: Result<ReceiptDraft, any Error>, gated: Bool = false) {
            self.result = result
            state.withLock { $0.open = !gated }
        }

        var calls: Int { state.withLock { $0.calls } }

        func scan(_ image: CGImage) async throws -> ReceiptDraft {
            state.withLock { $0.calls += 1 }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let resumeNow = state.withLock { state -> Bool in
                    if state.open { return true }
                    state.waiters.append(continuation)
                    return false
                }
                if resumeNow { continuation.resume() }
            }
            return try result.get()
        }

        func release() {
            let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
                state.open = true
                defer { state.waiters = [] }
                return state.waiters
            }
            waiters.forEach { $0.resume() }
        }
    }

    final class PermissionProbe: Sendable {
        private let state = Mutex(0)
        var requests: Int { state.withLock { $0 } }
        func didRequest() { state.withLock { $0 += 1 } }
    }

    func image() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    func makeFlow(
        camera: CameraPermissionStatus = .authorized,
        afterRequest: CameraPermissionStatus = .authorized,
        supported: Bool = true,
        scanner: FakeScanner? = nil,
        probe: PermissionProbe = PermissionProbe(),
        fixture: ScanFlow.Services.Fixture? = nil
    ) -> ScanFlow {
        let scanner = scanner ?? FakeScanner(.success(scanned))
        let services = ScanFlow.Services(
            cameraStatus: { camera },
            requestCameraAccess: { probe.didRequest(); return afterRequest },
            isCameraSupported: { supported },
            scan: { try await scanner.scan($0) },
            fixture: fixture
        )
        return ScanFlow(store: store, router: router, services: services, clock: clock)
    }

    /// Opens the capture screen the way Home does and lets the screen start the capture.
    func open(_ flow: ScanFlow, _ source: ScanSource) async {
        flow.open(source)
        await flow.captureScreenAppeared()
    }

    // MARK: Starting from Home

    @Test func openingFromHomePushesTheCaptureScreenWithTheChosenSource() {
        let flow = makeFlow()
        flow.open(.photoLibrary)
        #expect(router.path == [.capture])
        #expect(flow.source == .photoLibrary)
        #expect(flow.phase == .idle)
    }

    // MARK: Permission states

    @Test func anAuthorizedCameraShowsTheDocumentCamera() async {
        let probe = PermissionProbe()
        let flow = makeFlow(camera: .authorized, probe: probe)
        await open(flow, .camera)
        #expect(flow.phase == .presenting(.camera))
        #expect(probe.requests == 0)
    }

    @Test func anUndecidedCameraAsksOnceAndShowsTheCameraWhenGranted() async {
        let probe = PermissionProbe()
        let flow = makeFlow(camera: .notDetermined, afterRequest: .authorized, probe: probe)
        await open(flow, .camera)
        #expect(probe.requests == 1)
        #expect(flow.phase == .presenting(.camera))
    }

    @Test func anUndecidedCameraThatIsRefusedShowsTheDeniedScreen() async {
        let flow = makeFlow(camera: .notDetermined, afterRequest: .denied)
        await open(flow, .camera)
        #expect(flow.phase == .blocked(.denied))
    }

    @Test func aDeniedCameraShowsTheDeniedScreenWithoutAsking() async {
        let probe = PermissionProbe()
        let flow = makeFlow(camera: .denied, probe: probe)
        await open(flow, .camera)
        #expect(flow.phase == .blocked(.denied))
        #expect(probe.requests == 0)
    }

    @Test func aRestrictedCameraAndADeviceWithoutOneShowThePhotoOnlyScreen() async {
        let restricted = makeFlow(camera: .restricted)
        await open(restricted, .camera)
        #expect(restricted.phase == .blocked(.unavailable))

        let unsupported = makeFlow(camera: .authorized, supported: false)
        await open(unsupported, .camera)
        #expect(unsupported.phase == .blocked(.unavailable))
    }

    @Test func choosingAPhotoNeverTouchesTheCameraPermission() async {
        let probe = PermissionProbe()
        let flow = makeFlow(camera: .denied, probe: probe)
        await open(flow, .photoLibrary)
        #expect(flow.phase == .presenting(.photoLibrary))
        #expect(probe.requests == 0)
    }

    @Test func theDeniedScreenOffersThePhotoPicker() async {
        let flow = makeFlow(camera: .denied)
        await open(flow, .camera)
        flow.chooseAnotherPhoto()
        #expect(flow.source == .photoLibrary)
        #expect(flow.phase == .presenting(.photoLibrary))
    }

    // MARK: A scan that works

    @Test func aCapturedImageIsReadThenTheDraftGoesToTheBillAndReviewOpens() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        #expect(flow.phase == .processing)
        #expect(store.session == nil)
        await flow.scanTask?.value
        #expect(store.session?.draft == BillSession(draft: scanned).draft)
        #expect(router.path == [.capture, .review])
        #expect(flow.phase == .finished)
    }

    @Test func aPickedPhotoFollowsTheSamePath() async {
        let flow = makeFlow()
        await open(flow, .photoLibrary)
        flow.photoFinished(.success(image()))
        await flow.scanTask?.value
        #expect(store.session?.draft.items.count == scanned.items.count)
        #expect(router.current == .review)
    }

    @Test func aNewScanReplacesTheBillInProgress() async {
        store.startNewBill(draft: SampleBill.scannedDraft())
        store.update { $0.addParticipant(name: "Marisol") }
        let flow = makeFlow(scanner: FakeScanner(.success(ReceiptDraft())))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        #expect(store.session?.participants.isEmpty == true)
        #expect(store.session?.draft.items.isEmpty == true)
    }

    // MARK: A scan that does not

    @Test(arguments: [
        (ReceiptScanError.noTextFound, ScanFailure.unreadable),
        (.imageTooSmallOrUnreadable(minWordHeight: 6), .unreadable),
        (.receiptTooLongForSinglePhoto(aspectRatio: 6, maximumAspectRatio: 4), .tooLong),
        (.recognitionUnavailable, .unreadable),
    ])
    func aScanErrorShowsTheMatchingFailure(error: ReceiptScanError, expected: ScanFailure) async {
        let flow = makeFlow(scanner: FakeScanner(.failure(error)))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        #expect(flow.phase == .failed(expected))
        #expect(store.session == nil)
        #expect(router.path == [.capture])
    }

    @Test func anUnexpectedErrorIsTreatedAsAnUnreadableReceipt() async {
        struct Odd: Error {}
        let flow = makeFlow(scanner: FakeScanner(.failure(Odd())))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        #expect(flow.phase == .failed(.unreadable))
    }

    @Test(arguments: [
        (DocumentCameraError.tooManyPages, ScanFailure.tooManyPages),
        (.noImage, .unreadable),
        (.failed("boom"), .cameraFailed),
    ])
    func aDocumentCameraErrorShowsTheMatchingFailure(error: DocumentCameraError, expected: ScanFailure) async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.failure(error))
        #expect(flow.phase == .failed(expected))
        #expect(router.path == [.capture])
    }

    @Test(arguments: [PhotoImportError.loadFailed, .notAnImage])
    func aPhotoThatCannotBeLoadedShowsTheMatchingFailure(error: PhotoImportError) async {
        let flow = makeFlow()
        await open(flow, .photoLibrary)
        flow.photoFinished(.failure(error))
        #expect(flow.phase == .failed(.photoNotLoaded))
    }

    // MARK: Leaving

    @Test func cancellingTheCameraGoesBackHome() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.failure(.cancelled))
        #expect(router.path.isEmpty)
        #expect(flow.phase == .idle)
    }

    @Test func closingThePhotoPickerWithoutAPhotoGoesBackHome() async {
        let flow = makeFlow()
        await open(flow, .photoLibrary)
        flow.photoPickerClosedWithoutSelection()
        #expect(router.path.isEmpty)
    }

    @Test func closingThePhotoPickerAfterAPhotoWasPickedDoesNothing() async {
        let flow = makeFlow(scanner: FakeScanner(.success(scanned), gated: true))
        await open(flow, .photoLibrary)
        flow.photoSelected()
        flow.photoPickerClosedWithoutSelection()
        #expect(flow.phase == .processing)
        flow.photoFinished(.success(image()))
        #expect(router.path == [.capture])
    }

    @Test func cancellingWhileReadingDiscardsTheLateResult() async {
        let scanner = FakeScanner(.success(scanned), gated: true)
        let flow = makeFlow(scanner: scanner)
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        let task = flow.scanTask
        flow.cancel()
        scanner.release()
        await task?.value
        #expect(store.session == nil)
        #expect(router.path.isEmpty)
        #expect(flow.phase == .idle)
    }

    @Test func goingBackFromAFailureReturnsHome() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.failure(.tooManyPages))
        flow.cancel()
        #expect(router.path.isEmpty)
    }

    // MARK: Recovering

    @Test func tryAgainOpensTheSameSourceAgain() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.failure(.tooManyPages))
        await flow.retry()
        #expect(flow.phase == .presenting(.camera))
    }

    @Test func tryAgainFromAPhotoFailureOpensThePickerAgain() async {
        let flow = makeFlow()
        await open(flow, .photoLibrary)
        flow.photoFinished(.failure(.loadFailed))
        await flow.retry()
        #expect(flow.phase == .presenting(.photoLibrary))
    }

    @Test func chooseAnotherPhotoAfterAFailureOpensThePicker() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.failure(.tooManyPages))
        flow.chooseAnotherPhoto()
        #expect(flow.phase == .presenting(.photoLibrary))
        #expect(flow.source == .photoLibrary)
    }

    @Test func enteringItemsByHandStartsAnEmptyBillAndOpensReview() async {
        let flow = makeFlow(scanner: FakeScanner(.failure(ReceiptScanError.noTextFound)))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        flow.enterItemsManually()
        #expect(store.session?.draft.items.isEmpty == true)
        #expect(router.path == [.capture, .review])
        #expect(flow.phase == .finished)
    }

    @Test func enteringItemsByHandWhileStillReadingStopsTheReading() async {
        let scanner = FakeScanner(.success(scanned), gated: true)
        let flow = makeFlow(scanner: scanner)
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        let task = flow.scanTask
        flow.enterItemsManually()
        scanner.release()
        await task?.value
        #expect(store.session?.draft.items.isEmpty == true)
        #expect(router.path == [.capture, .review])
    }

    @Test func comingBackToCaptureFromReviewStartsANewCapture() async {
        let flow = makeFlow()
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        #expect(flow.phase == .finished)
        await flow.captureScreenAppeared()
        #expect(flow.phase == .presenting(.camera))
    }

    @Test func theCaptureScreenAppearingAgainWhileBusyChangesNothing() async {
        let flow = makeFlow(scanner: FakeScanner(.success(scanned), gated: true))
        await open(flow, .camera)
        await flow.captureScreenAppeared()
        #expect(flow.phase == .presenting(.camera))
        flow.cameraFinished(.success(image()))
        await flow.captureScreenAppeared()
        #expect(flow.phase == .processing)
    }

    // MARK: The processing screen

    @Test func theStatusMessageChangesEveryFewSecondsAndWrapsAround() async {
        let flow = makeFlow(scanner: FakeScanner(.success(scanned), gated: true))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        #expect(flow.messageIndex == 0)
        await clock.waitForSleepers(count: 2)
        clock.advance(by: ScanFlow.messageInterval)
        await clock.waitForSleepers(count: 2)
        #expect(flow.messageIndex == 1)
        clock.advance(by: ScanFlow.messageInterval)
        await clock.waitForSleepers(count: 2)
        #expect(flow.messageIndex == 2)
        clock.advance(by: ScanFlow.messageInterval)
        await clock.waitForSleepers(count: 2)
        #expect(flow.messageIndex == 0)
        #expect(ScanFlow.messageCount == 3)
    }

    @Test func enteringItemsByHandIsOfferedOnlyAfterEightSeconds() async {
        let flow = makeFlow(scanner: FakeScanner(.success(scanned), gated: true))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        #expect(!flow.offersManualEntry)
        await clock.waitForSleepers(count: 2)
        clock.advance(by: .seconds(7))
        await clock.waitForSleepers(count: 2)
        #expect(!flow.offersManualEntry)
        clock.advance(by: .seconds(1))
        await clock.waitForSleepers(count: 1)
        for _ in 0 ..< 50 { await Task.yield() } // let the woken task finish
        #expect(flow.offersManualEntry)
        #expect(ScanFlow.manualEntryDelay == .seconds(8))
    }

    @Test func theTimersStopWhenReadingEnds() async {
        let scanner = FakeScanner(.success(scanned), gated: true)
        let flow = makeFlow(scanner: scanner)
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await clock.waitForSleepers(count: 2)
        scanner.release()
        await flow.scanTask?.value
        await clock.waitForSleepers(count: 0)
        #expect(clock.sleeperCount == 0)
    }

    @Test func eachReadingStartsWithTheFirstMessageAndNoManualOffer() async {
        let flow = makeFlow(scanner: FakeScanner(.failure(ReceiptScanError.noTextFound)))
        await open(flow, .camera)
        flow.cameraFinished(.success(image()))
        await flow.scanTask?.value
        await flow.retry()
        flow.cameraFinished(.success(image()))
        #expect(flow.messageIndex == 0)
        #expect(!flow.offersManualEntry)
    }

    // MARK: Fixtures (UI tests, no camera)

    @Test func aFixtureSkipsTheSystemCameraAndReadsStraightAway() async {
        let flow = makeFlow(fixture: .init(image: image(), failsFirstWith: nil))
        await open(flow, .camera)
        #expect(flow.phase == .processing)
        await flow.scanTask?.value
        #expect(router.current == .review)
    }

    @Test func aFixtureCanFailTheFirstAttemptOnly() async {
        let flow = makeFlow(fixture: .init(image: image(), failsFirstWith: .tooManyPages))
        await open(flow, .camera)
        #expect(flow.phase == .failed(.tooManyPages))
        await flow.retry()
        await flow.scanTask?.value
        #expect(router.current == .review)
    }

    @Test func aFixtureStillHonoursThePermissionStates() async {
        let flow = makeFlow(camera: .denied, fixture: .init(image: image(), failsFirstWith: nil))
        await open(flow, .camera)
        #expect(flow.phase == .blocked(.denied))
    }
}
