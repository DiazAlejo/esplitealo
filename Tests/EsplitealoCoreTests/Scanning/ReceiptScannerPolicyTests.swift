import CoreGraphics
import XCTest
@testable import EsplitealoCore

final class ReceiptScannerPolicyTests: XCTestCase {
    func testRejectsExtremeAspectRatioBeforeOCR() async {
        let stub = StubTextRecognizer { _, _ in
            XCTFail("recognizer should not run for aspect-ratio rejection")
            return RecognizedText(imageSize: ImageSize(width: 100, height: 500), lines: [])
        }
        let scanner = ReceiptScanner(recognizer: stub, maximumSinglePhotoAspectRatio: 4)

        let image = Self.solidImage(width: 100, height: 500)
        do {
            _ = try await scanner.recognize(image: image, orientation: .up)
            XCTFail("expected receiptTooLongForSinglePhoto")
        } catch let error as ReceiptScanError {
            XCTAssertEqual(
                error,
                .receiptTooLongForSinglePhoto(aspectRatio: 5, maximumAspectRatio: 4)
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRejectsNoTextFromRecognizer() async throws {
        let stub = StubTextRecognizer { _, _ in
            RecognizedText(imageSize: ImageSize(width: 200, height: 200), lines: [])
        }
        let scanner = ReceiptScanner(recognizer: stub)

        let image = Self.solidImage(width: 200, height: 200)
        do {
            _ = try await scanner.recognize(image: image, orientation: .up)
            XCTFail("expected noTextFound")
        } catch let error as ReceiptScanError {
            XCTAssertEqual(error, .noTextFound)
        }
    }

    func testRejectsLowWordHeightAfterOCR() async throws {
        let tinyLine = RecognizedLine(
            text: "x",
            confidence: 1,
            rect: PixelRect(x: 0, y: 0, width: 10, height: 8),
            baselineAngle: 0,
            words: [RecognizedWord(text: "x", rect: PixelRect(x: 0, y: 0, width: 10, height: 8))]
        )
        let stub = StubTextRecognizer { _, _ in
            RecognizedText(
                imageSize: ImageSize(width: 200, height: 200),
                lines: [tinyLine]
            )
        }
        let scanner = ReceiptScanner(recognizer: stub)

        let image = Self.solidImage(width: 200, height: 200)
        do {
            _ = try await scanner.recognize(image: image, orientation: .up)
            XCTFail("expected imageTooSmallOrUnreadable")
        } catch let error as ReceiptScanError {
            if case .imageTooSmallOrUnreadable(let minHeight) = error {
                XCTAssertEqual(minHeight, 8)
            } else {
                XCTFail("expected imageTooSmallOrUnreadable")
            }
        }
    }

    func testRotatedOrientationSwapsDimensionsForAspectRatio() async {
        let stub = StubTextRecognizer { _, _ in
            XCTFail("recognizer should not run for aspect-ratio rejection")
            return RecognizedText(imageSize: ImageSize(width: 100, height: 500), lines: [])
        }
        let scanner = ReceiptScanner(recognizer: stub, maximumSinglePhotoAspectRatio: 4)

        do {
            _ = try await scanner.recognize(image: Self.solidImage(width: 500, height: 100), orientation: .right)
            XCTFail("expected receiptTooLongForSinglePhoto")
        } catch let error as ReceiptScanError {
            XCTAssertEqual(
                error,
                .receiptTooLongForSinglePhoto(aspectRatio: 5, maximumAspectRatio: 4)
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRotatedOrientationAcceptsImageThatIsUprightWide() async throws {
        let line = RecognizedLine(
            text: "TOTAL",
            confidence: 1,
            rect: PixelRect(x: 0, y: 0, width: 100, height: 30),
            baselineAngle: 0,
            words: [RecognizedWord(text: "TOTAL", rect: PixelRect(x: 0, y: 0, width: 100, height: 30))]
        )
        let stub = StubTextRecognizer { _, _ in
            RecognizedText(imageSize: ImageSize(width: 500, height: 100), lines: [line])
        }
        let scanner = ReceiptScanner(recognizer: stub, maximumSinglePhotoAspectRatio: 4)

        let result = try await scanner.recognize(image: Self.solidImage(width: 100, height: 500), orientation: .right)
        XCTAssertEqual(result.lines.count, 1)
    }

    private static func solidImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

struct StubTextRecognizer: TextRecognizing {
    var handler: @Sendable (CGImage, CGImagePropertyOrientation) async throws -> RecognizedText

    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) async throws -> RecognizedText {
        try await handler(image, orientation)
    }
}
