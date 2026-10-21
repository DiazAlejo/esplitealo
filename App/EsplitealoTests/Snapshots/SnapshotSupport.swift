import EsplitealoDesign
import SnapshotTesting
import SwiftUI
import Testing
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
    /// Named "xxxl" for historical reasons: this one is the accessibility size AX3.
    static let largeTextSpanish = SnapshotVariant(name: "light-es-xxxl", colorScheme: .light, language: "es", dynamicType: .accessibility3)

    // The accessibility matrix (`AccessibilitySnapshotTests`): xxxLarge (the largest size that is not an accessibility
    // size) and AX3 in every appearance and language, plus AX5, the largest size of all. Together with `.largeTextSpanish`
    // (AX3, light, Spanish) every combination of size, appearance and language is covered.
    static let xxxLargeLightSpanish = SnapshotVariant(name: "light-es-xxxLarge", colorScheme: .light, language: "es", dynamicType: .xxxLarge)
    static let xxxLargeDarkEnglish = SnapshotVariant(name: "dark-en-xxxLarge", colorScheme: .dark, language: "en", dynamicType: .xxxLarge)
    static let ax3LightEnglish = SnapshotVariant(name: "light-en-ax3", colorScheme: .light, language: "en", dynamicType: .accessibility3)
    static let ax3DarkSpanish = SnapshotVariant(name: "dark-es-ax3", colorScheme: .dark, language: "es", dynamicType: .accessibility3)
    static let ax3DarkEnglish = SnapshotVariant(name: "dark-en-ax3", colorScheme: .dark, language: "en", dynamicType: .accessibility3)
    static let ax5LightSpanish = SnapshotVariant(name: "light-es-ax5", colorScheme: .light, language: "es", dynamicType: .accessibility5)

    static let accessibilityMatrix: [SnapshotVariant] = [
        .xxxLargeLightSpanish, .xxxLargeDarkEnglish, .ax3LightEnglish, .ax3DarkSpanish, .ax3DarkEnglish, .ax5LightSpanish,
    ]

    /// The set every component is checked in: both appearances, both languages, and the largest type.
    static let standard: [SnapshotVariant] = [.lightSpanish, .darkSpanish, .lightEnglish, .largeTextSpanish]
}

extension DynamicTypeSize {
    /// The UIKit category with the same size, so a hosting controller measures the view at the size the environment says.
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// `App/SnapshotReferences/<test file name>`: kept out of the synchronized app folders so the PNGs are not bundled.
private func referencesDirectory(forTestFile file: StaticString) -> String {
    let testFile = URL(fileURLWithPath: "\(file)")
    return testFile
        .deletingLastPathComponent() // Snapshots
        .deletingLastPathComponent() // EsplitealoTests
        .deletingLastPathComponent() // App
        .appendingPathComponent("SnapshotReferences", isDirectory: true)
        .appendingPathComponent(testFile.deletingPathExtension().lastPathComponent, isDirectory: true)
        .path
}

/// Pass `fixedHeight` for content that wraps over several lines: `.sizeThatFits` measures such content at the default
/// text size and clips it in the large-Dynamic-Type variant, although the real layout is fine.
@MainActor
func assertDesignSnapshot(
    _ content: some View,
    named name: String,
    variants: [SnapshotVariant] = SnapshotVariant.standard,
    width: CGFloat = 390,
    fixedHeight: CGFloat? = nil,
    compactHeight: Bool = false,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    DesignFonts.registerAll()
    for variant in variants {
        let framed = content
            .frame(width: width)
            .frame(maxHeight: fixedHeight == nil ? nil : fixedHeight)
            .espScreenBackground()
            .environment(\.locale, Locale(identifier: variant.language))
            .environment(\.dynamicTypeSize, variant.dynamicType)
            .environment(\.colorScheme, variant.colorScheme)
            .environment(\.verticalSizeClass, compactHeight ? .compact : .regular)
        let layout: SwiftUISnapshotLayout = fixedHeight.map { .fixed(width: width, height: $0) } ?? .sizeThatFits
        let style: UIUserInterfaceStyle = variant.colorScheme == .dark ? .dark : .light
        let failure = verifySnapshot(
            of: framed,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.97,
                layout: layout,
                traits: UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(displayScale: 2),
                    // SwiftUI measures the view with the UIKit size category, so it must match the environment.
                    UITraitCollection(preferredContentSizeCategory: variant.dynamicType.uiContentSizeCategory),
                    UITraitCollection(verticalSizeClass: compactHeight ? .compact : .regular),
                ])
            ),
            named: "\(name).\(variant.name)",
            snapshotDirectory: referencesDirectory(forTestFile: file),
            file: file,
            testName: testName,
            line: line
        )
        if let failure {
            Issue.record(Comment(rawValue: failure), sourceLocation: SourceLocation(fileID: "\(fileID)", filePath: "\(file)", line: Int(line), column: 1))
        }
    }
}
