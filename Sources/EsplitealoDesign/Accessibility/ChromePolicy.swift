import SwiftUI

/// Which bars a screen pins to its top or bottom edge. Pinned bars are for people with room to spare: at the biggest
/// text sizes, and in landscape on a phone, they would cover the content, so they scroll with it instead.
public enum ChromePolicy {
    private static func isCompact(_ verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        verticalSizeClass == .compact
    }

    /// A header with a title, a meter and chips (Mark items): pinned in portrait up to xxLarge. From xxxLarge on, an
    /// iPhone SE (667 pt tall) would have less than half the screen left for the list.
    public static func pinsHeader(dynamicTypeSize: DynamicTypeSize, verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        dynamicTypeSize <= .xxLarge && !isCompact(verticalSizeClass)
    }

    /// A bar that holds one button (56 pt): pinned until AX4, because up to AX3 it still leaves most of the screen.
    public static func pinsActionBar(dynamicTypeSize: DynamicTypeSize, verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        dynamicTypeSize < .accessibility4
    }

    /// Secondary buttons and notes next to the main button: pinned in portrait up to xxLarge, otherwise inline.
    public static func pinsExtraActions(dynamicTypeSize: DynamicTypeSize, verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        dynamicTypeSize <= .xxLarge && !isCompact(verticalSizeClass)
    }
}
