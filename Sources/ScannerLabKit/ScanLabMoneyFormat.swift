import Foundation

enum ScanLabMoneyFormat {
    static func dollars(fromMinorUnits minor: Int) -> String {
        let sign = minor < 0 ? "-" : ""
        let absMinor = abs(minor)
        let dollars = absMinor / 100
        let cents = absMinor % 100
        return String(format: "%@%d.%02d", sign, dollars, cents)
    }
}
