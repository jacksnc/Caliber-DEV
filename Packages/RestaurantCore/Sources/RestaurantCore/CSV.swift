import Foundation

public enum CSVError: Error, Equatable, Sendable {
    case unterminatedQuote(row: Int)
}

/// RFC 4180 parser: quoted fields, doubled quotes, embedded commas and newlines, CRLF/LF/CR line ends, UTF-8 BOM.
/// Works on unicode scalars because Swift treats "\r\n" as a single Character.
public enum CSV {
    public static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var fieldWasQuoted = false

        let scalars = Array(text.unicodeScalars)
        var index = 0
        if scalars.first == "\u{FEFF}" { index = 1 }

        func endField() {
            fields.append(String(field))
            field = String.UnicodeScalarView()
            fieldWasQuoted = false
        }
        func endRow() {
            endField()
            // Blank lines carry no data.
            if !(fields.count == 1 && fields[0].isEmpty) { rows.append(fields) }
            fields = []
        }

        while index < scalars.count {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else {
                switch scalar {
                case "\"" where field.isEmpty && !fieldWasQuoted:
                    inQuotes = true
                    fieldWasQuoted = true
                case ",":
                    endField()
                case "\n":
                    endRow()
                case "\r":
                    endRow()
                    if index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
                default:
                    field.append(scalar)
                }
            }
            index += 1
        }
        if inQuotes { throw CSVError.unterminatedQuote(row: rows.count + 1) }
        if !field.isEmpty || !fields.isEmpty || fieldWasQuoted { endRow() }
        return rows
    }
}
