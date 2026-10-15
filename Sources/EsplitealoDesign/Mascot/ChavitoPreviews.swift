import SwiftUI

private struct ChavitoGallery: View {
    let appearance: ColorScheme
    var disc = false
    var sizes: [CGFloat] = [48, 96, 144]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(ChavitoExpression.allCases, id: \.self) { expression in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expression.rawValue).font(.caption.monospaced())
                        HStack(alignment: .bottom, spacing: 16) {
                            ForEach(sizes, id: \.self) { size in
                                ChavitoView(expression: expression, size: size, disc: disc)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(appearance == .dark ? Color(.sRGB, red: 15 / 255, green: 42 / 255, blue: 33 / 255) : Color(.sRGB, red: 251 / 255, green: 247 / 255, blue: 239 / 255))
        .environment(\.colorScheme, appearance)
    }
}

#Preview("Expressions, light") { ChavitoGallery(appearance: .light) }
#Preview("Expressions, dark") { ChavitoGallery(appearance: .dark) }
#Preview("Pink disc, light") { ChavitoGallery(appearance: .light, disc: true, sizes: [64, 120, 200]) }
#Preview("Pink disc, dark") { ChavitoGallery(appearance: .dark, disc: true, sizes: [64, 120, 200]) }

#Preview("Español, decorative off") {
    VStack(spacing: 12) {
        ChavitoView(expression: .thinking, size: 160, disc: true, language: .spanish)
        ChavitoView(expression: .worried, size: 96, language: .english)
        ChavitoView(expression: .happy, size: 64, decorative: true)
    }
    .padding()
}

#Preview("Switching expression (pop reaction)") {
    struct Demo: View {
        @State private var index = 0
        var body: some View {
            VStack(spacing: 16) {
                ChavitoView(expression: ChavitoExpression.allCases[index], size: 180, disc: true)
                Button("Next expression") { index = (index + 1) % ChavitoExpression.allCases.count }
            }
            .padding()
        }
    }
    return Demo()
}
