import Foundation

/// GS1 check-digit arithmetic and UPC-E zero-suppression. Pure functions on ASCII digit strings.
public enum GS1 {
    static func isASCIIDigits(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }

    /// Digit values of an all-digit string, or nil if any character is not an ASCII digit.
    static func digitValues(_ text: String) -> [Int]? {
        guard isASCIIDigits(text) else { return nil }
        return text.utf8.map { Int($0) - 48 }
    }

    /// Check digit for `body` (the code without its final digit).
    /// Digits are weighted 3,1,3,1... starting with the digit next to the check digit.
    public static func checkDigit(forBody body: String) -> Int? {
        guard let digits = digitValues(body) else { return nil }
        return checkDigit(forBody: digits)
    }

    static func checkDigit(forBody digits: [Int]) -> Int {
        var sum = 0
        var weight = 3
        for digit in digits.reversed() {
            sum += digit * weight
            weight = 4 - weight
        }
        return (10 - sum % 10) % 10
    }

    /// True when `code` is all digits and its last digit is the correct check digit for the rest.
    public static func isValid(_ code: String) -> Bool {
        guard let digits = digitValues(code), digits.count >= 2 else { return false }
        return checkDigit(forBody: Array(digits.dropLast())) == digits[digits.count - 1]
    }

    public static func appendingCheckDigit(to body: String) -> String? {
        checkDigit(forBody: body).map { body + String($0) }
    }

    // MARK: UPC-E

    /// Expands an 8-digit UPC-E (number system, six digits, check digit) to its 12-digit UPC-A.
    /// Returns nil unless the number system is 0 or 1 and the check digit matches the expanded code.
    public static func expandUPCE(_ upcE: String) -> String? {
        guard let d = digitValues(upcE), d.count == 8, d[0] <= 1 else { return nil }
        let numberSystem = d[0]
        let c = Array(d[1...6])
        let body: [Int]
        switch c[5] {
        case 0, 1, 2:
            body = [numberSystem, c[0], c[1], c[5], 0, 0, 0, 0, c[2], c[3], c[4]]
        case 3:
            body = [numberSystem, c[0], c[1], c[2], 0, 0, 0, 0, 0, c[3], c[4]]
        case 4:
            body = [numberSystem, c[0], c[1], c[2], c[3], 0, 0, 0, 0, 0, c[4]]
        default:
            body = [numberSystem, c[0], c[1], c[2], c[3], c[4], 0, 0, 0, 0, c[5]]
        }
        guard checkDigit(forBody: body) == d[7] else { return nil }
        return (body + [d[7]]).map(String.init).joined()
    }

    /// Zero-suppresses a 12-digit UPC-A into UPC-E when the code allows it (number system 0 or 1 only).
    public static func compressUPCA(_ upcA: String) -> String? {
        guard let d = digitValues(upcA), d.count == 12, d[0] <= 1, isValid(upcA) else { return nil }
        let ns = d[0]
        let m = Array(d[1...5])
        let p = Array(d[6...10])
        let check = d[11]
        let core: [Int]
        if m[2] <= 2, m[3] == 0, m[4] == 0, p[0] == 0, p[1] == 0 {
            core = [m[0], m[1], p[2], p[3], p[4], m[2]]
        } else if m[3] == 0, m[4] == 0, p[0] == 0, p[1] == 0, p[2] == 0 {
            core = [m[0], m[1], m[2], p[3], p[4], 3]
        } else if m[4] == 0, p[0] == 0, p[1] == 0, p[2] == 0, p[3] == 0 {
            core = [m[0], m[1], m[2], m[3], p[4], 4]
        } else if p[0] == 0, p[1] == 0, p[2] == 0, p[3] == 0, p[4] >= 5 {
            core = [m[0], m[1], m[2], m[3], m[4], p[4]]
        } else {
            return nil
        }
        return ([ns] + core + [check]).map(String.init).joined()
    }
}
