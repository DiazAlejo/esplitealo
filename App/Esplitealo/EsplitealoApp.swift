import EsplitealoCore
import EsplitealoDesign
import SwiftUI

@main
struct EsplitealoApp: App {
    @State private var store: BillStore
    @State private var router = AppRouter()

    init() {
        DesignFonts.registerAll()
        _store = State(initialValue: BillStore.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
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
