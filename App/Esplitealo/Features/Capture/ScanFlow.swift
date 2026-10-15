import CoreGraphics
import EsplitealoCapture
import EsplitealoCore
import EsplitealoScanning
import Foundation
import Observation
import VisionKit

/// The capture flow behind Home's two buttons and the capture screen: check the camera permission, hand over to the
/// system camera or photo picker, read the receipt on the device, then give the draft to the `BillStore` and open
/// Review. Every state the screens show is a `Phase`; every outcome the system UIs report is a method here, so the
/// whole flow is tested without a camera.
///
/// Reading never blocks the main actor: the scan closure runs the Vision pipeline off it. A result that arrives
/// after the user cancelled is thrown away.
@MainActor @Observable
final class ScanFlow {
    enum Phase: Equatable {
        /// Nothing has started (Home, or the capture screen just pushed).
        case idle
        /// The camera cannot be used; the screen explains and offers the photo picker.
        case blocked(CaptureBlock)
        /// The system document camera or photo picker is on screen.
        case presenting(ScanSource)
        /// Reading the receipt.
        case processing
        case failed(ScanFailure)
        /// The draft is in the bill and Review is open.
        case finished
    }

    static let messageInterval: Duration = .milliseconds(1700)
    static let messageCount = 3
    static let manualEntryDelay: Duration = .seconds(8)

    private(set) var phase: Phase = .idle
    private(set) var source: ScanSource = .camera
    /// Which of the three status lines ("Leyendo el recibo", "Buscando los precios", "Cuadrando el total") shows.
    private(set) var messageIndex = 0
    /// Entering the items by hand is offered once reading takes a while, and after any failure.
    private(set) var offersManualEntry = false
    /// The reading in progress. Exposed so tests can wait for it.
    private(set) var scanTask: Task<Void, Never>?

    @ObservationIgnored private let store: BillStore
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let services: Services
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var timelineTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var pendingFixtureFailure: ScanFailure?
    /// Bumped whenever work is stopped, so something that was waiting (the permission prompt) knows it is stale.
    @ObservationIgnored private var generation = 0

    init(store: BillStore, router: AppRouter, services: Services, clock: any Clock<Duration> = ContinuousClock()) {
        self.store = store
        self.router = router
        self.services = services
        self.clock = clock
        pendingFixtureFailure = services.fixture?.failsFirstWith
    }

    // MARK: Starting

    /// Home's buttons: remember the source and push the capture screen, which starts the capture when it appears.
    func open(_ source: ScanSource) {
        stopWork()
        self.source = source
        phase = .idle
        router.push(.capture)
    }

    /// The capture screen appeared: start a capture, unless one is already under way. Coming back from Review
    /// (the bill is already handed over) starts a new one.
    func captureScreenAppeared() async {
        guard phase == .idle || phase == .finished else { return }
        await begin()
    }

    private func begin() async {
        stopWork()
        if source == .camera {
            guard services.isCameraSupported() else { return block(.unavailable) }
            var status = services.cameraStatus()
            if status == .notDetermined {
                let started = generation
                status = await services.requestCameraAccess()
                guard started == generation else { return } // cancelled while the system asked
            }
            switch status {
            case .authorized, .notDetermined: break
            case .denied: return block(.denied)
            case .restricted: return block(.unavailable)
            }
        }
        present()
    }

    /// Shows the system camera or photo picker, or, under a UI-test fixture, goes straight on.
    private func present() {
        guard let fixture = services.fixture else {
            phase = .presenting(source)
            return
        }
        if let failure = pendingFixtureFailure {
            pendingFixtureFailure = nil
            phase = .failed(failure)
            offersManualEntry = true
        } else {
            startReading(fixture.image)
        }
    }

    private func block(_ block: CaptureBlock) {
        phase = .blocked(block)
    }

    // MARK: What the system UIs report

    func cameraFinished(_ result: Result<CGImage, DocumentCameraError>) {
        switch result {
        case .success(let image): startReading(image)
        case .failure(.cancelled): cancel()
        case .failure(let error): fail(ScanFailure(error))
        }
    }

    /// `loadToken` is what `photoSelected()` returned: a photo that finishes loading after the user cancelled or
    /// started over is thrown away.
    func photoFinished(_ result: Result<CGImage, PhotoImportError>, loadToken: Int? = nil) {
        if let loadToken, loadToken != generation { return }
        switch result {
        case .success(let image): startReading(image)
        case .failure(let error): fail(ScanFailure(error))
        }
    }

    /// A photo was picked and is being loaded: the reading screen shows while it comes in (it can be slow from iCloud).
    @discardableResult
    func photoSelected() -> Int {
        stopWork()
        phase = .processing
        messageIndex = 0
        offersManualEntry = false
        startTimeline()
        return generation
    }

    /// The photo picker went away and no photo came back (the user closed it).
    func photoPickerClosedWithoutSelection() {
        guard phase == .presenting(.photoLibrary) else { return }
        cancel()
    }

    // MARK: Leaving and recovering

    /// Back to Home. Whatever was being read is dropped.
    func cancel() {
        stopWork()
        phase = .idle
        router.popToRoot()
    }

    /// "Tratar otra vez": the same source again.
    func retry() async {
        await begin()
    }

    /// "Elegir otra foto", and "Elegir foto" on the camera-blocked screen.
    func chooseAnotherPhoto() {
        stopWork()
        source = .photoLibrary
        present() // the photo picker needs no permission
    }

    /// "Añadir los artículos a mano": an empty bill, then Review.
    func enterItemsManually() {
        stopWork()
        handOver(ReceiptDraft())
    }

    // MARK: Reading

    private func startReading(_ image: CGImage) {
        stopWork()
        phase = .processing
        messageIndex = 0
        offersManualEntry = false
        startTimeline()
        let scan = services.scan
        scanTask = Task { [weak self] in
            let outcome: Result<ReceiptDraft, any Error>
            do {
                outcome = .success(try await scan(image))
            } catch {
                outcome = .failure(error)
            }
            guard !Task.isCancelled, let self, phase == .processing else { return }
            stopTimeline()
            switch outcome {
            case .success(let draft): handOver(draft)
            case .failure(let error): fail(ScanFailure(error))
            }
        }
    }

    private func fail(_ failure: ScanFailure) {
        stopWork()
        phase = .failed(failure)
        offersManualEntry = true
    }

    private func handOver(_ draft: ReceiptDraft) {
        store.startNewBill(draft: draft)
        phase = .finished
        router.push(.review)
    }

    // MARK: Status messages and the manual-entry offer

    private func startTimeline() {
        let clock = clock
        timelineTasks = [
            Task { [weak self] in
                while !Task.isCancelled {
                    do { try await clock.sleep(for: Self.messageInterval) } catch { return }
                    self?.messageIndex = ((self?.messageIndex ?? 0) + 1) % Self.messageCount
                }
            },
            Task { [weak self] in
                do { try await clock.sleep(for: Self.manualEntryDelay) } catch { return }
                self?.offersManualEntry = true
            },
        ]
    }

    private func stopTimeline() {
        timelineTasks.forEach { $0.cancel() }
        timelineTasks = []
    }

    private func stopWork() {
        generation += 1
        scanTask?.cancel()
        scanTask = nil
        stopTimeline()
    }
}

extension ScanFlow {
    /// Everything the flow needs from the outside world, so tests and UI tests can stand in for it.
    struct Services {
        /// Used instead of the system camera and photo picker, for UI tests on a simulator without a camera.
        struct Fixture {
            var image: CGImage
            /// The first attempt fails with this, the next ones work: lets a test walk "try again".
            var failsFirstWith: ScanFailure?
        }

        var cameraStatus: () -> CameraPermissionStatus
        var requestCameraAccess: () async -> CameraPermissionStatus
        var isCameraSupported: () -> Bool
        /// Reads one image into a draft. Runs off the main actor.
        var scan: @Sendable (CGImage) async throws -> ReceiptDraft
        var fixture: Fixture?

        /// The real camera, Vision and parser.
        static var live: Services {
            Services(
                cameraStatus: { CameraPermission.currentStatus() },
                requestCameraAccess: { await CameraPermission.requestAccessIfNeeded() },
                isCameraSupported: { VNDocumentCameraViewController.isSupported },
                scan: { image in try await ReceiptScanPipeline().scan(image: image).draft },
                fixture: nil
            )
        }
    }
}
