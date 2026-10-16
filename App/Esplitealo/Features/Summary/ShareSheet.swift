import EsplitealoDesign
import SwiftUI
import UIKit

/// The share preview: the neutral text that will be sent (built by `ShareSummaryBuilder`, in the language of the app),
/// on the cream surface, with one green action that opens the iOS share sheet. Nothing here is pink: pink belongs to
/// the success moment that follows.
struct ShareSheetContent: View {
    let model: TotalsViewModel
    let onCancel: () -> Void

    @Environment(\.locale) private var locale
    @State private var showsActivity = false

    private var text: String {
        model.shareText(language: TotalsViewModel.shareLanguage(for: locale))
    }

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                preview
                Text("shareSheet.native")
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Button(action: send) {
                    Label("shareSheet.send", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.espPrimary(showsDivisionCoin: false))
                .accessibilityIdentifier("share.send")
                Button("shareSheet.cancel", action: onCancel)
                    .buttonStyle(.espQuiet)
                    .accessibilityIdentifier("share.cancel")
            }
        }
        .sheet(isPresented: $showsActivity) {
            ActivityView(items: [text]) { completed in
                if completed { model.shareCompleted() } else { model.shareCancelled() }
            }
            .presentationDetents([.medium, .large])
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("share.sheet")
    }

    private func send() {
        #if DEBUG
        // UI tests cannot drive the system share sheet: `--uitesting-share complete|cancel` answers for it.
        if let outcome = ShareLaunchOutcome.current {
            if outcome == .complete { model.shareCompleted() } else { model.shareCancelled() }
            return
        }
        #endif
        showsActivity = true
    }

    /// The recipients go under the title when the title has no room beside them (large text).
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                headerIcon
                headerTitle
                RecipientsStack(people: model.people)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    headerIcon
                    headerTitle
                }
                RecipientsStack(people: model.people)
            }
        }
    }

    private var headerIcon: some View {
        Image(systemName: "text.document")
            .font(.title3)
            .foregroundStyle(Color.esp.primary)
            .frame(width: 44, height: 44)
            .background(Color.esp.okBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    private var headerTitle: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if model.merchantName.isEmpty {
                        Text("totals.title")
                    } else {
                        Text(.shareSheetTitle(model.merchantName))
                    }
                }
                .espText(.headline)
                Text(.shareSheetSubtitle(model.peopleCount))
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private var preview: some View {
        Text(verbatim: text)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Color.esp.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
            .padding(.leading, Spacing.md)
            .padding(.trailing, Spacing.sm)
            .background(Color.esp.well, in: RoundedRectangle(cornerRadius: Spacing.sm, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule().fill(Color.esp.line).frame(width: 4).padding(.vertical, Spacing.xs).padding(.leading, 6).accessibilityHidden(true)
            }
            .textSelection(.enabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityIdentifier("share.preview")
    }
}

/// The people the summary goes to, overlapping, in their colours.
private struct RecipientsStack: View {
    let people: [(name: String, colorIndex: Int)]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(people.prefix(4).enumerated()), id: \.offset) { _, person in
                PersonAvatar(name: person.name, participantIndex: person.colorIndex, size: 28, announcesName: false)
                    .overlay(Circle().strokeBorder(Color.esp.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - System share sheet

/// `UIActivityViewController`, so the app learns whether the text was really sent (`ShareLink` does not say).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG
/// `--uitesting-share complete|cancel`: what the stand-in for the system share sheet answers.
enum ShareLaunchOutcome {
    case complete, cancel

    static var current: ShareLaunchOutcome? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--uitesting-share"), arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1] {
        case "complete": return .complete
        case "cancel": return .cancel
        default: return nil
        }
    }
}
#endif

// MARK: - Success

/// "¡Wepa! Cuentas claras.": Chavito happy on the pink disc, a few pink and green confetti pieces that settle once
/// (not at all with Reduce Motion), and the two ways on. This is the one place pink is allowed to be loud.
struct ShareSuccessView: View {
    let peopleCount: Int
    let totalCents: Int
    let onNewBill: () -> Void
    let onBack: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ChavitoView(expression: .happy, size: 260, disc: true, animated: !reduceMotion)
                        .accessibilityLabel(Text("mascot.success"))
                        .overlay { Confetti(settled: settled || reduceMotion) }
                    Text("success.title")
                        .espText(.title)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleFocused)
                        .accessibilityIdentifier("success.title")
                    Text(.successBody(peopleCount, MoneyFormatter(locale: locale).string(cents: totalCents)))
                        .espText(.subhead)
                        .foregroundStyle(Color.esp.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Spacing.xs)
                    Button("success.again", action: onNewBill)
                        .buttonStyle(.espPrimary(showsDivisionCoin: true))
                        .accessibilityIdentifier("success.again")
                    Button("success.back", action: onBack)
                        .buttonStyle(.espQuiet)
                        .accessibilityIdentifier("success.back")
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        .onAppear {
            // The picture comes first on screen, but the good news is the title: VoiceOver starts there.
            titleFocused = true
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9)) { settled = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("success.root")
    }
}

/// Decorative confetti around the mascot: fixed pieces, pink and green only.
private struct Confetti: View {
    let settled: Bool

    private struct Piece {
        let x: Double, y: Double, size: CGFloat, turn: Double, pink: Bool
    }

    private static let pieces: [Piece] = [
        Piece(x: 0.10, y: 0.18, size: 10, turn: 20, pink: true), Piece(x: 0.22, y: 0.05, size: 8, turn: -35, pink: false),
        Piece(x: 0.80, y: 0.10, size: 10, turn: 40, pink: false), Piece(x: 0.92, y: 0.30, size: 8, turn: -15, pink: true),
        Piece(x: 0.05, y: 0.52, size: 8, turn: 60, pink: false), Piece(x: 0.95, y: 0.62, size: 10, turn: -50, pink: true),
        Piece(x: 0.16, y: 0.80, size: 9, turn: 25, pink: true), Piece(x: 0.86, y: 0.84, size: 8, turn: 10, pink: false),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(Self.pieces.enumerated()), id: \.offset) { _, piece in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(piece.pink ? Color.esp.pink : Color.esp.primary)
                    .frame(width: piece.size, height: piece.size * 0.5)
                    .rotationEffect(.degrees(piece.turn * (settled ? 1 : 3)))
                    .position(x: proxy.size.width * piece.x, y: proxy.size.height * piece.y + (settled ? 0 : -24))
                    .opacity(settled ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
