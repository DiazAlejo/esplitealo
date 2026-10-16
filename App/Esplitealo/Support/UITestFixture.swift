import EsplitealoCore
import Foundation

/// Starts the app from a bill instead of the camera, for UI tests (the simulator has no camera). Honoured only with
/// `--uitesting`:
///
/// - `--fixture=<name>` starts a bill: `parsed` (a scan with a flagged row whose receipt does not add up), `unsure`
///   (a scan with two prices the parser could not read, so two warnings and a receipt that does not add up),
///   `scanned` (the same receipt fixed, nobody at the table), `table` (the same receipt with four people, nothing marked),
///   `quantities` (lines of several units, three people, nothing marked), `midway` (four people, items marked),
///   `complete` (all marked, ready to share), `mismatch` (all marked, but the receipt does not add up), `service` (all
///   marked, the receipt has a service charge), `empty`.
/// - `--start-at=<screen>` opens that screen (`review`, `people`, `mark`, `totals`) with the earlier ones behind it.
enum UITestFixture {
    static func apply(arguments: [String], store: BillStore, router: AppRouter) {
        guard arguments.contains("--uitesting") else { return }

        let session: BillSession? = switch value("--fixture=", in: arguments) {
        case "parsed": ReviewSamples.parsedSession()
        case "unsure": ReviewSamples.unsureSession()
        case "scanned": SampleBill.scanned()
        case "table": AssignSamples.table()
        case "quantities": AssignSamples.quantities()
        case "midway": SampleBill.midway()
        case "empty": BillSession(draft: ReceiptDraft())
        case "complete": SampleBill.complete()
        case "mismatch": TotalsSamples.mismatch()
        case "service": TotalsSamples.serviceCharge()
        default: nil
        }
        if let session {
            store.startNewBill(draft: session.draft)
            store.update { $0 = session }
        }

        if let name = value("--start-at=", in: arguments), let route = AppRoute(rawValue: name), route != .home {
            let flow = AppRoute.allCases.filter { $0 != .home }
            router.show(Array(flow.prefix(through: flow.firstIndex(of: route) ?? 0)))
        }
    }

    private static func value(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
}
