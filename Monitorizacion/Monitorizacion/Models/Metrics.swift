//
//  Metrics.swift
//  Monitorizacion
//
//  Tipos de datos de una lectura del sistema. Todo son structs de valores
//  (Sendable) porque el muestreo ocurre fuera del hilo principal y luego se
//  entrega a la vista.
//

import Foundation

/// Lectura completa del sistema en un instante concreto.
struct Snapshot: Sendable, Identifiable {
    var id: Date { date }
    var date = Date()
    var cpu = CPUMetrics()
    var gpu = GPUMetrics()
    var memory = MemoryMetrics()
    var power = PowerMetrics()
    var thermal = ThermalMetrics()
    var storage = StorageMetrics()
    var network = NetworkMetrics()
    var processes: [ProcessUsage] = []
}

// MARK: - CPU

struct CPUMetrics: Sendable {
    /// Uso global, 0...1.
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    /// Uso por núcleo, 0...1, en el mismo orden que devuelve el kernel.
    var perCore: [Double] = []
    /// Uso por cluster de rendimiento, con el nombre que reporta el sistema.
    var clusters: [ClusterUsage] = []
    /// Carga media de 1, 5 y 15 minutos.
    var loadAverage: [Double] = []
}

struct ClusterUsage: Sendable, Identifiable {
    var id: String { name }
    /// Nombre tal cual lo da `hw.perflevelN.name` ("Performance", "Efficiency", "Super"...).
    let name: String
    let coreCount: Int
    /// Uso medio del cluster, 0...1.
    var usage: Double = 0
}

// MARK: - GPU

struct GPUMetrics: Sendable {
    var name = ""
    /// Utilización del dispositivo, 0...1.
    var utilization: Double = 0
    var rendererUtilization: Double = 0
    var tilerUtilization: Double = 0
    /// Memoria en uso por el GPU (memoria unificada).
    var memoryInUse: UInt64 = 0
    var memoryAllocated: UInt64 = 0
    var memoryRecommendedMax: UInt64 = 0
    var available = false
}

// MARK: - Memoria

struct MemoryMetrics: Sendable {
    var total: UInt64 = 0
    /// Lo que Monitor de Actividad llama "memoria usada": apps + residente + comprimida.
    var used: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    /// Nivel de presión que publica el kernel.
    var pressure: MemoryPressure = .normal

    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Elevada"
        case .critical: return "Crítica"
        }
    }
}

// MARK: - Energía

struct PowerMetrics: Sendable {
    /// Consumo instantáneo del sistema en vatios. Solo se puede medir con la
    /// batería en uso: es tensión x corriente de la propia batería.
    var watts: Double?
    var charge: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var cycleCount = 0
    /// Salud de la batería, 0...1 (capacidad real frente a la de diseño).
    var health: Double = 0
    var minutesRemaining: Int?
    /// El sistema está limitando la carga por temperatura.
    var chargingThermallyLimited = false
    var hasBattery = false

    /// Qué representa `minutesRemaining`: al descargar es autonomía, al cargar
    /// es lo que falta para llegar al 100 %.
    var remainingLabel: String {
        isCharging ? "Hasta carga completa" : "Autonomía estimada"
    }
}

// MARK: - Temperatura y presión térmica

struct ThermalMetrics: Sendable {
    var sensors: [TemperatureSensor] = []
    var pressure = ProcessInfo.ThermalState.nominal
    /// Vacío en los Mac que no exponen RPM de ventiladores (Apple Silicon).
    var fans: [Fan] = []

    /// Temperatura que mejor representa "cómo está el chip": la más alta de
    /// los sensores del SoC, CPU, GPU y Neural Engine.
    var chipTemperature: Double? {
        sensors.filter(\.kind.isComputeCore).map(\.celsius).max()
    }

    func hottest(_ kind: SensorKind) -> Double? {
        sensors.filter { $0.kind == kind }.map(\.celsius).max()
    }

    func average(_ kind: SensorKind) -> Double? {
        let values = sensors.filter { $0.kind == kind }.map(\.celsius)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

struct TemperatureSensor: Sendable, Identifiable {
    let id: Int
    let name: String
    let kind: SensorKind
    var celsius: Double
}

enum SensorKind: String, Sendable, CaseIterable {
    case soc, cpu, gpu, neuralEngine, memory, battery, storage, other

    var label: String {
        switch self {
        case .soc: return "Chip (SoC)"
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .neuralEngine: return "Neural Engine"
        case .memory: return "Memoria"
        case .battery: return "Batería"
        case .storage: return "Almacenamiento"
        case .other: return "Otros"
        }
    }

    /// Sensores que miden silicio de cómputo, los que importan para throttling.
    var isComputeCore: Bool {
        switch self {
        case .soc, .cpu, .gpu, .neuralEngine: return true
        default: return false
        }
    }
}

struct Fan: Sendable, Identifiable {
    let id: Int
    var rpm: Double
    var minRPM: Double
    var maxRPM: Double
}

// MARK: - Disco y red

struct StorageMetrics: Sendable {
    var total: UInt64 = 0
    var free: UInt64 = 0
    /// Bytes por segundo.
    var readRate: Double = 0
    var writeRate: Double = 0

    var used: UInt64 { total > free ? total - free : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct NetworkMetrics: Sendable {
    /// Bytes por segundo.
    var downloadRate: Double = 0
    var uploadRate: Double = 0
}

// MARK: - Procesos

struct ProcessUsage: Sendable, Identifiable {
    let id: Int32
    let name: String
    /// Porcentaje de CPU, donde 100 equivale a un núcleo saturado.
    var cpuPercent: Double
    var memoryBytes: UInt64
}

// MARK: - Información fija del equipo

struct HardwareSummary: Sendable {
    var modelIdentifier = ""
    var chip = ""
    var coreCount = 0
    var clusters: [ClusterUsage] = []
    var physicalMemory: UInt64 = 0
    var osVersion = ""
    var bootDate = Date()
}
