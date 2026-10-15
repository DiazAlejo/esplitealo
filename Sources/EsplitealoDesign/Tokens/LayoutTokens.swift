import CoreGraphics

/// 4 pt base with steps of 4, 8, 12, 16, 24 and 32. Side margins are 16 pt.
public enum Spacing {
    public static let all: [CGFloat] = [4, 8, 12, 16, 24, 32]
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let screenMargin: CGFloat = 16
}

public enum Radius {
    public static let card: CGFloat = 16
    public static let sheet: CGFloat = 24
    public static let smallButton: CGFloat = 12
}

public enum Stroke {
    public static let hairline: CGFloat = 1
    /// The raised "lip" under the one primary button of a screen.
    public static let buttonLip: CGFloat = 3
}

public enum TapTarget {
    public static let minimum: CGFloat = 44
    public static let primaryButtonHeight: CGFloat = 56
    public static let secondaryButtonHeight: CGFloat = 52
}

public enum PressFeedback {
    public static let brightness: Double = 0.8
    public static let scale: CGFloat = 0.97
    public static let duration: Double = 0.1
}
