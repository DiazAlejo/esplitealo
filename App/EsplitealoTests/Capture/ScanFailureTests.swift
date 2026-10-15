import EsplitealoCapture
import EsplitealoScanning
import Foundation
import Testing
@testable import Esplitealo

/// What the user is told when a scan does not work: every failure has a title and a body in both languages, in the
/// mockups' voice, and the actions the screen offers depend on what went wrong.
@MainActor
struct ScanFailureTests {
    func text(_ resource: LocalizedStringResource, _ language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test func theUnreadableReceiptUsesTheApprovedMockupWording() {
        #expect(text(ScanFailure.unreadable.title, "es") == "Ay bendito, no pude leer ese recibo")
        #expect(text(ScanFailure.unreadable.title, "en") == "I couldn’t read that one")
        #expect(text(ScanFailure.unreadable.body, "es").hasSuffix("No se perdió nada."))
        #expect(text(ScanFailure.unreadable.body, "en").hasSuffix("Nothing is lost."))
    }

    @Test(arguments: ScanFailure.allCases)
    func everyFailureHasATitleAndBodyInBothLanguages(failure: ScanFailure) {
        for language in ["es", "en"] {
            let title = text(failure.title, language)
            let body = text(failure.body, language)
            #expect(!title.isEmpty && !title.contains("⚠️") && !title.contains("."), "\(failure) title [\(language)] = \(title)")
            #expect(!body.isEmpty && !body.contains("⚠️"), "\(failure) body [\(language)] = \(body)")
        }
        #expect(text(failure.title, "es") != text(failure.title, "en"))
    }

    @Test func spanishCopyFollowsTheHouseRules() {
        for failure in ScanFailure.allCases {
            let spanish = (text(failure.title, "es") + " " + text(failure.body, "es")).lowercased()
            for word in ["monto", "usted", "asign", "agreg"] { #expect(!spanish.contains(word)) }
        }
    }

    @Test func eachFailureSaysWhetherPickingAnotherPhotoMakesSense() {
        #expect(ScanFailure.unreadable.offersAnotherPhoto(from: .camera))
        #expect(!ScanFailure.unreadable.offersAnotherPhoto(from: .photoLibrary))
        #expect(ScanFailure.tooManyPages.offersAnotherPhoto(from: .camera))
    }

    @Test func blockedScreensHaveCopyInBothLanguages() {
        for block in [CaptureBlock.denied, .unavailable] {
            for language in ["es", "en"] {
                #expect(!text(block.title, language).isEmpty)
                #expect(!text(block.body, language).isEmpty)
            }
        }
        #expect(text(CaptureBlock.denied.title, "es") == "La cámara está desactivada")
        #expect(text(CaptureBlock.denied.body, "en").contains("Settings › Esplitéalo"))
        #expect(CaptureBlock.denied.offersSettings)
        #expect(!CaptureBlock.unavailable.offersSettings)
    }
}
