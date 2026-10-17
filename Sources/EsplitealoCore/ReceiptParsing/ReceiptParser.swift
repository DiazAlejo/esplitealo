import Foundation

public struct ReceiptParser: Sendable {
    public var preferredFormat: NumberFormat?

    public init(preferredFormat: NumberFormat? = .usdCents) {
        self.preferredFormat = preferredFormat
    }

    public func parse(_ text: RecognizedText) -> ReceiptDraft {
        let rows = RowBuilder.rows(from: text.lines)
        return parseRows(rows)
    }

    /// Human-readable rebuilt row lines for debugging (Scanner Lab and fixtures).
    public func rebuiltRowDescriptions(from text: RecognizedText) -> [String] {
        RowBuilder.rows(from: text.lines).map { row in
            if row.cells.isEmpty {
                return row.words.map(\.text).joined(separator: " ")
            }
            return row.cells.map(\.text).joined(separator: " | ")
        }
    }

    func parseRows(_ rows: [ReceiptRow]) -> ReceiptDraft {
        var classified: [ParsedLine] = []
        var rowIndexByEntry: [Int] = []
        var index = 0
        while index < rows.count {
            let line = splitLine(rows[index])
            var kind = classify(line)

            if kind == .nameOnly, index + 1 < rows.count {
                let next = splitLine(rows[index + 1])
                if classify(next) == .amountOnly {
                    classified.append(ParsedLine(line: line, kind: .nameOnly, row: rows[index]))
                    rowIndexByEntry.append(index)
                    classified.append(ParsedLine(line: next, kind: .amountOnly, row: rows[index + 1]))
                    rowIndexByEntry.append(index + 1)
                    index += 2
                    continue
                }
            }

            if kind == .amountOnly, index + 1 < rows.count {
                let next = splitLine(rows[index + 1])
                if classify(next) == .nameOnly {
                    classified.append(ParsedLine(line: line, kind: .amountOnly, row: rows[index]))
                    rowIndexByEntry.append(index)
                    classified.append(ParsedLine(line: next, kind: .nameOnly, row: rows[index + 1]))
                    rowIndexByEntry.append(index + 1)
                    index += 2
                    continue
                }
            }

            if isKeywordWithoutAmount(kind), index + 1 < rows.count {
                let next = splitLine(rows[index + 1])
                if classify(next) == .amountOnly, next.label.trimmingCharacters(in: .whitespaces).isEmpty {
                    var merged = line
                    merged.amounts = next.amounts
                    merged.row = line.row ?? next.row
                    kind = classify(merged)
                    classified.append(ParsedLine(line: merged, kind: kind, row: rows[index]))
                    rowIndexByEntry.append(index)
                    index += 2
                    continue
                }
            }

            classified.append(ParsedLine(line: line, kind: kind, row: rows[index]))
            rowIndexByEntry.append(index)
            index += 1
        }

        let firstItemRow = classified.enumerated().compactMap { offset, entry -> Int? in
            switch entry.kind {
            case .item:
                return rowIndexByEntry[offset]
            case .nameOnly:
                if offset + 1 < classified.count, classified[offset + 1].kind == .amountOnly {
                    return rowIndexByEntry[offset]
                }
                return nil
            case .amountOnly:
                if offset + 1 < classified.count, classified[offset + 1].kind == .nameOnly {
                    return rowIndexByEntry[offset]
                }
                return nil
            default:
                return nil
            }
        }.min()

        let totalsBoundaryRow = classified.enumerated().compactMap { offset, entry -> Int? in
            switch entry.kind {
            case .subtotal, .total:
                guard !entry.line.amounts.isEmpty else { return nil }
                let row = rowIndexByEntry[offset]
                if let firstItemRow, row < firstItemRow { return nil }
                return row
            default:
                return nil
            }
        }.min()

        let allTokens = classified.flatMap { $0.line.amounts + [$0.line.quantityDetail?.unit].compactMap { $0 } }
        let numberFormat = NumberFormatInference.infer(from: allTokens, preferred: preferredFormat)
        var issues: [ReceiptIssue] = []
        // What the Review screen can show: the same unsure readings as `issues`, with the row they came from.
        var warnings: [ReceiptWarning] = []
        if numberFormat.isGuessed {
            issues.append(.numberFormatGuessed(numberFormat))
            warnings.append(ReceiptWarning(issue: .numberFormatGuessed(numberFormat)))
        }

        func noteUnparsedPrice(_ text: String, label: String?, rect: PixelRect?) {
            issues.append(.unparsedPriceRow(text))
            let rowLabel = label?.trimmingCharacters(in: .whitespaces)
            warnings.append(ReceiptWarning(
                issue: .unparsedPriceRow(text),
                rowLabel: rowLabel?.isEmpty == false ? rowLabel : nil,
                sourceRect: rect
            ))
        }

        var items: [DraftItem] = []
        var subtotal: DraftAmount?
        var taxLines: [(label: String, amount: DraftAmount)] = []
        var tip: DraftAmount?
        var total: DraftAmount?
        var adjustments: [DraftAdjustment] = []
        var totalSeenAfterItems = false
        var priceBelowName = false
        var priceOrientationFixed = false

        func isPastTotalsSection(_ entryIndex: Int) -> Bool {
            guard let boundary = totalsBoundaryRow else { return false }
            return rowIndexByEntry[entryIndex] > boundary
        }

        func amount(from tokens: [AmountToken], rect: PixelRect?, label: String?) -> DraftAmount? {
            guard let last = tokens.last else { return nil }
            guard let minor = NumberFormatInference.minorUnits(last, format: numberFormat) else {
                noteUnparsedPrice(tokens.map(\.raw).joined(separator: " "), label: label, rect: rect)
                return DraftAmount(minorUnits: 0, sourceRect: rect, needsAttention: true)
            }
            let guessed = numberFormat.isGuessed || last.shape == .integer && last.digits.count >= 4
            return DraftAmount(minorUnits: minor, sourceRect: rect, needsAttention: guessed)
        }

        func addItem(name: String, qty: Int, tokens: [AmountToken], rect: PixelRect?, flags: Set<ItemFlag> = [], entryIndex: Int) {
            guard !isPastTotalsSection(entryIndex) else { return }
            let warningsBefore = warnings.count
            guard let draftAmount = amount(from: tokens, rect: rect, label: name) else { return }
            if draftAmount.minorUnits == 0 && !tokens.last!.isNegative {
                return
            }
            var itemFlags = flags
            if draftAmount.needsAttention { itemFlags.insert(.formatGuessed) }
            let item = DraftItem(
                name: name.trimmingCharacters(in: .whitespaces),
                quantity: qty,
                lineTotal: draftAmount,
                flags: itemFlags,
                sourceRect: rect
            )
            items.append(item)
            // An unreadable price that still made a row (a negative one) points at that row.
            for index in warnings.indices.dropFirst(warningsBefore) { warnings[index].itemID = item.id }
        }

        func rowRect(_ row: ReceiptRow?) -> PixelRect? {
            row?.words.map(\.rect).reduce(nil as PixelRect?) { acc, r in acc?.union(r) ?? r }
        }

        func applyQuantityDetail(_ detail: QuantityDetail, toItemAt index: Int) {
            guard let unitMinor = NumberFormatInference.minorUnits(detail.unit, format: numberFormat) else {
                items[index].flags.insert(.needsReview)
                return
            }
            let lineTotal = items[index].lineTotal.minorUnits
            let previousQuantity = items[index].quantity
            items[index].quantity = detail.quantity
            items[index].unitPrice = DraftAmount(minorUnits: unitMinor, needsAttention: numberFormat.isGuessed)
            // The right-hand figure is the line total; it is never rewritten. A quantity row that does
            // not multiply out to it, or that contradicts an explicit quantity, is left for review.
            let multipliesOut = detail.quantity * unitMinor == lineTotal
            let agreesWithPrefix = previousQuantity == 1 || previousQuantity == detail.quantity
            if !multipliesOut || !agreesWithPrefix {
                items[index].flags.formUnion([.quantityMismatch, .needsReview])
            }
        }

        var pendingName: (String, PixelRect?)?
        var i = 0
        while i < classified.count {
            let entry = classified[i]
            let line = entry.line
            let kind = entry.kind
            let rect = entry.row?.words.map(\.rect).reduce(nil as PixelRect?) { acc, r in
                acc?.union(r) ?? r
            }

            switch kind {
            case .tipTable, .payment, .other:
                if isHeaderNoise(line.label) { break }
                if kind == .other, hasLetters(line.label), line.amounts.isEmpty, !isPastTotalsSection(i) {
                    if line.label.hasPrefix("+") || line.label.hasPrefix("  ") {
                        if let last = items.indices.last {
                            items[last].notes.append(line.label.trimmingCharacters(in: .whitespaces))
                        }
                    }
                }

            case .subtotal:
                if let a = amount(from: line.amounts, rect: rect, label: line.label) { subtotal = a }

            case .tax:
                // Every tax line counts (state + county, IVU + municipal). A tax line repeated after the
                // total is a summary of the same tax, not another one.
                guard !(totalSeenAfterItems && !taxLines.isEmpty) else { break }
                if let a = amount(from: line.amounts, rect: rect, label: line.label) {
                    taxLines.append((line.label, a))
                }

            case .tip:
                if let a = amount(from: line.amounts, rect: rect, label: line.label) { tip = a }

            case .total:
                if let a = amount(from: line.amounts, rect: rect, label: line.label) {
                    total = a
                    if !items.isEmpty { totalSeenAfterItems = true }
                }

            case .discount:
                if var a = amount(from: line.amounts, rect: rect, label: line.label) {
                    a.minorUnits = -abs(a.minorUnits)
                    adjustments.append(DraftAdjustment(label: line.label.isEmpty ? "Descuento" : line.label, amount: a))
                }

            case .item:
                guard !isPastTotalsSection(i) else { break }
                var qty = line.leadingQty ?? 1
                var name = line.label
                if let q = parseQuantityPrefix(line.label) {
                    qty = q.quantity
                    name = q.name
                } else if let leadingQty = line.leadingQty {
                    name = stripLeadingQuantityPrefix(name, quantity: leadingQty)
                }
                let countBefore = items.count
                addItem(name: name, qty: qty, tokens: line.amounts, rect: rect, entryIndex: i)
                guard items.count > countBefore else { break }

                // A name that wraps over several rows stays one item: modifier rows ("Negro") and an
                // optional "(3 x $11.50)" quantity row follow the row that carries the price.
                var last = i
                var wrapped: [String] = []
                var wrappedRect = rect
                while last + 1 < classified.count,
                      isNameContinuation(classified, at: last + 1, after: last) {
                    wrapped.append(classified[last + 1].line.label.trimmingCharacters(in: .whitespaces))
                    wrappedRect = wrappedRect.flatMap { r in rowRect(classified[last + 1].row).map { r.union($0) } }
                    last += 1
                }
                if !wrapped.isEmpty {
                    items[items.count - 1].name += " " + wrapped.joined(separator: " ")
                    items[items.count - 1].sourceRect = wrappedRect
                }
                if last + 1 < classified.count,
                   classified[last + 1].kind == .quantityDetail,
                   let detail = classified[last + 1].line.quantityDetail,
                   isRowAdjacent(classified, at: last + 1, after: last) {
                    applyQuantityDetail(detail, toItemAt: items.count - 1)
                    last += 1
                }
                i = last

            case .quantityDetail:
                guard !isPastTotalsSection(i) else { break }
                noteUnparsedPrice(line.quantityDetail?.raw ?? "", label: nil, rect: rect)

            case .nameOnly:
                guard !isPastTotalsSection(i) else { break }
                if i + 1 < classified.count, classified[i + 1].kind == .amountOnly {
                    let next = classified[i + 1]
                    if !priceOrientationFixed {
                        priceBelowName = true
                        priceOrientationFixed = true
                    }
                    var flags: Set<ItemFlag> = [.priceOnNextRow]
                    if priceBelowName { flags.insert(.needsReview) }
                    addItem(
                        name: line.label,
                        qty: next.line.leadingQty ?? 1,
                        tokens: next.line.amounts,
                        rect: rect?.union(next.row?.words.first?.rect ?? PixelRect(x: 0, y: 0, width: 0, height: 0)),
                        flags: flags,
                        entryIndex: i
                    )
                    i += 1
                } else if line.label.hasPrefix("+") || line.label.hasPrefix("-") {
                    if let last = items.indices.last {
                        items[last].notes.append(line.label.trimmingCharacters(in: .whitespaces))
                    }
                } else if hasLetters(line.label) {
                    pendingName = (line.label, rect)
                }

            case .amountOnly:
                guard !isPastTotalsSection(i) else { break }
                if let pending = pendingName {
                    addItem(
                        name: pending.0,
                        qty: line.leadingQty ?? 1,
                        tokens: line.amounts,
                        rect: pending.1,
                        flags: [.priceOnPreviousRow],
                        entryIndex: i
                    )
                    pendingName = nil
                } else if i + 1 < classified.count, classified[i + 1].kind == .nameOnly {
                    let next = classified[i + 1]
                    if !priceOrientationFixed {
                        priceBelowName = false
                        priceOrientationFixed = true
                    }
                    addItem(
                        name: next.line.label,
                        qty: line.leadingQty ?? 1,
                        tokens: line.amounts,
                        rect: rect,
                        flags: [.priceOnPreviousRow, .needsReview],
                        entryIndex: i
                    )
                    i += 1
                } else {
                    noteUnparsedPrice(line.amounts.map(\.raw).joined(separator: " "), label: nil, rect: rect)
                }
            }
            i += 1
        }

        func isSummaryTaxLabel(_ label: String) -> Bool {
            let lowered = label.lowercased()
            return lowered.contains("total") || lowered.contains("summary")
        }

        func combinedTax(_ lines: [(label: String, amount: DraftAmount)]) -> DraftAmount? {
            guard var running = lines.first?.amount else { return nil }
            for line in lines.dropFirst() {
                running.minorUnits += line.amount.minorUnits
                running.needsAttention = running.needsAttention || line.amount.needsAttention
                running.sourceRect = running.sourceRect.flatMap { r in line.amount.sourceRect.map { r.union($0) } } ?? line.amount.sourceRect
            }
            return running
        }

        var tax: DraftAmount?
        if taxLines.count >= 3,
           let combined = taxLines.indices.first(where: { k in
               taxLines[k].amount.minorUnits == taxLines.enumerated().reduce(0) { $0 + ($1.offset == k ? 0 : $1.element.amount.minorUnits) }
           }) {
            var individual = taxLines
            individual.remove(at: combined)
            tax = combinedTax(individual)
        } else if taxLines.count >= 2, taxLines.contains(where: { isSummaryTaxLabel($0.label) }) {
            let withoutSummary = taxLines.filter { !isSummaryTaxLabel($0.label) }
            let readings = [combinedTax(taxLines), combinedTax(withoutSummary)].compactMap { $0 }
            let reconciling = readings.filter { reading in
                guard let sub = subtotal, let tot = total else { return false }
                return sub.minorUnits + reading.minorUnits + (tip?.minorUnits ?? 0) == tot.minorUnits
            }
            if reconciling.count == 1 {
                tax = reconciling[0]
            } else {
                tax = readings.first
                tax?.needsAttention = true
            }
        } else {
            tax = combinedTax(taxLines)
        }

        if items.isEmpty {
            issues.append(.noItemsFound)
        }
        if total == nil {
            issues.append(.noTotalFound)
        }

        let itemsSum = items.reduce(0) { $0 + $1.lineTotal.minorUnits }
        let adjustmentsSum = adjustments.reduce(0) { $0 + $1.amount.minorUnits }
        let netItemsSum = itemsSum + adjustmentsSum
        var reconciles = false

        if let sub = subtotal {
            if netItemsSum == sub.minorUnits {
                reconciles = true
            } else {
                issues.append(.itemsDoNotMatchSubtotal(itemsSum: netItemsSum, printed: sub.minorUnits))
            }
        } else if let tot = total {
            let taxVal = tax?.minorUnits ?? 0
            let tipVal = tip?.minorUnits ?? 0
            let expected = tot.minorUnits - taxVal - tipVal
            if netItemsSum == expected {
                reconciles = true
            } else {
                issues.append(.itemsDoNotMatchSubtotal(itemsSum: netItemsSum, printed: expected))
            }
        }

        if let sub = subtotal, let tot = total {
            let taxVal = tax?.minorUnits ?? 0
            let tipVal = tip?.minorUnits ?? 0
            let expected = sub.minorUnits + taxVal + tipVal
            if expected != tot.minorUnits {
                issues.append(.totalsDoNotAddUp(expected: expected, printed: tot.minorUnits))
                reconciles = false
            }
        }

        return ReceiptDraft(
            items: items,
            subtotal: subtotal,
            tax: tax,
            tip: tip,
            total: total,
            adjustments: adjustments,
            numberFormat: numberFormat,
            warnings: warnings,
            issues: issues,
            reconciles: reconciles
        )
    }
}

// MARK: - Line parsing

private struct ParsedLine {
    var line: LineFields
    var kind: RowKind
    var row: ReceiptRow?
}

private struct LineFields {
    var label: String
    var amounts: [AmountToken]
    var leadingQty: Int?
    var quantityDetail: QuantityDetail?
    var row: ReceiptRow?
}

/// A standalone `(3 x $11.50)` row under an item: quantity and unit price, no line total of its own.
private struct QuantityDetail {
    var quantity: Int
    var unit: AmountToken
    var raw: String
}

private enum RowKind {
    case item, nameOnly, amountOnly, quantityDetail, subtotal, tax, tip, total, discount, payment, tipTable, other
}

private func splitLine(_ row: ReceiptRow) -> LineFields {
    if let detail = parseQuantityDetail(row.words.map(\.text).joined(separator: " ")) {
        return LineFields(label: "", amounts: [], leadingQty: nil, quantityDetail: detail, row: row)
    }
    var words = repairWords(row.words.map(\.text))
    dropCurrencyWords(&words)
    var amounts: [AmountToken] = []
    while let last = words.last, amounts.count < 3, let token = AmountToken.parse(last) {
        amounts.insert(token, at: 0)
        words.removeLast()
    }
    var label = words.joined(separator: " ")
    var qty: Int?
    if let parsed = parseQuantityPrefix(label) {
        qty = parsed.quantity
        label = parsed.name
    } else if amounts.count >= 2,
              amounts[0].shape == .integer,
              amounts[0].digits.count <= 2,
              let q = Int(amounts[0].digits),
              q > 0 {
        qty = q
        amounts.removeFirst()
        label = stripLeadingQuantityPrefix(label, quantity: q)
    }
    return LineFields(
        label: label,
        amounts: amounts,
        leadingQty: qty,
        row: row
    )
}

private func repairWords(_ words: [String]) -> [String] {
    var result: [String] = []
    var i = 0
    while i < words.count {
        let w = words[i]
        if w.hasPrefix("@"), w.count > 1, i + 1 < words.count {
            let next = words[i + 1]
            result.append(String(w.dropFirst()) + next)
            i += 2
            continue
        }
        if w == "@", i + 1 < words.count {
            let next = words[i + 1]
            if next.contains(where: \.isNumber) {
                result.append(next.hasPrefix("@") ? next : "@" + next)
                i += 2
                continue
            }
        }
        if w.hasSuffix(".") && i + 1 < words.count, words[i + 1].allSatisfy(\.isNumber) {
            result.append(w + words[i + 1])
            i += 2
            continue
        }
        if w == "." && i > 0 && i + 1 < words.count,
           words[i - 1].allSatisfy(\.isNumber),
           words[i + 1].allSatisfy(\.isNumber) {
            result[result.count - 1] = result.last! + "." + words[i + 1]
            i += 2
            continue
        }
        result.append(w)
        i += 1
    }
    return result
}

private func dropCurrencyWords(_ words: inout [String]) {
    let drop = Set(["$", "USD"])
    words.removeAll { drop.contains($0) }
}

private func classify(_ line: LineFields) -> RowKind {
    if line.quantityDetail != nil { return .quantityDetail }
    let lower = canonicalKeywords(line.label)
    let tokens = lower.split(separator: " ")
    if line.amounts.isEmpty, isColumnHeader(tokens) { return .other }
    if tokens.contains(where: { $0.hasPrefix("(qty") }) || tokens.first == "qty" { return .other }
    if lower.contains("change due") { return .payment }
    if tokens.contains("no:") && !line.amounts.isEmpty { return .payment }
    if matchesTipTable(lower) { return .tipTable }
    if fuzzySubtotalLine(lower) { return .subtotal }
    if matches(subtotalKeywords, lower) { return .subtotal }
    if matches(paymentKeywords, lower) { return .payment }
    if matches(taxKeywords, lower) { return .tax }
    if matches(tipKeywords, lower) { return .tip }
    if matches(totalKeywords, lower) { return .total }
    if matches(discountKeywords, lower) || (line.amounts.last?.isNegative ?? false) { return .discount }

    switch (line.amounts.isEmpty, hasLetters(line.label)) {
    case (false, true): return .item
    case (false, false): return .amountOnly
    case (true, true): return .nameOnly
    default: return .other
    }
}

private let columnHeaderWords: Set<String> = [
    "item", "items", "description", "descripcion", "descripción", "product", "products", "producto", "productos",
    "articulo", "articulos", "artículo", "artículos", "qty", "quantity", "cant", "cantidad", "price", "precio",
    "amount", "unit", "each"
]

/// `Items  Price` / `Artículo  Precio` column headings of an items table.
private func isColumnHeader(_ tokens: [Substring]) -> Bool {
    guard !tokens.isEmpty else { return false }
    return tokens.allSatisfy { columnHeaderWords.contains($0.trimmingCharacters(in: CharacterSet.letters.inverted)) }
}

private func parseQuantityDetail(_ text: String) -> QuantityDetail? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    let pattern = #"^\(?\s*(\d{1,3})\s*[xX×@]\s*(?:USD|\$)?\s*(\d[\d.,]*)\s*\)?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
          let qRange = Range(match.range(at: 1), in: trimmed),
          let priceRange = Range(match.range(at: 2), in: trimmed),
          let quantity = Int(trimmed[qRange]), quantity > 0,
          let unit = AmountToken.parse(String(trimmed[priceRange]))
    else { return nil }
    return QuantityDetail(quantity: quantity, unit: unit, raw: trimmed)
}

private func rowHeight(_ row: ReceiptRow?) -> Double? {
    guard let heights = row?.words.map(\.rect.height).sorted(), !heights.isEmpty else { return nil }
    return heights[heights.count / 2]
}

/// True when the row at `index` sits directly under the row at `previous`: a normal line gap and roughly
/// the same left edge, so a wrapped name continues instead of starting a new block of text.
private func isRowAdjacent(_ lines: [ParsedLine], at index: Int, after previous: Int) -> Bool {
    guard let row = lines[index].row, let prevRow = lines[previous].row,
          let h = rowHeight(row), let prevH = rowHeight(prevRow),
          let left = row.words.map(\.rect.minX).min(), let prevLeft = prevRow.words.map(\.rect.minX).min()
    else { return false }
    let height = max(h, prevH)
    return row.centerY - prevRow.centerY <= 2 * height && abs(left - prevLeft) <= 4 * height
}

private func isNameContinuation(_ lines: [ParsedLine], at index: Int, after previous: Int) -> Bool {
    let entry = lines[index]
    guard entry.kind == .nameOnly, hasLetters(entry.line.label) else { return false }
    let label = entry.line.label.trimmingCharacters(in: .whitespaces)
    if label.hasPrefix("+") || label.hasPrefix("-") { return false }
    if index + 1 < lines.count, lines[index + 1].kind == .amountOnly { return false }
    return isRowAdjacent(lines, at: index, after: previous)
}

private func isKeywordWithoutAmount(_ kind: RowKind) -> Bool {
    switch kind {
    case .subtotal, .tax, .tip, .total, .discount: return true
    default: return false
    }
}

private func isHeaderNoise(_ label: String) -> Bool {
    let lower = label.lowercased()
    if lower.contains("tel") || lower.contains("phone") || lower.contains("www.") { return true }
    if label.filter(\.isNumber).count >= 10 && !label.contains(".") { return true }
    return false
}

private struct QuantityPrefix {
    var quantity: Int
    var name: String
}

private func fuzzySubtotalLine(_ lower: String) -> Bool {
    if lower.hasPrefix("sub") {
        let rest = lower.dropFirst(3).trimmingCharacters(in: .whitespaces)
        for token in rest.split(separator: " ") {
            if editDistance(String(token), "total") <= 1 { return true }
        }
    }
    return false
}

private func stripLeadingQuantityPrefix(_ label: String, quantity: Int) -> String {
    let trimmed = label.trimmingCharacters(in: .whitespaces)
    let prefix = "\(quantity)"
    if trimmed.hasPrefix(prefix) {
        let remainder = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        if remainder.hasPrefix("@") || remainder.hasPrefix("x") || remainder.hasPrefix("X") {
            return remainder.dropFirst().trimmingCharacters(in: .whitespaces)
        }
    }
    return label
}

private func parseQuantityPrefix(_ label: String) -> QuantityPrefix? {
    let trimmed = label.trimmingCharacters(in: .whitespaces)
    let patterns = [
        #"^(\d+)\s*[xX@]\s*(.+)$"#
    ]
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let qRange = Range(match.range(at: 1), in: trimmed),
              let nameRange = Range(match.range(at: 2), in: trimmed),
              let q = Int(trimmed[qRange]),
              q > 0, q <= 99
        else { continue }
        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
        if name.isEmpty { continue }
        return QuantityPrefix(quantity: q, name: name)
    }
    return nil
}

private func hasLetters(_ s: String) -> Bool {
    s.filter(\.isLetter).count >= 2
}

private func matches(_ keywords: [String], _ text: String) -> Bool {
    let lower = text.lowercased()
    for kw in keywords {
        if kw.contains(" ") {
            if lower.contains(kw) { return true }
            continue
        }
        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for token in tokens {
            if token == kw { return true }
            if token.count >= 5, kw.count >= 5, editDistance(token, kw) <= 1 { return true }
        }
    }
    return false
}

private func matchesTipTable(_ text: String) -> Bool {
    if text.lowercased().contains("suggested tip") { return true }
    if text.trimmingCharacters(in: .whitespaces).hasSuffix("%") {
        let parts = text.split(separator: " ")
        if parts.count >= 2, parts[0].hasSuffix("%") { return true }
    }
    return false
}

private let subtotalKeywords = ["subtotal", "sub total", "sub-total", "subtot"]
private let taxKeywords = ["tax", "iva", "vat", "ivu", "impuesto", "sales tax"]
private let tipKeywords = ["tip", "propina", "gratuity", "service", "servicio"]
private let totalKeywords = ["total", "importe", "amount due", "grandtotal", "grand total"]
private let discountKeywords = ["discount", "descuento", "off"]
private let paymentKeywords = [
    "cash", "change", "change due", "visa", "mastercard", "amex", "tarjeta", "efectivo", "card", "mesa",
    "approved", "edc", "cimb", "creditcard", "debit"
]

private func canonicalKeywords(_ label: String) -> String {
    label.lowercased()
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespaces)
}

private func editDistance(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { dp[i][0] = i }
    for j in 0...b.count { dp[0][j] = j }
    for i in 1...a.count {
        for j in 1...b.count {
            if a[i - 1] == b[j - 1] {
                dp[i][j] = dp[i - 1][j - 1]
            } else {
                dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
            }
        }
    }
    return dp[a.count][b.count]
}
