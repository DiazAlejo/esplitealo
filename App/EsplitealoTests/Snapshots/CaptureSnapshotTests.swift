import SwiftUI
import Testing
@testable import Esplitealo

/// The capture screen's own states: camera blocked, reading the receipt, and the ways a scan can fail.
/// The system camera and photo picker are not snapshotted; they are Apple's views.
@MainActor
struct CaptureSnapshotTests {
    private func screen(_ content: some View) -> some View {
        NavigationStack { content }
    }

    @Test func cameraDenied() {
        assertDesignSnapshot(screen(CaptureBlockedContent(block: .denied)), named: "camera-denied", fixedHeight: 844)
    }

    @Test func cameraUnavailable() {
        assertDesignSnapshot(screen(CaptureBlockedContent(block: .unavailable)), named: "camera-unavailable", fixedHeight: 844)
    }

    @Test func reading() {
        assertDesignSnapshot(
            screen(ProcessingContent(messageIndex: 0, offersManualEntry: false, animates: false)),
            named: "reading",
            fixedHeight: 844
        )
    }

    @Test func readingTakesAWhile() {
        assertDesignSnapshot(
            screen(ProcessingContent(messageIndex: 2, offersManualEntry: true, animates: false)),
            named: "reading-slow",
            fixedHeight: 844
        )
    }

    @Test func couldNotReadTheReceipt() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .unreadable, source: .camera, animates: false)),
            named: "failed-unreadable",
            fixedHeight: 844
        )
    }

    @Test func couldNotReadAPickedPhoto() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .unreadable, source: .photoLibrary, animates: false)),
            named: "failed-unreadable-photo",
            variants: [.lightSpanish, .lightEnglish],
            fixedHeight: 844
        )
    }

    @Test func tooManyPages() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .tooManyPages, source: .camera, animates: false)),
            named: "failed-too-many-pages",
            variants: [.lightSpanish, .lightEnglish],
            fixedHeight: 844
        )
    }

    @Test func tooLong() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .tooLong, source: .camera, animates: false)),
            named: "failed-too-long",
            variants: [.lightSpanish, .lightEnglish],
            fixedHeight: 844
        )
    }

    @Test func photoNotLoaded() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .photoNotLoaded, source: .photoLibrary, animates: false)),
            named: "failed-photo",
            variants: [.lightSpanish, .lightEnglish],
            fixedHeight: 844
        )
    }

    @Test func cameraFailed() {
        assertDesignSnapshot(
            screen(ScanFailedContent(failure: .cameraFailed, source: .camera, animates: false)),
            named: "failed-camera",
            variants: [.lightSpanish, .lightEnglish],
            fixedHeight: 844
        )
    }
}
