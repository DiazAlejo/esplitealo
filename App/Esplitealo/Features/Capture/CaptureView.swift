import EsplitealoCapture
import EsplitealoDesign
import PhotosUI
import SwiftUI

/// Capture and processing, one route: it starts the system document camera (or photo picker) when it appears, then
/// shows what `ScanFlow` is doing: the camera-blocked screen, reading, or a failure. On success `ScanFlow` hands the
/// draft to the bill and opens Review.
struct CaptureView: View {
    @Environment(ScanFlow.self) private var flow
    @Environment(\.openURL) private var openURL

    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        content
            .task { await flow.captureScreenAppeared() }
            .fullScreenCover(isPresented: presenting(.camera)) {
                DocumentCameraBridge { flow.cameraFinished($0) }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: photoPickerBinding, selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                flow.photoSelected()
                Task {
                    let result = await PhotoImport.loadImage(from: item)
                    pickedPhoto = nil
                    flow.photoFinished(result)
                }
            }
            // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AppRoute.capture.accessibilityIdentifier)
    }

    @ViewBuilder private var content: some View {
        switch flow.phase {
        case .blocked(let block):
            CaptureBlockedContent(
                block: block,
                onOpenSettings: openSettings,
                onChoosePhoto: { flow.chooseAnotherPhoto() },
                onCancel: { flow.cancel() }
            )
        case .processing:
            ProcessingContent(
                messageIndex: flow.messageIndex,
                offersManualEntry: flow.offersManualEntry,
                onManual: { flow.enterItemsManually() },
                onCancel: { flow.cancel() }
            )
        case .failed(let failure):
            ScanFailedContent(
                failure: failure,
                source: flow.source,
                onRetry: { Task { await flow.retry() } },
                onManual: { flow.enterItemsManually() },
                onAnotherPhoto: { flow.chooseAnotherPhoto() },
                onBack: { flow.cancel() }
            )
        case .idle, .presenting, .finished:
            // Behind the system camera or picker: a calm blank screen with the way out.
            Color.clear
                .espScreenBackground()
                .captureBackButton("capture.cancel", showsChevron: false) { flow.cancel() }
        }
    }

    private func presenting(_ source: ScanSource) -> Binding<Bool> {
        // The document camera reports its own end (saved, cancelled or failed), so nothing needs to be set here.
        Binding(get: { flow.phase == .presenting(source) }, set: { _ in })
    }

    /// The picker closes itself; closing it without a photo is a cancel, a photo arrives through `pickedPhoto`.
    private var photoPickerBinding: Binding<Bool> {
        Binding(
            get: { flow.phase == .presenting(.photoLibrary) },
            set: { isPresented in
                guard !isPresented, flow.phase == .presenting(.photoLibrary) else { return }
                Task {
                    // The chosen photo is reported just after the picker closes; wait for it before calling it a cancel.
                    try? await Task.sleep(for: .milliseconds(500))
                    if pickedPhoto == nil { flow.photoPickerClosedWithoutSelection() }
                }
            }
        )
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

#Preview("Capture, camera denied") {
    NavigationStack { CaptureView() }
        .environment(ScanFlow.preview(camera: .denied))
        .environment(AppRouter())
}
