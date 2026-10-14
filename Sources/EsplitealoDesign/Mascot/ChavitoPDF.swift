import SwiftUI

/// Vector PDF of a reference export, rendered from the same SwiftUI view the app uses.
@MainActor
public enum ChavitoPDF {
    /// One art unit is one point, so the page is 200 × 190 pt (head) or 208 × 208 pt (disc).
    public static func data(for variant: ChavitoExportVariant) -> Data? {
        let palette = ChavitoPalette.palette(for: variant.appearance)
        let width = ChavitoMetrics.viewBox(disc: variant.disc).width
        let content = ChavitoView(
            expression: variant.expression,
            size: width,
            disc: variant.disc,
            decorative: true,
            animated: false
        )
        .background(variant.includesGround ? palette.ground.color : Color.clear)
        .environment(\.colorScheme, variant.appearance == .dark ? .dark : .light)

        let renderer = ImageRenderer(content: content)
        let output = NSMutableData()
        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: output as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            wrote = true
        }
        return wrote ? output as Data : nil
    }

    public static func mediaBox(of data: Data) -> CGRect? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else { return nil }
        return page.getBoxRect(.mediaBox)
    }
}
