//
//  Formatting.swift
//  Monitorizacion
//
//  Formateo compartido y escala de color por temperatura.
//

import SwiftUI

extension UInt64 {
    /// Tamaño legible ("12,4 GB").
    var byteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}

extension Double {
    /// Tasa por segundo ("3,2 MB/s"). Acota el valor porque convertir un
    /// `Double` infinito o fuera de rango a `Int64` aborta el proceso.
    var byteRate: String {
        guard isFinite, self >= 1 else { return "0 KB/s" }
        let bytes = Int64(min(self, Double(Int64.max / 2)))
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + "/s"
    }

    /// Fracción 0...1 como porcentaje entero.
    var percent: String { String(format: "%.0f %%", self * 100) }

    var oneDecimal: String { String(format: "%.1f", self) }

    /// Grados con un decimal.
    var degrees: String { String(format: "%.1f °C", self) }
}

extension TimeInterval {
    /// Duración abreviada ("1 h 24 min").
    var compactDuration: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min \(total % 60) s" }
        return "\(total) s"
    }
}

nonisolated enum TemperatureScale {
    /// Color por tramos. Los Apple Silicon trabajan cómodos por debajo de 70 °C
    /// y empiezan a limitar frecuencia cerca de los 100 °C.
    static func color(_ celsius: Double) -> Color {
        switch celsius {
        case ..<60: return .green
        case ..<80: return .yellow
        case ..<95: return .orange
        default: return .red
        }
    }

    static func description(_ celsius: Double) -> String {
        switch celsius {
        case ..<60: return "Fresco"
        case ..<80: return "Templado"
        case ..<95: return "Caliente"
        default: return "Muy caliente"
        }
    }
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Templado"
        case .serious: return "Limitando"
        case .critical: return "Crítico"
        @unknown default: return "Desconocido"
        }
    }

    var color: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    /// Explicación de qué está haciendo el sistema en ese estado.
    var explanation: String {
        switch self {
        case .nominal: return "El sistema no está limitando el rendimiento."
        case .fair: return "Temperatura en aumento, sin límites todavía."
        case .serious: return "macOS está reduciendo el rendimiento para bajar la temperatura."
        case .critical: return "El sistema recorta el rendimiento de forma agresiva."
        @unknown default: return ""
        }
    }
}
