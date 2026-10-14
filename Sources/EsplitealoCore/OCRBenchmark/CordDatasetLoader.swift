import Foundation

public struct CordReceiptRecord: Sendable {
    public var imageURL: URL
    public var groundTruth: ReceiptGroundTruth
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
            let parsed = try CordGroundTruthParser.parse(id: entry.id, data: gtData)
            records.append(CordReceiptRecord(imageURL: imageURL, groundTruth: parsed))
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
        let items = menuItems(from: json["menu"])
        let subtotal = amountMinor(from: json["sub_total"], keys: ["subtotal_price", "price"])
        let tax = amountMinor(from: json["sub_total"], keys: ["tax_price"]) ?? amountMinor(from: json["tax"], keys: ["price"])
        let total = amountMinor(from: json["total"], keys: ["total_price", "price"])
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

    private static func menuItems(from value: Any?) -> [GroundTruthItem] {
        if let array = value as? [[String: Any]] {
            return array.compactMap { item(from: $0) }
        }
        guard let menu = value as? [String: Any] else { return [] }
        if menu["nm"] is String {
            if let item = itemFromFlatMenu(menu) { return [item] }
            return []
        }
        let names = indexedStrings(menu["nm"])
        guard !names.isEmpty else { return [] }
        let prices = indexedStrings(menu["price"])
        let counts = indexedStrings(menu["cnt"] ?? menu["num"])
        var items: [GroundTruthItem] = []
        for (index, name) in names.sorted(by: { $0.key < $1.key }) {
            let priceString = prices[index] ?? ""
            guard let minor = digitsOnlyMinor(priceString) else { continue }
            let qty = parseQuantity(counts[index] ?? "1")
            items.append(GroundTruthItem(name: name, quantity: qty, lineTotalMinor: minor))
        }
        return items
    }

    private static func item(from dict: [String: Any]) -> GroundTruthItem? {
        let name = (dict["nm"] as? String) ?? (dict["name"] as? String) ?? ""
        guard !name.isEmpty else { return nil }
        let priceRaw = (dict["price"] as? String) ?? (dict["itemsubtotal"] as? String) ?? (dict["price"] as? Int).map(String.init) ?? ""
        guard let minor = digitsOnlyMinor(priceRaw) else { return nil }
        let qty = parseQuantity((dict["cnt"] as? String) ?? (dict["num"] as? String) ?? "1")
        return GroundTruthItem(name: name, quantity: qty, lineTotalMinor: minor)
    }

    private static func itemFromFlatMenu(_ menu: [String: Any]) -> GroundTruthItem? {
        item(from: menu)
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

    private static func amountMinor(from value: Any?, keys: [String]) -> Int? {
        guard let dict = value as? [String: Any] else {
            if let price = value as? String { return digitsOnlyMinor(price) }
            return nil
        }
        for key in keys {
            if let price = dict[key] as? String, let minor = digitsOnlyMinor(price) { return minor }
            if let price = dict[key] as? Int { return price }
        }
        return nil
    }

    /// CORD prices are often whole currency units without a decimal point; store as printed digits.
    public static func digitsOnlyMinor(_ raw: String) -> Int? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }
}
