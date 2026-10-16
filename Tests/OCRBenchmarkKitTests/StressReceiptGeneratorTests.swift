import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

final class StressReceiptGeneratorTests: XCTestCase {
    private let corpus = StressReceiptGenerator.corpus(count: 224)

    func testCorpusIsDeterministicForASeed() {
        XCTAssertEqual(StressReceiptGenerator.corpus(count: 12, seed: 5), StressReceiptGenerator.corpus(count: 12, seed: 5))
        XCTAssertNotEqual(
            StressReceiptGenerator.corpus(count: 12, seed: 5).map(\.rows),
            StressReceiptGenerator.corpus(count: 12, seed: 6).map(\.rows)
        )
        XCTAssertEqual(Set(corpus.map(\.id)).count, corpus.count, "ids are unique")
    }

    func testGroundTruthAddsUp() {
        for receipt in corpus {
            let truth = receipt.truth
            let net = truth.itemsSumMinor + truth.adjustmentsSumMinor
            XCTAssertEqual(
                truth.totalMinor,
                net + truth.taxMinor + truth.tipMinor,
                "total = items + adjustments + tax + tip for \(receipt.id)"
            )
            XCTAssertTrue(
                truth.subtotalMinor == net || receipt.features.contains(.discount),
                "subtotal is the net of items and adjustments unless a discount prints after it: \(receipt.id)"
            )
            XCTAssertFalse(truth.items.isEmpty, receipt.id)
            XCTAssertTrue(truth.items.allSatisfy { $0.lineTotalMinor > 0 && $0.quantity >= 1 }, receipt.id)
            XCTAssertTrue(truth.adjustmentsMinor.allSatisfy { $0 < 0 }, receipt.id)
        }
    }

    func testEveryTruthAmountIsPrintedOnTheReceipt() {
        for receipt in corpus {
            let printed = receipt.plainRows.joined(separator: "\n")
            for amount in [receipt.truth.totalMinor, receipt.truth.subtotalMinor] + receipt.truth.taxLinesMinor
                + (receipt.truth.tipMinor == 0 ? [] : [receipt.truth.tipMinor]) + receipt.truth.items.map(\.lineTotalMinor)
                + receipt.truth.adjustmentsMinor.map { abs($0) } {
                XCTAssertTrue(
                    printed.contains(StressMoney.format(amount, dollar: false)),
                    "\(StressMoney.format(amount, dollar: false)) is printed on \(receipt.id)\n\(printed)"
                )
            }
        }
    }

    func testRowsFitTheColumnGrid() {
        for receipt in corpus {
            for row in receipt.rows {
                XCTAssertLessThanOrEqual(
                    row.text(columns: receipt.columns).count,
                    row.effectiveColumns(receipt.columns) + 2,
                    "row too wide on \(receipt.id): \(row.left)"
                )
            }
        }
    }

    func testCorpusCoversEveryFeatureVenueAndDegradation() {
        for feature in StressFeature.allCases {
            let count = corpus.filter { $0.features.contains(feature) }.count
            XCTAssertGreaterThanOrEqual(count, 5, "feature \(feature) appears on \(count) of \(corpus.count) receipts")
        }
        for venue in StressVenue.allCases {
            XCTAssertGreaterThanOrEqual(corpus.filter { $0.venue == venue }.count, 40)
        }
        for degradation in StressDegradation.allCases {
            XCTAssertGreaterThanOrEqual(corpus.filter { $0.degradation == degradation }.count, 8, "\(degradation)")
        }
    }

    func testReceiptsStayBelowTheSinglePhotoAspectRatio() {
        // The renderer draws 1.42 text heights per row at 0.6 text heights per column and pads the paper by 14% of the
        // width on each side; the scanner rejects images more than 4x taller than wide.
        for receipt in corpus {
            let rows = Double(receipt.rows.count) + Double(receipt.rows.filter { $0.style == .large }.count) * 0.6
            let aspect = (2.13 * rows / Double(receipt.columns) + 0.4) / 1.28
            XCTAssertLessThan(aspect, 3.8, "\(receipt.id) has \(receipt.rows.count) rows in \(receipt.columns) columns")
        }
    }

    func testIdealRecognizedTextRoundTripsThePrintedRows() {
        let receipt = corpus[0]
        let recognized = StressRecognizedTextBuilder.build(from: receipt)
        let printed = receipt.plainRows.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let words = recognized.lines.flatMap(\.words).map(\.text)
        XCTAssertEqual(words, printed.flatMap { $0.split(separator: " ").map(String.init) })
        XCTAssertTrue(recognized.lines.flatMap(\.words).allSatisfy { $0.rect.width > 0 })
    }
}
