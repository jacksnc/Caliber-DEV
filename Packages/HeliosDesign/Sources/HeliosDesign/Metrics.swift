import Foundation

extension HeliosTokens {
    /// One-based spacing step, mirroring the CSS `--space-N` variables: `space(1)` is 4, `space(4)` is 16.
    public static func space(_ step: Int) -> Double {
        spacing[min(max(step - 1, 0), spacing.count - 1)]
    }
}
