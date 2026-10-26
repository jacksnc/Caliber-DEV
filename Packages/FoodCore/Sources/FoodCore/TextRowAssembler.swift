import Foundation

/// One piece of recognised text with its position, in the normalised coordinates Vision reports
/// (origin at the bottom-left, so larger `midY` means higher on the page).
public struct TextFragment: Equatable, Sendable {
    public var text: String
    public var minX: Double
    public var midY: Double
    public var height: Double

    public init(text: String, minX: Double, midY: Double, height: Double) {
        self.text = text
        self.minX = minX
        self.midY = midY
        self.height = height
    }
}

/// Text recognition returns a nutrition panel as separate fragments ("Total Fat" on the left, "8g" and "10%" in the
/// columns on the right). This rebuilds the printed rows so `LabelParser` sees "Total Fat 8g 10%" as one line.
public enum TextRowAssembler {
    /// - Parameter tolerance: how far apart (as a fraction of text height) two fragments' centres may be and still share a row.
    public static func rows(from fragments: [TextFragment], tolerance: Double = 0.6) -> [String] {
        let usable = fragments.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let sorted = usable.sorted { $0.midY > $1.midY }

        var rows: [[TextFragment]] = []
        var rowCenters: [Double] = []
        var rowHeights: [Double] = []
        for fragment in sorted {
            if let last = rows.indices.last, abs(fragment.midY - rowCenters[last]) <= tolerance * max(fragment.height, rowHeights[last]) {
                rows[last].append(fragment)
                let count = Double(rows[last].count)
                rowCenters[last] += (fragment.midY - rowCenters[last]) / count
                rowHeights[last] = max(rowHeights[last], fragment.height)
            } else {
                rows.append([fragment])
                rowCenters.append(fragment.midY)
                rowHeights.append(fragment.height)
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }
                .map { $0.text.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }
    }
}
