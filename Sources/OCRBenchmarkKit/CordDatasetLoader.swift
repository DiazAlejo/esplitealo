import EsplitealoCore
import Foundation

public struct CordReceiptRecord: Sendable {
    public var imageURL: URL
    public var groundTruth: ReceiptGroundTruth
    public var groundTruthJSON: String
    public var isInProductScope: Bool
}

/// Loads CORD v2 samples from a local cache (images + `*.gt.json` sidecars produced by `Scripts/fetch-cord-benchmark.py`).
public enum CordDatasetLoader {
    public static func load(from cacheDirectory: URL, limit: Int? = nil) throws -> [CordReceiptRecord] {
        let manifestURL = cacheDirectory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }
        let manifest = try JSONDecoder().decode(CordManifest.self, from: Data(contentsOf: manifestURL))
        var records: [CordReceiptRecord] = []
        for entry in manifest.entries {
            if let limit, records.count >= limit { break }
            let gtURL = cacheDirectory.appendingPathComponent(entry.groundTruthFile)
            let imageURL = cacheDirectory.appendingPathComponent(entry.imageFile)
            guard FileManager.default.fileExists(atPath: gtURL.path),
                  FileManager.default.fileExists(atPath: imageURL.path)
            else { continue }
            let gtData = try Data(contentsOf: gtURL)
            let jsonText = String(data: gtData, encoding: .utf8) ?? ""
            let parsed = try CordGroundTruthParser.parse(id: entry.id, data: gtData)
            let inScope = CordBenchmarkScope.isInProductScope(groundTruthJSON: jsonText, groundTruth: parsed)
            records.append(
                CordReceiptRecord(
                    imageURL: imageURL,
                    groundTruth: parsed,
                    groundTruthJSON: jsonText,
                    isInProductScope: inScope
                )
            )
        }
        return records
    }
}

private struct CordManifest: Decodable {
    struct Entry: Decodable {
        var id: String
        var imageFile: String
        var groundTruthFile: String
    }

    var entries: [Entry]
}

public enum CordGroundTruthParser {
    public static func parse(id: String, data: Data) throws -> ReceiptGroundTruth {
        let rootObject = try JSONSerialization.jsonObject(with: data)
        let json = unwrapRoot(rootObject)
        let format = PriceStringParsing.inferFormat(from: priceStrings(in: json))
        let items = menuItems(from: json["menu"], format: format)
        let subtotal = amountMinor(from: json["sub_total"], keys: ["subtotal_price", "price"], format: format)
        let tax = amountMinor(from: json["sub_total"], keys: ["tax_price"], format: format)
            ?? amountMinor(from: json["tax"], keys: ["price"], format: format)
        let total = amountMinor(from: json["total"], keys: ["total_price", "price"], format: format)
        return ReceiptGroundTruth(
            id: id,
            items: items,
            subtotalMinor: subtotal,
            taxMinor: tax,
            totalMinor: total,
            expectsReconciles: nil
        )
    }

    private static func unwrapRoot(_ value: Any) -> [String: Any] {
        if let dict = value as? [String: Any], let inner = dict["gt_parse"] as? [String: Any] {
            return inner
        }
        return value as? [String: Any] ?? [:]
    }

    private static func menuItems(from value: Any?, format: NumberFormat) -> [GroundTruthItem] {
        if let array = value as? [[String: Any]] {
            return array.compactMap { item(from: $0, format: format) }
        }
        guard let menu = value as? [String: Any] else { return [] }
        if menu["nm"] is String {
            if let item = item(from: menu, format: format) { return [item] }
            return []
        }
        let names = indexedStrings(menu["nm"])
        guard !names.isEmpty else { return [] }
        let prices = indexedStrings(menu["price"])
        let counts = indexedStrings(menu["cnt"] ?? menu["num"])
        var items: [GroundTruthItem] = []
        for (index, name) in names.sorted(by: { $0.key < $1.key }) {
            let priceString = prices[index] ?? ""
            guard let minor = minor(priceString, format: format) else { continue }
            let qty = parseQuantity(counts[index] ?? "1")
            items.append(GroundTruthItem(name: name, quantity: qty, lineTotalMinor: minor))
        }
        return items
    }

    private static func item(from dict: [String: Any], format: NumberFormat) -> GroundTruthItem? {
        let name = (dict["nm"] as? String) ?? (dict["name"] as? String) ?? ""
        guard !name.isEmpty else { return nil }
        let priceRaw = (dict["price"] as? String) ?? (dict["itemsubtotal"] as? String) ?? (dict["price"] as? Int).map(String.init) ?? ""
        guard let minor = minor(priceRaw, format: format) else { return nil }
        let qty = parseQuantity((dict["cnt"] as? String) ?? (dict["num"] as? String) ?? "1")
        return GroundTruthItem(name: name, quantity: qty, lineTotalMinor: minor)
    }

    private static func indexedStrings(_ value: Any?) -> [String: String] {
        if let string = value as? String { return ["0": string] }
        guard let dict = value as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (key, val) in dict {
            if let s = val as? String { out[key] = s }
        }
        return out
    }

    private static func parseQuantity(_ raw: String) -> Int {
        let digits = raw.prefix { $0.isNumber }
        if let q = Int(digits), q > 0 { return q }
        return 1
    }

    private static func amountMinor(from value: Any?, keys: [String], format: NumberFormat) -> Int? {
        guard let dict = value as? [String: Any] else {
            if let price = value as? String { return minor(price, format: format) }
            return nil
        }
        for key in keys {
            if let price = dict[key] as? String, let value = minor(price, format: format) { return value }
            if let price = dict[key] as? Int, let value = minor(String(price), format: format) { return value }
        }
        return nil
    }

    /// Interprets a printed price with the same per-receipt number format the parser infers,
    /// so whole-unit prices ("12" on a USD receipt, "12.500" on an IDR one) compare equal to parser output.
    public static func minor(_ raw: String, format: NumberFormat) -> Int? {
        PriceStringParsing.minorUnits(of: raw, format: format)
    }

    private static func priceStrings(in value: Any) -> [String] {
        if let dict = value as? [String: Any] {
            return dict.flatMap { key, child -> [String] in
                if let text = child as? String {
                    return key.contains("price") || key.contains("subtotal") ? [text] : []
                }
                return priceStrings(in: child)
            }
        }
        if let array = value as? [Any] { return array.flatMap(priceStrings) }
        return []
    }
}
