import Foundation

/// A small, dependency-free JSON value. Public food APIs are loosely typed (numbers arrive as strings, fields appear
/// and vanish), so the mappers read through this tree instead of strict `Decodable` models, and parsing behaves the
/// same on every platform.
public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public struct ParseError: Error, Equatable, Sendable {
        public let offset: Int
        public let reason: String
    }

    public static func parse(_ data: Data) throws -> JSONValue {
        var parser = Parser(bytes: [UInt8](data))
        parser.skipWhitespace()
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.index == parser.bytes.count else { throw parser.error("trailing characters") }
        return value
    }

    // MARK: Accessors

    public subscript(key: String) -> JSONValue? {
        if case let .object(dictionary) = self { return dictionary[key] }
        return nil
    }

    public subscript(index: Int) -> JSONValue? {
        if case let .array(items) = self, items.indices.contains(index) { return items[index] }
        return nil
    }

    public var array: [JSONValue]? {
        if case let .array(items) = self { return items }
        return nil
    }

    public var object: [String: JSONValue]? {
        if case let .object(dictionary) = self { return dictionary }
        return nil
    }

    /// Strings pass through; numbers are rendered without a spurious ".0" (barcodes sometimes arrive as numbers).
    public var string: String? {
        switch self {
        case let .string(text): return text
        case let .number(number):
            if number == number.rounded(), abs(number) < 1e15 { return String(Int64(number)) }
            return String(number)
        default: return nil
        }
    }

    /// Numbers pass through; strings are parsed leniently ("12.5", "12,5", " 3 ").
    public var double: Double? {
        switch self {
        case let .number(number): return number.isFinite ? number : nil
        case let .string(text):
            let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(trimmed), value.isFinite else { return nil }
            return value
        default: return nil
        }
    }

    public var int: Int? {
        guard let value = double, value == value.rounded(), abs(value) < 1e15 else { return nil }
        return Int(value)
    }

    public var bool: Bool? {
        switch self {
        case let .bool(flag): return flag
        case let .number(number): return number == 1 ? true : (number == 0 ? false : nil)
        case let .string(text): return ["1", "true"].contains(text.lowercased()) ? true : (["0", "false"].contains(text.lowercased()) ? false : nil)
        default: return nil
        }
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Strings in an array, ignoring non-strings.
    public var strings: [String] {
        (array ?? []).compactMap { $0.string }
    }

    // MARK: Parser

    private struct Parser {
        let bytes: [UInt8]
        var index = 0

        init(bytes: [UInt8]) {
            self.bytes = bytes
            // Skip a UTF-8 byte order mark.
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { index = 3 }
        }

        func error(_ reason: String) -> ParseError { ParseError(offset: index, reason: reason) }

        mutating func skipWhitespace() {
            while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
        }

        mutating func parseValue(depth: Int) throws -> JSONValue {
            guard depth < 64 else { throw error("nesting too deep") }
            guard index < bytes.count else { throw error("unexpected end") }
            switch bytes[index] {
            case UInt8(ascii: "{"): return try parseObject(depth: depth)
            case UInt8(ascii: "["): return try parseArray(depth: depth)
            case UInt8(ascii: "\""): return .string(try parseString())
            case UInt8(ascii: "t"): try expect("true"); return .bool(true)
            case UInt8(ascii: "f"): try expect("false"); return .bool(false)
            case UInt8(ascii: "n"): try expect("null"); return .null
            default: return try parseNumber()
            }
        }

        mutating func expect(_ literal: String) throws {
            let expected = Array(literal.utf8)
            guard index + expected.count <= bytes.count, Array(bytes[index..<(index + expected.count)]) == expected else {
                throw error("invalid literal")
            }
            index += expected.count
        }

        mutating func parseObject(depth: Int) throws -> JSONValue {
            index += 1
            var result: [String: JSONValue] = [:]
            skipWhitespace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "}") { index += 1; return .object(result) }
            while true {
                skipWhitespace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw error("expected key") }
                let key = try parseString()
                skipWhitespace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw error("expected ':'") }
                index += 1
                skipWhitespace()
                result[key] = try parseValue(depth: depth + 1)
                skipWhitespace()
                guard index < bytes.count else { throw error("unterminated object") }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "}") { index += 1; return .object(result) }
                throw error("expected ',' or '}'")
            }
        }

        mutating func parseArray(depth: Int) throws -> JSONValue {
            index += 1
            var result: [JSONValue] = []
            skipWhitespace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "]") { index += 1; return .array(result) }
            while true {
                skipWhitespace()
                result.append(try parseValue(depth: depth + 1))
                skipWhitespace()
                guard index < bytes.count else { throw error("unterminated array") }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "]") { index += 1; return .array(result) }
                throw error("expected ',' or ']'")
            }
        }

        mutating func parseNumber() throws -> JSONValue {
            let start = index
            while index < bytes.count, "+-0123456789.eE".utf8.contains(bytes[index]) { index += 1 }
            guard index > start, let text = String(bytes: bytes[start..<index], encoding: .utf8), let value = Double(text) else {
                index = start
                throw error("invalid number")
            }
            return .number(value)
        }

        mutating func parseHex4() throws -> UInt32 {
            guard index + 4 <= bytes.count else { throw error("short unicode escape") }
            var value: UInt32 = 0
            for _ in 0..<4 {
                let byte = bytes[index]
                let digit: UInt32
                switch byte {
                case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt32(byte - UInt8(ascii: "0"))
                case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt32(byte - UInt8(ascii: "a")) + 10
                case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = UInt32(byte - UInt8(ascii: "A")) + 10
                default: throw error("bad unicode escape")
                }
                value = value * 16 + digit
                index += 1
            }
            return value
        }

        mutating func parseString() throws -> String {
            index += 1 // opening quote
            var buffer: [UInt8] = []
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "\"") {
                    index += 1
                    guard let text = String(bytes: buffer, encoding: .utf8) else { throw error("invalid UTF-8") }
                    return text
                }
                if byte == UInt8(ascii: "\\") {
                    index += 1
                    guard index < bytes.count else { break }
                    let escape = bytes[index]
                    index += 1
                    switch escape {
                    case UInt8(ascii: "\""): buffer.append(UInt8(ascii: "\""))
                    case UInt8(ascii: "\\"): buffer.append(UInt8(ascii: "\\"))
                    case UInt8(ascii: "/"): buffer.append(UInt8(ascii: "/"))
                    case UInt8(ascii: "b"): buffer.append(0x08)
                    case UInt8(ascii: "f"): buffer.append(0x0C)
                    case UInt8(ascii: "n"): buffer.append(0x0A)
                    case UInt8(ascii: "r"): buffer.append(0x0D)
                    case UInt8(ascii: "t"): buffer.append(0x09)
                    case UInt8(ascii: "u"):
                        var scalarValue = try parseHex4()
                        if (0xD800...0xDBFF).contains(scalarValue) {
                            // High surrogate: a low surrogate escape must follow.
                            guard index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") else {
                                throw error("lone surrogate")
                            }
                            index += 2
                            let low = try parseHex4()
                            guard (0xDC00...0xDFFF).contains(low) else { throw error("bad surrogate pair") }
                            scalarValue = 0x10000 + ((scalarValue - 0xD800) << 10) + (low - 0xDC00)
                        }
                        guard let scalar = Unicode.Scalar(scalarValue) else { throw error("invalid scalar") }
                        buffer.append(contentsOf: Array(String(Character(scalar)).utf8))
                    default:
                        throw error("invalid escape")
                    }
                } else {
                    buffer.append(byte)
                    index += 1
                }
            }
            throw error("unterminated string")
        }
    }
}
