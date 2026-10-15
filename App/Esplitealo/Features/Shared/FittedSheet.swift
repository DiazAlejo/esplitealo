import EsplitealoDesign
import SwiftUI

/// The body of a bottom sheet: it asks for exactly its own height (and the large detent when it needs more), scrolls
/// when it must, and lets the keyboard be dragged away. The sheet itself, its grabber and its corners are the system's.
struct FittedSheet<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 360
    @State private var bottomInset: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .foregroundStyle(Color.esp.ink)
        .tint(Color.esp.primary)
        .presentationDetents([.height(contentHeight + bottomInset), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.esp.surface)
    }
}

/// A sheet's title: Spanish or English text in SF Pro Rounded, with the pink ÷ before it unless the sheet is a warning.
struct SheetTitle: View {
    private let title: Text
    private let showsMark: Bool
    @ScaledMetric(relativeTo: .title2) private var markSize: CGFloat = 13

    init(_ title: LocalizedStringKey, showsMark: Bool = true) {
        self.title = Text(title)
        self.showsMark = showsMark
    }

    init(resource: LocalizedStringResource, showsMark: Bool = false) {
        self.title = Text(resource)
        self.showsMark = showsMark
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            if showsMark {
                DivisionMark()
                    .fill(Color.esp.pink)
                    .frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
            }
            title
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
