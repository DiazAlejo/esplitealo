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
    /// The store the app runs with. `--uitesting` keeps the draft in a throwaway directory.
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> BillStore {
        let directory: URL
        if arguments.contains("--uitesting") {
            directory = DraftLocation.temporaryDirectory()
        } else {
            // If Application Support is unreachable the bill still works; it just is not autosaved.
            directory = (try? DraftLocation.defaultDirectory()) ?? DraftLocation.temporaryDirectory()
        }
        return BillStore(draftStore: FileBillDraftStore(directory: directory))
    }
}
