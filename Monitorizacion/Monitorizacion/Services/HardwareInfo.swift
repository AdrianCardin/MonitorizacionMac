//
//  HardwareInfo.swift
//  Monitorizacion
//
//  Datos del equipo que no cambian mientras la app está abierta, y utilidades
//  de sysctl compartidas por los demás lectores.
//

import Foundation

nonisolated enum Sysctl {
    /// Lee una clave de sysctl como texto.
    static func string(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    /// Lee una clave de sysctl como entero.
    static func integer(_ key: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname(key, &value, &size, nil, 0) == 0 { return Int(value) }
        // Algunas claves son de 32 bits.
        var small: Int32 = 0
        var smallSize = MemoryLayout<Int32>.size
        guard sysctlbyname(key, &small, &smallSize, nil, 0) == 0 else { return nil }
        return Int(small)
    }

    /// Lee una struct completa de sysctl.
    static func value<T>(_ key: String, as type: T.Type) -> T? {
        var size = MemoryLayout<T>.stride
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard sysctlbyname(key, pointer, &size, nil, 0) == 0 else { return nil }
        return pointer.pointee
    }
}

nonisolated enum HardwareInfo {

    /// Describe los clusters de núcleos usando los nombres que publica el propio
    /// sistema (`hw.perflevelN.name`), en lugar de asumir "rendimiento" y
    /// "eficiencia": los nombres y el reparto cambian según el chip.
    ///
    /// El kernel enumera los núcleos en `host_processor_info` siguiendo el orden
    /// de los niveles, así que el nivel 0 ocupa los primeros índices.
    static func clusters() -> [ClusterUsage] {
        let levels = Sysctl.integer("hw.nperflevels") ?? 1
        return (0..<levels).compactMap { level in
            guard let count = Sysctl.integer("hw.perflevel\(level).logicalcpu"), count > 0 else { return nil }
            let name = Sysctl.string("hw.perflevel\(level).name") ?? "Nivel \(level)"
            return ClusterUsage(name: name, coreCount: count)
        }
    }

    static func summary() -> HardwareSummary {
        var summary = HardwareSummary()
        summary.modelIdentifier = Sysctl.string("hw.model") ?? "Mac"
        summary.chip = Sysctl.string("machdep.cpu.brand_string") ?? "Apple silicon"
        summary.coreCount = Sysctl.integer("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount
        summary.clusters = clusters()
        summary.physicalMemory = ProcessInfo.processInfo.physicalMemory

        let os = ProcessInfo.processInfo.operatingSystemVersion
        summary.osVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        if let boot = Sysctl.value("kern.boottime", as: timeval.self) {
            summary.bootDate = Date(timeIntervalSince1970: Double(boot.tv_sec))
        }
        return summary
    }
}
