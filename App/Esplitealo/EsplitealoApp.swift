import EsplitealoCore
import EsplitealoDesign
import SwiftUI

@main
struct EsplitealoApp: App {
    @State private var store: BillStore
    @State private var router: AppRouter
    @State private var scanFlow: ScanFlow

    init() {
        DesignFonts.registerAll()
        let store = BillStore.live()
        let router = AppRouter()
        UITestFixture.apply(arguments: ProcessInfo.processInfo.arguments, store: store, router: router)
        _store = State(initialValue: store)
        _router = State(initialValue: router)
        _scanFlow = State(initialValue: ScanFlow(store: store, router: router, services: Self.scanServices()))
    }

    /// The real camera and Vision. Debug builds can swap in a fixture receipt for UI tests (see `ScanLaunchConfiguration`).
    private static func scanServices() -> ScanFlow.Services {
        #if DEBUG
        if let configuration = ScanLaunchConfiguration() {
            do {
                return try configuration.services()
            } catch {
                fatalError("Could not set up the UI-test scan services: \(error)")
            }
        }
        #endif
        return .live
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(scanFlow)
                .espScreenBackground()
        }
    }
}

extension BillStore {
    /// The store the app runs with. `--uitesting` keeps the draft in a throwaway directory (or the one named by `--uitesting-draft-dir`).
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> BillStore {
        let directory: URL
        if arguments.contains("--uitesting") {
            directory = uiTestDraftDirectory(arguments) ?? DraftLocation.temporaryDirectory()
        } else {
            // If Application Support is unreachable the bill still works; it just is not autosaved.
            directory = (try? DraftLocation.defaultDirectory()) ?? DraftLocation.temporaryDirectory()
        }
        let draftStore = FileBillDraftStore(directory: directory)
        if arguments.contains("--uitesting"), arguments.contains("--uitesting-resume-prompt") {
            // A bill left behind by a previous launch, so the "¿Seguimos con tu cuenta?" prompt can be tested.
            try? draftStore.save(SampleBill.midway())
        }
        return BillStore(draftStore: draftStore)
    }

    /// `--uitesting-draft-dir <path>` (Debug only) keeps the draft in a directory that survives a relaunch, so a UI
    /// test can quit the app and start it again.
    private static func uiTestDraftDirectory(_ arguments: [String]) -> URL? {
        #if DEBUG
        guard let index = arguments.firstIndex(of: "--uitesting-draft-dir"), arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        #else
        return nil
        #endif
    }
}
