import Foundation

public enum StringSimilarity {
    /// Normalized Levenshtein similarity in \[0, 1\].
    public static func normalized(_ a: String, _ b: String) -> Double {
        let left = normalize(a)
        let right = normalize(b)
        if left == right { return 1.0 }
        if left.isEmpty || right.isEmpty { return 0.0 }
        let distance = editDistance(left, right)
        let maxLen = max(left.count, right.count)
        return 1.0 - Double(distance) / Double(maxLen)
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dp[i][0] = i }
        for j in 0...b.count { dp[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }
        return dp[a.count][b.count]
    }
}
