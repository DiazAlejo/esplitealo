import EsplitealoDesign
import SwiftUI

/// The top of the Mark items screen: the title with "6 de 8", the progress meter, and one chip per person with their
/// live pre-tax subtotal (tap a chip to paint items for that person), plus the paint bar while painting.
struct AssignHeader: View {
    let model: AssignViewModel
    let people: [AssignViewModel.Person]

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let total = model.totalUnitCount
        let done = model.assignedUnitCount
        let isComplete = total > 0 && done == total
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AdaptiveStack(rowAlignment: .firstTextBaseline, rowSpacing: Spacing.xs, stackedSpacing: Spacing.xxs) {
                    EspTitle("assign.title").frame(maxWidth: .infinity, alignment: .leading)
                    progress(done: done, total: total, isComplete: isComplete)
                }
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(isComplete ? Color.esp.primary : Color.esp.pink)
                    .accessibilityLabel("assign.meter")
                    .accessibilityValue(Text(.assignProgress(done, total)))
                    .accessibilityIdentifier("assign.meter")
            }
            .padding(.horizontal, Spacing.screenMargin)

            VStack(alignment: .leading, spacing: 0) {
                Text("assign.chips")
                    .espText(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .padding(.horizontal, Spacing.screenMargin)
                    .accessibilityAddTraits(.isHeader)
                if dynamicTypeSize.isAccessibilitySize {
                    // A sideways strip would hide most of the table behind a swipe: the chips stack instead.
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        ForEach(people) { person in
                            chip(person)
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            HStack(spacing: Spacing.xxs) {
                                ForEach(people) { person in
                                    chip(person).id(person.id)
                                }
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: model.paintingID) { _, id in
                            if let id { withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(id, anchor: .center) } }
                        }
                    }
                }
            }

            if let painter = people.first(where: \.isPainting) {
                paintBar(painter)
            }
        }
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xxs)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.esp.hairline).frame(height: Stroke.hairline).accessibilityHidden(true)
        }
    }

    private func progress(done: Int, total: Int, isComplete: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            Text(.assignProgress(done, total))
            if isComplete {
                Image(systemName: "checkmark").accessibilityHidden(true)
            }
        }
        .espText(.subhead)
        .fontWeight(.semibold)
        .monospacedDigit()
        .foregroundStyle(isComplete ? Color.esp.primary : Color.esp.inkSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("assign.progress")
    }

    private func chip(_ person: AssignViewModel.Person) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            model.togglePainting(person.id)
        } label: {
            PersonChip(name: person.name, participantIndex: person.colorIndex, subtotalCents: person.subtotalCents)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .frame(minWidth: 112, alignment: .leading)
                .background(person.isPainting ? Color.esp.selection : Color.clear, in: shape)
                .overlay(alignment: .bottom) {
                    if person.isPainting {
                        Capsule().fill(Color.esp.pink).frame(height: 3).padding(.horizontal, 14).padding(.bottom, 2)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.spokenSubtotal(MoneyFormatter(locale: locale)))
        .accessibilityHint(Text("assign.chip.hint"))
        .accessibilityAddTraits(person.isPainting ? .isSelected : [])
        .accessibilityIdentifier("assign.chip.\(person.colorIndex)")
    }

    private func paintBar(_ painter: AssignViewModel.Person) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(PersonColorSlot(participantIndex: painter.colorIndex).fillColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(.assignPaintBar(painter.name))
                .espText(.subhead)
                .foregroundStyle(Color.esp.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("assign.paintbar")
            Button {
                model.togglePainting(painter.id)
            } label: {
                Text("assign.done")
                    .espText(.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.esp.primary)
                    .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("assign.paintbar.done")
        }
        .padding(.horizontal, Spacing.screenMargin)
    }
}

/// Review split pressed with items left: what is missing, why it matters, and the one-tap way out.
struct AssignWarningBanner: View {
    let count: Int
    let onSplitRest: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the icon goes above the words instead of taking a quarter of the width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
        layout {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.esp.warn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(.assignWarnTitle(count)).espText(.headline)
                    Text(count == 1 ? "assign.warn.bodyOne" : "assign.warn.bodyMany")
                        .espText(.footnote)
                        .foregroundStyle(Color.esp.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("assign.warning")

                Button("assign.restEven", action: onSplitRest)
                    .buttonStyle(.espSecondary)
                    .accessibilityIdentifier("assign.restEven")
            }
        }
        .padding(Spacing.md)
        .background(Color.esp.warnSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
