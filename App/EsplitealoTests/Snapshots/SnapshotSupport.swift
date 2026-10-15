import EsplitealoDesign
import SnapshotTesting
import SwiftUI
import UIKit

/// How a screen or component is rendered for a snapshot: appearance, language and Dynamic Type size.
///
/// References are recorded on **iPhone 16, iOS 18.6** (the simulator `Scripts/ios-simulator-udid.sh 18` picks) and
/// compared with a small tolerance, so anti-aliasing noise passes but a changed colour, size, string or layout fails.
struct SnapshotVariant: Sendable {
    let name: String
    let colorScheme: ColorScheme
    let language: String
    let dynamicType: DynamicTypeSize

    static let lightSpanish = SnapshotVariant(name: "light-es", colorScheme: .light, language: "es", dynamicType: .large)
    static let darkSpanish = SnapshotVariant(name: "dark-es", colorScheme: .dark, language: "es", dynamicType: .large)
    static let lightEnglish = SnapshotVariant(name: "light-en", colorScheme: .light, language: "en", dynamicType: .large)
    static let darkEnglish = SnapshotVariant(name: "dark-en", colorScheme: .dark, language: "en", dynamicType: .large)
    static let largeTextSpanish = SnapshotVariant(name: "light-es-xxxl", colorScheme: .light, language: "es", dynamicType: .accessibility3)

    /// The set every component is checked in: both appearances, both languages, and the largest type.
    static let standard: [SnapshotVariant] = [.lightSpanish, .darkSpanish, .lightEnglish, .largeTextSpanish]
}

@MainActor
func assertDesignSnapshot(
    _ content: some View,
    named name: String,
    variants: [SnapshotVariant] = SnapshotVariant.standard,
    width: CGFloat = 390,
    fixedHeight: CGFloat? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    DesignFonts.registerAll()
    for variant in variants {
        let framed = content
            .frame(width: width)
            .frame(maxHeight: fixedHeight == nil ? nil : fixedHeight)
            .background(Color.esp.paper)
            .environment(\.locale, Locale(identifier: variant.language))
            .environment(\.dynamicTypeSize, variant.dynamicType)
            .environment(\.colorScheme, variant.colorScheme)
        let controller = UIHostingController(rootView: framed)
        controller.overrideUserInterfaceStyle = variant.colorScheme == .dark ? .dark : .light
        let layout: SwiftUISnapshotLayout = fixedHeight.map { .fixed(width: width, height: $0) } ?? .sizeThatFits
        assertSnapshot(
            of: controller,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.97,
                layout: layout,
                traits: UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: variant.colorScheme == .dark ? .dark : .light),
                    UITraitCollection(displayScale: 2),
                ])
            ),
            named: "\(name).\(variant.name)",
            file: file,
            testName: testName,
            line: line
        )
    }
}
