import EsplitealoCore
import Foundation

public struct ScanLabExportPayload: Equatable, Sendable, Codable {
    public var recognizedText: RecognizedText
    public var draft: ScanLabDraftExport
    public var ocrDurationMilliseconds: Int?

    public init(recognizedText: RecognizedText, draft: ScanLabDraftExport, ocrDurationMilliseconds: Int?) {
        self.recognizedText = recognizedText
        self.draft = draft
        self.ocrDurationMilliseconds = ocrDurationMilliseconds
    }
}

public struct ScanLabDraftExport: Equatable, Sendable, Codable {
    public var items: [ScanLabItemExport]
    public var subtotalMinorUnits: Int?
    public var taxMinorUnits: Int?
    public var tipMinorUnits: Int?
    public var totalMinorUnits: Int?
    public var reconciles: Bool
    public var issues: [String]
    public var flaggedRows: [String]
}

public struct ScanLabItemExport: Equatable, Sendable, Codable {
    public var name: String
    public var quantity: Int
    public var lineTotalMinorUnits: Int
    public var flags: [String]
}

public enum ScanLabJSONExport {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func exportPayload(
        from result: ReceiptScanResult,
        display: ScanLabDisplayResult
    ) -> ScanLabExportPayload {
        let draft = result.draft
        let items = draft.items.map {
            ScanLabItemExport(
                name: $0.name,
                quantity: $0.quantity,
                lineTotalMinorUnits: $0.lineTotal.minorUnits,
                flags: $0.flags.map(\.rawValue).sorted()
            )
        }
        let draftExport = ScanLabDraftExport(
            items: items,
            subtotalMinorUnits: draft.subtotal?.minorUnits,
            taxMinorUnits: draft.tax?.minorUnits,
            tipMinorUnits: draft.tip?.minorUnits,
            totalMinorUnits: draft.total?.minorUnits,
            reconciles: draft.reconciles,
            issues: display.issues,
            flaggedRows: display.flaggedRows
        )
        return ScanLabExportPayload(
            recognizedText: result.recognizedText,
            draft: draftExport,
            ocrDurationMilliseconds: display.ocrDurationMilliseconds
        )
    }

    public static func encodeFullResult(
        _ result: ReceiptScanResult,
        ocrDurationMilliseconds: Int?
    ) throws -> Data {
        let display = ScanLabResultBuilder.display(from: result, ocrDurationMilliseconds: ocrDurationMilliseconds)
        let payload = exportPayload(from: result, display: display)
        return try makeEncoder().encode(payload)
    }

    public static func encodeRecognizedText(_ recognized: RecognizedText) throws -> Data {
        try makeEncoder().encode(recognized)
    }
}
