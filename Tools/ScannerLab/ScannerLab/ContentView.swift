import EsplitealoCapture
import PhotosUI
import ScannerLabKit
import SwiftUI

struct ContentView: View {
    @StateObject private var state = LabScreenState()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    captureButtons
                    if let thumbnail = state.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if state.isProcessing {
                        ProgressView("Running OCR and parser…")
                    }
                    if let message = state.errorMessage {
                        SectionHeader("Error")
                        Text(message)
                            .foregroundStyle(.red)
                    }
                    if let display = state.display {
                        resultSections(display)
                        exportButtons
                    }
                }
                .padding()
            }
            .navigationTitle("Scanner Lab")
        }
        .fullScreenCover(isPresented: $state.showDocumentCamera) {
            DocumentCameraBridge { state.handleDocumentCameraResult($0) }
                .ignoresSafeArea()
        }
    }

    private var captureButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Scan with document camera") {
                Task { await state.scanWithDocumentCameraTapped() }
            }
            .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $state.photoPickerItem, matching: .images) {
                Text("Choose photo")
            }
            .buttonStyle(.bordered)
            .onChange(of: state.photoPickerItem) { _, item in
                guard let item else { return }
                Task { await state.loadPhotoItem(item) }
            }
        }
    }

    @ViewBuilder
    private func resultSections(_ display: ScanLabDisplayResult) -> some View {
        if let ms = display.ocrDurationMilliseconds {
            SectionHeader("OCR time")
            Text("\(ms) ms")
        }

        SectionHeader("Recognized lines")
        ForEach(Array(display.recognizedLines.enumerated()), id: \.offset) { _, line in
            HStack(alignment: .top) {
                Text(line.text)
                Spacer(minLength: 8)
                Text(line.confidenceLabel)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }

        SectionHeader("Rebuilt rows")
        ForEach(Array(display.rebuiltRows.enumerated()), id: \.offset) { _, row in
            Text(row)
                .font(.caption.monospaced())
        }

        SectionHeader("Items")
        ForEach(Array(display.items.enumerated()), id: \.offset) { _, item in
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.description) ×\(item.quantity) — \(item.priceLabel)")
                if !item.flags.isEmpty {
                    Text(item.flags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }

        SectionHeader("Totals")
        totalRow("Subtotal", amount: display.subtotal)
        totalRow("Tax", amount: display.tax)
        totalRow("Tip", amount: display.tip)
        totalRow("Total", amount: display.total)

        SectionHeader("Reconciliation")
        Text(display.reconciliationSummary)
        Text(display.reconciles ? "reconciles: true" : "reconciles: false")
            .font(.caption.monospaced())

        if !display.flaggedRows.isEmpty {
            SectionHeader("Flagged rows")
            ForEach(Array(display.flaggedRows.enumerated()), id: \.offset) { _, row in
                Text(row)
                    .foregroundStyle(.orange)
            }
        }

        if !display.issues.isEmpty {
            SectionHeader("Issues")
            ForEach(Array(display.issues.enumerated()), id: \.offset) { _, issue in
                Text(issue)
            }
        }
    }

    private var exportButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Copy full result JSON") {
                state.copyFullResultJSON()
            }
            .buttonStyle(.bordered)

            if state.copyConfirmation {
                Text("Copied to clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let shareURL = state.recognizedTextFileURL {
                ShareLink(
                    item: shareURL,
                    preview: SharePreview("recognized-text.json", image: Image(systemName: "doc.text"))
                ) {
                    Text("Share recognized-text JSON")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func totalRow(_ title: String, amount: ScanLabAmountDisplay?) -> some View {
        if let amount {
            HStack {
                Text(title)
                Spacer()
                Text(amount.label)
                    .foregroundStyle(amount.needsAttention ? .orange : .primary)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}
