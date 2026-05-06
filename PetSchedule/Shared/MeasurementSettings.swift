import Foundation

// MARK: - Weight Unit

enum WeightUnit: String {
    case kg    = "kg"
    case stone = "stone"

    static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "kg") ?? .kg
    }

    var label: String {
        switch self {
        case .kg:    return "kg"
        case .stone: return "st"
        }
    }

    var pickerLabel: String {
        switch self {
        case .kg:    return "Kilograms (kg)"
        case .stone: return "Stone (st)"
        }
    }

    func displayValue(fromKg kg: Double) -> Double {
        switch self {
        case .kg:    return kg
        case .stone: return kg / 6.35029
        }
    }

    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg:    return value
        case .stone: return value * 6.35029
        }
    }

    func formatValue(_ kg: Double) -> String {
        String(format: "%.1f \(label)", displayValue(fromKg: kg))
    }

    func formatChange(_ kgDiff: Double) -> String {
        let val = displayValue(fromKg: abs(kgDiff))
        let sign = kgDiff >= 0 ? "+" : "-"
        return String(format: "\(sign)%.1f \(label)", val)
    }
}

// MARK: - Height Unit

enum HeightUnit: String {
    case cm       = "cm"
    case imperial = "imperial"

    static var current: HeightUnit {
        HeightUnit(rawValue: UserDefaults.standard.string(forKey: "heightUnit") ?? "cm") ?? .cm
    }

    /// Short label used next to text fields
    var inputLabel: String {
        switch self {
        case .cm:       return "cm"
        case .imperial: return "in"
        }
    }

    var pickerLabel: String {
        switch self {
        case .cm:       return "Centimetres (cm)"
        case .imperial: return "Feet & Inches"
        }
    }

    func displayValue(fromCm cm: Double) -> Double {
        switch self {
        case .cm:       return cm
        case .imperial: return cm / 2.54
        }
    }

    func toCm(_ value: Double) -> Double {
        switch self {
        case .cm:       return value
        case .imperial: return value * 2.54
        }
    }

    /// Human-readable string for displaying a stored cm value
    func formatValue(_ cm: Double) -> String {
        switch self {
        case .cm:
            return String(format: "%.1f cm", cm)
        case .imperial:
            let totalIn = cm / 2.54
            if totalIn >= 12 {
                let ft = Int(totalIn / 12)
                let inches = totalIn.truncatingRemainder(dividingBy: 12)
                return String(format: "%d ft %.0f in", ft, inches)
            } else {
                return String(format: "%.1f in", totalIn)
            }
        }
    }

    func formatChange(_ cmDiff: Double) -> String {
        let absVal = abs(cmDiff)
        let sign = cmDiff >= 0 ? "+" : "-"
        switch self {
        case .cm:
            return String(format: "\(sign)%.1f cm", absVal)
        case .imperial:
            return String(format: "\(sign)%.1f in", absVal / 2.54)
        }
    }
}

// MARK: - Time Format

enum TimeFormat: String {
    case twelveHour     = "12h"
    case twentyFourHour = "24h"

    static var current: TimeFormat {
        TimeFormat(rawValue: UserDefaults.standard.string(forKey: "timeFormat") ?? "24h") ?? .twentyFourHour
    }

    var dateFormat: String {
        switch self {
        case .twelveHour:     return "h:mm a"
        case .twentyFourHour: return "HH:mm"
        }
    }

    var pickerLabel: String {
        switch self {
        case .twelveHour:     return "12-hour"
        case .twentyFourHour: return "24-hour"
        }
    }
}
